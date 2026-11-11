package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
mouse_drag_arms_at_six_and_hits_only_matching_scope_type :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	ds := descriptions([]string{"card"})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	r := dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Mouse, point = {10, 10}})
	if !testing.expect(t, r.code == .Applied && r.phase == .Armed && r.cycle == 1) {return}
	for point, index in ([3][2]f64{{13, 14}, {16, 10}, {150, 20}}) {
		if !publish(t, &p, &ctx, &s, ds[:]) {return}
		r = dispatch(&s, &ctx, nil, {kind = .Move, source = .Mouse, cycle = 1, point = point})
		if !testing.expect(t, r.code == .Applied) {return}
		if index == 0 {testing.expect(t, r.phase == .Armed && r.count == 1)}
		if index ==
		   1 {testing.expect(t, r.phase == .Active && r.count == 2 && r.signals[0].kind == .Activated)}
		if index == 2 {testing.expect(t, s.live.target_id == "drop" && s.live.target_accepted)}
	}
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	r = dispatch(&s, &ctx, nil, {kind = .End, source = .Mouse, cycle = 1})
	testing.expect(t, r.has_proposal && p.sequence == 1)
}
