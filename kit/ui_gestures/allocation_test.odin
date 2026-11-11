package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:testing"
@(test)
every_gesture_prepare_copy_and_dispatch_refusal_cleans_partial_owners :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s); ds := descriptions([]string{"card"})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_allocator, &fault}
	refs := p.lifetime.references
	f, ok := try_copy_frame(
		&s.frame,
		a,
	); testing.expect(t, ok); count := fault.requests; destroy_frame(&f)
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		f, ok = try_copy_frame(&s.frame, a); destroy_frame(&f)
		testing.expect(
			t,
			!ok &&
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	stamp, _ := base.begin_attempt(&p, 7)
	nodes := [3]layout.Resolved_Node {
		{description = {id = "root", role = .Row}},
		{description = {id = "source", parent = "root", role = .Box}},
		{description = {id = "target", parent = "root", role = .Box}},
	}
	g := layout.Frame {
		nodes    = nodes[:],
		stamp    = stamp,
		ui_scale = 1,
	}
	views := [2]interaction.Target_View {
		{
			description = {id = "source", role = "button"},
			availability = .Applied,
			activation_owner = "gestures",
		},
		{description = {id = "target", role = "drop"}, availability = .Applied},
	}
	i := interaction.Frame {
		targets = views[:],
		stamp   = stamp,
	}
	fault.requests, fault.refuse = 0, 0
	c, ce := prepare(&s, &g, &i, nil, ds[:], 7, a)
	testing.expect(
		t,
		ce.code == .None && validate_candidate(&p, &s, &c),
	); count = fault.requests; destroy_candidate(&c)
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		c, ce = prepare(&s, &g, &i, nil, ds[:], 7, a)
		testing.expect(t, ce.code == .Allocation && c.frame.gestures == nil); destroy_candidate(&c)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	previous := s.allocator; s.allocator = a; defer {s.allocator = previous}
	fault.requests, fault.refuse = 0, 0
	r := dispatch(&s, &ctx, nil, {kind = .Aim, id = "drop", cycle = 1, source = .Agent})
	testing.expect(t, r.code == .Applied); count = fault.requests
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		version := s.version
		r = dispatch(&s, &ctx, nil, {kind = .Aim, id = "drop", cycle = 1, source = .Agent})
		testing.expect(
			t,
			r.code == .Allocation &&
			s.version == version &&
			p.ready &&
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0,
		)
	}
}
