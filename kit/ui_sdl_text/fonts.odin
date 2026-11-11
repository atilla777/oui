package ui_sdl_text

import base "../ui_base"
import backend "../ui_sdl"
import style "../ui_style"
import text "../ui_text"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Font_Source :: struct {
	id:   string,
	size: f64,
	data: []u8,
}
Font :: struct {
	id, revision:    string,
	data:            []u8,
	font:            ^ttf.Font,
	size, scale:     f64,
	native_revision: u32,
}
Generation :: struct {
	renderer:  ^sdl.Renderer,
	revision:  string,
	fonts:     []Font,
	scale:     f64,
	readers:   u64,
	allocator: mem.Allocator,
	ledger:    ^backend.Resource_Ledger,
}
create_generation :: proc(
	r: ^sdl.Renderer,
	revision: string,
	sources: []Font_Source,
	scale: f64,
	a: mem.Allocator,
	ledger: ^backend.Resource_Ledger = nil,
) -> (
	^Generation,
	backend.Error,
) {
	if r == nil || revision == "" || !base.finite(scale) || scale <= 0 {return nil, {.Invalid, ""}}
	g, e := new(Generation, a); if e != nil {return nil, {.Allocation, ""}}
	g^ = {
		renderer  = r,
		scale     = scale,
		readers   = 1,
		allocator = a,
		ledger    = ledger,
	}
	complete := false; defer {if !complete {release_generation(&g)}}
	g.revision, e = strings.clone(revision, a); if e != nil {return nil, {.Allocation, ""}}
	g.fonts, e = make([]Font, len(sources), a); if e != nil {return nil, {.Allocation, ""}}
	for source, i in sources {
		if source.id == "" ||
		   !base.finite(source.size) ||
		   source.size <= 0 ||
		   len(source.data) == 0 ||
		   !base.finite(source.size * scale) ||
		   source.size * scale > f64(max(f32)) {return nil, {.Invalid, source.id}}
		for prior in sources[:i] {if prior.id == source.id && prior.size == source.size {return nil, {.Invalid, source.id}}}
		f := &g.fonts[i]; f.size, f.scale = source.size, scale
		f.id, e = strings.clone(source.id, a); if e != nil {return nil, {.Allocation, source.id}}
		f.data, e = make(
			[]u8,
			len(source.data),
			a,
		); if e != nil {return nil, {.Allocation, source.id}}; copy(f.data, source.data)
		if !backend.resource_can_acquire(ledger) {return nil, {.Invalid, source.id}}
		stream := sdl.IOFromConstMem(
			raw_data(f.data),
			uint(len(f.data)),
		); if stream == nil {return nil, {.Resource, source.id}}
		f.font = ttf.OpenFontIO(
			stream,
			true,
			f32(source.size * scale),
		); if f.font == nil {return nil, {.Resource, source.id}}
		backend.resource_acquired(ledger)
		f.native_revision = ttf.GetFontGeneration(f.font)
		buffer: [80]u8
		suffix := fmt.bprintf(buffer[:], ":%p:%d", f.font, f.native_revision)
		if len(revision) > max(int) - len(suffix) {return nil, {.Invalid, source.id}}
		bytes, ae := make(
			[]u8,
			len(revision) + len(suffix),
			a,
		); if ae != nil {return nil, {.Allocation, source.id}}
		copy(bytes, revision); copy(bytes[len(revision):], suffix); f.revision = string(bytes)
	}
	complete = true; return g, {}
}
release_generation :: proc(generation: ^^Generation) {
	g := generation^; generation^ = nil; if g == nil {return}
	g.readers -= 1; if g.readers > 0 {return}
	for f in g.fonts {if f.font != nil {ttf.CloseFont(f.font); backend.resource_released(g.ledger)}; delete(f.id, g.allocator); delete(f.data, g.allocator); delete(f.revision, g.allocator)}
	delete(g.fonts, g.allocator); delete(g.revision, g.allocator); free(g, g.allocator)
}
retain_generation :: proc(g: ^Generation) -> bool {
	if g == nil || g.readers == max(u64) {return false}; g.readers += 1; return true
}
metrics :: proc(g: ^Generation) -> text.Text_Layout_Metrics {return {
		font_metrics = font_metrics,
		measure_line = measure_line,
		validate_text = validate_text,
		user = g,
	}}
find_font :: proc(g: ^Generation, id: string, size: f64) -> ^Font {
	if g == nil {return nil}
	for &f in g.fonts {if f.id == id && f.size == size && f.font != nil && ttf.GetFontGeneration(f.font) == f.native_revision {return &f}}
	return nil
}
font_metrics :: proc(
	id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Font_Metrics,
	text.Text_Metric_Error,
) {
	f := find_font((^Generation)(user), id, size); if f == nil {return {}, .Failed}
	return {
			ascent = f64(ttf.GetFontAscent(f.font)) / f.scale,
			descent = f64(-ttf.GetFontDescent(f.font)) / f.scale,
			line_advance = f64(max(ttf.GetFontLineSkip(f.font), ttf.GetFontHeight(f.font))) /
			f.scale,
			font_revision = f.revision,
		},
		.None
}
measure_line :: proc(
	value, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Line_Metrics,
	text.Text_Metric_Error,
) {
	f := find_font((^Generation)(user), id, size); if f == nil {return {}, .Failed}
	if error, _ := validate_text(value, id, size, user); error != .None {return {}, error}
	if value == "" {return {}, .None}
	w, h: i32
	if !ttf.GetStringSize(f.font, raw_data(value), uint(len(value)), &w, &h) {return {}, .Failed}
	return {f64(w) / f.scale, {f64(w) / f.scale, f64(h) / f.scale}}, .None
}
validate_text :: proc(
	value, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Metric_Error,
	int,
) {
	f := find_font((^Generation)(user), id, size); if f == nil {return .Failed, 0}
	for glyph, offset in value {if glyph == '\r' || glyph == '\n' {continue}; if !ttf.FontHasGlyph(f.font, u32(glyph)) {return .Glyph_Missing, offset}}
	return .None, 0
}
matches :: proc(g: ^Generation, f: ^text.Frame, paint: ^style.Frame) -> bool {
	if g == nil ||
	   f.stamp.attempt == 0 ||
	   f.stamp != paint.stamp ||
	   f.drawable != paint.drawable ||
	   f.ui_scale != g.scale ||
	   f.ui_scale != paint.ui_scale ||
	   !backend.output_matches(g.renderer, f.drawable) {return false}
	for b in f.text_blocks {
		font := find_font(g, b.font_id, b.font_size)
		if font == nil || b.font_revision != font.revision {return false}
		fm, e := font_metrics(b.font_id, b.font_size, g)
		if e != .None || b.ascent != fm.ascent || b.line_advance < fm.line_advance {return false}
		found := false
		for p in paint.presentation {if p.id == b.node_id {found = p.computed[.Font].value.(style.Font_ID).id == b.font_id && p.computed[.Font_Size].value.(f64) == b.font_size}}
		if !found {return false}
		for line in b.lines {
			measurement, error := measure_line(line.display_text, b.font_id, b.font_size, g)
			if error != .None || measurement.surface_extent != line.measured_extent {return false}
		}
	}
	return true
}
render_node :: proc(
	g: ^Generation,
	f: ^text.Frame,
	paint: ^style.Frame,
	id: string,
	transform: base.Frozen_Geometry = {scale = 1, opacity = 1},
) -> bool {
	if id == "" || !matches(g, f, paint) {return false}
	found :=
		false; for b in f.text_blocks {if b.node_id == id {found = true}}; if !found {return false}
	if !base.finite(transform.offset[0]) ||
	   !base.finite(transform.offset[1]) ||
	   !base.finite(transform.scale) ||
	   transform.scale <= 0 ||
	   !base.finite(transform.opacity) ||
	   transform.opacity < 0 ||
	   transform.opacity > 1 {return false}
	state, saved := backend.save_renderer_state(g.renderer); if !saved {return false}
	ok := backend.pixel_coordinates(g.renderer) && draw(g, f, paint, id, transform)
	restored := backend.restore_renderer_state(g.renderer, state); return ok && restored
}
render :: proc(g: ^Generation, f: ^text.Frame, paint: ^style.Frame) -> bool {
	if !matches(g, f, paint) {return false}
	state, saved := backend.save_renderer_state(g.renderer); if !saved {return false}
	ok := backend.pixel_coordinates(g.renderer) && draw(g, f, paint)
	restored := backend.restore_renderer_state(g.renderer, state)
	return ok && restored
}
@(private)
draw :: proc(
	g: ^Generation,
	f: ^text.Frame,
	paint: ^style.Frame,
	id: string = "",
	transform: base.Frozen_Geometry = {scale = 1, opacity = 1},
) -> bool {
	for b in f.text_blocks {
		if id != "" && b.node_id != id {continue}
		font := find_font(g, b.font_id, b.font_size)
		for p in paint.presentation {
			if p.id != b.node_id || !p.drawable {continue}
			color := p.computed[.Foreground].value.(style.Color)
			color[3] = u8(f64(color[3]) * transform.opacity)
			for line in b.lines {
				if !line.displayed || line.display_text == "" {continue}
				surface := ttf.RenderText_Blended(
					font.font,
					raw_data(line.display_text),
					uint(len(line.display_text)),
					{color[0], color[1], color[2], color[3]},
				)
				if surface == nil {return false}; defer sdl.DestroySurface(surface)
				if f64(surface.w) / f.ui_scale != line.measured_extent.w ||
				   f64(surface.h) / f.ui_scale != line.measured_extent.h {return false}
				texture := sdl.CreateTextureFromSurface(
					g.renderer,
					surface,
				); if texture == nil {return false}; defer sdl.DestroyTexture(texture)
				clip := backend.pixel_rect(p.content_clip, f.ui_scale)
				point := base.forward_point(
					transform,
					{line.logical_rect.x, line.baseline - b.ascent},
				)
				dest := sdl.FRect {
					f32(point[0] * f.ui_scale),
					f32(math.round(point[1] * f.ui_scale)),
					f32(f64(surface.w) * transform.scale),
					f32(f64(surface.h) * transform.scale),
				}
				if !sdl.SetRenderClipRect(g.renderer, &clip) ||
				   !sdl.SetTextureBlendMode(texture, sdl.BLENDMODE_BLEND) ||
				   !sdl.RenderTexture(g.renderer, texture, nil, &dest) {return false}
			}
		}
	}
	return true
}
