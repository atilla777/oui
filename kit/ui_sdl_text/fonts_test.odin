package ui_sdl_text

import base "../ui_base"
import layout "../ui_layout"
import backend "../ui_sdl"
import style "../ui_style"
import text "../ui_text"
import "core:mem"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
own_font_and_real_ru_en_metrics :: proc(t: ^testing.T) {
	testing.expect(t, ttf.Init()); defer ttf.Quit()
	surface := sdl.CreateSurface(
		100,
		60,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	data, read := os.read_entire_file("resources/font.ttf", context.allocator)
	if !testing.expect(t, read == nil) {return}; defer delete(data)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	sources := [1]Font_Source{{"own", 16, data}}
	ledger: backend.Resource_Ledger
	g, e := create_generation(r, "v1", sources[:], 1.5, a, &ledger)
	if !testing.expect(t, e.code == .None && g != nil) {return}
	testing.expect(t, ledger.created == 1 && ledger.live == 1 && ledger.peak == 1)
	testing.expect(t, raw_data(g.fonts[0].data) != raw_data(data))
	testing.expect(t, retain_generation(g)); reader := g; release_generation(&g)
	m := metrics(reader)
	fm, fe := m.font_metrics("own", 16, m.user)
	testing.expect(t, fe == .None && fm.ascent > 0 && fm.font_revision != "")
	for value in ([2]string{"Action", "Действие"}) {
		v, _ := m.validate_text(value, "own", 16, m.user); testing.expect(t, v == .None)
		line, le := m.measure_line(
			value,
			"own",
			16,
			m.user,
		); testing.expect(t, le == .None && line.advance_width > 0)
	}
	_, missing := m.font_metrics("missing", 16, m.user); testing.expect(t, missing == .Failed)
	p, _ := base.create(a); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 0)
	nodes := [1]layout.Node {
		{
			id = "label",
			role = .Content,
			visible = true,
			enabled = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 60}, y = {mode = .Content}},
		},
	}
	labels := [1]text.Text_Node{{id = "label", text = "Да", font = {"own"}, font_size = 16}}
	c, ce := text.prepare(labels[:], nodes[:], {drawable = {100, 60}, ui_scale = 1.5}, m, a, s)
	testing.expect(t, ce.code == .None)
	ds := [1]style.Description {
		{
			id = "label",
			role = "label",
			appearance = {
				local = {
					states = #partial{
						.Normal = []style.Declaration {
							{.Font, style.Font_ID{"own"}},
							{.Font_Size, f64(16)},
						},
					},
				},
			},
		},
	}
	paint, pe := style.prepare(&c.geometry, ds[:], {revision = "theme"}, {revision = "images"}, a)
	testing.expect(t, pe.code == .None)
	testing.expect(t, matches(reader, &c.text, &paint))
	testing.expect(
		t,
		render_node(reader, &c.text, &paint, "label"),
		"node text draw must use the existing font owner",
	)
	testing.expect(t, !render_node(reader, &c.text, &paint, "missing"))
	state, _ := backend.save_renderer_state(r)
	testing.expect(t, render(reader, &c.text, &paint))
	after, _ := backend.save_renderer_state(r); testing.expect(t, state == after)
	style.destroy_frame(&paint); text.destroy_candidate(&c)
	base.destroy(&p)
	release_generation(&reader)
	testing.expect(t, ledger.live == 0 && ledger.destroyed == 1)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
