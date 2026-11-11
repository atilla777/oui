package selected_tools
import "core:mem"
import "core:strings"
import "core:testing"
import base "ui:ui_base"
import debug "ui:ui_debug"
import common "ui:ui_inspect"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import transitions "ui:ui_transitions/debug"

Clock_Probe :: struct {
	p:     base.Publication,
	g:     layout.Frame,
	ctx:   interaction.Context,
	calls: int,
}
clock_capture :: proc(user: rawptr, a: mem.Allocator) -> debug.Capture {
	u := cast(^Clock_Probe)user
	i, e := common.capture(
		{
			frame = &u.g,
			interaction = &u.ctx.frame,
			ready = interaction.ready(&u.ctx),
			model_revision = 1,
			published_revision = 1,
		},
		a,
	)
	if e != .None {return {error = common.error_name(e)}}
	c := debug.Capture {
		inspection = i,
		frame = {drawable = i.frame.drawable, ui_scale = i.frame.ui_scale},
		family = .Layout,
	}
	allocation: mem.Allocator_Error; c.nodes, allocation = make([]debug.Wire_Node, 1, a); if allocation != nil {c.error = "Allocation"; return c}
	n := i.frame.nodes[0]
	c.nodes[0], _ = debug.node_projection(
		&c.inspection,
		"button",
		{
			id = "button",
			role = .Button,
			enabled = true,
			visible = true,
			layout = n.description.layout,
		},
	)
	return c
}
clock_execute :: proc(
	user: rawptr,
	r: debug.Request,
	a: mem.Allocator,
) -> debug.Action_Reply {u := cast(^Clock_Probe)user; u.calls += 1; return {}}
clock_refusal :: proc(
	user: rawptr,
	c: ^debug.Capture,
	r: debug.Request,
	result: ^debug.Result,
) -> (
	bool,
	string,
) {
	return false, transitions.guard_request(r, false)
}
@(test)
interactive_clock_gate_precedes_callback_and_uses_existing_envelope :: proc(t: ^testing.T) {
	when !(ODIN_DEBUG || #config(UI_DEMO_TEST, false)) {return}
	u: Clock_Probe; u.p, _ = base.create(context.allocator); defer base.destroy(&u.p)
	u.ctx = interaction.create(context.allocator, &u.p); defer interaction.destroy(&u.ctx)
	s, _ := base.begin_attempt(&u.p, 1)
	nodes := [1]layout.Node {
		{
			id = "button",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	u.g, _ = layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); defer layout.destroy_frame(&u.g)
	targets := [1]interaction.Target{{"button", "button", true, true}}
	f, _ := interaction.prepare(
		&u.g,
		targets[:],
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&f)
	base.enter_commit(&u.p, s); interaction.commit(&u.ctx, &f); base.finish_commit(&u.p, s)
	h := debug.Host {
		allowed           = true,
		user              = &u,
		capture           = clock_capture,
		execute_extension = clock_execute,
		query             = clock_refusal,
	}
	transitions.configure(&h)
	r := debug.handle_line(
		&h,
		transmute([]u8)string(`{"protocol":16,"request_id":"r","op":"advance","duration_ms":1}`),
		context.allocator,
	); defer delete(r)
	testing.expect(
		t,
		u.calls == 0 &&
		strings.contains(string(r), `"Interactive_Clock"`) &&
		!strings.contains(string(r), `"frame_id"`),
		string(r),
	)
	h.execute_extension = nil
	missing := debug.handle_line(
		&h,
		transmute([]u8)string(`{"protocol":16,"request_id":"r","op":"finish-transitions"}`),
		context.allocator,
	); defer delete(missing)
	testing.expect(
		t,
		u.calls == 0 &&
		strings.contains(string(missing), `"Interactive_Clock"`) &&
		!strings.contains(string(missing), `"frame_id"`),
		string(missing),
	)
}
