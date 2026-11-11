package ui_rich_sdl

import ui ".."
import base "../../ui_base"
import backend "../../ui_sdl"
import "core:fmt"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Rich_Font_Source :: struct {
	id:   string,
	data: []u8,
}
Rich_Font_Chain :: struct {
	primary:   string,
	fallbacks: []string,
}
Rich_Font_Request :: struct {
	font_id:                 string,
	size:                    f64,
	bold, italic, underline: bool,
}
@(private)
create_rich_generation :: proc(
	renderer: ^sdl.Renderer,
	revision: string,
	images: []RGBA_Image,
	sources: []Rich_Font_Source,
	chains: []Rich_Font_Chain,
	requests: []Rich_Font_Request,
	scale: f64,
	allocator := context.allocator,
	error_out: ^backend.Error = nil,
) -> (
	^Generation,
	bool,
) {
	if error_out != nil {error_out^ = {
			code = .Invalid,
		}}
	if len(sources) == 0 || len(chains) == 0 || len(requests) == 0 {return nil, false}
	for source, index in sources {
		if source.id == "" ||
		   len(source.data) == 0 {return nil, creation_failure(error_out, .Invalid, source.id)}
		for prior in sources[:index] {if prior.id == source.id {return nil, creation_failure(error_out, .Invalid, source.id)}}
	}
	for request, index in requests {
		if !base.finite(request.size) ||
		   request.size <= 0 ||
		   !base.finite(request.size * scale) ||
		   request.size * scale >
			   f64(max(f32)) {return nil, creation_failure(error_out, .Invalid, request.font_id)}
		for prior in requests[:index] {if prior == request {return nil, creation_failure(error_out, .Invalid, request.font_id)}}
		found :=
			false; for chain in chains {if chain.primary == request.font_id {found = true; break}}; if !found {return nil, creation_failure(error_out, .Invalid, request.font_id)}
	}
	for c, i in chains {
		primary_found := false
		for source in sources {if source.id == c.primary {primary_found = true; break}}
		if !primary_found {return nil, false}
		if c.primary == "" || len(c.fallbacks) > 3 {return nil, false}
		for old in chains[:i] {if old.primary == c.primary {return nil, false}}
		for f, j in c.fallbacks {
			fallback_found := false
			for source in sources {if source.id == f {fallback_found = true; break}}
			if !fallback_found {return nil, false}
			if f == c.primary || f == "" {return nil, false}
			for old in c.fallbacks[:j] {if old == f {return nil, false}}
			if rich_chain_reaches(chains, f, c.primary, 0) {return nil, false}
		}
	}
	g, ok := new_generation(renderer, revision, images, scale, allocator, error_out)
	if !ok {return nil, false}
	if error_out != nil {error_out^ = {
			code = .Resource,
		}}
	allocation_error: mem.Allocator_Error
	complete := false; defer {if !complete {release_generation(&g)}}
	defer {if !complete && allocation_error != nil && error_out != nil {error_out^ = {
				code = .Allocation,
			}}}
	g.rich_sources, allocation_error = make(
		[dynamic]Rich_Native_Source,
		0,
		len(sources),
		g.allocator,
	)
	if allocation_error != nil {return nil, false}
	g.rich_fonts, allocation_error = make([dynamic]Rich_Native_Font, 0, len(requests), g.allocator)
	if allocation_error != nil {return nil, false}
	for source in sources {
		if source.id == "" {return nil, false}
		for old in g.rich_sources {if old.id == source.id {return nil, false}}
		data, e := make([]u8, len(source.data), g.allocator)
		if e !=
		   nil {return nil, creation_failure(error_out, .Allocation, source.id)}; copy(data, source.data)
		font, valid := create(data, 16, scale)
		if !valid {delete(data, g.allocator); return nil, false}
		inserted := false
		defer {if !inserted {destroy(&font); delete(data, g.allocator)}}
		id, id_error := strings.clone(source.id, g.allocator)
		if id_error != nil {return nil, creation_failure(error_out, .Allocation, source.id)}
		defer {if !inserted {delete(id, g.allocator)}}
		if _, append_error := append(&g.rich_sources, Rich_Native_Source{id, data, font});
		   append_error != nil {return nil, creation_failure(error_out, .Allocation, source.id)}
		inserted = true
	}
	for request in requests {
		for old in g.rich_fonts {if old.request == request {return nil, false}}
		chain: Rich_Font_Chain; found := false
		for c in chains {if c.primary == request.font_id {chain = c; found = true; break}}
		if !found {return nil, false}
		if _, e := append(&g.rich_fonts, Rich_Native_Font{});
		   e != nil {return nil, creation_failure(error_out, .Allocation, request.font_id)}
		f := &g.rich_fonts[len(g.rich_fonts) - 1]
		f.request = request; f.request.font_id = ""
		f.request.font_id, allocation_error = strings.clone(request.font_id, g.allocator)
		if allocation_error != nil {return nil, false}
		count := 1 + len(chain.fallbacks)
		f.instances, allocation_error = make([dynamic]Adapter, 0, count, g.allocator)
		if allocation_error != nil {return nil, false}
		f.ids, allocation_error = make([dynamic]string, 0, count, g.allocator)
		if allocation_error != nil {return nil, false}
		f.revisions, allocation_error = make([dynamic]u32, 0, count, g.allocator)
		if allocation_error != nil {return nil, false}
		for i in 0 ..< 1 + len(chain.fallbacks) {
			id := chain.primary; if i > 0 {id = chain.fallbacks[i - 1]}
			source := rich_source(g, id); if source == nil {return nil, false}
			adapter, valid := create(source.data, request.size, scale)
			if !valid {return nil, false}
			if _, e := append(&f.instances, adapter);
			   e !=
			   nil {destroy(&adapter); return nil, creation_failure(error_out, .Allocation, request.font_id)}
			owned_id, e := strings.clone(id, g.allocator)
			if e != nil {return nil, creation_failure(error_out, .Allocation, request.font_id)}
			if _, append_error := append(&f.ids, owned_id);
			   append_error !=
			   nil {delete(owned_id, g.allocator); return nil, creation_failure(error_out, .Allocation, request.font_id)}
			flags: ttf.FontStyleFlags
			if request.bold {flags += {.BOLD}}; if request.italic {flags += {.ITALIC}}; if request.underline {flags += {.UNDERLINE}}
			ttf.SetFontStyle(adapter.font, flags)
			if !ttf.SetFontDirection(adapter.font, .LTR) {return nil, false}
		}
		for i in 1 ..< len(f.instances) {if !ttf.AddFallbackFont(f.instances[0].font, f.instances[i].font) {return nil, false}}
		for instance in f.instances {if _, e := append(&f.revisions, ttf.GetFontGeneration(instance.font)); e != nil {return nil, creation_failure(error_out, .Allocation, request.font_id)}}
		buffer: [64]u8
		suffix := fmt.bprintf(buffer[:], ":rich:1:%p", f.instances[0].font)
		if len(revision) > max(int) - len(suffix) {return nil, false}
		bytes, revision_error := make([]u8, len(revision) + len(suffix), g.allocator)
		if revision_error !=
		   nil {return nil, creation_failure(error_out, .Allocation, request.font_id)}
		copy(bytes, revision); copy(bytes[len(revision):], suffix)
		f.revision = string(bytes)
	}
	complete = true; return g, true
}
rich_metrics :: proc(g: ^Generation) -> ui.Rich_Text_Metrics {return {
		coverage = rich_metric_coverage,
		font_chain = rich_metric_chain,
		measure = rich_measure,
		image = rich_image,
		user = g,
	}}

@(private)
rich_metric_coverage :: proc(
	scalar: rune,
	style: ui.Rich_Style,
	user: rawptr,
) -> string {return rich_coverage(cast(^Generation)user, style, scalar)}
@(private)
rich_metric_chain :: proc(style: ui.Rich_Style, user: rawptr) -> []string {f := rich_font(
		cast(^Generation)user,
		style,
	)
	if f == nil {return nil}
	return f.ids[:]}

Rich_Native_Source :: struct {
	id:       string,
	data:     []u8,
	coverage: Adapter,
}
Rich_Native_Font :: struct {
	request:   Rich_Font_Request,
	instances: [dynamic]Adapter,
	ids:       [dynamic]string,
	revisions: [dynamic]u32,
	revision:  string,
}
@(private)
rich_chain_reaches :: proc(chains: []Rich_Font_Chain, from, to: string, depth: int) -> bool {
	if from == to || depth > len(chains) {return true}
	for chain in chains {if chain.primary == from {for f in chain.fallbacks {if rich_chain_reaches(chains, f, to, depth + 1) {return true}}}}
	return false
}
@(private)
rich_source :: proc(g: ^Generation, id: string) -> ^Rich_Native_Source {for &source in g.rich_sources {if source.id ==
		   id {return &source}}
	return nil}
@(private)
rich_font :: proc(g: ^Generation, s: ui.Rich_Style) -> ^Rich_Native_Font {
	if g == nil {return nil}
	req := Rich_Font_Request{s.font_id, s.size, s.bold, s.italic, s.underline}
	for &font in g.rich_fonts {
		if font.request != req {continue}
		for instance, i in font.instances {if ttf.GetFontGeneration(instance.font) != font.revisions[i] {return nil}}
		return &font
	}
	return nil
}
// Raw independent font coverage: never query the attached primary as proof of a hit.
rich_coverage :: proc(g: ^Generation, style: ui.Rich_Style, scalar: rune) -> string {
	f := rich_font(g, style); if f == nil {return ""}
	for id in f.ids {s := rich_source(g, id); if s != nil && ttf.FontHasGlyph(s.coverage.font, u32(scalar)) {return id}}
	return ""
}
@(private)
rich_image :: proc(id: string, user: rawptr) -> bool {
	if user == nil {return false}; g := cast(^Generation)user
	_, found := resolve_image(g, id); return found
}
@(private)
rich_measure :: proc(
	text: string,
	style: ui.Rich_Style,
	user: rawptr,
) -> (
	ui.Rich_Run_Metrics,
	ui.Rich_Error_Code,
) {
	g := cast(^Generation)user; f := rich_font(g, style)
	if f == nil {return {}, .Resource_Missing}
	for r in text {if rich_coverage(g, style, r) == "" {return {}, .Glyph_Missing}}
	font := f.instances[0].font; scale := f.instances[0].scale
	ascent, descent := f64(ttf.GetFontAscent(font)) / scale, f64(-ttf.GetFontDescent(font)) / scale
	gap := max(0, f64(ttf.GetFontLineSkip(font)) / scale - ascent - descent)
	if ascent < 0 || descent < 0 {return {}, .Invalid_Geometry}
	w, h := i32(0), ttf.GetFontHeight(font)
	if text != "" {
		surface := ttf.RenderText_Blended(
			font,
			raw_data(text),
			uint(len(text)),
			{255, 255, 255, 255},
		)
		if surface == nil {return {}, .Metrics_Failed}
		w, h = surface.w, surface.h; sdl.DestroySurface(surface)
	}
	height := f64(h) / scale
	if height < ascent {return {}, .Invalid_Geometry}
	return {
			f64(w) / scale,
			height,
			ascent,
			ascent,
			max(descent, height - ascent),
			gap,
			f.revision,
		},
		.None
}
@(private)
destroy_rich_fonts :: proc(g: ^Generation) {
	for &f in g.rich_fonts {
		// Primary is closed first, while all referenced fallback fonts still live.
		for &instance in f.instances {destroy(&instance)}
		for id in f.ids {delete(id, g.allocator)}
		delete(
			f.ids,
		); delete(f.instances); delete(f.revisions); delete(f.revision, g.allocator); delete(f.request.font_id, g.allocator)
	}
	for &source in g.rich_sources {destroy(&source.coverage); delete(source.id, g.allocator); delete(source.data, g.allocator)}
	delete(g.rich_sources); delete(g.rich_fonts)
}
