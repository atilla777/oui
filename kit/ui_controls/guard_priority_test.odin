package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
slider_common_gates_precede_values_and_missing_interface_is_addressed :: proc(t: ^testing.T) {
	for source in interaction.Source {
		p, _ := base.create(context.allocator); f := make_fixture(t, &p, .Slider)
		ds := [1]Description {
			f.recipe.control,
		}; c, e := prepare(&f.interaction, f.layer.frame.layers, ds[:], context.allocator, &f.geometry)
		if !testing.expect(t, e.code == .None) {destroy_fixture(&f); base.destroy(&p); continue}
		s := create(); commit(&s, &c)
		ctx := interaction.create(context.allocator, &p); stamp := f.geometry.stamp
		base.enter_commit(
			&p,
			stamp,
		); interaction.commit(&ctx, &f.interaction); base.finish_commit(&p, stamp)
		n, _ := interaction.find(&ctx.frame, ds[0].node_id); n.availability = .Disabled
		r := dispatch(
			&s,
			&ctx,
			{kind = .Set_Value, id = ds[0].node_id, source = source, value = 55},
		)
		testing.expect(t, r.dispatch.code == .Disabled && p.ready && p.sequence == 0)
		n.availability = .Applied
		r = dispatch(&s, &ctx, {kind = .Set_Value, id = "missing", source = source, value = 55})
		testing.expect(
			t,
			r.dispatch.code == .Not_Found && p.ready,
			"missing target is refused before validating its value",
		)
		r = dispatch(&s, &ctx, {kind = .Set_Value, id = "trigger", source = source, value = 55})
		testing.expect(
			t,
			r.dispatch.code == .Not_Found && p.ready,
			"ordinary button does not acquire a slider interface",
		)
		base.invalidate(&p)
		r = dispatch(
			&s,
			&ctx,
			{kind = .Set_Value, id = "missing", source = interaction.Source(99), value = 55},
		); testing.expect(t, r.dispatch.code == .Not_Ready)
		destroy(&s); interaction.destroy(&ctx); destroy_fixture(&f); base.destroy(&p)
	}
}
