package main

import base "ui:ui_base"
import controls "ui:ui_controls"
import controls_sdl "ui:ui_controls/sdl"
import hold "ui:ui_hold"
import hold_sdl "ui:ui_hold/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import scroll "ui:ui_scroll"
import backend "ui:ui_sdl"

Reader :: struct {
	render:      Render_Frame,
	input_frame: interaction.Frame,
	geometry:    layout.Frame,
	wheel:       interaction.Frame,
	layers:      layers.Frame,
	scroll:      scroll.Frame,
	hold:        hold.Frame,
	controls:    controls.Frame,
}
Runtime :: struct {
	render:                Render_Config,
	p:                     base.Publication,
	ctx:                   interaction.Context,
	layers:                layers.State,
	scroll:                scroll.State,
	hold:                  hold.State,
	controls:              controls.State,
	device:                backend.Input,
	hold_input:            hold_sdl.Adapter,
	controls_input:        controls_sdl.Adapter,
	reader:                Reader,
	checked, popup, modal: bool,
	value:                 i64,
	pointer:               [2]f64,
	has_pointer:           bool,
}
Input_Result :: struct {
	control:  controls.Result,
	hold:     hold.Result,
	scroll:   interaction.Dispatch_Result,
	consumed: bool,
}
init :: proc(r: ^Runtime) {r.p, _ = base.create(context.allocator); r.ctx = interaction.create(
		context.allocator,
		&r.p,
	)
	r.layers = layers.create(context.allocator)
	r.scroll = scroll.create(context.allocator)
	r.hold = hold.create(context.allocator)
	r.controls = controls.create()
	r.controls_input = controls_sdl.create(context.allocator)
	r.device = {
		window_id  = 1,
		gamepad_id = 9,
	}
	r.value = 50}
destroy_reader :: proc(r: ^Reader) {destroy_render_frame(&r.render); interaction.destroy_frame(
		&r.input_frame,
	)
	layout.destroy_frame(&r.geometry)
	interaction.destroy_frame(&r.wheel)
	layers.destroy_frame(&r.layers)
	scroll.destroy_frame(&r.scroll)
	hold.destroy_frame(&r.hold)
	controls.destroy_frame(&r.controls)
	r^ = {}}
destroy :: proc(r: ^Runtime) {backend.close_input(&r.device); destroy_reader(&r.reader)
	controls_sdl.destroy(&r.controls_input)
	controls.destroy(&r.controls)
	hold.destroy(&r.hold)
	scroll.destroy(&r.scroll)
	layers.destroy(&r.layers)
	interaction.destroy(&r.ctx)
	base.destroy(&r.p)}
publish :: proc(r: ^Runtime, samples: []base.Geometry_Entry = nil) -> bool {
	stamp, be := base.begin_attempt(&r.p, 1); if be != .None {return false}
	complete :=
		false; defer {if !complete {hold_sdl.block(&r.hold_input, &r.ctx); controls_sdl.block(&r.controls_input, &r.ctx)}}
	// This bounded fixture has at most 17 nodes, 9 targets and 5 controls.
	// Reserve checked capacity first; descriptor appends below cannot allocate.
	ns, ne := make([dynamic]layout.Node, 0, 17); if ne != nil {return false}; defer delete(ns)
	append(
		&ns,
		layout.Node {
			id = "root",
			role = .Absolute,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 400},
				y = {mode = .Fixed, value = 300},
			},
		},
	)
	append_node(&ns, "base", "root", .Absolute, 0, 0, 400, 300)
	append_node(&ns, "check", "base", .Box, 0, 0, 100, 30)
	append_node(&ns, "slider", "base", .Stack, 0, 40, 100, 30)
	append_node(&ns, "track", "slider", .Box, 0, 0, 100, 20)
	append_node(&ns, "hold", "base", .Box, 0, 80, 100, 30)
	append_node(&ns, "list", "base", .Stack, 0, 120, 100, 60)
	append(
		&ns,
		layout.Node {
			id = "content",
			parent = "list",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Content}},
		},
	)
	items := [3]controls.Item {
		{"a", "4:list1:a", "A"},
		{"b", "4:list1:b", "B"},
		{"c", "4:list1:c", "C"},
	}
	for item in items {append_node(&ns, item.node_id, "content", .Box, 0, 0, 100, 30)}
	append_node(&ns, "select", "base", .Box, 140, 0, 80, 30)
	append_node(&ns, "popup", "root", .Absolute, 0, 40, 100, 80); ns[len(ns) - 1].visible = r.popup
	append_node(&ns, "pb", "popup", .Box, 0, 0, 40, 30)
	append_node(&ns, "tip", "root", .Box, 0, 0, 100, 30)
	if r.modal {append_node(&ns, "modal", "root", .Absolute, 200, 0, 150, 100); append_node(&ns, "ok", "modal", .Box, 0, 0, 100, 30)}
	stage, stage_ok := prepare_geometry(
		r,
		ns[:],
		stamp,
	); if !stage_ok {return false}; defer destroy_render_stage(&stage)
	g := stage.geometry; stage.geometry = {}; defer layout.destroy_frame(&g)
	ts, te := make(
		[dynamic]interaction.Target,
		0,
		9,
	); if te != nil {return false}; defer delete(ts)
	for id in ([]string{"check", "slider", "hold", "select", "pb"}) {append(&ts, interaction.Target{id, "button", true, true})}
	for item in items {append(&ts, interaction.Target{item.node_id, "button", true, true})}; if r.modal {append(&ts, interaction.Target{"ok", "button", true, true})}
	ms := [1]layers.Modal {
		{"modal", "ok", true},
	}; ps := [1]layers.Popup{{"popup", "", "select"}}; tips := [1]layers.Tooltip{{"tip", ""}}
	plan := layers.Layers {
		base_root_id = "base",
		popups       = ps[:],
		tooltips     = tips[:],
	}; if r.modal {plan.modals = ms[:]}
	claims := [1]interaction.Capture_Claim{{"hold", "hold"}}
	lc, le := layers.prepare(
		&r.layers,
		&r.ctx,
		&g,
		ts[:],
		claims[:],
		plan,
		context.allocator,
	); if le.code != .None {return false}; defer layers.destroy_candidate(&lc)
	sds := [1]scroll.Description{{"list", "content"}}
	sc, se := scroll.prepare(
		&r.scroll,
		&g,
		&lc.interaction,
		sds[:],
		context.allocator,
		lc.focus_id,
	); if se.code != .None {return false}; defer scroll.destroy_candidate(&sc)
	if sc.has_focus {lc.focus_id = interaction.retained_id(&lc.interaction, sc.focus_id)}
	for &n in lc.interaction.targets {v, _ := layout.find(&sc.geometry, n.description.id); n.bounds = v.bounds; n.clip = v.paint_clip}
	// Consume already frozen numerical samples; no clock/transition solver here.
	for entry, k in samples {
		for prior in samples[:k] {if prior.id == entry.id {return false}}
		n, found := interaction.find(&lc.interaction, entry.id); if !found {return false}
		v := entry.geometry
		for number in ([]f64{v.scale, v.opacity, v.bounds.x, v.bounds.y, v.bounds.w, v.bounds.h, v.clip.x, v.clip.y, v.clip.w, v.clip.h}) {if !base.finite(number) {return false}}
		if v.scale < 0 ||
		   v.opacity < 0 ||
		   v.bounds.w < 0 ||
		   v.bounds.h < 0 ||
		   v.clip.w < 0 ||
		   v.clip.h < 0 {return false}
		n.bounds = v.bounds; n.clip = v.clip
		if !entry.input_enabled || v.scale == 0 || v.opacity == 0 {n.availability = .Not_Visible}
	}
	cds, de := make(
		[dynamic]controls.Description,
		0,
		5,
	); if de != nil {return false}; defer delete(cds)
	append(
		&cds,
		controls.Description {
			id = "checked",
			node_id = "check",
			kind = .Checkbox,
			checked = r.checked,
		},
		controls.Description {
			id = "level",
			node_id = "slider",
			track_id = "track",
			kind = .Slider,
			maximum = 100,
			step = 10,
			value = r.value,
		},
		controls.Description{id = "list", node_id = "list", kind = .List, items = items[:]},
		controls.Description {
			id = "choice",
			node_id = "select",
			layer_id = "popup",
			kind = .Select,
			open = r.popup,
			items = []controls.Item{{"item", "pb", "Item"}},
		},
	)
	if r.modal {append(&cds, controls.Description{id = "dialog", node_id = "modal", layer_id = "modal", initial_focus_id = "ok", cancel_id = "ok", kind = .Dialog, open = true, items = []controls.Item{{"ok", "ok", "OK"}}})}
	cc, ce := controls.prepare(
		&lc.interaction,
		plan,
		cds[:],
		context.allocator,
		&sc.geometry,
	); if ce.code != .None {return false}; defer controls.destroy_candidate(&cc)
	hs := [1]hold.Description{{"hold", 500}}
	hc, he := hold.prepare(
		&r.hold,
		&r.ctx,
		&sc.geometry,
		&lc.interaction,
		nil,
		hs[:],
		context.allocator,
	); if he.code != .None {return false}; defer hold.destroy_candidate(&hc)
	next: Reader; defer {destroy_reader(&next)}
	ok: bool
	next.geometry, ok = layout.try_copy_frame(
		&sc.geometry,
		context.allocator,
	); if !ok {return false}
	for entry in samples {n, _ := layout.find(&next.geometry, entry.id); n.bounds = entry.geometry.bounds; n.paint_clip = entry.geometry.clip; n.content = entry.geometry.content; n.clip = entry.geometry.content_clip}
	next.input_frame, ok = interaction.try_copy_frame(
		&lc.interaction,
		context.allocator,
	); if !ok {return false}
	next.wheel, ok = interaction.try_copy_frame(
		&lc.interaction,
		context.allocator,
	); if !ok {return false}
	for &n in next.wheel.targets {availability := n.availability; n.availability = .Invalid_Action; for region in sc.frame.regions {if region.id == n.description.id {n.availability = region.availability; n.bounds = region.viewport; n.clip = region.viewport; for entry in samples {if entry.id == region.id {n.bounds = entry.geometry.content_clip; n.clip = entry.geometry.content_clip}}; if availability != .Applied && availability != .Invalid_Action {n.availability = availability}}}}
	next.layers, ok = layers.try_copy_frame(&lc.frame, context.allocator); if !ok {return false}
	next.scroll, ok = scroll.try_copy_frame(&sc.frame, context.allocator); if !ok {return false}
	next.hold, ok = hold.try_copy_frame(&hc.frame, context.allocator); if !ok {return false}
	next.controls, ok = controls.try_copy_frame(&cc, context.allocator); if !ok {return false}
	if !finish_render_stage(
		r,
		&stage,
		&g,
		&sc.geometry,
		&next.geometry,
		lc.focus_id,
		samples,
	) {return false}
	next.render = stage.frame; stage.frame = {}
	if r.render.renderer != nil && render_injected(r, .Precommit) {return false}
	if !layers.validate_candidate(&r.p, &lc) ||
	   !scroll.validate_candidate(&r.p, &r.scroll, &sc) ||
	   !hold.validate_candidate(&r.p, &hc) ||
	   !controls.validate_candidate(&r.p, &cc) {return false}
	if base.enter_commit(&r.p, stamp) != .None {return false}
	layers.commit(
		&r.layers,
		&r.ctx,
		&lc,
	); scroll.commit(&r.scroll, &sc); hold.commit(&r.hold, &hc); controls.commit(&r.controls, &cc)
	old :=
		r.reader; r.reader = next; next = {}; base.finish_commit(&r.p, stamp); controls_sdl.reconcile(&r.controls_input, &r.controls, &r.ctx, &r.reader.geometry, r.pointer, r.has_pointer); interaction.reconcile_registrations(&r.ctx); destroy_reader(&old)
	complete = true; return true
}
append_node :: proc(
	ns: ^[dynamic]layout.Node,
	id, parent: string,
	kind: layout.Kind,
	x, y, w, h: f64,
) {append(
		ns,
		layout.Node {
			id = id,
			parent = parent,
			role = kind,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = w},
				y = {mode = .Fixed, value = h},
				offset = {x, y},
			},
		},
	)}
