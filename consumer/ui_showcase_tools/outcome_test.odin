package main

import app "../ui_showcase/app"
import "core:encoding/json"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"

_ :: strings.contains
_ :: sdl.Event
_ :: json.unmarshal

@(test)
v19_last_outcome_survives_reply_loss_and_recovery_without_replay :: proc(t: ^testing.T) {
	when (ODIN_DEBUG || #config(UI_DEMO_TEST, false)) && app.TEST {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s; enable_capture(s)
		if !testing.expect(t, app.rebuild(&s.runtime)) {return}
		h := Host {
			shell   = s,
			allowed = true,
		}
		s.runtime.fault = .Copy
		lost_reply := handle_line(
			&h,
			request_bytes(
				`{"protocol":19,"request_id":"accepted-once","op":"activate","id":"controls/checkbox"}`,
			),
			context.allocator,
		)
		// The envelope reports publication failure, independently of the
		// dispatch and application outcome already accepted exactly once.
		Reply_Oracle :: struct {
			ok, ready, historical: bool,
			error:                 struct {
				code: string,
			},
			result:                struct {
				dispatch:                      Dispatch,
				application:                   Application,
				effects_before, effects_after: u64,
			},
		}
		wire: Reply_Oracle
		e := json.unmarshal(lost_reply, &wire, allocator = context.temp_allocator)
		testing.expect(
			t,
			e == nil &&
			!wire.ok &&
			!wire.ready &&
			wire.historical &&
			wire.error.code == "Not_Ready" &&
			wire.result.dispatch.code == "Applied" &&
			wire.result.dispatch.has_event &&
			wire.result.dispatch.sequence == 1 &&
			wire.result.application.status == "applied" &&
			wire.result.effects_before == 0 &&
			wire.result.effects_after == 1,
			string(lost_reply),
		)
		delete(lost_reply) // Simulate a client that did not observe the answer.
		testing.expect(t, s.model.checkbox && s.model.effects == 1 && !s.runtime.publication.ready)
		data := handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"observe","op":"tree"}`),
			context.allocator,
		)
		testing.expect(
			t,
			strings.contains(string(data), `"request_id":"accepted-once"`) &&
			strings.contains(string(data), `"application_status":"applied"`) &&
			strings.contains(string(data), `"historical":true`),
			string(data),
		); delete(data)
		testing.expect(t, app.recover(s) && s.model.checkbox && s.model.effects == 1)
		// A native activation replaces the single record using its true source.
		app.page_key(s, sdl.K_TAB)
		app.page_key(s, sdl.K_RETURN)
		data = handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"native","op":"tree"}`),
			context.allocator,
		)
		testing.expect(
			t,
			strings.contains(string(data), `"source":"Keyboard"`) &&
			!strings.contains(string(data), `"request_id":"accepted-once"`),
			string(data),
		); delete(data)
	}
}
