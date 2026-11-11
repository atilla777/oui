package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:strings"
import "core:testing"

@(test)
validation_errors_are_addressed_and_copyable :: proc(t: ^testing.T) {
	id := strings.clone("missing")
	e, ok := base.try_copy_error(
		describe_error({.Invalid_Hold, id}),
		context.allocator,
	); delete(id); defer base.destroy_error(&e)
	testing.expect(
		t,
		ok &&
		e.family == .Hold &&
		e.stage == .Prepare &&
		e.id == "missing" &&
		e.code == u32(Error_Code.Invalid_Hold),
	)
}

@(test)
rejects_invalid_ranges_roles_duplicates_and_stamp_mismatch_without_binding :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g, i := geometry(t, &p); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	for hs in ([]([]Description){{{"confirm", 0}}, {{"confirm", -1}}, {{"missing", 1}}, {{"root", 1}}, {{"confirm", 1}, {"confirm", 2}}}) {
		c, e := prepare(
			&s,
			&ctx,
			&g,
			&i,
			nil,
			hs,
			context.allocator,
		); destroy_candidate(&c); testing.expect(t, e.code == .Invalid_Hold && e.id != "")
	}
	for ps in ([]([]Progress_Description){{{"bar", -1, 100}}, {{"bar", 0, 0}}, {{"bar", 101, 100}}, {{"bar", transmute(f64)u64(0x7ff8000000000000), 100}}, {{"missing", 0, 100}}, {{"bar", 1, 100}, {"bar", 2, 100}}}) {
		c, e := prepare(
			&s,
			&ctx,
			&g,
			&i,
			ps,
			nil,
			context.allocator,
		); destroy_candidate(&c); testing.expect(t, e.code == .Invalid_Progress && e.id != "")
	}
	wrong := g; wrong.stamp.attempt += 1
	c, e := prepare(
		&s,
		&ctx,
		&wrong,
		&i,
		nil,
		nil,
		context.allocator,
	); destroy_candidate(&c); testing.expect(t, e.code == .Stale)
	for n in i.targets {testing.expect(t, n.activation_owner == "")}
}

@(test)
progress_geometry_and_metadata_are_owning_and_snap_at_scale :: proc(t: ^testing.T) {
	p, _ := base.create(
		context.allocator,
	); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
	g, i := geometry(t, &p); g.ui_scale = 2
	ps := [1]Progress_Description{{"bar", 1, 3}}
	c, e := prepare(&s, &ctx, &g, &i, ps[:], nil, context.allocator)
	r, ok := try_copy_frame(&c.frame, context.allocator)
	destroy_candidate(
		&c,
	); layout.destroy_frame(&g); interaction.destroy_frame(&i); destroy(&s); interaction.destroy(&ctx); base.destroy(&p); defer destroy_frame(&r)
	testing.expect(
		t,
		e.code == .None &&
		ok &&
		r.progress[0].id == "bar" &&
		r.progress[0].fill.w == 33.5 &&
		r.progress[0].value == 1 &&
		r.progress[0].maximum == 3,
	)
}
