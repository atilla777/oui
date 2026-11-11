package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

Scene :: struct {
	g:       layout.Frame,
	targets: [dynamic]interaction.Target,
}
destroy_scene :: proc(s: ^Scene) {layout.destroy_frame(&s.g); delete(s.targets); s^ = {}}
scene :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	l: Layers,
	disabled: string = "",
	hidden: string = "",
) -> Scene {
	nodes := make([dynamic]layout.Node); defer delete(nodes)
	append(
		&nodes,
		layout.Node {
			id = "root",
			role = .Absolute,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 100},
			},
		},
	)
	for k in 0 ..< 1 + len(l.modals) + len(l.popups) + len(l.tooltips) {
		id := root_at(l, k)
		append(
			&nodes,
			layout.Node {
				id = id,
				parent = "root",
				role = .Stack,
				enabled = id != disabled,
				visible = id != hidden,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 100},
					y = {mode = .Fixed, value = 100},
				},
			},
		)
		children: []string
		switch id {case "base":
			children = []string{"open", "second"}; case "a":
			children = []string{"ab", "ax"}; case "b":
			children = []string{"bb"}; case "c":
			children = []string{"cb"}; case "pop":
			children = []string{"pb"}; case "tip":
			children = []string{"tiptext"}}
		for child in children {append(&nodes, layout.Node{id = child, parent = id, role = .Box, enabled = child != disabled, visible = child != hidden, layout = layout.Layout{x = {mode = .Fixed, value = 40}, y = {mode = .Fixed, value = 40}}})}
	}
	stamp, _ := base.begin_attempt(p, 1)
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); testing.expect(t, e.code == .None)
	s := Scene {
		g       = g,
		targets = make([dynamic]interaction.Target),
	}
	for n in nodes {if n.parent != "root" && n.parent != "" && n.id != "tiptext" {append(&s.targets, interaction.Target{n.id, "button", n.enabled, n.visible})}}
	return s
}
accept_scene :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	s: ^State,
	ctx: ^interaction.Context,
	l: Layers,
	disabled: string = "",
	hidden: string = "",
) -> bool {
	f := scene(t, p, l, disabled, hidden); defer destroy_scene(&f)
	c, e := prepare(
		s,
		ctx,
		&f.g,
		f.targets[:],
		nil,
		l,
		context.allocator,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None && validate_candidate(p, &c)) {return false}
	if !testing.expect(t, base.enter_commit(p, f.g.stamp) == .None) {return false}
	commit(
		s,
		ctx,
		&c,
	); base.finish_commit(p, f.g.stamp); interaction.reconcile_registrations(ctx); return true
}

@(test)
depth_three_stack_transitions_exact_return_records_and_scope_refusals :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ms := [3]Modal{{"a", "ab", true}, {"b", "bb", false}, {"c", "cb", true}}
	l := Layers {
		base_root_id = "base",
	}
	depths := [9]int{0, 1, 2, 3, 3, 1, 2, 0, 1}
	want := [9]string{"open", "ab", "bb", "cb", "cb", "ab", "bb", "open", "ab"}
	for depth, k in depths {
		l.modals = ms[:depth]
		if !accept_scene(t, &p, &s, &ctx, l) {return}
		testing.expect(t, ctx.focus_id == want[k] && len(s.frame.returns) == depth)
		if depth > 0 {testing.expect(t, s.frame.returns[0] == "open")}
		if depth > 1 {testing.expect(t, s.frame.returns[1] == "ab")}
		for source in interaction.Source {
			if depth >
			   0 {testing.expect(t, dispatch(&s, &ctx, {kind = .Activate, id = "open", source = source}).dispatch.code == .Blocked_By_Modal && p.sequence == 0 && p.ready)}
			testing.expect(
				t,
				dispatch(&s, &ctx, {kind = .Activate, id = "missing", source = source}).dispatch.code ==
				.Not_Found,
			)
		}
	}
	// Same-depth replacement, non-prefix push and jumping by two are not stack operations.
	for bad in ([]([]Modal){{{"b", "bb", true}}, {{"a", "ab", true}, {"c", "cb", true}, {"b", "bb", true}}, {{"a", "ab", true}, {"b", "bb", true}, {"c", "cb", true}}}) {
		next := Layers {
			base_root_id = "base",
			modals       = bad,
		}; f := scene(t, &p, next)
		c, e := prepare(
			&s,
			&ctx,
			&f.g,
			f.targets[:],
			nil,
			next,
			context.allocator,
		); destroy_candidate(&c); destroy_scene(&f)
		testing.expect(
			t,
			e.code == .Invalid_Transition &&
			len(s.frame.layers.modals) == 1 &&
			s.frame.returns[0] == "open" &&
			!p.ready,
		)
	}
}

@(test)
retention_fallback_empty_scope_and_opening_initial_focus_are_distinct :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ms := [2]Modal{{"a", "ab", true}, {"b", "bb", true}}
	l := Layers {
		base_root_id = "base",
	}; accept_scene(t, &p, &s, &ctx, l)
	l.modals = ms[:1]; accept_scene(t, &p, &s, &ctx, l)
	dispatch(
		&s,
		&ctx,
		{kind = .Focus, id = "ax", source = .Keyboard},
	); accept_scene(t, &p, &s, &ctx, l)
	l.modals = ms[:]; accept_scene(t, &p, &s, &ctx, l)
	l.modals = ms[:1]; accept_scene(t, &p, &s, &ctx, l, "ax")
	testing.expect(t, ctx.focus_id == "ab", "unavailable return falls back to first main button")
	accept_scene(t, &p, &s, &ctx, l, "ab", "ax")
	testing.expect(
		t,
		ctx.focus_id == "" &&
		p.ready &&
		dispatch(&s, &ctx, {kind = .Navigate, source = .Keyboard}).dispatch.code ==
			.Invalid_Action,
	)
	accept_scene(t, &p, &s, &ctx, l, "ab")
	testing.expect(
		t,
		ctx.focus_id == "ax",
		"existing scope recovers without reusing unavailable initial focus",
	)
	l.modals = nil; accept_scene(t, &p, &s, &ctx, l)
	l.modals = ms[:1]; f := scene(t, &p, l, "ab"); defer destroy_scene(&f)
	c, e := prepare(
		&s,
		&ctx,
		&f.g,
		f.targets[:],
		nil,
		l,
		context.allocator,
	); defer destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Invalid_Layers &&
		e.id == "ab" &&
		ctx.focus_id == "open" &&
		len(s.frame.returns) == 0,
	)
}

@(test)
popup_and_tooltip_scope_paint_order_and_noninteractive_overlay_are_frozen :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ms := [1]Modal {
		{"a", "ab", true},
	}; ps := [1]Popup{{"pop", "a", "ax"}}; ts := [1]Tooltip{{"tip", "a"}}
	l := Layers {
		base_root_id = "base",
		modals       = ms[:],
		popups       = ps[:],
		tooltips     = ts[:],
	}
	f := scene(t, &p, l); defer destroy_scene(&f)
	c, e := prepare(
		&s,
		&ctx,
		&f.g,
		f.targets[:],
		nil,
		l,
		context.allocator,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		len(c.frame.groups) == 4 &&
		c.frame.groups[0].kind == .Main &&
		c.frame.groups[1].kind == .Main &&
		c.frame.groups[2].kind == .Popup &&
		c.frame.groups[3].kind == .Tooltip,
	)
	scrims := 0; for command in c.frame.paint {if command.kind == .Scrim {scrims += 1}}
	testing.expect(t, scrims == 1)
	for id in ([]string{"tip", "tiptext"}) {n, _ := interaction.find(&c.interaction, id); testing.expect(t, n.availability == .Non_Interactive_Overlay)}
	n, _ := interaction.find(&c.interaction, "pb"); testing.expect(t, n.availability == .Applied)
	// Tooltip has no input targets, even when explicitly described as disabled.
	append(&f.targets, interaction.Target{"tiptext", "button", false, false})
	bad, be := prepare(
		&s,
		&ctx,
		&f.g,
		f.targets[:],
		nil,
		l,
		context.allocator,
	); destroy_candidate(&bad)
	testing.expect(t, be.code == .Invalid_Layers && be.id == "tiptext")
}
