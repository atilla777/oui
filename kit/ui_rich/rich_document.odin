package ui_rich

import style "../ui_style"
import text "../ui_text"
import graphemes "../unicode_graphemes"
import "core:mem"
import "core:strings"

Text_Source_Range :: text.Text_Source_Range
Color :: style.Color
Update_Error :: text.Update_Error

Rich_Style :: struct {
	font_id:                 string,
	size:                    f64,
	color:                   Color,
	bold, italic, underline: bool,
}
Rich_Run :: struct {
	decoded_range, source_range: Text_Source_Range,
	style:                       Rich_Style,
	image_id, alt:               string,
	width, height:               f64,
}
Rich_Mapping :: struct {
	decoded_range, source_range: Text_Source_Range,
}
Rich_Document :: struct {
	allocator:                 mem.Allocator,
	source, decoded, alt_text: string,
	runs:                      [dynamic]Rich_Run,
	mappings:                  [dynamic]Rich_Mapping,
	tags:                      [dynamic]Text_Source_Range,
}
Rich_Error_Code :: enum {
	None,
	Invalid_UTF8,
	Invalid_Markup,
	Invalid_Attribute,
	Invalid_Grapheme_Boundary,
	Unsupported_Text_Control,
	Rich_Limit_Exceeded,
	Existing,
	Invalid_Text_Options,
	Resource_Missing,
	Glyph_Missing,
	Metrics_Failed,
	Invalid_Geometry,
	Allocation,
}
Rich_Error :: struct {
	code:         Rich_Error_Code,
	id:           string,
	source_range: Text_Source_Range,
	reason:       string,
	existing:     Update_Error,
}
parse_rich_text :: proc(
	source: string,
	base: Rich_Style,
	allocator := context.allocator,
) -> (
	Rich_Document,
	Rich_Error,
) {
	d := Rich_Document {
		allocator = allocator,
	}
	d.runs = make([dynamic]Rich_Run, 0, 0, allocator)
	d.mappings = make([dynamic]Rich_Mapping, 0, 0, allocator)
	d.tags = make([dynamic]Text_Source_Range, 0, 0, allocator)
	good := false
	defer {if !good {destroy_rich_document(&d)}}
	if len(source) >
	   65536 {return {}, rich_error(.Rich_Limit_Exceeded, 0, len(source), "source bytes")}
	if bad, failed := graphemes.count(source).(graphemes.Invalid_UTF8); failed {
		return {}, rich_error(.Invalid_UTF8, bad.byte_offset, min(bad.byte_offset + 1, len(source)), "UTF-8")
	}
	ae: mem.Allocator_Error
	d.source, ae = strings.clone(source, allocator); if ae != nil {return {}, {code = .Allocation}}
	bytes := make([dynamic]u8, allocator); defer delete(bytes)
	stack: [16]struct {
		name:  string,
		style: Rich_Style,
	}
	depth := 0
	style := base
	i := 0
	for i < len(source) {
		start := i
		if source[i] == '[' {
			end := i + 1
			quoted, escaped := false, false
			for end < len(source) {
				c := source[end]
				if escaped {escaped = false} else if c == '\\' {escaped = true} else if c == '"' {quoted = !quoted} else if c == ']' && !quoted {break}
				end += 1
			}
			if end ==
			   len(source) {return {}, rich_error(.Invalid_Markup, start, end, "unclosed tag")}
			tag := source[i + 1:end]
			if _, e := append(&d.tags, Text_Source_Range{start, end + 1});
			   e != nil {return {}, {code = .Allocation}}
			if len(d.tags) >
			   8192 {return {}, rich_error(.Rich_Limit_Exceeded, start, end + 1, "tag count")}
			i = end + 1
			if strings.has_prefix(tag, "/") {
				if depth == 0 ||
				   tag[1:] !=
					   stack[depth - 1].name {return {}, rich_error(.Invalid_Markup, start, i, "mismatched close")}
				depth -= 1; style = stack[depth].style
				continue
			}
			if strings.has_prefix(tag, "img ") {
				id, alt, w, h, valid, allocation_failed := rich_parse_image(tag, allocator)
				if allocation_failed {return {}, {code = .Allocation}}
				if !valid {return {}, rich_error(.Invalid_Attribute, start, i, "image attributes")}
				defer delete(id, allocator); defer delete(alt, allocator)
				ds := len(bytes)
				if _, e := append(&bytes, "\ufffc"); e != nil {return {}, {code = .Allocation}}
				if !rich_append_run(
					&d,
					{ds, len(bytes)},
					{start, i},
					style,
					id,
					alt,
					w,
					h,
				) {return {}, {code = .Allocation}}
				if _, e := append(&d.mappings, Rich_Mapping{{ds, len(bytes)}, {start, i}});
				   e != nil {return {}, {code = .Allocation}}
			} else {
				name := tag
				next := style
				switch {
				case tag == "b":
					next.bold = true
				case tag == "i":
					next.italic = true
				case tag == "u":
					next.underline = true
				case strings.has_prefix(tag, "color="):
					name = "color"
					if len(tag) != 15 ||
					   tag[6] != '#' {return {}, rich_error(.Invalid_Attribute, start, i, "color")}
					for k in 0 ..< 4 {
						a, oa := rich_hex(tag[7 + k * 2]); b, ob := rich_hex(tag[8 + k * 2])
						if !oa ||
						   !ob {return {}, rich_error(.Invalid_Attribute, start, i, "color hex")}
						next.color[k] = a * 16 + b
					}
				case strings.has_prefix(tag, "size="):
					name = "size"; value, ok := rich_integer(tag[5:], 128)
					if !ok {return {}, rich_error(.Invalid_Attribute, start, i, "size")}
					next.size = f64(value)
				case:
					return {}, rich_error(.Invalid_Markup, start, i, "unknown tag")
				}
				if depth ==
				   16 {return {}, rich_error(.Rich_Limit_Exceeded, start, i, "nesting depth")}
				stack[depth] = {name, style}; depth += 1; style = next
			}
		} else {
			if source[i] ==
			   ']' {return {}, rich_error(.Invalid_Markup, i, i + 1, "unescaped bracket")}
			if source[i] == '\\' {
				if i + 1 == len(source) ||
				   !rich_escape(
						   source[i + 1],
					   ) {return {}, rich_error(.Invalid_Markup, i, min(i + 2, len(source)), "escape")}
				i += 2
				ds := len(
					bytes,
				); if _, e := append(&bytes, source[i - 1]); e != nil {return {}, {code = .Allocation}}
				if !rich_append_run(
					&d,
					{ds, len(bytes)},
					{start, i},
					style,
					"",
					"",
					0,
					0,
				) {return {}, {code = .Allocation}}
				if _, e := append(&d.mappings, Rich_Mapping{{ds, len(bytes)}, {start, i}});
				   e != nil {return {}, {code = .Allocation}}
			} else {
				i += 1
				for i < len(source) && (source[i] & 0xc0) == 0x80 {i += 1}
				scalar := source[start:i]
				for r in scalar {if rich_control(r) || r == 0xfffc {return {}, rich_error(.Unsupported_Text_Control, start, i, "text control")}}
				ds := len(
					bytes,
				); if _, e := append(&bytes, scalar); e != nil {return {}, {code = .Allocation}}
				if !rich_append_run(
					&d,
					{ds, len(bytes)},
					{start, i},
					style,
					"",
					"",
					0,
					0,
				) {return {}, {code = .Allocation}}
				if _, e := append(&d.mappings, Rich_Mapping{{ds, len(bytes)}, {start, i}});
				   e != nil {return {}, {code = .Allocation}}
			}
		}
		if len(d.runs) > 4096 {return {}, rich_error(.Rich_Limit_Exceeded, start, i, "run count")}
	}
	if depth !=
	   0 {return {}, rich_error(.Invalid_Markup, len(source), len(source), "unclosed style")}
	d.decoded, ae = strings.clone(
		string(bytes[:]),
		allocator,
	); if ae != nil {return {}, {code = .Allocation}}
	result, be := graphemes.try_boundaries(
		d.decoded,
		allocator,
	); if be != nil {return {}, {code = .Allocation}}
	boundaries := result.([]int); defer delete(boundaries, allocator)
	for run, k in d.runs {
		if k > 0 && !rich_boundary(boundaries, run.decoded_range.start) {
			return {}, rich_error(.Invalid_Grapheme_Boundary, run.source_range.start, run.source_range.end, "style/object inside EGC")
		}
		if run.image_id != "" && !rich_boundary(boundaries, run.decoded_range.end) {
			return {}, rich_error(.Invalid_Grapheme_Boundary, run.source_range.start, run.source_range.end, "object inside EGC")
		}
	}
	clear(&bytes)
	for run in d.runs {
		part := run.alt
		if run.image_id == "" {part = d.decoded[run.decoded_range.start:run.decoded_range.end]}
		if _, e := append(&bytes, part); e != nil {return {}, {code = .Allocation}}
	}
	d.alt_text, ae = strings.clone(
		string(bytes[:]),
		allocator,
	); if ae != nil {return {}, {code = .Allocation}}
	good = true
	return d, {}
}
destroy_rich_document :: proc(d: ^Rich_Document) {
	a := d.allocator
	if a.procedure == nil {return}
	delete(d.source, a); delete(d.decoded, a); delete(d.alt_text, a)
	for run in d.runs {delete(run.style.font_id, a); delete(run.image_id, a); delete(run.alt, a)}
	delete(d.runs); delete(d.mappings); delete(d.tags)
	d^ = {}
}
try_copy_document :: proc(
	d: ^Rich_Document,
	allocator := context.allocator,
) -> (
	Rich_Document,
	bool,
) {
	r := Rich_Document {
		allocator = allocator,
	}
	r.runs = make([dynamic]Rich_Run, 0, 0, allocator)
	r.mappings = make([dynamic]Rich_Mapping, 0, 0, allocator)
	r.tags = make([dynamic]Text_Source_Range, 0, 0, allocator)
	complete := false; defer {if !complete {destroy_rich_document(&r)}}
	ae: mem.Allocator_Error
	r.source, ae = strings.clone(d.source, allocator); if ae != nil {return {}, false}
	r.decoded, ae = strings.clone(d.decoded, allocator); if ae != nil {return {}, false}
	r.alt_text, ae = strings.clone(d.alt_text, allocator); if ae != nil {return {}, false}
	for run in d.runs {if !rich_append_run(&r, run.decoded_range, run.source_range, run.style, run.image_id, run.alt, run.width, run.height) {return {}, false}}
	if _, e := append(&r.mappings, ..d.mappings[:]); e != nil {return {}, false}
	if _, e := append(&r.tags, ..d.tags[:]); e != nil {return {}, false}
	complete = true
	return r, true
}
@(private)
rich_append_run :: proc(
	d: ^Rich_Document,
	decoded, source: Text_Source_Range,
	style: Rich_Style,
	id, alt: string,
	w, h: f64,
) -> bool {
	if id == "" && len(d.runs) > 0 {
		p := &d.runs[len(d.runs) - 1]
		if p.image_id == "" &&
		   p.style ==
			   style {p.decoded_range.end = decoded.end; p.source_range.end = source.end; return true}
	}
	s := style
	ae: mem.Allocator_Error
	s.font_id, ae = strings.clone(style.font_id, d.allocator); if ae != nil {return false}
	image, ie := strings.clone(
		id,
		d.allocator,
	); if ie != nil {delete(s.font_id, d.allocator); return false}
	alternative, ale := strings.clone(
		alt,
		d.allocator,
	); if ale != nil {delete(s.font_id, d.allocator); delete(image, d.allocator); return false}
	_, append_error := append(&d.runs, Rich_Run{decoded, source, s, image, alternative, w, h})
	if append_error !=
	   nil {delete(s.font_id, d.allocator); delete(image, d.allocator); delete(alternative, d.allocator); return false}
	return true
}
@(private)
rich_error :: proc(code: Rich_Error_Code, start, end: int, reason: string) -> Rich_Error {return {
		code = code,
		source_range = {start, end},
		reason = reason,
	}}
@(private)
rich_boundary :: proc(bounds: []int, offset: int) -> bool {for b in bounds {if b == offset {return(
				true \
			)}}
	return false}
@(private)
rich_escape :: proc(c: u8) -> bool {return c == '\\' || c == '[' || c == ']' || c == '"'}
@(private)
rich_hex :: proc(c: u8) -> (u8, bool) {
	if c >= '0' &&
	   c <=
		   '9' {return c - '0', true}; if c >= 'a' && c <= 'f' {return c - 'a' + 10, true}; if c >= 'A' && c <= 'F' {return c - 'A' + 10, true}; return 0, false
}
@(private)
rich_integer :: proc(s: string, limit: int) -> (int, bool) {
	if len(s) == 0 || s[0] == '0' {return 0, false}
	n := 0
	for c in s {if c < '0' || c > '9' {return 0, false}; n = n * 10 + int(c - '0'); if n > limit {return 0, false}}
	return n, true
}
@(private)
rich_control :: proc(r: rune) -> bool {
	return(
		(r < 32 && r != '\r' && r != '\n') ||
		(r >= 0x7f && r <= 0x9f) ||
		r == 0x2028 ||
		r == 0x2029 ||
		r == 0x061c ||
		r == 0x200e ||
		r == 0x200f ||
		(r >= 0x202a && r <= 0x202e) ||
		(r >= 0x2066 && r <= 0x2069) \
	)
}
@(private)
rich_parse_image :: proc(
	tag: string,
	a: mem.Allocator,
) -> (
	id, alt: string,
	w, h: f64,
	ok, allocation_failed: bool,
) {
	defer {if !ok {delete(id, a); delete(alt, a); id, alt = "", ""}}
	if !strings.has_prefix(tag, "img id=\"") {return}
	i := 8; begin := i
	for i < len(tag) && tag[i] != '"' {i += 1}
	if i == len(tag) || i - begin < 1 || i - begin > 64 {return}
	for c in tag[begin:i] {if !((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '.' || c == '-') {return}}
	ident := tag[begin:i]; i += 1
	if !strings.has_prefix(tag[i:], " alt=\"") {return}; i += 6
	bytes := make([dynamic]u8, a); defer delete(bytes)
	for i < len(tag) && tag[i] != '"' {
		if tag[i] ==
		   '\\' {if i + 1 == len(tag) || !rich_escape(tag[i + 1]) {return}; i += 1} else if tag[i] == '[' || tag[i] == ']' {return}
		if _, e := append(&bytes, tag[i]); e != nil {allocation_failed = true; return}; i += 1
	}
	if i == len(tag) || len(bytes) == 0 {return}
	for r in string(bytes[:]) {if rich_control(r) || r == '\r' || r == '\n' {return}}
	i += 1
	if !strings.has_prefix(tag[i:], " w=") {return}; i += 3; begin = i
	for i < len(tag) && tag[i] != ' ' {i += 1}; wi, ow := rich_integer(tag[begin:i], 256)
	if !ow || !strings.has_prefix(tag[i:], " h=") {return}; i += 3
	if len(tag) < i + 2 || tag[len(tag) - 1] != '/' {return}
	hi, oh := rich_integer(tag[i:len(tag) - 1], 256); if !oh {return}
	ae: mem.Allocator_Error
	id, ae = strings.clone(ident, a); if ae != nil {allocation_failed = true; return}
	alt, ae = strings.clone(string(bytes[:]), a); if ae != nil {allocation_failed = true; return}
	w = f64(wi); h = f64(hi); ok = true
	return
}
