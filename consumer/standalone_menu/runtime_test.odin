package main

import "core:mem"
import "core:os"
import "core:testing"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
publication_and_owning_reader :: proc(t: ^testing.T) {
	testing.expect(t, ttf.Init()); defer ttf.Quit()
	surface := sdl.CreateSurface(
		480,
		320,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	r: Runtime
	if !testing.expect(t, init(&r, renderer, data, 2, a)) {return}; defer destroy(&r)
	r.drawable = {480, 320}
	if !testing.expect(t, rebuild(&r)) {return}
	testing.expect(
		t,
		r.interaction.focus_id == "action" && r.rebuilds == 1 && r.model.effects == 0,
	)
	testing.expect(t, base.is_current(&r.publication, r.live.text.stamp))
	action := interaction.dispatch(&r.interaction, {.Activate, "action", .Agent, false})
	if !testing.expect(t, action.has_event && accept(&r, action.event)) {return}
	testing.expect(t, !accept(&r, action.event) && r.model.count == 1 && r.model.effects == 1)
	if !testing.expect(t, rebuild(&r)) {return}
	for id in ([3]string{"open", "language", "back"}) {
		result := interaction.dispatch(&r.interaction, {.Activate, id, .Agent, false})
		if !testing.expect(t, result.has_event && accept(&r, result.event) && rebuild(&r)) {return}
		if id == "open" {testing.expect(t, r.interaction.focus_id == "language")}
	}
	testing.expect(
		t,
		r.model.count == 1 && r.model.effects == 4 && r.interaction.focus_id == "action",
	)
	testing.expect(t, present(&r))
	baseline := tracking.current_memory_allocated
	for _ in 0 ..< 64 {testing.expect(t, rebuild(&r))}
	testing.expect(t, r.model.effects == 4 && tracking.current_memory_allocated == baseline)
	other_surface := sdl.CreateSurface(480, 320, .RGBA32); testing.expect(t, other_surface != nil)
	other_renderer := sdl.CreateSoftwareRenderer(
		other_surface,
	); testing.expect(t, other_renderer != nil)
	r.renderer = other_renderer
	testing.expect(t, !rebuild(&r) && !r.publication.ready)
	r.renderer = renderer
	testing.expect(t, rebuild(&r))
	sdl.DestroyRenderer(other_renderer); sdl.DestroySurface(other_surface)
	r.input.window_id = 17
	before_native := r.model.effects
	event: sdl.Event; event.key = {
		type     = .KEY_DOWN,
		windowID = 17,
		key      = sdl.K_RETURN,
	}
	testing.expect(t, handle_input(&r, event, {480, 320}))
	event.key.repeat = true
	testing.expect(t, handle_input(&r, event, {480, 320}) && r.model.effects == before_native + 1)
	when TEST {
		for fault in ([7]Fault{.Prepare, .Resource, .Copy, .Publish, .Render, .Readback, .Present}) {
			activation := interaction.dispatch(
				&r.interaction,
				{.Activate, "action", .Agent, false},
			)
			testing.expect(t, activation.has_event && accept(&r, activation.event))
			accepted := r.model
			old_stamp := r.live.text.stamp
			r.fault = fault
			if fault <= .Publish {
				testing.expect(t, !rebuild(&r) && r.live.text.stamp == old_stamp)
			} else {
				testing.expect(t, rebuild(&r))
				testing.expect(t, !present(&r))
			}
			testing.expect(t, r.model == accepted && !r.publication.ready)
			testing.expect(
				t,
				interaction.dispatch(&r.interaction, {.Activate, "action", .Agent, false}).code ==
					.Not_Ready &&
				!present(&r),
			)
			r.fault = .None
			testing.expect(t, rebuild(&r) && present(&r) && r.model == accepted)
			testing.expect(t, !accept(&r, activation.event))
		}
	}
	reader, ok := copy_reader(&r.live, a); if !testing.expect(t, ok) {return}
	destroy(&r)
	testing.expect(t, draw_reader(&reader)) // Historical draw, never current dispatch/snapshot.
	testing.expect(t, reader.text.text_blocks[0].original_text == "Меню")
	testing.expect(t, reader.fonts.fonts[0].font != nil && reader.images.renderer == renderer)
	destroy_reader(&reader)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
