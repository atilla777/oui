package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
top_modal_cancel_is_one_intention_for_every_source :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	for source in interaction.Source {
		g := fixture(t, &p, true); accept(t, &p, &s, &ctx, &g, true); layout.destroy_frame(&g)
		before := p.sequence
		r := dispatch(&s, &ctx, {kind = .Cancel, source = source})
		cancel, ok := r.cancel.?
		testing.expect(
			t,
			r.dispatch.code == .Applied &&
			!r.dispatch.has_event &&
			ok &&
			cancel.root_id == "modal" &&
			cancel.sequence == before + 1 &&
			cancel.source == source,
		)
		testing.expect(
			t,
			!p.ready &&
			dispatch(&s, &ctx, {kind = .Cancel, source = source}).dispatch.code == .Not_Ready,
		)
	}
}
Route :: struct {
	ids:   [3]string,
	count: int,
}
observe :: proc(
	d: interaction.Delivery,
	user: rawptr,
) -> interaction.Propagation {r := cast(^Route)user; r.ids[r.count] = d.current_id; r.count += 1
	return .Continue}
@(test)
popup_shield_half_open_hit_and_real_route_boundary :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g := popup_geometry(t, &p, true); defer layout.destroy_frame(&g)
	targets := [4]interaction.Target {
		{"open", "button", true, true},
		{"return", "button", true, true},
		{"ab", "button", true, true},
		{"bb", "button", true, true},
	}
	popups := [2]Popup{{"b", "", "return"}, {"a", "", "open"}}
	c, e := prepare(
		&s,
		&ctx,
		&g,
		targets[:],
		nil,
		{base_root_id = "base", popups = popups[:]},
		context.allocator,
	); defer destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .None,
	); base.enter_commit(&p, g.stamp); commit(&s, &ctx, &c); base.finish_commit(&p, g.stamp)
	for point, i in ([4][2]f64{{20, 20}, {29, 29}, {30, 30}, {70, 70}}) {
		n, code := hit_test(&s.frame, &g, &ctx.frame, point[0], point[1])
		if i == 2 {testing.expect(t, code == .Not_Found, "popup body shields underlying button")
		} else {want := "ab"; if i == 3 {want = "return"}
			testing.expect(t, code == .Applied && n != nil && n.description.id == want)}
	}
	r: Route
	for id in ([3]string{"ab", "a", "root"}) {_, code := interaction.register_handler(&ctx, id, observe, &r); testing.expect(t, code == .Applied)}
	result := dispatch(&s, &ctx, {kind = .Activate, id = "ab", source = .Agent})
	testing.expect(
		t,
		result.dispatch.has_event && r.count == 2 && r.ids[0] == "ab" && r.ids[1] == "a",
	)
}
