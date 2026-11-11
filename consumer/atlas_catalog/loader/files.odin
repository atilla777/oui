package loader

import "core:crypto/sha2"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import linux "core:sys/linux"
import ui "ui:ui_style"

Loaded_Set :: struct {
	path:           string,
	manifest_bytes: []u8,
	manifest:       Manifest,
	page_bytes:     [][]u8,
	page_paths:     []string,
	decoded:        []Decoded_RGBA,
	catalog:        ui.Atlas_Catalog,
	allocator:      mem.Allocator,
}
load_set :: proc(
	path: string,
	allocator := context.allocator,
) -> (
	result: Loaded_Set,
	error: Load_Error,
) {
	defer {if error.stage != "" && error.path_length == 0 {error_path(&error, path)}}
	s := Loaded_Set {
		allocator = allocator,
	}
	complete := false; defer {if !complete {destroy_loaded_set(&s)}}
	e: Load_Error
	s.manifest_bytes, s.path, e = read_limited(path, 1024 * 1024, "", allocator)
	if e.stage != "" {return {}, e}
	s.manifest, e = parse_manifest(s.manifest_bytes, allocator)
	if e.stage != "" {return {}, e}
	n := len(s.manifest.pages)
	ae: mem.Allocator_Error
	s.page_bytes, ae = make(
		[][]u8,
		n,
		allocator,
	); if ae != nil {return {}, {stage = "staging", field = "allocation"}}
	s.page_paths, ae = make(
		[]string,
		n,
		allocator,
	); if ae != nil {return {}, {stage = "staging", field = "allocation"}}
	s.decoded, ae = make(
		[]Decoded_RGBA,
		n,
		allocator,
	); if ae != nil {return {}, {stage = "staging", field = "allocation"}}
	s.catalog.pages, ae = make(
		[]ui.Atlas_Page_Metadata,
		n,
		allocator,
	); if ae != nil {return {}, {stage = "staging", field = "allocation"}}
	s.catalog.regions = s.manifest.regions[:]
	root, _ := os.split_path(s.path)
	compressed, decoded := 0, 0
	hash: sha2.Context_256; sha2.init_256(&hash)
	identity_part(&hash, s.manifest_bytes)
	for page, i in s.manifest.pages {
		if !safe_relative_page(
			page.file,
		) {return {}, {stage = "path", field = "relative_page", index = i}}
		joined, je := strings.concatenate([]string{root, "/", page.file}, allocator)
		if je != nil {return {}, {stage = "path", field = "allocation", index = i}}
		s.page_bytes[i], s.page_paths[i], e = read_limited(
			joined,
			min(16 * 1024 * 1024, 64 * 1024 * 1024 - compressed),
			root,
			allocator,
		)
		if e.stage != "" {error_path(&e, joined)}
		delete(joined, allocator)
		if e.stage != "" {e.index = i; return {}, e}
		compressed += len(s.page_bytes[i])
		w, h, pe := png_envelope(s.page_bytes[i])
		if pe.stage != "" {return {}, png_load_error(pe, s.page_paths[i], i)}
		bytes := int(u64(w) * u64(h) * 4)
		if bytes >
		   64 * 1024 * 1024 -
			   decoded {return {}, {stage = "decode", field = "total_decoded_limit", index = i}}
		s.decoded[i], pe = decode_png(s.page_bytes[i], allocator)
		if pe.stage != "" {return {}, png_load_error(pe, s.page_paths[i], i)}
		decoded += bytes
		s.catalog.pages[i] = {page.id, {int(w), int(h)}}
		identity_part(&hash, transmute([]u8)page.id)
		identity_part(&hash, s.page_bytes[i])
	}
	digest: [32]u8; sha2.final(&hash, digest[:])
	hex: [64]u8; alphabet := "0123456789abcdef"
	for b, i in digest {hex[2 * i] = alphabet[b >> 4]; hex[2 * i + 1] = alphabet[b & 15]}
	s.catalog.revision, ae = strings.clone(string(hex[:]), allocator)
	if ae != nil {return {}, {stage = "staging", field = "allocation"}}
	if metadata_error, valid := ui.validate_atlas(s.catalog); !valid {
		index := 0
		for region, i in s.catalog.regions {if region.image.id == metadata_error.region {index = i; break}}
		return {}, {stage = "metadata", field = metadata_error.field, index = index}
	}
	complete = true
	return s, {}
}
@(private)
error_path :: proc(error: ^Load_Error, path: string) {error.path_length = copy(
		error.path[:],
		path,
	)}
@(private)
png_load_error :: proc(png: Decode_Error, path: string, index: int) -> Load_Error {
	e := Load_Error {
		stage   = png.stage,
		field   = png.field,
		index   = index,
		message = png.message,
	}
	error_path(&e, path); return e
}
recheck_set :: proc(set: ^Loaded_Set) -> Load_Error {
	a := set.allocator
	b, canonical, e := read_limited(set.path, 1024 * 1024, "", a)
	if e.stage != "" {return e}
	changed := string(b) != string(set.manifest_bytes) || canonical != set.path
	delete(b, a); delete(canonical, a)
	if changed {return {stage = "recheck", field = "Files_Changed"}}
	root, _ := os.split_path(set.path)
	for page, i in set.manifest.pages {
		joined, ae := strings.concatenate([]string{root, "/", page.file}, a)
		if ae != nil {return {stage = "recheck", field = "allocation", index = i}}
		b, canonical, e = read_limited(joined, 16 * 1024 * 1024, root, a)
		delete(joined, a)
		if e.stage != "" {e.index = i; return e}
		changed = string(b) != string(set.page_bytes[i])
		delete(b, a); delete(canonical, a)
		if changed {return {stage = "recheck", field = "Files_Changed", index = i}}
	}
	return {}
}
@(private)
identity_part :: proc(hash: ^sha2.Context_256, bytes: []u8) {
	prefix: [8]u8
	for i in 0 ..< 8 {prefix[7 - i] = u8(u64(len(bytes)) >> u64(8 * i))}
	sha2.update(hash, prefix[:]); sha2.update(hash, bytes)
}
@(private)
safe_relative_page :: proc(path: string) -> bool {
	if path == "" || path[0] == '/' {return false}
	start := 0
	for b, i in path {
		if b == 0 {return false}
		if b == '/' {if path[start:i] == ".." {return false}; start = i + 1}
	}
	return path[start:] != ".."
}
// Linux fd ownership stays on the stack. Resolve the opened fd before reading,
// rather than a lexical absolute path; no os.File allocation can leak this fd.
@(private)
read_limited :: proc(
	path: string,
	limit: int,
	root: string,
	a: mem.Allocator,
) -> (
	[]u8,
	string,
	Load_Error,
) {
	for b in path {if b == 0 {return nil, "", {stage = "path", field = "nul"}}}
	name, ae := strings.clone_to_cstring(path, a)
	if ae != nil {return nil, "", {stage = "read", field = "allocation"}}; defer delete(name, a)
	fd, oe := linux.open(name, {.CLOEXEC, .NONBLOCK})
	if oe != .NONE {return nil, "", {stage = "read", field = "open"}}; defer linux.close(fd)
	stat: linux.Stat
	if linux.fstat(fd, &stat) != .NONE ||
	   !linux.S_ISREG(stat.mode) {return nil, "", {stage = "read", field = "regular_file"}}
	if stat.size > uint(limit) {return nil, "", {stage = "read", field = "input_limit"}}
	link: [64]u8
	link_name := fmt.bprintf(link[:], "/proc/self/fd/%d\x00", fd)
	buffer: [4096]u8
	n, re := linux.readlink(cast(cstring)raw_data(link_name), buffer[:])
	if re != .NONE ||
	   n <= 0 ||
	   n == len(buffer) {return nil, "", {stage = "path", field = "resolve"}}
	canonical := string(buffer[:n])
	if root != "" &&
	   root != "/" &&
	   !(len(canonical) > len(root) &&
			   canonical[:len(root)] == root &&
			   canonical[len(root)] == '/') {return nil, "", {stage = "path", field = "escape"}}
	owned, ce := strings.clone(canonical, a)
	if ce != nil {return nil, "", {stage = "path", field = "allocation"}}
	data, de := make([]u8, int(stat.size), a)
	if de != nil {delete(owned, a); return nil, "", {stage = "read", field = "allocation"}}
	complete := false; defer {if !complete {delete(data, a); delete(owned, a)}}
	pos := 0
	for pos < len(data) {
		count, err := linux.read(fd, data[pos:])
		if err == .EINTR {continue}
		if err != .NONE || count <= 0 {return nil, "", {stage = "read", field = "Files_Changed"}}
		pos += count
	}
	extra: [1]u8
	count, err := linux.read(fd, extra[:])
	if err != .NONE || count != 0 {return nil, "", {stage = "read", field = "Files_Changed"}}
	complete = true
	return data, owned, {}
}
destroy_loaded_set :: proc(set: ^Loaded_Set) {
	a := set.allocator
	for &d in set.decoded {destroy_decoded(&d)}
	for b in set.page_bytes {delete(b, a)}
	for p in set.page_paths {delete(p, a)}
	delete(set.decoded, a); delete(set.page_bytes, a); delete(set.page_paths, a)
	delete(set.catalog.pages, a); delete(set.catalog.revision, a)
	destroy_manifest(&set.manifest)
	delete(set.manifest_bytes, a); delete(set.path, a); set^ = {}
}
