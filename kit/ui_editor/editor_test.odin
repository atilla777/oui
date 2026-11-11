package ui_editor

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import text "../ui_text"
import "core:testing"

metrics :: proc() -> text.Text_Layout_Metrics {return {
		font_metrics = proc(
			_: string,
			_: f64,
			_: rawptr,
		) -> (
			text.Text_Font_Metrics,
			text.Text_Metric_Error,
		) {return {8, 2, 10, "test-font-v1"}, .None},
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
// A real layout/interaction projection; only font metrics are deterministic.
publish :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^State,
	d: Description,
) -> bool {
	stamp, pe := base.begin_attempt(
		p,
		d.revision,
	); if !testing.expect(t, pe == .None) {return false}
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
	targets := [1]interaction.Target{{"field", "editor", true, true}}
	claims := [1]interaction.Capture_Claim{{"field", "editor"}}
	i, ie := interaction.prepare(&g, targets[:], claims[:], context.allocator)
	if !testing.expect(t, ie == .Applied) {return false}; defer interaction.destroy_frame(&i)
	// Borrowed text projection supplied by the explicit selected composition.
	blocks := [1]text.Text_Block {
		{
			node_id = "value",
			original_text = d.value,
			font_id = "test",
			font_revision = "test-font-v1",
			font_size = 12,
		},
	}
	tf := text.Frame {
		stamp       = stamp,
		text_blocks = blocks[:],
	}
	c, ce := prepare(s, &g, &i, &tf, ([]Description{d}), metrics())
	defer destroy_candidate(&c)
	if !testing.expect(
		t,
		ce.code == .None && validate_candidate(p, s, &c),
		"editor candidate must prepare against shared owners",
	) {return false}
	if !testing.expect(t, base.enter_commit(p, stamp) == .None) {return false}
	interaction.commit(ctx, &i, "field"); commit(s, &c); base.finish_commit(p, stamp)
	return true
}
description :: proc(value := "aяb") -> Description {return {
		id = "name",
		node_id = "field",
		text_node_id = "value",
		label = "Имя / Name",
		value = value,
		revision = 1,
	}}

@(test)
editor_selection_and_delete_emit_one_owned_proposal :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	d := description("a\u0301я")
	if !publish(t, &p, &ctx, &s, d) {return}
	r := dispatch(&s, &ctx, {id = "name", kind = .Select, anchor = 3, caret = 3}, metrics())
	testing.expect(t, r.code == .Applied && r.proposal == nil && !p.ready && p.sequence == 0)
	if !publish(t, &p, &ctx, &s, d) {return}
	r = dispatch(&s, &ctx, {id = "name", kind = .Backspace}, metrics())
	defer destroy_result(&r)
	proposal, has := r.proposal.?
	if !testing.expect(t, r.code == .Applied && has && !p.ready && p.sequence == 1) {return}
	testing.expect(t, proposal.value == "я" && proposal.caret == 0 && proposal.base_revision == 1)
	testing.expect(
		t,
		dispatch(&s, &ctx, {id = "name", kind = .Backspace}, metrics()).code == .Not_Ready,
	)
	d.value = "я"; d.revision = 2; d.resolution = {
		kind     = .Accepted,
		sequence = proposal.sequence,
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	e, _ := find(&s.frame, "name")
	testing.expect(t, e.value == "я" && e.caret == 0 && p.sequence == 1 && s.pending == nil)
	// Independent result survives the mandatory rebuild/pending disposal.
	testing.expect(t, proposal.value == "я")
}
@(test)
editor_prepares_owned_unicode_geometry :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	if !publish(t, &p, &ctx, &s, description()) {return}
	e, ok := find(&s.frame, "name")
	testing.expect(t, ok && e.count == 3 && e.caret == 4 && e.anchor == 4 && e.stops[3] == 30)
	testing.expect(t, p.ready && s.frame.stamp == ctx.frame.stamp && p.sequence == 0)
}
