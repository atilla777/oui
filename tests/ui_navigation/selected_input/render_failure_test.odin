package main

import "core:fmt"
import "core:mem"
import "core:testing"
import base "ui:ui_base"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

@(test)
native_bad_font_after_image_candidate_preserves_the_complete_old_bundle :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	testing.expect(t, publish(&e.r)); stamp := e.r.ctx.frame.stamp
	bad := [8]u8 {
		1,
		2,
		3,
		4,
		5,
		6,
		7,
		8,
	}; e.r.render.font_data = bad[:]; e.r.render.font_revision = "bad-font"; e.r.render.image_revision = "new-image"
	testing.expect(
		t,
		!publish(&e.r) &&
		!e.r.p.ready &&
		e.r.ctx.frame.stamp == stamp &&
		e.r.reader.render.paint.stamp == stamp,
	)
	testing.expect(
		t,
		e.font_ledger.live == 1 &&
		e.image_ledger.live == 1 &&
		e.image_ledger.created == 2 &&
		e.image_ledger.destroyed == 1,
	)
}

@(test)
renderer_replacement_cannot_mix_old_generations_with_new_output :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e); testing.expect(t, publish(&e.r))
	surface := sdl.CreateSurface(400, 300, .RGBA32); defer sdl.DestroySurface(surface)
	other := sdl.CreateSoftwareRenderer(surface); defer sdl.DestroyRenderer(other)
	e.r.render.renderer = other
	testing.expect(
		t,
		!render_current(&e.r) && !e.r.p.ready,
		"new renderer requires a complete new generation/bundle publication",
	)
	e.r.render.renderer = e.renderer
}

@(test)
partial_layer_render_failure_restores_renderer_and_blocks_all_captures :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	testing.expect(t, publish(&e.r)); button(&e.r, 20, 50, true); testing.expect(t, publish(&e.r))
	testing.expect(t, e.r.controls_input.capture_id == "level")
	clip := sdl.Rect {
		2,
		3,
		17,
		19,
	}; sdl.SetRenderClipRect(e.renderer, &clip); sdl.SetRenderScale(e.renderer, 1.2, 1.3); sdl.SetRenderDrawColor(e.renderer, 41, 43, 47, 113)
	before, ok := backend.save_renderer_state(e.renderer); testing.expect(t, ok)
	// A concrete malformed command fails after earlier commands already drew.
	e.r.reader.layers.paint[3].node_index = -1
	testing.expect(
		t,
		!render_current(&e.r) &&
		!e.r.p.ready &&
		e.r.controls_input.capture_id == "" &&
		!e.r.hold_input.has_base,
	)
	after, _ := backend.save_renderer_state(e.renderer); testing.expect(t, before == after)
}

@(test)
precommit_and_readback_boundary_faults_restore_state_and_recover_without_replay :: proc(
	t: ^testing.T,
) {
	if !RENDER_TEST {return}
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	testing.expect(t, publish(&e.r)); stamp := e.r.ctx.frame.stamp
	e.r.render.fault = .Precommit
	testing.expect(
		t,
		!publish(&e.r) &&
		e.r.ctx.frame.stamp == stamp &&
		e.r.reader.render.paint.stamp == stamp &&
		!e.r.p.ready,
	)
	testing.expect(t, e.font_ledger.live == 1 && e.image_ledger.live == 1)
	e.r.render.fault = .None; testing.expect(t, publish(&e.r))
	e.r.render.fault = .Readback; before, _ := backend.save_renderer_state(e.renderer)
	surface, ok := readback_current(&e.r); defer {if surface != nil {sdl.DestroySurface(surface)}}
	testing.expect(t, !ok && surface == nil && !e.r.p.ready && e.r.p.sequence == 0)
	after, _ := backend.save_renderer_state(e.renderer); testing.expect(t, before == after)
	e.r.render.fault = .None; testing.expect(t, publish(&e.r)); testing.expect(t, render_current(&e.r) && e.r.p.sequence == 0)
}

@(test)
render_publisher_allocator_refusals_release_every_candidate_and_native_generation :: proc(
	t: ^testing.T,
) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	previous :=
		context.allocator; backing := mem.tracking_allocator(&tracking); context.allocator = backing; defer {context.allocator = previous}
	testing.expect(t, publish(&e.r))
	e.r.render.font_revision = "font-2"; e.r.render.image_revision = "image-2"
	samples := [3]base.Geometry_Entry {
		{
			id = "slider",
			input_enabled = true,
			geometry = {
				scale = 2,
				offset = {100, -40},
				opacity = 0.5,
				bounds = {100, 40, 200, 60},
				content = {100, 40, 200, 60},
				clip = {100, 40, 200, 60},
				content_clip = {100, 40, 200, 60},
			},
		},
		{
			id = "track",
			input_enabled = true,
			geometry = {
				scale = 2,
				offset = {100, -40},
				opacity = 0.5,
				bounds = {100, 40, 200, 40},
				content = {100, 40, 200, 40},
				clip = {100, 40, 200, 40},
				content_clip = {100, 40, 200, 40},
			},
		},
		{
			id = "slider-label",
			input_enabled = true,
			geometry = {
				scale = 2,
				offset = {100, -40},
				opacity = 0.5,
				bounds = {108, 44, 176, 48},
				content = {108, 44, 176, 48},
				clip = {108, 44, 176, 48},
				content_clip = {108, 44, 176, 48},
			},
		},
	}
	fault := Fault {
		backing = backing,
	}; a := mem.Allocator{fault_allocator, &fault}
	context.allocator =
		a; testing.expect(t, publish(&e.r, samples[:])); count := fault.count; context.allocator = backing
	live :=
		tracking.current_memory_allocated; refs := e.r.p.lifetime.references; stamp := e.r.ctx.frame.stamp
	e.r.render.font_revision = "font-3"; e.r.render.image_revision = "image-3"
	for pos in 1 ..= count {
		fault.count, fault.refuse = 0, pos; context.allocator = a
		ok := publish(&e.r, samples[:]); context.allocator = backing
		testing.expect(
			t,
			!ok &&
			!e.r.p.ready &&
			e.r.ctx.frame.stamp == stamp &&
			e.r.reader.render.paint.stamp == stamp,
			fmt.tprintf("render publish refusal=%d", pos),
		)
		testing.expect(
			t,
			tracking.current_memory_allocated == live &&
			len(tracking.bad_free_array) == 0 &&
			e.r.p.lifetime.references == refs &&
			e.font_ledger.live == 1 &&
			e.image_ledger.live == 1,
			fmt.tprintf("render cleanup refusal=%d", pos),
		)
	}
	// Destroy these owners while their tracking/fault allocator state still lives.
	destroy(
		&e.r,
	); testing.expect(t, tracking.current_memory_allocated == 0 && e.font_ledger.live == 0 && e.image_ledger.live == 0)
	fmt.printf(
		"render publisher-refusals=%d peak=%d live=%d fonts=%d/%d images=%d/%d\n",
		count,
		tracking.peak_memory_allocated,
		tracking.current_memory_allocated,
		e.font_ledger.created,
		e.font_ledger.destroyed,
		e.image_ledger.created,
		e.image_ledger.destroyed,
	)
}
