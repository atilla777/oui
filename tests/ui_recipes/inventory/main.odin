package recipe

import "core:fmt"
import "core:mem"
import "core:strings"
import base "ui:ui_base"
import collections "ui:ui_collections"
import collections_sdl "ui:ui_collections/sdl"
import gestures "ui:ui_gestures"
import gestures_sdl "ui:ui_gestures/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import fonts "ui:ui_sdl_text"
import text "ui:ui_text"

// Two concrete region owners in one publication. No ordinary scroll.State,
// no showcase import, and no drag ownership on a virtual row target.
Reader :: struct {
	geometry:    layout.Frame,
	interaction: interaction.Frame,
	layers:      layers.Frame,
	left, right: collections.Frame,
	gestures:    gestures.Frame,
}
destroy_reader :: proc(r: ^Reader) {
	layout.destroy_frame(&r.geometry); interaction.destroy_frame(&r.interaction)
	layers.destroy_frame(&r.layers); collections.destroy_frame(&r.left)
	collections.destroy_frame(&r.right); gestures.destroy_frame(&r.gestures); r^ = {}
}
box :: proc(id, parent: string, x, y, w, h: f64, kind := layout.Kind.Box) -> layout.Node {
	return {
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
	}
}
publish :: proc(
	p: ^base.Publication,
	ctx: ^interaction.Context,
	ls: ^layers.State,
	left, right: ^collections.State,
	gs: ^gestures.State,
	moved: bool,
	revision: u64,
	conflicts: ^int,
	drawable: layout.Extent = {300, 120},
) -> Reader {
	a := context.allocator
	stamp, pe := base.begin_attempt(p, revision); assert(pe == .None)
	left_items := []collections.Collection_Item {
		{"a", "A", true, true, ""},
		{"b", "B", true, true, ""},
	}
	right_items := []collections.Collection_Item{{"c", "C", true, true, ""}}
	if moved {
		left_items = []collections.Collection_Item{{"b", "B", true, true, ""}}
		right_items = []collections.Collection_Item {
			{"c", "C", true, true, ""},
			{"a", "A", true, true, ""},
		}
	}
	ds := []collections.Collection_Description {
		{
			id = "left",
			scroll_id = "left-view",
			content_id = "left-content",
			height = 20,
			items = left_items,
			data_revision = revision,
		},
		{
			id = "right",
			scroll_id = "right-view",
			content_id = "right-content",
			height = 20,
			items = right_items,
			data_revision = revision,
			selected_id = "a" if moved else "",
		},
	}
	lc, le := collections.prepare(
		left,
		stamp,
		ds[0],
		{x = 0, y = 20, w = 100, h = 40},
		0,
		focus_id = ctx.focus_id,
	)
	assert(le.code == .None); defer collections.destroy_candidate(&lc)
	rc, re := collections.prepare(
		right,
		stamp,
		ds[1],
		{x = 150, y = 20, w = 100, h = 40},
		0,
		focus_id = ctx.focus_id,
	)
	assert(re.code == .None); defer collections.destroy_candidate(&rc)
	lrows, lre := collections.materialize(
		&lc.frame,
	); assert(lre.code == .None); defer collections.destroy_nodes(lrows)
	rrows, rre := collections.materialize(
		&rc.frame,
	); assert(rre.code == .None); defer collections.destroy_nodes(rrows)
	nodes := make([dynamic]layout.Node); defer delete(nodes)
	append(
		&nodes,
		box("root", "", 0, 0, 300, 120, .Stack),
		box("base", "root", 0, 0, 300, 120, .Absolute),
		box("left-header", "base", 0, 0, 100, 20),
		box("right-header", "base", 150, 0, 100, 20),
		box("left-view", "base", 0, 20, 100, 40, .Stack),
		box("right-view", "base", 150, 20, 100, 40, .Stack),
		layout.Node {
			id = "left-content",
			parent = "left-view",
			role = .Column,
			enabled = true,
			visible = true,
			layout = collections.content_layout(&lc.frame),
		},
		layout.Node {
			id = "right-content",
			parent = "right-view",
			role = .Column,
			enabled = true,
			visible = true,
			layout = collections.content_layout(&rc.frame),
		},
		box("handle", "base", 0, 80, 100, 20),
	)
	append(&nodes, ..lrows); append(&nodes, ..rrows)
	g, ge := layout.prepare(nodes[:], {drawable = drawable, ui_scale = 1}, {}, a, stamp)
	assert(ge.code == .None); defer layout.destroy_frame(&g)
	assert(collections.validate_regions(&g, ds).code == .None)
	assert(
		collections.validate_regions(&g, []collections.Collection_Description{ds[0], ds[0]}).code !=
		.None,
	)
	projected_left, ple := collections.project_layout(
		&lc,
		&g,
	); assert(ple.code == .None); defer layout.destroy_frame(&projected_left)
	projected, pre := collections.project_layout(
		&rc,
		&projected_left,
	); assert(pre.code == .None); defer layout.destroy_frame(&projected)
	targets := make([dynamic]interaction.Target); defer delete(targets)
	claims := make([dynamic]interaction.Capture_Claim); defer delete(claims)
	for row in lc.frame.nodes {append(&targets, interaction.Target{row.description.id, "button", row.enabled, row.visible}); append(&claims, interaction.Capture_Claim{row.description.id, "collections"})}
	for row in rc.frame.nodes {append(&targets, interaction.Target{row.description.id, "button", row.enabled, row.visible}); append(&claims, interaction.Capture_Claim{row.description.id, "collections"})}
	append(
		&targets,
		interaction.Target{"handle", "button", true, true},
		interaction.Target{"left-header", "drop", true, true},
		interaction.Target{"right-header", "drop", true, true},
	)
	append(&claims, interaction.Capture_Claim{"handle", "gestures"})
	if conflicts^ == 0 {
		row := lc.frame.nodes[0].description.id
		bad, code := interaction.prepare(
			&projected,
			targets[:],
			[]interaction.Capture_Claim{{row, "collections"}, {row, "gestures"}},
			a,
		)
		defer interaction.destroy_candidate(
			&bad,
		); assert(code == .Conflict && !p.ready); conflicts^ += 1
	}
	layers_candidate, layer_error := layers.prepare(
		ls,
		ctx,
		&projected,
		targets[:],
		claims[:],
		{base_root_id = "base"},
		a,
	)
	assert(layer_error.code == .None); defer layers.destroy_candidate(&layers_candidate)
	assert(
		collections.bind_candidate(&lc, &projected, &layers_candidate.interaction).code == .None,
	)
	assert(
		collections.bind_candidate(&rc, &projected, &layers_candidate.interaction).code == .None,
	)
	gc, gce := gestures.prepare(
		gs,
		&projected,
		&layers_candidate.interaction,
		nil,
		[]gestures.Description {
			{
				id = "drag",
				node_id = "handle",
				kind = .Drag_Source,
				payload_id = "a",
				payload_type = "card",
			},
			{
				id = "left-drop",
				node_id = "left-header",
				kind = .Drop_Target,
				accept_types = []string{"card"},
			},
			{
				id = "right-drop",
				node_id = "right-header",
				kind = .Drop_Target,
				accept_types = []string{"card"},
			},
		},
		revision,
		a,
	)
	assert(gce.code == .None); defer gestures.destroy_candidate(&gc)
	r: Reader; complete := false; defer {if !complete {destroy_reader(&r)}}
	ok: bool
	r.geometry, ok = layout.try_copy_frame(&projected, a); assert(ok)
	r.interaction, ok = interaction.try_copy_frame(&layers_candidate.interaction, a); assert(ok)
	r.layers, ok = layers.try_copy_frame(&layers_candidate.frame, a); assert(ok)
	r.left, ok = collections.try_copy_frame(&lc.frame, a); assert(ok)
	r.right, ok = collections.try_copy_frame(&rc.frame, a); assert(ok)
	r.gestures, ok = gestures.try_copy_frame(&gc.frame, a); assert(ok)
	assert(
		layout.validate_candidate(p, &g) &&
		layers.validate_candidate(p, &layers_candidate) &&
		collections.validate_candidate(p, left, &lc) &&
		collections.validate_candidate(p, right, &rc) &&
		gestures.validate_candidate(p, gs, &gc),
	)
	assert(base.enter_commit(p, stamp) == .None)
	layers.commit(
		ls,
		ctx,
		&layers_candidate,
	); collections.commit(left, &lc); collections.commit(right, &rc); gestures.commit(gs, &gc)
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
	left, right := collections.create(), collections.create(); gs := gestures.create()
	ca: collections_sdl.Result; ga: gestures_sdl.Adapter; tf: text.Frame; font: ^fonts.Generation
	assert(size_of(ca) > 0 && size_of(ga) > 0 && size_of(tf) > 0 && font == nil)
	moved := false; revision := u64(1); effects, conflicts := 0, 0
	r := publish(&p, &ctx, &ls, &left, &right, &gs, moved, revision, &conflicts)
	begin := gestures.dispatch(
		&gs,
		&ctx,
		nil,
		{kind = .Begin, id = "drag", source = .Agent},
	); assert(begin.code == .Applied)
	cycle := begin.cycle
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &left, &right, &gs, moved, revision, &conflicts)
	assert(
		gestures.dispatch(&gs, &ctx, nil, {kind = .Aim, id = "right-drop", cycle = cycle, source = .Agent}).code ==
		.Applied,
	)
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &left, &right, &gs, moved, revision, &conflicts)
	result := gestures.dispatch(&gs, &ctx, nil, {kind = .End, cycle = cycle, source = .Agent})
	assert(result.has_proposal && result.proposal.payload_id == "a" && !moved && effects == 0)
	// Copy the borrowed proposal before another family mutation. The real Lab
	// adds Cancel/Confirm UI; this snippet shows the bounded app decision seam.
	pending := result.proposal
	err: mem.Allocator_Error
	pending.source_id, err = strings.clone(
		result.proposal.source_id,
		context.allocator,
	); assert(err == nil)
	pending.target_id, err = strings.clone(
		result.proposal.target_id,
		context.allocator,
	); assert(err == nil)
	pending.payload_id, err = strings.clone(
		result.proposal.payload_id,
		context.allocator,
	); assert(err == nil)
	pending.payload_type, err = strings.clone(
		result.proposal.payload_type,
		context.allocator,
	); assert(err == nil)
	assert(pending.model_revision == revision && pending.target_id == "right-drop")
	moved = true; revision += 1; effects += 1
	delete(
		pending.source_id,
	); delete(pending.target_id); delete(pending.payload_id); delete(pending.payload_type); pending = {}
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &left, &right, &gs, moved, revision, &conflicts)
	_, missing := collections.lookup_collection_item(&r.left, "left", "a")
	selected, found := collections.lookup_collection_item(&r.right, "right", "a")
	assert(
		missing == .Not_Found &&
		found == .Applied &&
		selected.selected &&
		selected.item.item_id == "a",
	)
	base.invalidate(&p)
	assert(
		gestures.dispatch(&gs, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent}).code ==
		.Not_Ready,
	)
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &left, &right, &gs, moved, revision, &conflicts)
	assert(effects == 1 && moved)
	gestures.destroy(&gs); collections.destroy(&left); collections.destroy(&right)
	layers.destroy(&ls); interaction.destroy(&ctx); base.destroy(&p)
	selected, found = collections.lookup_collection_item(&r.right, "right", "a")
	assert(!r.left.stamp.lifetime.alive && found == .Applied && selected.selected)
	destroy_reader(&r)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
	fmt.printf(
		"recipe-inventory effects=%d conflicts=%d live=%d\n",
		effects,
		conflicts,
		tracking.current_memory_allocated,
	)
}
