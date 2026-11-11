package recipe

import "core:fmt"
import "core:mem"
import "core:unicode/utf8"
import base "ui:ui_base"
import controls "ui:ui_controls"
import controls_sdl "ui:ui_controls/sdl"
import editor "ui:ui_editor"
import editor_sdl "ui:ui_editor/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import text "ui:ui_text"

// Deterministic metrics make this a headless selected composition. Actual
// SDL text-input/paint and the Apply/Confirm/Stay/Discard app flow stay in Lab.
font :: proc(
	_: string,
	_: f64,
	_: rawptr,
) -> (
	text.Text_Font_Metrics,
	text.Text_Metric_Error,
) {return {8, 2, 10, "fixture"}, .None}
measure :: proc(
	s: string,
	_: string,
	_: f64,
	_: rawptr,
) -> (
	text.Text_Line_Metrics,
	text.Text_Metric_Error,
) {
	w := f64(utf8.rune_count_in_string(s)) * 5; return {w, {w, 10}}, .None
}
validate :: proc(
	_: string,
	_: string,
	_: f64,
	_: rawptr,
) -> (
	text.Text_Metric_Error,
	int,
) {return .None, 0}
metrics :: proc() -> text.Text_Layout_Metrics {return {font, measure, validate, nil}}
Reader :: struct {
	geometry:    layout.Frame,
	interaction: interaction.Frame,
	layers:      layers.Frame,
	controls:    controls.Frame,
	editor:      editor.Frame,
	text:        text.Frame,
}
destroy_reader :: proc(r: ^Reader) {
	layout.destroy_frame(&r.geometry); interaction.destroy_frame(&r.interaction)
	layers.destroy_frame(&r.layers); controls.destroy_frame(&r.controls)
	editor.destroy_frame(&r.editor); text.destroy_frame(&r.text); r^ = {}
}
publish :: proc(
	p: ^base.Publication,
	ctx: ^interaction.Context,
	ls: ^layers.State,
	cs: ^controls.State,
	es: ^editor.State,
	checked: bool,
	revision: u64,
	conflicts: ^int,
	drawable: layout.Extent = {300, 100},
	text_metrics: text.Text_Layout_Metrics = {font, measure, validate, nil},
	name_text: string = "Name",
	checkbox_label: string = "Enabled",
) -> Reader {
	a := context.allocator
	stamp, pe := base.begin_attempt(p, revision); assert(pe == .None)
	composition, error := controls.compose_control(
		{id = "enabled", kind = .Checkbox, label = checkbox_label, checked = checked},
		"settings",
		"root",
		a,
		font = {"fixture"},
		font_size = 10,
	)
	assert(error.code == .None); defer controls.destroy_composition(&composition)
	nodes := make([dynamic]layout.Node); defer delete(nodes)
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
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		layout.Node {
			id = "settings",
			parent = "root",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		layout.Node {
			id = "field",
			parent = "settings",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 200},
				y = {mode = .Fixed, value = 20},
			},
		},
		layout.Node {
			id = "value",
			parent = "field",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
	)
	append(&nodes, ..composition.nodes[:])
	texts := make([dynamic]text.Text_Node); defer delete(texts)
	append(
		&texts,
		text.Text_Node{id = "value", text = name_text, font = {"fixture"}, font_size = 10},
	)
	append(&texts, ..composition.texts[:])
	tc, te := text.prepare(
		texts[:],
		nodes[:],
		{drawable = drawable, ui_scale = 1},
		text_metrics,
		a,
		stamp,
	)
	assert(te.code == .None); defer text.destroy_candidate(&tc)
	targets := make([dynamic]interaction.Target); defer delete(targets)
	append(
		&targets,
		interaction.Target{"field", "editor", true, true},
	); append(&targets, ..composition.targets[:])
	claims := make([dynamic]interaction.Capture_Claim); defer delete(claims)
	append(
		&claims,
		interaction.Capture_Claim{"field", "editor"},
		interaction.Capture_Claim{"value", "editor"},
	)
	for target in composition.targets {append(&claims, interaction.Capture_Claim{target.id, "controls"})}
	if conflicts^ == 0 {
		bad, code := interaction.prepare(
			&tc.geometry,
			targets[:],
			[]interaction.Capture_Claim{{"field", "editor"}, {"field", "controls"}},
			a,
		)
		defer interaction.destroy_candidate(
			&bad,
		); assert(code == .Conflict && !p.ready); conflicts^ += 1
	}
	plan := layers.Layers {
		base_root_id = "base",
		modals       = []layers.Modal{{"settings", "field", true}},
	}
	lc, le := layers.prepare(ls, ctx, &tc.geometry, targets[:], claims[:], plan, a)
	assert(le.code == .None); defer layers.destroy_candidate(&lc)
	cc, ce := controls.prepare(
		&lc.interaction,
		lc.frame.layers,
		[]controls.Description{composition.control},
		a,
		&tc.geometry,
	)
	assert(ce.code == .None); defer controls.destroy_candidate(&cc)
	ec, ee := editor.prepare(
		es,
		&tc.geometry,
		&lc.interaction,
		&tc.text,
		[]editor.Description {
			{
				id = "name",
				node_id = "field",
				text_node_id = "value",
				label = name_text,
				value = name_text,
				revision = 1,
			},
		},
		text_metrics,
		a,
		scope_id = "settings",
	)
	assert(ee.code == .None); defer editor.destroy_candidate(&ec)
	r: Reader; complete := false; defer {if !complete {destroy_reader(&r)}}
	ok: bool
	r.geometry, ok = layout.try_copy_frame(&tc.geometry, a); assert(ok)
	r.interaction, ok = interaction.try_copy_frame(&lc.interaction, a); assert(ok)
	r.layers, ok = layers.try_copy_frame(&lc.frame, a); assert(ok)
	r.controls, ok = controls.try_copy_frame(&cc, a); assert(ok)
	r.editor, ok = editor.try_copy_frame(&ec.frame, a); assert(ok)
	r.text, ok = text.try_copy_frame(&tc.text, a); assert(ok)
	assert(
		text.validate_candidate(p, &tc) &&
		layers.validate_candidate(p, &lc) &&
		controls.validate_candidate(p, &cc) &&
		editor.validate_candidate(p, es, &ec),
	)
	assert(base.enter_commit(p, stamp) == .None)
	layers.commit(ls, ctx, &lc); controls.commit(cs, &cc); editor.commit(es, &ec)
	base.finish_commit(p, stamp); interaction.reconcile_registrations(ctx)
	complete = true; return r
}
main :: proc() {
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&tracking,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&tracking)
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, pe := base.create(context.allocator); assert(pe == .None)
	ctx := interaction.create(context.allocator, &p); ls := layers.create(context.allocator)
	cs := controls.create(); es := editor.create()
	ca: controls_sdl.Adapter; ea: editor_sdl.Adapter; assert(size_of(ca) > 0 && size_of(ea) > 0)
	checked := false; effects, conflicts := 0, 0; revision := u64(1)
	r := publish(&p, &ctx, &ls, &cs, &es, checked, revision, &conflicts)
	assert(ctx.focus_id == "field" && r.editor.scope_id == "settings")
	result := controls.dispatch(
		&cs,
		&ctx,
		{kind = .Activate, id = cs.frame.controls[0].node_id, source = .Agent},
		&ls,
	)
	assert(result.event != nil && result.event.?.kind == .Bool && result.event.?.checked)
	checked = result.event.?.checked; effects += 1; revision += 1
	// A second action cannot consume an already-invalidated published frame.
	assert(
		!controls.dispatch(&cs, &ctx, {kind = .Activate, id = cs.frame.controls[0].node_id, source = .Agent}, &ls).dispatch.has_event,
	)
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &cs, &es, checked, revision, &conflicts)
	base.invalidate(&p)
	assert(
		editor.dispatch(&es, &ctx, {kind = .Submit, id = "name", source = .Agent}, metrics()).code ==
		.Not_Ready,
	)
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &cs, &es, checked, revision, &conflicts)
	assert(effects == 1 && r.controls.controls[0].checked && r.editor.editors[0].value == "Name")
	editor.destroy(
		&es,
	); controls.destroy(&cs); layers.destroy(&ls); interaction.destroy(&ctx); base.destroy(&p)
	assert(!r.editor.stamp.lifetime.alive && r.editor.editors[0].value == "Name")
	destroy_reader(&r)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
	fmt.printf(
		"recipe-settings effects=%d conflicts=%d live=%d\n",
		effects,
		conflicts,
		tracking.current_memory_allocated,
	)
}
