package main

import recipe ".."
import fixture "../../native_fixture"
import "core:fmt"
import "core:os"
import base "ui:ui_base"
import collections "ui:ui_collections"
import ca "ui:ui_collections/sdl"
import gestures "ui:ui_gestures"
import ga "ui:ui_gestures/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

State :: struct {
	p:                  base.Publication,
	ctx:                interaction.Context,
	ls:                 layers.State,
	left, right:        collections.State,
	gs:                 gestures.State,
	adapter:            ga.Adapter,
	reader:             recipe.Reader,
	moved:              bool,
	effects, conflicts: int,
	revision:           u64,
}
publish :: proc(s: ^State) {recipe.destroy_reader(&s.reader); s.reader = recipe.publish(
		&s.p,
		&s.ctx,
		&s.ls,
		&s.left,
		&s.right,
		&s.gs,
		s.moved,
		s.revision,
		&s.conflicts,
		{800, 600},
	)}
input :: proc(f: ^fixture.Fixture, s: ^State, e: sdl.Event) {
	n := fixture.normalized(f, &s.ctx, e)
	gr := ga.event(&s.adapter, &f.input, &s.ctx, &s.gs, nil, n)
	if gr.has_gesture && gr.gesture.has_proposal {
		assert(
			gr.gesture.proposal.payload_id == "a" && gr.gesture.proposal.target_id == "right-drop",
		)
		// Bounded fixture app decision; the full Cancel/Confirm transaction remains Lab.
		s.moved = true; s.effects += 1; s.revision += 1
	}
	if !gr.consumed {lr := ca.handle(&s.left, &s.ctx, n); if !lr.consumed {rr := ca.handle(&s.right, &s.ctx, n); if !rr.consumed {backend.dispatch_input(&s.ctx, n)}}}
	publish(s)
}
verify :: proc(f: ^fixture.Fixture, s: ^State) {
	e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = f.input.window_id,
		button   = 1,
		x        = 8,
		y        = 88,
	}; input(f, s, e)
	e.motion = {
		type     = .MOUSE_MOTION,
		windowID = f.input.window_id,
		x        = 16,
		y        = 88,
	}; input(f, s, e)
	e.motion.x = 160; e.motion.y = 8; input(f, s, e)
	e.button = {
		type     = .MOUSE_BUTTON_UP,
		windowID = f.input.window_id,
		button   = 1,
		x        = 160,
		y        = 8,
	}; input(f, s, e)
	assert(s.moved && s.effects == 1)
	_, missing := collections.lookup_collection_item(&s.reader.left, "left", "a")
	v, found := collections.lookup_collection_item(&s.reader.right, "right", "a")
	assert(missing == .Not_Found && found == .Applied && v.selected)
	base.invalidate(
		&s.p,
	); assert(gestures.dispatch(&s.gs, &s.ctx, nil, {kind = .Begin, id = "drag", source = .Agent}).code == .Not_Ready)
	publish(s); assert(s.effects == 1)
	fmt.println(
		"native-inventory=ok two-regions=true drag-effect=1 stable-membership=true recovery=no-replay input=native-synthetic",
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
	); s.ls = layers.create(context.allocator); s.left = collections.create(); s.right = collections.create(); s.gs = gestures.create()
	defer {recipe.destroy_reader(&s.reader); gestures.destroy(&s.gs); collections.destroy(&s.left)
		collections.destroy(&s.right)
		layers.destroy(&s.ls)
		interaction.destroy(&s.ctx)
		base.destroy(&s.p)}
	publish(&s)
	fixture.require_owner_observations(&f)
	fixture.describe(&f)
	for {
		event: sdl.Event
		for sdl.PollEvent(
			    &event,
		    ) {if fixture.quit(event) {return true}; if fixture.check(event) {fixture.check_invalid_font(&f); verify(&f, &s)} else {input(&f, &s, event)}}
		labels := []string {
			"Left",
			"Right",
			"Move A",
		}; if f.russian {labels = []string{"Слева", "Справа", "Перенести A"}}
		ids := make([dynamic]string); defer delete(ids)
		values := make([dynamic]string); defer delete(values)
		append(&ids, "left-header", "right-header", "handle"); append(&values, ..labels)
		for frame in ([2]collections.Frame{s.reader.left, s.reader.right}) {for n in frame.nodes {if n.visible && n.clip.h > 0 && n.bounds.y >= n.clip.y && n.bounds.y + n.bounds.h <= n.clip.y + n.clip.h {append(&ids, n.description.id); append(&values, n.item.semantic_name)}}}
		if !fixture.paint_labels(
			&f,
			&s.reader.geometry,
			ids[:],
			values[:],
		) {return false}; sdl.Delay(10)
	}
}
