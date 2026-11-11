package qualification_menu

import menu ".."
import fixture "../../../tests/ui_recipes/native_fixture"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
menu_cycle_is_connected_and_restores_equivalent_page :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		800,
		600,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	f: fixture.Fixture; f.renderer = renderer; f.instrument = true
	r: menu.Runtime; if !testing.expect(t, init_runtime(&r, &f, data)) {return}; defer menu.destroy(&r)
	testing.expect(
		t,
		f.ledger.live == 1,
		"actual native font acquisition must reach the fixture ledger",
	)
	r.drawable = {800, 600}; if !testing.expect(t, menu.rebuild(&r)) {return}
	s: fixture.Sample
	if !testing.expect(
		t,
		cycle(&r, &f, &s),
		"one actual Action/Open/Back cycle must succeed",
	) {return}
	testing.expect(
		t,
		r.model.count == 1 && r.model.effects == 3 && r.model.page == .Main && r.publication.ready,
	)
	testing.expect(
		t,
		cycle(&r, &f, &s) && r.model.count == 2 && r.model.effects == 6,
		"a second cycle must reuse equivalent app/resource state",
	)
	r.scale = 2
	testing.expect(
		t,
		menu.rebuild(&r) && f.ledger.live == 1,
		"font replacement must preserve the borrowed native ledger",
	)
}
