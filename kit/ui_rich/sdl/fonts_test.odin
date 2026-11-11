package ui_rich_sdl

import ui ".."
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
native_fallback_style_metrics_and_retained_generation :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		240,
		200,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	primary, pe := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, pe == nil) {return}; defer delete(primary)
	fallback, fe := os.read_entire_file(
		"resources/fallback.ttf",
		context.allocator,
	); if !testing.expect(t, fe == nil) {return}; defer delete(fallback)
	g, ok := create_rich_generation(
		r,
		"rich-v1",
		nil,
		[]Rich_Font_Source{{"default", primary}, {"greek", fallback}},
		[]Rich_Font_Chain{{"default", {"greek"}}},
		[]Rich_Font_Request {
			{"default", 16, false, false, false},
			{"default", 24, true, true, true},
		},
		1,
	)
	if !testing.expect(t, ok) {return}
	testing.expect(
		t,
		retain_generation(g),
	); reader := g; release_generation(&g); defer release_generation(&reader)
	m := rich_metrics(reader)
	value, e := m.measure("α Ω ά ∞", {font_id = "default", size = 16}, m.user)
	testing.expect(t, e == .None && value.width > 0 && value.height > 0 && value.baseline > 0)
	_, missing := m.measure("\U0001f680", {font_id = "default", size = 16}, m.user)
	testing.expect_value(t, missing, ui.Rich_Error_Code.Glyph_Missing)
	_, styled := m.measure(
		"α Go",
		{font_id = "default", size = 24, bold = true, italic = true, underline = true},
		m.user,
	)
	testing.expect_value(t, styled, ui.Rich_Error_Code.None)
	testing.expect_value(t, rich_coverage(reader, {font_id = "default", size = 16}, 'α'), "greek")
	testing.expect(
		t,
		!ttf.FontHasGlyph(reader.rich_sources[0].coverage.font, u32('α')) &&
		ttf.FontHasGlyph(reader.rich_sources[1].coverage.font, u32('α')),
	)
}
