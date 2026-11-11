package main

import fixture "../../../tests/ui_recipes/native_fixture"
import app "../app"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

act :: proc(s: ^app.Shell, id: string) -> bool {return app.dispatch(
		s,
		{.Activate, id, .Agent, false},
	)}
go :: proc(s: ^app.Shell, selector: string) -> bool {r := app.request_section(s, selector, .Agent)
	return r.code == .Applied && r.ready}

cycle :: proc(
	s: ^app.Shell,
	f: ^fixture.Fixture,
	collection: bool,
	sample: ^fixture.Sample,
) -> bool {
	t := fixture.begin(f)
	if collection {
		for pair in ([][2]string{{"collections/start", "10:collection10:item-00001"}, {"collections/middle", "10:collection10:item-05000"}, {"collections/end", "10:collection10:item-10000"}}) {
			if !act(s, pair[0]) || !act(s, pair[1]) {return false}
		}
		if s.collection.count != 10000 || s.collection.selected != 10000 {return false}
		if !act(s, "collections/reverse") ||
		   !act(s, "collections/end") ||
		   !act(s, "collections/reverse") ||
		   !act(s, "collections/start") ||
		   !act(s, "10:collection10:item-00001") {return false}
		if s.collection.count != 10000 || s.collection.selected != 1 {return false}
	} else {
		if !go(s, "atlas") {return false}
		for id in ([]string{"atlas/assets", "atlas/reload", "atlas/assets", "atlas/reload", "shell/language", "shell/language", "shell/scale", "shell/scale", "shell/scale"}) {if !act(s, id) {return false}}
		if !go(s, "lab-hud") ||
		   !go(s, "catalogue") ||
		   s.model.scale != 1 ||
		   s.model.locale != .Russian {return false}
	}
	sample.action_ns = fixture.elapsed(f, t)
	t = fixture.begin(f); copy, copied := app.copy_reader(&s.runtime.live, s.allocator)
	if !copied {return false}; defer app.destroy_reader(&copy); sample.copy_ns = fixture.elapsed(f, t)
	effects := s.model.effects; revision := s.model.revision
	t = fixture.begin(f); s.runtime.fault = .Copy
	if app.rebuild(&s.runtime) ||
	   app.current(&s.runtime) {return false}; sample.failure_ns = fixture.elapsed(f, t)
	t = fixture.begin(f)
	if !app.recover(s) ||
	   s.model.effects != effects ||
	   s.model.revision != revision {return false}; sample.recovery_ns = fixture.elapsed(f, t)
	if !app.current(&s.runtime) {return false}
	when app.QUALIFICATION {
		sample.rebuild_phases_available = f.instrument
		sample.prepare_ns = s.runtime.qualification.phases[.Prepare].ns
		sample.phase_copy_ns = s.runtime.qualification.phases[.Copy].ns
		sample.commit_ns = s.runtime.qualification.phases[.Commit].ns
	}
	t = fixture.begin(
		f,
	); if !app.draw_reader(&s.runtime.live) {return false}; sample.draw_ns = fixture.elapsed(f, t)
	t = fixture.begin(
		f,
	); pixels, ok := backend.readback(f.renderer, s.drawable); if !ok {return false}; sdl.DestroySurface(pixels); sample.readback_ns = fixture.elapsed(f, t)
	t = fixture.begin(
		f,
	); if !sdl.RenderPresent(f.renderer) {return false}; sample.present_ns = fixture.elapsed(f, t)
	return true
}
