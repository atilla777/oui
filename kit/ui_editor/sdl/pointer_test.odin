package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"
@(test)
ordinary_front_target_shields_editor_pointer_acquisition :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := editor.create(); defer editor.destroy(&s)
	d := editor.Description {
		id           = "name",
		node_id      = "field",
		text_node_id = "value",
		value        = "abc",
		revision     = 1,
	}
	a := create(); defer cancel_capture(&a); input := backend.Input {
		window_id = 5,
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	// A frozen ordinary front target in the common projection, not an editor.
	views := make([]interaction.Target_View, len(ctx.frame.targets) + 1)
	copy(views, ctx.frame.targets); delete(ctx.frame.targets); ctx.frame.targets = views
	id, _ := strings.clone("shield"); role, _ := strings.clone("button")
	views[len(views) - 1] = {
		description = {id = id, role = role},
		availability = .Applied,
		bounds = {0, 0, 100, 20},
		clip = {0, 0, 100, 20},
	}
	e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 5,
		button   = 1,
		x        = 6,
		y        = 5,
	}
	r := event(
		&a,
		&input,
		&ctx,
		&s,
		backend.normalize_event(&input, &ctx, e, {200, 100}),
		metrics(),
	)
	testing.expect(t, !r.consumed && a.capture_id == "" && p.ready)
}
@(test)
invalid_coordinate_release_still_cleans_editor_capture :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := editor.create(); defer editor.destroy(&s)
	d := editor.Description {
		id           = "name",
		node_id      = "field",
		text_node_id = "value",
		value        = "abc",
		revision     = 1,
	}
	a := create(); defer cancel_capture(&a); input := backend.Input {
		window_id = 5,
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 5,
		button   = 1,
		x        = 6,
		y        = 5,
	}
	event(&a, &input, &ctx, &s, backend.normalize_event(&input, &ctx, e, {200, 100}), metrics())
	testing.expect(t, a.capture_id != "" && !p.ready)
	e.button.type = .MOUSE_BUTTON_UP
	r := event(&a, &input, &ctx, &s, backend.normalize_event(&input, &ctx, e, {}), metrics())
	testing.expect(t, r.consumed && a.capture_id == "" && !p.ready && p.sequence == 0)
}
@(test)
pointer_focus_rebuild_selection_and_release_while_not_ready :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := editor.create(); defer editor.destroy(&s)
	d := editor.Description {
		id           = "name",
		node_id      = "field",
		text_node_id = "value",
		value        = "aя",
		revision     = 1,
	}
	a := create(); defer cancel_capture(&a); input := backend.Input {
		window_id = 5,
	}
	if !publish(t, &p, &ctx, &s, d, "") {return}
	e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 5,
		button   = 1,
		x        = 6,
		y        = 5,
	}
	r := event(
		&a,
		&input,
		&ctx,
		&s,
		backend.normalize_event(&input, &ctx, e, {200, 100}),
		metrics(),
	)
	if !testing.expect(
		t,
		r.consumed && !p.ready && a.capture_id == "name" && ctx.focus_id == "field",
	) {return}
	if !publish(t, &p, &ctx, &s, d) {return}
	r = take_pointer(&a, &ctx, &s, metrics())
	testing.expect(t, r.consumed && r.has_editor && r.editor.code == .Applied && !p.ready)
	if !publish(t, &p, &ctx, &s, d) {return}
	v, _ := editor.find(&s.frame, "name"); testing.expect(t, v.caret == 1 && v.anchor == 1)
	e.motion = {
		type     = .MOUSE_MOTION,
		windowID = 5,
		x        = 19,
		y        = 5,
	}
	r = event(
		&a,
		&input,
		&ctx,
		&s,
		backend.normalize_event(&input, &ctx, e, {200, 100}),
		metrics(),
	)
	testing.expect(t, r.consumed && r.has_editor && !p.ready)
	e.button = {
		type     = .MOUSE_BUTTON_UP,
		windowID = 5,
		button   = 1,
		x        = 19,
		y        = 5,
	}
	r = event(
		&a,
		&input,
		&ctx,
		&s,
		backend.normalize_event(&input, &ctx, e, {200, 100}),
		metrics(),
	)
	testing.expect(t, r.consumed && a.capture_id == "" && !p.ready)
	if !publish(t, &p, &ctx, &s, d) {return}
	v, _ = editor.find(
		&s.frame,
		"name",
	); testing.expect(t, v.caret == 3 && v.anchor == 1 && p.sequence == 0)
}
