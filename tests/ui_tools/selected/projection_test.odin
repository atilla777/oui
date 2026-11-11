package selected_tools
import "core:strings"
import "core:testing"
import base "ui:ui_base"
import debug "ui:ui_debug"
import gestures "ui:ui_gestures"
import gd "ui:ui_gestures/debug"
import hold "ui:ui_hold"
import hd "ui:ui_hold/debug"
import common "ui:ui_inspect"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
@(test)
hold_projection_owns_serialized_payload_and_keeps_refusal_codes :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	f := hold.Frame {
		holds = []hold.Description{{"button", 100}},
		progress = []hold.Progress{{id = "button", value = 1, maximum = 2}},
		hold = {id = "button", phase = .Holding, cycle = 9007199254740993, threshold_ms = 100},
	}
	nodes := make([]debug.Wire_Node, 1); nodes[0].resolved.description.id = "button"
	m: debug.Frame_Metadata
	testing.expect(
		t,
		hd.project_node(&f, &nodes[0], context.allocator) &&
		hd.project_frame(&f, &m, context.allocator),
	)
	defer debug.destroy_projection(nodes, &m, nil, context.allocator)
	f.hold.cycle = 0; f.holds[0].id = "gone"
	bytes := debug.encode(m, context.allocator); defer delete(bytes)
	testing.expect(
		t,
		strings.contains(string(bytes), `"cycle":9007199254740993`) &&
		strings.contains(string(bytes), `"cancel":null`),
		string(bytes),
	)
	i := common.Inspection {
		children = [][]int{nil},
		frame = {nodes = []layout.Resolved_Node{{description = {id = "button", role = .Box}}}},
		ready = true,
		interaction = {
			targets = []interaction.Target_View {
				{
					activation_owner = "hold",
					description = {id = "button", role = "button", enabled = true, visible = true},
					availability = .Applied,
				},
			},
		},
	}
	i.frame.stamp = stamp
	i.capabilities[.Activate], i.capabilities[.Begin] = true, true
	f.holds[0].id = "button"; f.hold.phase = .Idle
	a, ok := hd.actions(
		&i,
		&f,
		"button",
	); testing.expect(t, ok && a[.Activate].code == .Hold_Required && a[.Begin].code == .Applied)
	i.ready =
		false; a, ok = hd.actions(&i, &f, "button"); testing.expect(t, ok && a[.Activate].code == .Not_Ready && a[.Begin].code == .Not_Ready)
}
@(test)
busy_begin_keeps_old_priority_before_missing_target :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1); base.enter_commit(&p, s); base.finish_commit(&p, s)
	ctx := interaction.Context {
		publication = &p,
		frame = {stamp = s},
	}
	g := gestures.State {
		frame = {stamp = s},
		live = {phase = .Active},
	}
	r, valid := gd.parse_gestures_request(
		transmute([]u8)string(
			`{"protocol":14,"request_id":"r","op":"gesture_begin","id":"missing"}`,
		),
	); testing.expect(t, valid)
	_, reply, representable := gd.dispatch_request(&g, &ctx, nil, r)
	testing.expect(t, representable && reply.code == .Gesture_Busy && g.live.phase == .Active)
}
