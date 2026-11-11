package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:fmt"
import "core:testing"

descriptions :: proc(types: []string) -> [2]Description {return {
		{
			id = "drag",
			node_id = "source",
			payload_id = "card",
			payload_type = "card",
			kind = .Drag_Source,
		},
		{id = "drop", node_id = "target", kind = .Drop_Target, accept_types = types},
	}}
publish :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^State,
	ds: []Description,
	revision: u64 = 7,
) -> bool {
	stamp, _ := base.begin_attempt(p, revision)
	nodes := [3]layout.Node {
		{
			id = "root",
			role = .Row,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 200},
				y = {mode = .Fixed, value = 100},
			},
		},
		{
			id = "source",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 100},
			},
		},
		{
			id = "target",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 100},
			},
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {200, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	)
	if !testing.expect(t, ge.code == .None) {return false}; defer layout.destroy_frame(&g)
	i, ie := interaction.prepare(
		&g,
		[]interaction.Target{{"source", "button", true, true}, {"target", "drop", true, true}},
		[]interaction.Capture_Claim{{"source", "gestures"}},
		context.allocator,
	)
	if !testing.expect(t, ie == .Applied) {return false}; defer interaction.destroy_frame(&i)
	c, ce := prepare(s, &g, &i, nil, ds, revision); defer destroy_candidate(&c)
	if !testing.expect(
		t,
		ce.code == .None && validate_candidate(p, s, &c),
		fmt.tprintf("gesture candidate must prepare on shared owners: %v", ce),
	) {return false}
	if !testing.expect(t, base.enter_commit(p, stamp) == .None) {return false}
	interaction.commit(ctx, &i, "source"); commit(s, &c); base.finish_commit(p, stamp)
	return true
}
@(test)
independent_gesture_family_prepares_without_editor_or_text :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	ds := descriptions([]string{"card"})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	v, ok := find(&s.frame, "drag")
	testing.expect(
		t,
		ok &&
		v.payload_type == "card" &&
		s.frame.model_revision == 7 &&
		s.live.phase == .Idle &&
		p.ready,
	)
}
