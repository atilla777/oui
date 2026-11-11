package loader

import "core:hash"
import "core:mem"

PNG_LIBRARY :: #config(ATLAS_PNG_LIBRARY, "system:png16")
foreign import libpng_native {PNG_LIBRARY}
foreign import zlib "system:z"
PNG_Image :: struct {
	opaque:                                                                    rawptr,
	version, width, height, format, flags, colormap_entries, warning_or_error: u32,
	message:                                                                   [64]u8,
}
foreign libpng_native {
	png_image_begin_read_from_memory :: proc "c" (image: ^PNG_Image, bytes: rawptr, size: uintptr) -> i32 ---
	png_image_finish_read :: proc "c" (image: ^PNG_Image, background, buffer: rawptr, row_stride: i32, colormap: rawptr) -> i32 ---
	png_image_free :: proc "c" (image: ^PNG_Image) ---
	png_get_libpng_ver :: proc "c" (png: rawptr) -> cstring ---
	png_access_version_number :: proc "c" () -> u32 ---
}
foreign zlib {
	zlibVersion :: proc "c" () -> cstring ---
}
#assert(size_of(PNG_Image) == 104)
#assert(offset_of(PNG_Image, width) == 12)
#assert(offset_of(PNG_Image, warning_or_error) == 32)
#assert(offset_of(PNG_Image, message) == 36)

runtime_versions_match :: proc() -> bool {
	return(
		string(png_get_libpng_ver(nil)) == "1.6.59" &&
		png_access_version_number() == 10659 &&
		string(zlibVersion()) == "1.4" \
	)
}

@(private)
png_u32 :: proc(b: []u8) -> u32 {
	return u32(b[0]) << 24 | u32(b[1]) << 16 | u32(b[2]) << 8 | u32(b[3])
}
// Nonallocating framing/profile pass only; IDAT is decoded solely by libpng.
@(private)
png_envelope :: proc(bytes: []u8) -> (width, height: u32, error: Decode_Error) {
	if len(bytes) > 16 * 1024 * 1024 {return 0, 0, {stage = "envelope", field = "input_limit"}}
	if len(bytes) < 8 ||
	   string(bytes[:8]) !=
		   "\x89PNG\r\n\x1a\n" {return 0, 0, {stage = "envelope", field = "signature"}}
	offset := 8
	ihdr, idat, after_idat := false, false, false
	plte := false
	for offset < len(bytes) {
		if len(bytes) - offset < 12 {return 0, 0, {stage = "envelope", field = "chunk_bounds"}}
		n := u64(png_u32(bytes[offset:]))
		if n >
		   u64(
			   len(bytes) - offset - 12,
		   ) {return 0, 0, {stage = "envelope", field = "chunk_bounds"}}
		end := offset + 8 + int(n)
		kind := string(bytes[offset + 4:offset + 8])
		body := bytes[offset + 8:end]
		if hash.crc32(bytes[offset + 4:end]) !=
		   png_u32(bytes[end:]) {return 0, 0, {stage = "envelope", field = "crc"}}
		if !ihdr && kind != "IHDR" {return 0, 0, {stage = "envelope", field = "IHDR"}}
		switch kind {
		case "IHDR":
			if ihdr || n != 13 {return 0, 0, {stage = "envelope", field = "IHDR"}}
			width, height = png_u32(body), png_u32(body[4:])
			if width < 1 ||
			   width > 4096 ||
			   height < 1 ||
			   height > 4096 {return 0, 0, {stage = "envelope", field = "dimensions"}}
			if body[8] != 8 ||
			   (body[9] != 2 && body[9] != 6) ||
			   body[10] != 0 ||
			   body[11] != 0 ||
			   body[12] != 0 {return 0, 0, {stage = "envelope", field = "profile"}}
			ihdr = true
		case "IDAT":
			if after_idat {return 0, 0, {stage = "envelope", field = "IDAT"}}
			idat = true
		case "PLTE":
			if plte ||
			   idat ||
			   n == 0 ||
			   n > 768 ||
			   n % 3 != 0 {return 0, 0, {stage = "envelope", field = "PLTE"}}
			plte = true
		case "IEND":
			if !idat ||
			   n != 0 ||
			   end + 4 != len(bytes) {return 0, 0, {stage = "envelope", field = "IEND"}}
			return width, height, {}
		case "acTL", "fcTL", "fdAT":
			return 0, 0, {stage = "envelope", field = "APNG"}
		case:
			if bytes[offset + 4] & 32 ==
			   0 {return 0, 0, {stage = "envelope", field = "critical_chunk"}}
		}
		if idat && kind != "IDAT" {after_idat = true}
		offset = end + 4
	}
	return 0, 0, {stage = "envelope", field = "IEND"}
}

Decoded_RGBA :: struct {
	width, height: i32,
	pixels:        []u8,
	allocator:     mem.Allocator,
}
Decode_Error :: struct {
	stage, field: string,
	message:      [64]u8,
}
decode_png :: proc(
	bytes: []u8,
	output_allocator := context.allocator,
) -> (
	Decoded_RGBA,
	Decode_Error,
) {
	if !runtime_versions_match() {return {}, {stage = "runtime", field = "version"}}
	w, h, error := png_envelope(bytes)
	if error.stage != "" {return {}, error}
	native := PNG_Image {
		version = 1,
	}
	defer png_image_free(&native)
	if png_image_begin_read_from_memory(&native, raw_data(bytes), uintptr(len(bytes))) == 0 ||
	   native.warning_or_error != 0 {
		return {}, {stage = "begin", field = "png", message = native.message}
	}
	if native.width != w || native.height != h {return {}, {stage = "begin", field = "dimensions"}}
	stride := u64(w) * 4
	n := stride * u64(h)
	if stride > u64(max(i32)) ||
	   n > 64 * 1024 * 1024 ||
	   n > u64(max(int)) ||
	   n > u64(max(uintptr)) {return {}, {stage = "output", field = "limit"}}
	native.format = 3 // PNG_FORMAT_RGBA; unassociated alpha, 8-bit sRGB.
	pixels, e := mem.alloc_bytes(int(n), allocator = output_allocator)
	if e != nil {return {}, {stage = "output", field = "allocation"}}
	complete := false
	defer {if !complete {delete(pixels, output_allocator)}}
	if png_image_finish_read(&native, nil, raw_data(pixels), i32(stride), nil) == 0 ||
	   native.warning_or_error != 0 {
		return {}, {stage = "finish", field = "png", message = native.message}
	}
	complete = true
	return {i32(w), i32(h), pixels, output_allocator}, {}
}
destroy_decoded :: proc(image: ^Decoded_RGBA) {
	delete(image.pixels, image.allocator); image^ = {}
}
