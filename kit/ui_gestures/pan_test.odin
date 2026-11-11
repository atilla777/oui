package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import scroll "../ui_scroll"
import "core:testing"
@(test)
pan_clamps_in_layout_space_and_resize_rebases_without_jump :: proc(t: ^testing.T) {
	for scale in ([2]f64{1, 2}) {
		p, _ := base.create(context.allocator); defer base.destroy(&p)
		ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
		s := create()
		defer destroy(&s)
		ss := scroll.create(context.allocator)
		defer scroll.destroy(&ss)
		ds := scroll_descriptions()
		if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:], 100, scale) {return}
		scroll.dispatch(&ss, &ctx, {kind = .Scroll_By, id = "viewport", delta_y = 180})
		if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:], 100, scale) {return}
		r := dispatch(
			&s,
			&ctx,
			&ss,
			{kind = .Begin, id = "pan", source = .Mouse, point = {30, 50}},
		)
		if !testing.expect(t, r.code == .Applied && r.phase == .Armed) {return}
		if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:], 100, scale) {return}
		r = dispatch(&s, &ctx, &ss, {kind = .Move, source = .Mouse, cycle = 1, point = {30, -50}})
		if !testing.expect(t, r.code == .Applied && r.phase == .Active && r.count == 2) {return}
		if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:], 100, scale) {return}
		testing.expect(t, ss.frame.regions[0].offset == 200)
		if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:], 50, scale) {return}
		r = dispatch(&s, &ctx, &ss, {kind = .Move, source = .Mouse, cycle = 1, point = {30, -49}})
		if !testing.expect(t, r.code == .Applied) {return}
		if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:], 50, scale) {return}
		testing.expect(
			t,
			ss.frame.regions[0].offset == 199 && ctx.focus_id == "source" && p.sequence == 0,
		)
	}
}
