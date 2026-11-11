package collection_input

import "core:testing"
import base "ui:ui_base"
import ui "ui:ui_collections"
import adapter "ui:ui_collections/sdl"
import editor "ui:ui_editor"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import text "ui:ui_text"
import sdl "vendor:sdl3"

publish :: proc(
	t: ^testing.T,
	s: ^ui.State,
	ctx: ^interaction.Context,
	es: ^editor.State = nil,
	ed: editor.Description = {},
) -> bool {
	revision := u64(1); if ed.id != "" {revision = ed.revision}
	stamp, _ := base.begin_attempt(ctx.publication, revision)
	offset := f64(0); if len(s.frame.collections) > 0 {offset = s.frame.collections[0].offset}
	d := ui.Collection_Description {
		id         = "list",
		scroll_id  = "viewport",
		content_id = "content",
		height     = 20,
		items      = []ui.Collection_Item {
			{"a", "A", true, true, ""},
			{"b", "B", true, true, ""},
			{"c", "C", true, true, ""},
		},
	}
	c, ce := ui.prepare(
		s,
		stamp,
		d,
		{w = 100, h = 20},
		offset,
		focus_id = ctx.focus_id,
	); defer ui.destroy_candidate(&c)
	if !testing.expect(t, ce.code == .None) {return false}
	rows, re := ui.materialize(&c.frame); defer ui.destroy_nodes(rows)
	if !testing.expect(t, re.code == .None) {return false}
	nodes := make([]layout.Node, 5 + len(rows)); defer delete(nodes)
	nodes[0] = {
		id = "viewport",
		role = .Stack,
		enabled = true,
		visible = true,
		layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
	}
	nodes[1] = {
		id      = "content",
		parent  = "viewport",
		role    = .Column,
		enabled = true,
		visible = true,
		layout  = ui.content_layout(&c.frame),
	}
	copy(nodes[2:], rows)
	nodes[0].parent = "scene"
	nodes[0].layout = layout.Layout {
		x = {mode = .Fixed, value = 100},
		y = {mode = .Fixed, value = 20},
	}
	nodes[len(nodes) - 3] = {
		id = "scene",
		role = .Absolute,
		enabled = true,
		visible = true,
		layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
	}
	nodes[len(nodes) - 2] = {
		id = "field",
		parent = "scene",
		role = .Stack,
		enabled = true,
		visible = true,
		layout = layout.Layout {
			x = {mode = .Fixed, value = 100},
			y = {mode = .Fixed, value = 20},
			offset = {100, 0},
		},
	}
	nodes[len(nodes) - 1] = {
		id = "value",
		parent = "field",
		role = .Box,
		enabled = true,
		visible = true,
		layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
	}
	g, ge := layout.prepare(
		nodes,
		{drawable = {200, 20}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); defer layout.destroy_frame(&g)
	if !testing.expect(t, ge.code == .None) {return false}
	if !testing.expect(
		t,
		ui.validate_regions(&g, []ui.Collection_Description{d}).code == .None,
	) {return false}
	projected, pe := ui.project_layout(&c, &g); defer layout.destroy_frame(&projected)
	if !testing.expect(t, pe.code == .None) {return false}
	targets := make([]interaction.Target, 1 + len(c.frame.nodes)); defer delete(targets)
	for row, index in c.frame.nodes {targets[index] = {row.description.id, "button", row.enabled, row.visible}}
	targets[len(targets) - 1] = {"field", "editor", true, true}
	i, ie := interaction.prepare(
		&projected,
		targets,
		[]interaction.Capture_Claim{{"field", "editor"}},
		context.allocator,
	); defer interaction.destroy_frame(&i)
	if !testing.expect(
		t,
		ie == .Applied &&
		ui.bind_candidate(&c, &projected, &i).code == .None &&
		ui.validate_candidate(ctx.publication, s, &c),
	) {return false}
	focus := ""; if c.has_focus {focus = c.frame.collections[0].focus_node_id}
	ec: editor.Candidate; defer editor.destroy_candidate(&ec)
	if es != nil {
		description := ed
		if description.id == "" {description = {
				id           = "name",
				node_id      = "field",
				text_node_id = "value",
				value        = "Я",
				revision     = 1,
			}}
		tf := text.Frame {
			stamp       = stamp,
			text_blocks = []text.Text_Block {
				{
					node_id = "value",
					original_text = description.value,
					font_id = "test",
					font_revision = "test-v1",
					font_size = 12,
				},
			},
		}
		error: editor.Error
		ec, error = editor.prepare(
			es,
			&projected,
			&i,
			&tf,
			[]editor.Description{description},
			metrics(),
		)
		if !testing.expect(
			t,
			error.code == .None && editor.validate_candidate(ctx.publication, es, &ec),
		) {return false}
	}
	base.enter_commit(ctx.publication, stamp); interaction.commit(ctx, &i, focus); ui.commit(s, &c)
	if es != nil {editor.commit(es, &ec)}
	base.finish_commit(ctx.publication, stamp)
	return true
}

metrics :: proc() -> text.Text_Layout_Metrics {return {
		font_metrics = proc(
			_: string,
			_: f64,
			_: rawptr,
		) -> (
			text.Text_Font_Metrics,
			text.Text_Metric_Error,
		) {return {8, 2, 10, "test-v1"}, .None},
		measure_line = proc(
			_: string,
			_: string,
			_: f64,
			_: rawptr,
		) -> (
			text.Text_Line_Metrics,
			text.Text_Metric_Error,
		) {return {10, {10, 10}}, .None},
		validate_text = proc(
			_: string,
			_: string,
			_: f64,
			_: rawptr,
		) -> (
			text.Text_Metric_Error,
			int,
		) {return .None, 0},
	}}
@(test)
editor_and_collection_share_publication_focus_and_failure_barrier :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := ui.create(); defer ui.destroy(&s)
	es := editor.create(); defer editor.destroy(&es)
	if !publish(t, &s, &ctx, &es) {return}
	r := ui.dispatch(
		&s,
		&ctx,
		{kind = .Focus, collection_id = "list", item_id = "c", source = .Agent},
	)
	if !testing.expect(t, r.dispatch.code == .Applied && !p.ready) {return}
	if !publish(t, &s, &ctx, &es) {return}
	testing.expect(
		t,
		es.frame.stamp == s.frame.stamp &&
		ctx.frame.stamp == s.frame.stamp &&
		s.frame.collections[0].offset == 40,
	)
	id, code := ui.tab_target(&s.frame, &ctx.frame, ctx.focus_id, false)
	testing.expect(t, code == .Applied && id == "field")
	fr := interaction.dispatch(&ctx, {.Focus, "field", .Agent, false})
	if !testing.expect(t, fr.code == .Applied) {return}
	if !publish(t, &s, &ctx, &es) {return}
	er := editor.dispatch(
		&es,
		&ctx,
		{id = "name", kind = .Insert, text = "!", source = .Agent},
		metrics(),
	); defer editor.destroy_result(&er)
	testing.expect(
		t,
		er.code == .Applied &&
		er.proposal != nil &&
		er.proposal.?.value == "Я!" &&
		p.sequence == 1 &&
		!p.ready,
	)
	refused := ui.dispatch(
		&s,
		&ctx,
		{kind = .Activate, collection_id = "list", item_id = "c", source = .Agent},
	)
	testing.expect(t, refused.dispatch.code == .Not_Ready && p.sequence == 1)
	base.begin_attempt(&p, 2)
	testing.expect(
		t,
		!p.ready && es.frame.editors[0].value == "Я" && s.frame.collections[0].offset == 40,
	)
	if !publish(
		t,
		&s,
		&ctx,
		&es,
		{
			id = "name",
			node_id = "field",
			text_node_id = "value",
			value = er.proposal.?.value,
			revision = 2,
			resolution = {kind = .Accepted, sequence = er.proposal.?.sequence},
		},
	) {return}
	testing.expect(
		t,
		p.ready &&
		p.sequence == 1 &&
		es.pending == nil &&
		es.frame.editors[0].value == "Я!" &&
		s.frame.collections[0].offset == 40,
	)
}
@(test)
one_normalizer_click_rebuild_release_produces_one_logical_item_event :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := ui.create(); defer ui.destroy(&s)
	input := backend.Input {
		window_id = 1,
	}
	if !publish(t, &s, &ctx) {return}
	e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = 10,
		y        = 10,
	}
	r := adapter.handle(&s, &ctx, backend.normalize_event(&input, &ctx, e, {100, 20}))
	if !testing.expect(t, r.consumed && r.result.dispatch.code == .Applied && !p.ready) {return}
	if !publish(t, &s, &ctx) {return}
	e.button.type = .MOUSE_BUTTON_UP
	r = adapter.handle(&s, &ctx, backend.normalize_event(&input, &ctx, e, {100, 20}))
	testing.expect(
		t,
		r.consumed &&
		r.result.event != nil &&
		r.result.event.?.item_id == "a" &&
		p.sequence == 1 &&
		!p.ready,
	)
	r = adapter.handle(&s, &ctx, backend.normalize_event(&input, &ctx, e, {100, 20}))
	testing.expect(t, r.result.event == nil && p.sequence == 1)
}
@(test)
normalized_arrows_move_logically_and_tab_leaves_the_one_collection_stop :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := ui.create(); defer ui.destroy(&s)
	device := backend.Input {
		window_id = 1,
	}
	if !publish(t, &s, &ctx) {return}
	r := ui.dispatch(
		&s,
		&ctx,
		{kind = .Focus, collection_id = "list", item_id = "a", source = .Agent},
	)
	if !testing.expect(t, r.dispatch.code == .Applied) {return}
	if !publish(t, &s, &ctx) {return}
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 1,
		key      = sdl.K_DOWN,
	}
	ar := adapter.handle(&s, &ctx, backend.normalize_event(&device, &ctx, e, {200, 20}))
	if !testing.expect(t, ar.consumed && ar.result.dispatch.code == .Applied && !p.ready) {return}
	if !publish(t, &s, &ctx) {return}
	_, item, valid := ui.decode_item_node_id(ctx.focus_id)
	testing.expect(t, valid && item == "b" && p.sequence == 0)
	e.key.key = sdl.K_TAB
	ar = adapter.handle(&s, &ctx, backend.normalize_event(&device, &ctx, e, {200, 20}))
	testing.expect(
		t,
		ar.consumed && ar.result.dispatch.code == .Applied && ctx.focus_id == "field" && !p.ready,
	)
}
@(test)
normalized_wheel_uses_one_offset_owner_and_ignores_sibling_editor_region :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := ui.create(); defer ui.destroy(&s)
	device := backend.Input {
		window_id = 1,
	}
	if !publish(t, &s, &ctx) {return}
	e: sdl.Event; e.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 1,
		mouse_x  = 150,
		mouse_y  = 10,
		y        = -1,
	}
	r := adapter.handle(&s, &ctx, backend.normalize_event(&device, &ctx, e, {200, 20}))
	testing.expect(t, !r.consumed && p.ready)
	e.wheel.mouse_x = 10
	r = adapter.handle(&s, &ctx, backend.normalize_event(&device, &ctx, e, {200, 20}))
	if !testing.expect(t, r.consumed && r.result.dispatch.code == .Applied && !p.ready) {return}
	if !publish(t, &s, &ctx) {return}
	testing.expect(t, s.frame.collections[0].offset == 30 && p.sequence == 0)
}
