package qualification_menu

import menu ".."
import fixture "../../../tests/ui_recipes/native_fixture"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

init_runtime :: proc(r: ^menu.Runtime, f: ^fixture.Fixture, data: []u8) -> bool {return menu.init(
		r,
		f.renderer,
		data,
		1,
		context.allocator,
		fixture.ledger(f),
	)}

cycle :: proc(r: ^menu.Runtime, f: ^fixture.Fixture, s: ^fixture.Sample) -> bool {
	before := r.model
	t := fixture.begin(f)
	for id in ([]string{"action", "open", "back"}) {
		x := interaction.dispatch(&r.interaction, {.Activate, id, .Agent, false})
		if !x.has_event || !menu.accept(r, x.event) || !menu.rebuild(r) {return false}
	}
	s.action_ns = fixture.elapsed(f, t)
	if r.model.page != .Main ||
	   r.model.count != before.count + 1 ||
	   r.model.effects != before.effects + 3 {return false}
	t = fixture.begin(f)
	copy, copied := menu.copy_reader(
		&r.live,
		r.allocator,
	); if !copied {return false}; defer menu.destroy_reader(&copy)
	s.copy_ns = fixture.elapsed(f, t)
	accepted := r.model
	t = fixture.begin(f); r.fault = .Copy
	if menu.rebuild(r) || r.publication.ready {return false}; s.failure_ns = fixture.elapsed(f, t)
	t = fixture.begin(
		f,
	); if !menu.rebuild(r) || r.model != accepted {return false}; s.recovery_ns = fixture.elapsed(f, t)
	if !base.is_current(&r.publication, r.live.text.stamp) {return false}
	t = fixture.begin(
		f,
	); if !menu.draw_reader(&r.live) {return false}; s.draw_ns = fixture.elapsed(f, t)
	t = fixture.begin(
		f,
	); pixels, ok := backend.readback(f.renderer, r.drawable); if !ok {return false}; sdl.DestroySurface(pixels); s.readback_ns = fixture.elapsed(f, t)
	t = fixture.begin(
		f,
	); if !sdl.RenderPresent(f.renderer) {return false}; s.present_ns = fixture.elapsed(f, t)
	return true
}
