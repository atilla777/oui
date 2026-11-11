package main

import recipe ".."
import fixture "../../native_fixture"
import "core:fmt"
import "core:os"
import base "ui:ui_base"
import controls "ui:ui_controls"
import ca "ui:ui_controls/sdl"
import editor "ui:ui_editor"
import ea "ui:ui_editor/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"

State :: struct {
	p:                  base.Publication,
	ctx:                interaction.Context,
	ls:                 layers.State,
	cs:                 controls.State,
	es:                 editor.State,
	controls:           ca.Adapter,
	editing:            ea.Adapter,
	reader:             recipe.Reader,
	checked:            bool,
	effects, conflicts: int,
	revision:           u64,
}
publish :: proc(f: ^fixture.Fixture, s: ^State) {recipe.destroy_reader(&s.reader); s.reader =
		recipe.publish(
			&s.p,
			&s.ctx,
			&s.ls,
			&s.cs,
			&s.es,
			s.checked,
			s.revision,
			&s.conflicts,
			{800, 600},
			fonts.metrics(f.fonts),
			"Имя" if f.russian else "Name",
			"Включено" if f.russian else "Enabled",
		)
	assert(ea.sync(&s.editing, &f.input, &s.ctx, &s.es, f.window))}
input :: proc(f: ^fixture.Fixture, s: ^State, e: sdl.Event) {
	n := fixture.normalized(f, &s.ctx, e)
	er := ea.event(&s.editing, &f.input, &s.ctx, &s.es, n, fonts.metrics(f.fonts))
	defer editor.destroy_result(&er.editor)
	if !er.consumed {
		cr := ca.handle(&s.controls, &s.cs, &s.ctx, &s.reader.geometry, n)
		if !cr.consumed && n.has_action && n.action.kind == .Activate {
			for c in s.cs.frame.controls {if c.node_id == n.action.id {cr.result = controls.dispatch(&s.cs, &s.ctx, {kind = .Activate, id = c.node_id, source = n.action.source}, &s.ls); cr.consumed = true; break}}
		}
		if cr.result.event !=
		   nil {s.checked = cr.result.event.?.checked; s.effects += 1; s.revision += 1}
		if !cr.consumed {backend.dispatch_input(&s.ctx, n)}
	}
	publish(f, s)
}
verify :: proc(f: ^fixture.Fixture, s: ^State) {
	assert(s.editing.text_active)
	e: sdl.Event; e.key = {
			type     = .KEY_DOWN,
			windowID = f.input.window_id,
			key      = sdl.K_END,
		}
	input(f, s, e); e.key.type = .KEY_UP; input(f, s, e)
	id := s.cs.frame.controls[0].node_id
	assert(
		interaction.dispatch(&s.ctx, {kind = .Focus, id = id, source = .Agent}).code == .Applied,
	); publish(f, s)
	e.key = {
			type     = .KEY_DOWN,
			windowID = f.input.window_id,
			key      = sdl.K_SPACE,
		}; input(f, s, e)
	assert(s.checked && s.effects == 1)
	e.key.type = .KEY_UP; input(f, s, e)
	base.invalidate(&s.p)
	assert(
		editor.dispatch(&s.es, &s.ctx, {kind = .Submit, id = "name", source = .Agent}, fonts.metrics(f.fonts)).code ==
		.Not_Ready,
	)
	publish(f, s); assert(s.effects == 1)
	fmt.println(
		"native-settings=ok native-font-metrics=true text-lifecycle=true checkbox-effects=1 recovery=no-replay input=native-synthetic",
	)
}
main :: proc() {if !run() {os.exit(1)}}
run :: proc() -> bool {
	f: fixture.Fixture; defer fixture.close(&f); if !fixture.init(&f) {return false}
	context.allocator = fixture.owner_allocator(&f)
	s: State; s.revision = 1
	p, e := base.create(context.allocator); if e != .None {return false}; s.p = p
	s.ctx = interaction.create(
		context.allocator,
		&s.p,
	); s.ls = layers.create(context.allocator); s.cs = controls.create(); s.es = editor.create(); s.controls = ca.create(context.allocator); s.editing = ea.create()
	defer {assert(ea.close(&s.editing, f.window)); ca.destroy(&s.controls)
		recipe.destroy_reader(&s.reader)
		editor.destroy(&s.es)
		controls.destroy(&s.cs)
		layers.destroy(&s.ls)
		interaction.destroy(&s.ctx)
		base.destroy(&s.p)}
	publish(&f, &s)
	fixture.require_owner_observations(&f)
	fixture.describe(&f)
	for {
		event: sdl.Event
		for sdl.PollEvent(
			    &event,
		    ) {if fixture.quit(event) {return true}; if fixture.check(event) {fixture.check_invalid_font(&f); verify(&f, &s)} else {input(&f, &s, event)}}
		if !fixture.paint(&f, &s.reader.geometry, &s.reader.text) {return false}; sdl.Delay(10)
	}
}
