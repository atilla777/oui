package loader

import "core:encoding/json"
import "core:mem"
import "core:strconv"
import "core:unicode/utf8"
import ui "ui:ui_style"

Page_File :: struct {
	id, file: string,
}
Manifest :: struct {
	pages:     [dynamic]Page_File,
	regions:   [dynamic]ui.Atlas_Region,
	allocator: mem.Allocator,
}
Load_Error :: struct {
	path:         [4096]u8,
	path_length:  int,
	message:      [64]u8,
	stage, field: string,
	index:        int,
}
parse_manifest :: proc(bytes: []u8, allocator := context.allocator) -> (Manifest, Load_Error) {
	m := Manifest {
		allocator = allocator,
	}
	complete := false; defer {if !complete {destroy_manifest(&m)}}
	p := Manifest_Parser {
		allocator = allocator,
	}
	if len(bytes) > 1024 * 1024 ||
	   !utf8.valid_string(string(bytes)) {return {}, {stage = "manifest", field = "input"}}
	p.scanner = json.make_tokenizer(string(bytes), .JSON, true)
	mf_next(&p)
	if !mf_expect(&p, .Open_Brace) {return {}, p.error}
	seen: u32
	for {
		key := mf_member(&p, []string{"version", "pages", "regions"}, &seen)
		if key < 0 {break}
		switch key {
		case 0:
			if mf_integer(&p) != 1 {mf_fail(&p, "version")}
		case 1:
			if !mf_expect(&p, .Open_Bracket) {break}
			for p.token.kind != .Close_Bracket && p.error.stage == "" {
				if len(m.pages) >= 16 {mf_fail(&p, "pages_limit"); break}
				if len(m.pages) > 0 {if !mf_expect(&p, .Comma) {break}}
				page := mf_page(&p)
				if p.error.stage !=
				   "" {delete(page.id, allocator); delete(page.file, allocator); break}
				if _, e := append(&m.pages, page);
				   e !=
				   nil {delete(page.id, allocator); delete(page.file, allocator); mf_fail(&p, "allocation"); break}
			}
			mf_expect(&p, .Close_Bracket)
		case 2:
			if !mf_expect(&p, .Open_Bracket) {break}
			for p.token.kind != .Close_Bracket && p.error.stage == "" {
				if len(m.regions) >= 4096 {mf_fail(&p, "regions_limit"); break}
				if len(m.regions) > 0 {if !mf_expect(&p, .Comma) {break}}
				region := mf_region(&p)
				if p.error.stage !=
				   "" {delete(region.image.id, allocator); delete(region.page_id, allocator); break}
				if _, e := append(&m.regions, region);
				   e !=
				   nil {delete(region.image.id, allocator); delete(region.page_id, allocator); mf_fail(&p, "allocation"); break}
			}
			mf_expect(&p, .Close_Bracket)
		}
		if p.error.stage != "" {break}
	}
	if seen != 7 {mf_fail(&p, "required_field")}
	if p.token.kind != .EOF {mf_fail(&p, "trailing_content")}
	if p.error.stage != "" {return {}, p.error}
	for page, i in m.pages {
		if page.id == "" ||
		   page.file == "" {return {}, {stage = "manifest", field = "page", index = i}}
		for prior in m.pages[:i] {if prior.id == page.id {return {}, {stage = "manifest", field = "duplicate_page", index = i}}}
	}
	for region, i in m.regions {
		if region.image.id == "" ||
		   !ui.valid_image_metadata(
				   region.image,
			   ) {return {}, {stage = "manifest", field = "image", index = i}}
		for prior in m.regions[:i] {if prior.image.id == region.image.id {return {}, {stage = "manifest", field = "duplicate_region", index = i}}}
		found := false; for page in m.pages {if page.id == region.page_id {found = true; break}}
		if !found {return {}, {stage = "manifest", field = "page_reference", index = i}}
	}
	complete = true
	return m, {}
}

// Schema-specific cursor over the standard nonallocating strict JSON tokenizer.
// It deliberately does not use the generic tree parser's unchecked array append.
@(private)
Manifest_Parser :: struct {
	scanner:   json.Tokenizer,
	token:     json.Token,
	allocator: mem.Allocator,
	error:     Load_Error,
}
@(private)
mf_fail :: proc(p: ^Manifest_Parser, field: string) {
	if p.error.stage == "" {p.error = {
			stage = "manifest",
			field = field,
			index = p.token.offset,
		}}
}
@(private)
mf_next :: proc(p: ^Manifest_Parser) {
	if p.error.stage != "" {return}
	token, e := json.get_token(&p.scanner)
	if e != .None && e != .EOF {mf_fail(p, "json"); return}
	p.token = token
}
@(private)
mf_expect :: proc(p: ^Manifest_Parser, kind: json.Token_Kind) -> bool {
	if p.error.stage != "" {return false}
	if p.token.kind != kind {mf_fail(p, "type_or_syntax"); return false}
	mf_next(p); return p.error.stage == ""
}
@(private)
mf_string :: proc(p: ^Manifest_Parser) -> string {
	if p.error.stage != "" {return ""}
	if p.token.kind != .String {mf_fail(p, "string"); return ""}
	s: string
	if e := json.unmarshal_string(p.token.text, &s, .JSON, p.allocator);
	   e != nil {delete(s, p.allocator); mf_fail(p, "string_or_allocation"); return ""}
	mf_next(p); return s
}
@(private)
mf_member :: proc(p: ^Manifest_Parser, names: []string, seen: ^u32) -> int {
	if p.error.stage != "" {return -1}
	if p.token.kind == .Close_Brace {mf_next(p); return -1}
	if seen^ != 0 && !mf_expect(p, .Comma) {return -1}
	name := mf_string(p); defer delete(name, p.allocator)
	if p.error.stage != "" {return -1}
	for expected, i in names {if name == expected {
			bit := u32(1) << u32(i)
			if seen^ & bit != 0 {mf_fail(p, "duplicate_field"); return -1}
			seen^ |= bit
			if !mf_expect(p, .Colon) {return -1}
			return i
		}}
	mf_fail(p, "unknown_field"); return -1
}
@(private)
mf_integer :: proc(p: ^Manifest_Parser) -> int {
	if p.error.stage != "" {return 0}
	if p.token.kind != .Integer {mf_fail(p, "pixel_integer"); return 0}
	v, ok := strconv.parse_i64(p.token.text, 10)
	if !ok || v < i64(min(int)) || v > i64(max(int)) {mf_fail(p, "integer_range"); return 0}
	mf_next(p); return int(v)
}
@(private)
mf_number :: proc(p: ^Manifest_Parser) -> f64 {
	if p.error.stage != "" {return 0}
	if p.token.kind != .Integer && p.token.kind != .Float {mf_fail(p, "number"); return 0}
	v, ok := strconv.parse_f64(p.token.text)
	if !ok || !ui.finite_nonnegative(v) {mf_fail(p, "number_range"); return 0}
	mf_next(p); return v
}
@(private)
mf_int4 :: proc(p: ^Manifest_Parser) -> [4]int {
	r: [4]int
	if !mf_expect(p, .Open_Bracket) {return r}
	for i in 0 ..< 4 {if i > 0 {mf_expect(p, .Comma)}; r[i] = mf_integer(p)}
	mf_expect(p, .Close_Bracket); return r
}
@(private)
mf_page :: proc(p: ^Manifest_Parser) -> Page_File {
	r: Page_File
	if !mf_expect(p, .Open_Brace) {return r}
	seen: u32
	for {
		key := mf_member(p, []string{"id", "file"}, &seen)
		if key < 0 {break}
		if key == 0 {r.id = mf_string(p)} else {r.file = mf_string(p)}
	}
	if seen != 3 {mf_fail(p, "required_page_field")}; return r
}
@(private)
mf_region :: proc(p: ^Manifest_Parser) -> ui.Atlas_Region {
	r: ui.Atlas_Region
	if !mf_expect(p, .Open_Brace) {return r}
	seen: u32
	for {
		key := mf_member(p, []string{"id", "page", "rect", "pivot", "nine_slice"}, &seen)
		if key < 0 {break}
		switch key {
		case 0:
			r.image.id = mf_string(p)
		case 1:
			r.page_id = mf_string(p)
		case 2:
			r.rect = mf_int4(p)
			if r.rect[0] < 0 ||
			   r.rect[1] < 0 ||
			   r.rect[2] <= 0 ||
			   r.rect[3] <= 0 {mf_fail(p, "rect")}
			r.image.source = {f64(r.rect[2]), f64(r.rect[3])}
		case 3:
			mf_expect(p, .Open_Bracket); x := mf_number(p); mf_expect(p, .Comma); y := mf_number(p)
			mf_expect(p, .Close_Bracket)
			if x > 1 || y > 1 {mf_fail(p, "pivot")}
			r.pivot = [2]f64{x, y}
		case 4:
			r.image.nine_slice = mf_nine(p)
		}
	}
	if seen & 7 != 7 {mf_fail(p, "required_region_field")}; return r
}
@(private)
mf_mode :: proc(p: ^Manifest_Parser) -> ui.Slice_Mode {
	s := mf_string(p); defer delete(s, p.allocator)
	if s == "repeat" {return .Repeat}
	if s != "stretch" {mf_fail(p, "slice_mode")}; return .Stretch
}
@(private)
mf_nine :: proc(p: ^Manifest_Parser) -> ui.Nine_Slice_Metadata {
	r: ui.Nine_Slice_Metadata
	if !mf_expect(p, .Open_Brace) {return r}
	seen: u32
	for {
		key := mf_member(
			p,
			[]string {
				"border",
				"texture_scale",
				"edges",
				"center_x",
				"center_y",
				"omit_center",
				"padding",
			},
			&seen,
		)
		if key < 0 {break}
		switch key {
		case 0:
			r.border = mf_int4(p)
		case 1:
			r.texture_scale = mf_number(p)
		case 2:
			r.edges = mf_mode(p)
		case 3:
			r.center_x = mf_mode(p)
		case 4:
			r.center_y = mf_mode(p)
		case 5:
			if p.token.kind != .True && p.token.kind != .False {mf_fail(p, "boolean")}
			r.omit_center = p.token.kind == .True; mf_next(p)
		case 6:
			insets: ui.Insets
			if !mf_expect(p, .Open_Brace) {break}
			padding_seen: u32
			for {
				field := mf_member(p, []string{"left", "top", "right", "bottom"}, &padding_seen)
				if field < 0 {break}
				value := mf_number(p)
				switch field {case 0:
					insets.left = value; case 1:
					insets.top = value; case 2:
					insets.right = value; case 3:
					insets.bottom = value}
			}
			if padding_seen != 15 {mf_fail(p, "required_padding_field")}
			r.padding = insets
		}
	}
	if seen & 63 != 63 {mf_fail(p, "required_nine_slice_field")}; return r
}
destroy_manifest :: proc(m: ^Manifest) {
	for p in m.pages {delete(p.id, m.allocator); delete(p.file, m.allocator)}
	for r in m.regions {delete(r.image.id, m.allocator); delete(r.page_id, m.allocator)}
	delete(m.pages); delete(m.regions); m^ = {}
}
