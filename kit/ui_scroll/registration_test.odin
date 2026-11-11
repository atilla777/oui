package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

handler :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {return(
		.Continue \
	)}
dispose :: proc(user: rawptr) {counter := cast(^int)user; counter^ += 1}

@(test)
failed_prepare_does_not_dispose_removed_rows_and_success_does_once :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ids := [3]string{"a", "b", "c"}; if !publish(t, &p, &ctx, &s, ids[:], "a") {return}
	disposals := 0
	_, code := interaction.register_handler(
		&ctx,
		"c",
		handler,
		&disposals,
		dispose,
	); if !testing.expect(t, code == .Applied) {return}
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	ds := [1]Description{{"scroll", "missing"}}
	c, e := prepare(&s, &g, &i, ds[:], context.allocator); destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Invalid_Scroll && disposals == 0 && len(ctx.registrations) == 1 && !p.ready,
	)
	publish(t, &p, &ctx, &s, ids[:2])
	testing.expect(t, disposals == 1 && len(ctx.registrations) == 0)
	interaction.destroy(&ctx); testing.expect(t, disposals == 1)
}

@(test)
reference_refusal_has_no_partial_owner_or_fallback :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	s := create(context.allocator); defer destroy(&s)
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(
		&s,
		&g,
		&i,
		ds[:],
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer destroy_candidate(&c)
	refs := p.lifetime.references; p.lifetime.references = max(u64)
	failed, error := prepare(&s, &g, &i, ds[:], context.allocator); destroy_candidate(&failed)
	reader, ok := try_copy_frame(&c.frame, context.allocator); destroy_frame(&reader)
	testing.expect(t, error.code == .Allocation && !ok && p.lifetime.references == max(u64))
	p.lifetime.references = refs
}
