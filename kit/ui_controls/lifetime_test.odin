package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import "core:mem"
import "core:testing"

publish_fixture :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^State,
	checked: bool = false,
) -> bool {
	f := make_fixture(t, p, .Checkbox, checked); defer destroy_fixture(&f)
	ds := [1]Description{f.recipe.control}
	c, e := prepare(
		&f.interaction,
		f.layer.frame.layers,
		ds[:],
		context.allocator,
		&f.geometry,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None && validate_candidate(p, &c)) {return false}
	if !testing.expect(t, base.enter_commit(p, c.stamp) == .None) {return false}
	stamp := c.stamp
	interaction.commit(
		ctx,
		&f.interaction,
		f.recipe.control.node_id,
	); commit(s, &c); base.finish_commit(p, stamp)
	interaction.reconcile_registrations(ctx)
	return true
}
@(test)
repeated_publication_does_not_grow_history_and_owning_readers_survive_runtime :: proc(
	t: ^testing.T,
) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, _ := base.create(context.allocator)
	ctx := interaction.create(context.allocator, &p); s := create()
	if !publish_fixture(
		t,
		&p,
		&ctx,
		&s,
	) {destroy(&s); interaction.destroy(&ctx); base.destroy(&p); return}
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {if !publish_fixture(t, &p, &ctx, &s) {break}; testing.expect(t, tracking.current_memory_allocated == live)}
	reader, ok := try_copy_frame(&s.frame, context.allocator); testing.expect(t, ok)
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	if ok {testing.expect(t, reader.controls[0].label == "Выбор / Choice" && !reader.stamp.lifetime.alive)}
	destroy_frame(&reader)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}

@(test)
application_intention_is_not_replayed_by_failed_metadata_and_recovery :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	if !publish_fixture(t, &p, &ctx, &s) {return}
	r := dispatch(&s, &ctx, {kind = .Activate, id = s.frame.controls[0].node_id, source = .Agent})
	if !testing.expect(t, r.event != nil) {return}
	effects := 1; model := r.event.?.checked
	old := s.frame.stamp
	base.begin_attempt(&p, 2)
	bad := [1]Description{{id = "bad", node_id = "missing", kind = .Checkbox}}
	c, e := prepare(&ctx.frame, {}, bad[:], context.allocator); destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Invalid_Control && s.frame.stamp == old && effects == 1 && model && !p.ready,
	)
	testing.expect(
		t,
		dispatch(&s, &ctx, {kind = .Activate, id = s.frame.controls[0].node_id, source = .Agent}).dispatch.code ==
		.Not_Ready,
	)
	if !publish_fixture(t, &p, &ctx, &s, model) {return}
	testing.expect(t, effects == 1 && p.sequence == 1 && s.frame.controls[0].checked && p.ready)
}

@(test)
explicit_composition_claims_refuse_cross_family_double_ownership :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	f := make_fixture(t, &p, .Slider); defer destroy_fixture(&f)
	claims := make([]interaction.Capture_Claim, len(f.recipe.targets) + 1); defer delete(claims)
	for target, k in f.recipe.targets {claims[k] = {target.id, "controls"}}
	claims[len(claims) - 1] = {f.recipe.control.node_id, "other-family"}
	i, code := interaction.prepare(
		&f.geometry,
		f.recipe.targets[:],
		claims,
		context.allocator,
	); defer interaction.destroy_frame(&i)
	testing.expect(t, code == .Conflict && i.targets == nil)
}
