package ui_debug
import base "../ui_base"
import inspect "../ui_inspect"
import interaction "../ui_interaction"
import layout "../ui_layout"
import wire "../ui_wire"
import "core:mem"
import "core:strings"
import "core:testing"

Fixture :: struct {
	calls:                int,
	revision, published:  u64,
	failed, bad_metadata: bool,
	caps:                 Capabilities,
}
fixture_capture :: proc(user: rawptr, a: mem.Allocator) -> Capture {
	u := cast(^Fixture)user
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, u.published)
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
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); defer layout.destroy_frame(&g)
	if e.code != .None {return {error = "Preparation_Failed"}}
	targets := [1]interaction.Target{{"button", "button", true, true}}
	f, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&f)
	if code != .Applied {return {error = "Preparation_Failed"}}
	i, ie := inspect.capture(
		{
			frame = &g,
			interaction = &f,
			ready = !u.failed,
			model_revision = u.revision,
			published_revision = u.published,
			capabilities = u.caps.actions,
			semantics = []inspect.Semantic{{"button", "button", "Кнопка", "source:1"}},
		},
		a,
	)
	if ie != .None {return {error = "Capture_Failed"}}
	projected := make([]Wire_Node, 1, a)
	projected[0], _ = node_projection(
		&i,
		"button",
		{id = "button", role = .Button, enabled = true, visible = true, layout = nodes[0].layout},
	)
	c := Capture {
		inspection = i,
		nodes = projected,
		frame = {drawable = g.drawable, ui_scale = g.ui_scale},
		family = .Layout,
	}
	if u.bad_metadata {c.frame.ui_scale = 2}
	owner, oe := new(base.Publication, a)
	if oe != nil {c.error = "Allocation"; return c}
	owner^ = p; p = {}
	c.owner =
		owner; c.release = proc(data: rawptr, a: mem.Allocator) {p := cast(^base.Publication)data; base.destroy(p); free(p, a)}
	return c
}
fixture_execute :: proc(user: rawptr, a: Debug_Action) -> Action_Reply {
	u := cast(^Fixture)user; u.calls += 1; u.revision += 1; u.failed = true; return {error = "Not_Ready"}
}
@(test)
envelope_gates_and_exactly_one_effect :: proc(t: ^testing.T) {
	u := Fixture {
		revision  = 3,
		published = 3,
	}; u.caps.actions[.Activate] = true
	h := Host {
		user         = &u,
		capture      = fixture_capture,
		execute      = fixture_execute,
		capabilities = u.caps,
	}
	line := transmute([]u8)string(`{"protocol":10,"request_id":"a","op":"activate","id":"button"}`)
	denied := handle_line(&h, line, context.allocator); defer delete(denied)
	testing.expect(
		t,
		strings.contains(string(denied), `"Forbidden"`) &&
		!strings.contains(string(denied), `"frame_id"`) &&
		u.calls == 0,
	)
	h.allowed = true
	when !(ODIN_DEBUG || #config(UI_DEMO_TEST, false)) {
		r := handle_line(&h, line, context.allocator); defer delete(r)
		testing.expect(
			t,
			strings.contains(string(r), `"Forbidden"`) &&
			!strings.contains(string(r), `"frame_id"`) &&
			u.calls == 0,
		)
		return
	}
	failed := handle_line(&h, line, context.allocator); defer delete(failed)
	testing.expect(
		t,
		u.calls == 1 &&
		strings.contains(string(failed), `"historical":true`) &&
		strings.contains(string(failed), `"model_revision":4`) &&
		strings.contains(string(failed), `"published_revision":3`),
		string(failed),
	)
	refused := handle_line(&h, line, context.allocator); defer delete(refused)
	testing.expect(t, u.calls == 1 && strings.contains(string(refused), `"Not_Ready"`))
	u.failed = false; u.published = u.revision
	recovered := handle_line(
		&h,
		transmute([]u8)string(`{"protocol":10,"request_id":"r","op":"tree"}`),
		context.allocator,
	); defer delete(recovered)
	testing.expect(
		t,
		u.calls == 1 &&
		strings.contains(string(recovered), `"ready":true`) &&
		strings.contains(string(recovered), `"structural_role":"Button"`),
	)
}
@(test)
projection_metadata_cannot_claim_another_scale :: proc(t: ^testing.T) {
	when !(ODIN_DEBUG || #config(UI_DEMO_TEST, false)) {return}
	u := Fixture {
		revision     = 3,
		published    = 3,
		bad_metadata = true,
	}
	h := Host {
		user    = &u,
		allowed = true,
		capture = fixture_capture,
	}
	r := handle_line(
		&h,
		transmute([]u8)string(`{"protocol":10,"request_id":"r","op":"tree"}`),
		context.allocator,
	); defer delete(r)
	testing.expect(t, strings.contains(string(r), `"Metadata_Mismatch"`), string(r))
}
@(test)
raw_integer_projection_and_bounded_error_identity :: proc(t: ^testing.T) {
	s := `{"frame_id":18446744073709551615,"result":{"observation":null}}`
	data := encode_result_projection(transmute([]u8)s, struct {
			revision: u64,
		}{max(u64)}, context.allocator); defer delete(data)
	r := encode_observation(
		data,
		transmute([]u8)string("{\n \"cycle\":9007199254740993\n}"),
		context.allocator,
	); defer delete(r)
	testing.expect(
		t,
		strings.contains(string(r), `"frame_id":18446744073709551615`) &&
		strings.contains(string(r), `"revision":18446744073709551615`) &&
		strings.contains(string(r), `"observation":{"cycle":9007199254740993}`),
	)
	id := strings.repeat("q", MESSAGE_LIMIT); defer delete(id)
	e := error_reply(id, "Message_Too_Large", context.allocator); defer delete(e)
	testing.expect(
		t,
		len(e) + 1 <= MESSAGE_LIMIT && strings.contains(string(e), `"request_id":""`),
	)
	testing.expect(
		t,
		int(wire.Code.Hold_Required) == 7 &&
		int(wire.Code.Gesture_Busy) == 9 &&
		int(wire.Role.Button) == 2,
	)
	_, mapped := wire.code(
		.Conflict,
	); testing.expect(t, !mapped, "Conflict is not generically Gesture_Busy")
}
@(test)
selected_action_reply_replaces_placeholder_without_duplicate_keys :: proc(t: ^testing.T) {
	base := `{"frame_id":18446744073709551615,"result":{"gesture_reply":null,"observation":null}}`
	r := encode_result_projection(transmute([]u8)base, struct {
			gesture_reply: struct {
				cycle: u64,
			},
		}{{9007199254740993}}, context.allocator); defer delete(r)
	testing.expect(
		t,
		strings.count(string(r), `"gesture_reply"`) == 1 &&
		strings.contains(string(r), `"cycle":9007199254740993`),
		string(r),
	)
}
