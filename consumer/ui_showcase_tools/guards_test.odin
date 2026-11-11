package main

import app "../ui_showcase/app"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"

_ :: sdl.Event
_ :: strings.contains

@(test)
v19_slider_plain_activation_preserves_native_no_setter_outcome :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		n, found := node_projection(&s.runtime.live, true, "controls/slider")
		if !testing.expect(t, found) {return}
		before := s.model
		// ui_controls permits the base proposal, but emits no Integer event
		// for this intention. Technical permission is not a value setter.
		for status in n.actions {if status.action == "activate" {testing.expect(t, status.allowed)}}
		x := app.execute_tool_action(s, {op = "activate", id = n.id})
		testing.expect(
			t,
			x.code == "Applied" && x.application == "rejected" && s.model == before,
			x.code,
		)
		h := Host {
			shell   = s,
			allowed = true,
		}
		data := handle_line(
			&h,
			request_bytes(
				`{"protocol":19,"request_id":"no-setter","op":"activate","id":"controls/slider"}`,
			),
			context.allocator,
		); defer delete(data)
		last, exists := observation(&h).last_action.?
		testing.expect(
			t,
			exists &&
			last.application_status == "rejected" &&
			last.sequence == s.runtime.publication.sequence,
			string(data),
		)
	}
}

@(test)
v19_disabled_custom_and_editor_owner_have_no_plain_activation_bypass :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Custom) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		testing.expect(t, app.dispatch(s, {.Activate, "custom/disabled", .Agent, false}))
		id := "node:4:left7:content6:circle"
		n, found := node_projection(&s.runtime.live, true, id)
		testing.expect(t, found && !n.enabled)
		for status in n.actions {if status.action == "activate" {testing.expect(t, !status.allowed && status.reason == "Disabled")}}
		before := s.model.effects
		x := app.execute_tool_action(s, {op = "activate", id = id})
		testing.expect(t, x.code == "Disabled" && s.model.effects == before)
		app.request_section(s, "text-input", .Agent)
		n, found = node_projection(&s.runtime.live, true, "name/field")
		if !testing.expect(t, found) {return}
		for status in n.actions {if status.action == "activate" {testing.expect(t, !status.allowed)}}
		before = s.model.effects
		x = app.execute_tool_action(s, {op = "activate", id = "name/field"})
		testing.expect(t, x.code != "Applied" && s.model.effects == before)
		x = app.execute_tool_action(s, {op = "activate", id = id})
		testing.expect(t, x.code == "Not_Found" && s.model.effects == before)
	}
}

@(test)
v19_agent_hold_loss_and_not_ready_release_do_not_complete_or_replay :: proc(t: ^testing.T) {
	when #config(UI_DEMO_TEST, false) && app.TEST {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Hud) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		x := app.execute_tool_action(
			s,
			{op = "begin-hold", id = "hud/restore"},
		); testing.expect(t, x.code == "Applied")
		x = app.execute_tool_action(
			s,
			{op = "advance-hold", duration_ms = 999, test_time = true},
		); testing.expect(t, x.code == "Applied")
		app.handle_input(
			s,
			sdl.Event{window = {type = .WINDOW_FOCUS_LOST, windowID = s.input.window_id}},
			{1280, 960},
		)
		testing.expect(t, s.model.hud_count == 0)
		x = app.execute_tool_action(s, {op = "advance-hold", duration_ms = 1000, test_time = true})
		testing.expect(t, x.code != "Applied" && s.model.hud_count == 0)
		x = app.execute_tool_action(
			s,
			{op = "begin-hold", id = "hud/restore"},
		); testing.expect(t, x.code == "Applied")
		app.block(&s.runtime)
		x = app.execute_tool_action(s, {op = "release-hold"})
		testing.expect(t, x.code == "Not_Ready" && s.model.hud_count == 0)
		testing.expect(t, app.recover(s) && s.model.hud_count == 0)
		// Native R is handled inside host_tick, which drains pending cleanup
		// through the selected clock adapter before servicing another RPC.
		testing.expect(t, app.step_session_clock({shell = s, options = {test_time = true}}, 0))
		x = app.execute_tool_action(s, {op = "advance-hold", duration_ms = 1000, test_time = true})
		testing.expect(t, x.code != "Applied" && s.model.hud_count == 0)
	}
}

@(test)
v19_unsupported_rpc_never_changes_app_or_recovery_state :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		h := Host {
			shell   = s,
			allowed = true,
		}
		for line in ([]string{`{"protocol":19,"request_id":"unsupported","op":"set_value"}`, `{"protocol":19,"request_id":"unsupported","op":"drag"}`, `{"protocol":19,"request_id":"unsupported","op":"overlays"}`}) {
			before := s.model
			data := handle_line(&h, request_bytes(line), context.allocator)
			testing.expect(
				t,
				strings.contains(string(data), "Unsupported_Action") &&
				s.model == before &&
				app.current(&s.runtime),
			); delete(data)
		}
	}
}
