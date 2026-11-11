package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"

@(private)
fixture :: proc(t: ^testing.T, p: ^base.Publication, modal: bool) -> layout.Frame {
	s, _ := base.begin_attempt(p, 1)
	ids := [5]string{"root", "base", "open", "modal", "confirm"}
	parents := [5]string{"", "root", "base", "root", "modal"}
	nodes: [5]layout.Node
	for id, i in ids {nodes[i] = {
			id = id,
			parent = parents[i],
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 100},
			},
		}}
	count := 3; if modal {count = 5}
	g, e := layout.prepare(
		nodes[:count],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	testing.expect(t, e.code == .None); return g
}
@(private)
accept :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	s: ^State,
	ctx: ^interaction.Context,
	g: ^layout.Frame,
	modal: bool,
) {
	targets := [2]interaction.Target {
		{"open", "button", true, true},
		{"confirm", "button", true, true},
	}
	modals := [1]Modal{{"modal", "confirm", true}}
	l := Layers {
		base_root_id = "base",
	}; count := 1
	if modal {l.modals = modals[:]; count = 2}
	c, e := prepare(
		s,
		ctx,
		g,
		targets[:count],
		nil,
		l,
		context.allocator,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(t, validate_candidate(p, &c))
	testing.expect(
		t,
		base.enter_commit(p, g.stamp) == .None,
	); commit(s, ctx, &c); base.finish_commit(p, g.stamp)
}
@(test)
modal_focus_refusal_return_and_single_owner :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g := fixture(t, &p, false); accept(t, &p, &s, &ctx, &g, false); layout.destroy_frame(&g)
	testing.expect(t, ctx.focus_id == "open")
	g = fixture(t, &p, true); accept(t, &p, &s, &ctx, &g, true); layout.destroy_frame(&g)
	testing.expect(t, ctx.focus_id == "confirm" && ctx.pressed_id == "")
	for source in interaction.Source {
		for kind in ([2]interaction.Action_Kind{.Focus, .Activate}) {
			r := interaction.dispatch(&ctx, {kind = kind, id = "open", source = source})
			testing.expect(t, r.code == .Blocked_By_Modal && !r.has_event && p.sequence == 0)
		}
	}
	g = fixture(t, &p, false); accept(t, &p, &s, &ctx, &g, false); layout.destroy_frame(&g)
	testing.expect(t, ctx.focus_id == "open")
}

@(test)
prepared_candidate_cannot_resurrect_a_cancelled_pointer_press :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g := fixture(t, &p, false); accept(t, &p, &s, &ctx, &g, false); layout.destroy_frame(&g)
	interaction.begin_pointer_press(&ctx, "open")
	g = fixture(t, &p, false); defer layout.destroy_frame(&g)
	targets := [1]interaction.Target{{"open", "button", true, true}}
	c, e := prepare(
		&s,
		&ctx,
		&g,
		targets[:],
		nil,
		{base_root_id = "base"},
		context.allocator,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None && validate_candidate(&p, &c)) {return}
	interaction.cancel_press(&ctx)
	testing.expect(
		t,
		!validate_candidate(&p, &c),
		"loss/cancel during prepare must invalidate its retained capture",
	)
}
Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}
fault_allocator :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := cast(^Fault)data
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode ==
				   .Resize_Non_Zeroed) {f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
every_prepare_allocation_refusal_cleans_partial_owners :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g := fixture(t, &p, true); defer layout.destroy_frame(&g)
	targets := [2]interaction.Target {
		{"open", "button", true, true},
		{"confirm", "button", true, true},
	}
	modals := [1]Modal{{"modal", "confirm", true}}
	l := Layers {
		base_root_id = "base",
		modals       = modals[:],
	}
	live: mem.Tracking_Allocator; mem.tracking_allocator_init(&live, context.allocator); defer mem.tracking_allocator_destroy(&live)
	live.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	f := Fault {
		backing = mem.tracking_allocator(&live),
	}; a := mem.Allocator{fault_allocator, &f}
	refs := p.lifetime.references
	c, e := prepare(&s, &ctx, &g, targets[:], nil, l, a)
	testing.expect(t, e.code == .None); destroy_candidate(&c)
	count := f.requests
	for refusal in 1 ..= count {
		f.requests, f.refuse = 0, refusal
		c, e = prepare(&s, &ctx, &g, targets[:], nil, l, a)
		testing.expect(
			t,
			e.code != .None,
			fmt.tprintf("refusal %d", refusal),
		); destroy_candidate(&c)
		testing.expect(
			t,
			len(live.allocation_map) == 0 &&
			len(live.bad_free_array) == 0 &&
			p.lifetime.references == refs,
			fmt.tprintf("rollback %d", refusal),
		)
	}
	fmt.printf(
		"layers prepare allocations=%d peak=%d live=%d Frame=%d State=%d Candidate=%d handlers=0 backend-resources=0\n",
		count,
		live.peak_memory_allocated,
		live.current_memory_allocated,
		size_of(Frame),
		size_of(State),
		size_of(Candidate),
	)
}
@(test)
candidate_owns_input_and_rejects_wrong_owner_and_stale_attempt :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g := fixture(t, &p, true); defer layout.destroy_frame(&g)
	targets := [2]interaction.Target {
		{"open", "button", true, true},
		{"confirm", "button", true, true},
	}
	modals := [1]Modal{{"modal", "confirm", true}}
	c, e := prepare(
		&s,
		&ctx,
		&g,
		targets[:],
		nil,
		{base_root_id = "base", modals = modals[:]},
		context.allocator,
	); defer destroy_candidate(&c)
	testing.expect(t, e.code == .None); modals[0] = {"changed", "changed", false}
	testing.expect(t, c.frame.layers.modals[0].root_id == "modal" && c.focus_id == "confirm")
	other, _ := base.create(context.allocator); defer base.destroy(&other)
	testing.expect(t, !validate_candidate(&other, &c)); base.begin_attempt(&p, 2)
	testing.expect(t, !validate_candidate(&p, &c))
}

@(test)
owning_copy_survives_source_and_every_refusal_rolls_back :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator)
	ctx := interaction.create(context.allocator, &p)
	s := create(context.allocator)
	g := fixture(t, &p, true); accept(t, &p, &s, &ctx, &g, true); layout.destroy_frame(&g)
	live: mem.Tracking_Allocator; mem.tracking_allocator_init(&live, context.allocator); defer mem.tracking_allocator_destroy(&live)
	live.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	f := Fault {
		backing = mem.tracking_allocator(&live),
	}; a := mem.Allocator{fault_allocator, &f}
	copy, ok := try_copy_frame(&s.frame, a)
	testing.expect(t, ok, "owning layer reader must be available")
	count := f.requests; refs := p.lifetime.references
	for refusal in 1 ..= count {
		f.requests, f.refuse = 0, refusal
		failed, success := try_copy_frame(&s.frame, a)
		testing.expect(t, !success); destroy_frame(&failed)
		testing.expect(t, p.lifetime.references == refs && len(live.bad_free_array) == 0)
	}
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	if ok {
		testing.expect(
			t,
			copy.layers.modals[0].root_id == "modal" &&
			copy.layers.modals[0].initial_focus_id == "confirm",
		)
		// Four layer-subtree nodes each emit draw+focus; common root is not
		// painted, and the one modal adds one scrim: 4*2+1 = 9.
		testing.expect(t, len(copy.paint) == 9 && copy.returns[0] == "")
		testing.expect(t, copy.stamp.lifetime != nil && !copy.stamp.lifetime.alive)
	}
	destroy_frame(&copy)
	testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
}

@(private)
popup_geometry :: proc(t: ^testing.T, p: ^base.Publication, popup: bool) -> layout.Frame {
	s, _ := base.begin_attempt(p, 1)
	ids := [8]string{"root", "base", "open", "return", "a", "ab", "b", "bb"}
	parents := [8]string{"", "root", "base", "base", "root", "a", "root", "b"}
	nodes: [8]layout.Node
	for id, i in ids {nodes[i] = {
			id = id,
			parent = parents[i],
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 100},
			},
		}}
	nodes[0].role = .Absolute
	for i in ([2]int{4, 6}) {nodes[i].layout = layout.Layout {
			x = {mode = .Fixed, value = 50},
			y = {mode = .Fixed, value = 50},
			offset = {20, 20},
		}}
	for i in ([2]int{5, 7}) {nodes[i].layout = layout.Layout {
			x = {mode = .Fixed, value = 10},
			y = {mode = .Fixed, value = 10},
		}}
	count := 4; if popup {count = 8}
	g, e := layout.prepare(
		nodes[:count],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	testing.expect(t, e.code == .None); return g
}
@(test)
popup_descriptor_navigation_return_and_capture_reorder :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	targets := [4]interaction.Target {
		{"open", "button", true, true},
		{"return", "button", true, true},
		{"ab", "button", true, true},
		{"bb", "button", true, true},
	}
	popups := [2]Popup{{"b", "", "return"}, {"a", "", "open"}}
	for expected in ([3]string{"open", "return", "bb"}) {
		g := popup_geometry(t, &p, true)
		c, e := prepare(
			&s,
			&ctx,
			&g,
			targets[:],
			nil,
			{base_root_id = "base", popups = popups[:]},
			context.allocator,
		)
		testing.expect(t, e.code == .None)
		testing.expect(
			t,
			base.enter_commit(&p, g.stamp) == .None,
		); commit(&s, &ctx, &c); base.finish_commit(&p, g.stamp)
		destroy_candidate(&c); layout.destroy_frame(&g)
		testing.expect(
			t,
			ctx.focus_id == expected,
			"navigation must follow descriptor order, not physical sibling order",
		)
		interaction.dispatch(&ctx, {kind = .Navigate, source = .Keyboard})
	}
	// Focus a popup and acquire press before changing popup order.
	g := popup_geometry(t, &p, true)
	c, e := prepare(
		&s,
		&ctx,
		&g,
		targets[:],
		nil,
		{base_root_id = "base", popups = popups[:]},
		context.allocator,
	)
	testing.expect(
		t,
		e.code == .None,
	); base.enter_commit(&p, g.stamp); commit(&s, &ctx, &c); base.finish_commit(&p, g.stamp); layout.destroy_frame(&g)
	interaction.begin_pointer_press(&ctx, "bb")
	g = popup_geometry(t, &p, true); popups[0], popups[1] = popups[1], popups[0]
	c, e = prepare(
		&s,
		&ctx,
		&g,
		targets[:],
		nil,
		{base_root_id = "base", popups = popups[:]},
		context.allocator,
	)
	testing.expect(
		t,
		e.code == .None && c.pressed_id == "",
		"changed popup order must cancel capture",
	)
	base.enter_commit(
		&p,
		g.stamp,
	); commit(&s, &ctx, &c); base.finish_commit(&p, g.stamp); layout.destroy_frame(&g)
	// Removing b returns to its explicit target, not the first base button.
	g = popup_geometry(t, &p, false)
	c, e = prepare(&s, &ctx, &g, targets[:2], nil, {base_root_id = "base"}, context.allocator)
	testing.expect(
		t,
		e.code == .None && c.focus_id == "return",
		"popup close must honor return_focus_id",
	)
	destroy_candidate(&c); layout.destroy_frame(&g)
}
