package main

import fixture "../../../tests/ui_recipes/native_fixture"
import app "../app"
import model "../model"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
qualification_collection_and_switch_workloads_have_real_outcomes :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		1280,
		960,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	for collection in ([]bool{true, false}) {
		s := app.Shell {
			model = model.initial(),
			renderer = renderer,
			font_data = data,
			allocator = context.allocator,
			drawable = {1280, 960},
			sources = {
				assets = "resources/atlas/a/manifest.json",
				alternate_assets = "resources/atlas/b/manifest.json",
			},
		}
		if collection {s.model.page = .Collections}
		if !testing.expect(t, app.enter(&s)) {return}; defer app.destroy_shell(&s)
		f: fixture.Fixture; f.renderer = renderer
		sample: fixture.Sample
		if !testing.expect(
			t,
			cycle(&s, &f, collection, &sample),
			"the workload must exercise actual guarded actions and restore its page",
		) {return}
		testing.expect(
			t,
			app.current(&s.runtime) &&
			s.model.page == (.Collections if collection else .Catalogue),
		)
		if collection {testing.expect(t, s.collection.count == 10000 && s.collection.selected == 1)}
		testing.expect(
			t,
			cycle(&s, &f, collection, &sample),
			"the workload must be repeatable without resetting the runtime or replaying outcomes",
		)
	}
}
