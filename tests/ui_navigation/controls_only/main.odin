package main

import "core:fmt"
import "core:mem"
import "core:unicode/utf8"
import base "ui:ui_base"
import controls "ui:ui_controls"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import style "ui:ui_style"
import text "ui:ui_text"

font :: proc(
	id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Font_Metrics,
	text.Text_Metric_Error,
) {return {8, 2, 10, "fixture"}, .None}
measure :: proc(
	s, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Line_Metrics,
	text.Text_Metric_Error,
) {w := f64(utf8.rune_count_in_string(s)) * 5; return {w, {w, 10}}, .None}
validate :: proc(
	s, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Metric_Error,
	int,
) {return .None, 0}
Reader :: struct {
	geometry: layout.Frame,
	text:     text.Frame,
	paint:    style.Frame,
	controls: controls.Frame,
}
destroy_reader :: proc(r: ^Reader) {layout.destroy_frame(&r.geometry); text.destroy_frame(&r.text)
	style.destroy_frame(&r.paint)
	controls.destroy_frame(&r.controls)
	r^ = {}}
copy_reader :: proc(
	g: ^layout.Frame,
	t: ^text.Frame,
	p: ^style.Frame,
	c: ^controls.Frame,
	a: mem.Allocator,
) -> (
	Reader,
	bool,
) {
	r: Reader; complete := false; defer {if !complete {destroy_reader(&r)}}
	ok: bool; r.geometry, ok = layout.try_copy_frame(g, a); if !ok {return {}, false}
	r.text, ok = text.try_copy_frame(t, a); if !ok {return {}, false}
	r.paint, ok = style.try_copy_frame(p, a); if !ok {return {}, false}
	r.controls, ok = controls.try_copy_frame(c, a); if !ok {return {}, false}
	complete = true; return r, true
}
report :: proc(name: string, a: ^mem.Tracking_Allocator) {fmt.printf(
		"%s allocations=%d bytes=%d live=%d peak=%d handlers=0 backend-resources=0\n",
		name,
		a.total_allocation_count,
		a.total_memory_allocated,
		a.current_memory_allocated,
		a.peak_memory_allocated,
	)}
main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, pe := base.create(context.allocator); assert(pe == .None)
	ctx := interaction.create(context.allocator, &p)
	ls := layers.create(context.allocator); cs := controls.create()
	reader: Reader
	checked := false; effects := u64(0)
	report("common-init", &tracking)
	words := [2]string{"Enable", "Включено"}
	for locale in 0 ..< 2 {
		stamp, be := base.begin_attempt(&p, u64(locale)); assert(be == .None)
		recipe, re := controls.compose_control(
			{id = "enabled", kind = .Checkbox, label = words[locale], checked = checked},
			"base",
			"root",
			context.allocator,
			font = {"fixture"},
			font_size = 10,
		); assert(re.code == .None)
		nodes := make([dynamic]layout.Node)
		append(
			&nodes,
			layout.Node {
				id = "root",
				role = .Stack,
				enabled = true,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 300},
					y = {mode = .Fixed, value = 100},
				},
			},
			layout.Node {
				id = "base",
				parent = "root",
				role = .Column,
				enabled = true,
				visible = true,
				layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
			},
		)
		append(&nodes, ..recipe.nodes[:])
		tc, te := text.prepare(
			recipe.texts[:],
			nodes[:],
			{drawable = {300, 100}, ui_scale = 1},
			{font, measure, validate, nil},
			context.allocator,
			stamp,
		); assert(te.code == .None)
		claims := make(
			[]interaction.Capture_Claim,
			len(recipe.targets),
		); for target, k in recipe.targets {claims[k] = {target.id, "controls"}}
		lc, le := layers.prepare(
			&ls,
			&ctx,
			&tc.geometry,
			recipe.targets[:],
			claims,
			{base_root_id = "base"},
			context.allocator,
		); assert(le.code == .None)
		ds := [1]controls.Description{recipe.control}
		cc, ce := controls.prepare(
			&lc.interaction,
			lc.frame.layers,
			ds[:],
			context.allocator,
			&tc.geometry,
		); assert(ce.code == .None)
		for &d in recipe.styles {if d.id == lc.focus_id {d.states += {.Focused}}}
		paint, se := style.prepare(
			&tc.geometry,
			recipe.styles[:],
			{},
			{},
			context.allocator,
		); assert(se.code == .None)
		next, ok := copy_reader(&tc.geometry, &tc.text, &paint, &cc, context.allocator); assert(ok)
		assert(
			layers.validate_candidate(&p, &lc) &&
			controls.validate_candidate(&p, &cc) &&
			text.validate_candidate(&p, &tc) &&
			style.validate_candidate(&p, &paint),
		)
		assert(base.enter_commit(&p, stamp) == .None)
		layers.commit(&ls, &ctx, &lc); controls.commit(&cs, &cc)
		old := reader; reader = next; base.finish_commit(&p, stamp)
		interaction.reconcile_registrations(&ctx); destroy_reader(&old)
		style.destroy_frame(
			&paint,
		); text.destroy_candidate(&tc); layers.destroy_candidate(&lc); controls.destroy_candidate(&cc)
		delete(claims); delete(nodes); controls.destroy_composition(&recipe)
		report("controls-published-plus-reader", &tracking)
		if locale == 0 {
			r := controls.dispatch(
				&cs,
				&ctx,
				{kind = .Activate, id = cs.frame.controls[0].node_id, source = .Agent},
				&ls,
			)
			assert(
				r.event != nil &&
				r.event.?.kind == .Bool &&
				r.event.?.checked &&
				r.event.?.sequence == 1,
			)
			assert(effects < max(u64)); effects += 1; checked = r.event.?.checked
			assert(
				!controls.dispatch(&cs, &ctx, {kind = .Activate, id = cs.frame.controls[0].node_id, source = .Agent}, &ls).dispatch.has_event,
			)
		}
	}
	assert(
		effects == 1 &&
		checked &&
		p.sequence == 1 &&
		cs.frame.controls[0].label == "Включено",
	)
	fmt.printf(
		"State=%d Frame=%d Composition=%d Publication=%d Context=%d effects=%d scale=1 locale=en,ru\n",
		size_of(controls.State),
		size_of(controls.Frame),
		size_of(controls.Composition),
		size_of(base.Publication),
		size_of(interaction.Context),
		effects,
	)
	controls.destroy(&cs); layers.destroy(&ls); interaction.destroy(&ctx); base.destroy(&p)
	assert(
		reader.controls.controls[0].checked &&
		reader.controls.controls[0].label == "Включено" &&
		!reader.controls.stamp.lifetime.alive,
	)
	destroy_reader(&reader); report("destroy", &tracking)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
