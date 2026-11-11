package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import text "../../ui_text"
import "core:testing"
import sdl "vendor:sdl3"

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
			v, _: string,
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
publish :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^editor.State,
	d: editor.Description,
	focus := "field",
) -> bool {
	stamp, _ := base.begin_attempt(p, d.revision)
	nodes := [2]layout.Node {
		{
			id = "field",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
		{
			id = "value",
			parent = "field",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {200, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	)
	if !testing.expect(t, ge.code == .None) {return false}; defer layout.destroy_frame(&g)
	i, ie := interaction.prepare(
		&g,
		[]interaction.Target{{"field", "editor", true, true}},
		[]interaction.Capture_Claim{{"field", "editor"}},
		context.allocator,
	)
	if !testing.expect(t, ie == .Applied) {return false}; defer interaction.destroy_frame(&i)
	blocks := [1]text.Text_Block {
		{node_id = "value", original_text = d.value, font_id = "font", font_size = 12},
	}
	tf := text.Frame {
		stamp       = stamp,
		text_blocks = blocks[:],
	}
	c, ce := editor.prepare(
		s,
		&g,
		&i,
		&tf,
		[]editor.Description{d},
		metrics(),
	); defer editor.destroy_candidate(&c)
	if !testing.expect(t, ce.code == .None && editor.validate_candidate(p, s, &c)) {return false}
	if !testing.expect(t, base.enter_commit(p, stamp) == .None) {return false}
	interaction.commit(ctx, &i, focus); editor.commit(s, &c); base.finish_commit(p, stamp)
	return true
}
@(test)
normalized_committed_text_is_one_proposal_and_keyboard_is_specialized :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := editor.create(); defer editor.destroy(&s)
	d := editor.Description {
		id           = "name",
		node_id      = "field",
		text_node_id = "value",
		value        = "a",
		revision     = 1,
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	a := create(); input := backend.Input {
		window_id = 5,
	}
	e: sdl.Event; e.text = {
		type     = .TEXT_INPUT,
		windowID = 5,
		text     = "я",
	}
	n := backend.normalize_event(&input, &ctx, e, {200, 100})
	r := event(&a, &input, &ctx, &s, n, metrics()); defer editor.destroy_result(&r.editor)
	if !testing.expect(t, r.consumed && r.has_editor && r.editor.proposal != nil) {return}
	testing.expect(t, r.editor.proposal.?.value == "aя" && p.sequence == 1 && !p.ready)
	d.value = "aя"; d.revision = 2; d.resolution = {
		kind     = .Accepted,
		sequence = p.sequence,
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_HOME,
	}
	n = backend.normalize_event(&input, &ctx, e, {200, 100})
	editor.destroy_result(&r.editor)
	r = event(&a, &input, &ctx, &s, n, metrics())
	testing.expect(
		t,
		r.consumed && r.has_editor && r.editor.code == .Applied && !p.ready && p.sequence == 1,
	)
	if !publish(t, &p, &ctx, &s, d) {return}
	v, _ := editor.find(&s.frame, "name"); testing.expect(t, v.caret == 0)
	e.text = {
		type     = .TEXT_INPUT,
		windowID = 6,
		text     = "x",
	}
	testing.expect(
		t,
		!event(&a, &input, &ctx, &s, backend.normalize_event(&input, &ctx, e, {200, 100}), metrics()).consumed,
	)
}
