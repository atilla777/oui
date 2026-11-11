package main

import app "../ui_showcase/app"
import "core:encoding/json"
import "core:strings"
import "core:testing"

_ :: app.Shell
_ :: json.unmarshal

request_bytes :: proc(s: string) -> []u8 {return transmute([]u8)s}

@(test)
v19_gate_precedes_any_app_access_and_authorized_catalogue_has_exact_inventory :: proc(
	t: ^testing.T,
) {
	for allowed in ([]bool{false, true}) {
		h := Host {
			allowed = allowed,
		}
		when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {if allowed {continue}}
		data := handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"gate","op":"tree"}`),
			context.allocator,
		)
		defer delete(data)
		testing.expect(
			t,
			strings.contains(string(data), `"Forbidden"`) &&
			!strings.contains(string(data), `"section"`) &&
			!strings.contains(string(data), `"result"`),
			string(data),
		)
	}
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}
		h := Host {
			shell   = &f.s,
			allowed = true,
		}
		data := handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"inventory","op":"list-sections"}`),
			context.allocator,
		)
		defer delete(data)
		Response :: struct {
			ok:     bool,
			result: struct {
				sections: []struct {
					id: string,
				},
			},
		}
		r: Response; e := json.unmarshal(data, &r, allocator = context.temp_allocator)
		if !testing.expect(
			t,
			e == nil && r.ok && len(r.result.sections) == 24,
			string(data),
		) {return}
		testing.expect(
			t,
			r.result.sections[0].id == "catalogue" &&
			r.result.sections[1].id == "layout" &&
			r.result.sections[20].id == "lab-menu" &&
			r.result.sections[23].id == "lab-inventory",
		)
	}
}

@(test)
v19_current_query_and_action_observe_real_application_not_dispatch_success :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}
		s := &f.s; s.runtime.tools_state.enabled = true
		if !testing.expect(t, app.rebuild(&s.runtime)) {return}
		h := Host {
			shell   = s,
			allowed = true,
		}
		data := handle_line(
			&h,
			request_bytes(
				`{"protocol":19,"request_id":"find","op":"find","id":"controls/checkbox"}`,
			),
			context.allocator,
		)
		testing.expect(
			t,
			strings.contains(string(data), `"ok":true`) &&
			strings.contains(string(data), `"ids":["controls/checkbox"]`),
			string(data),
		); delete(data)
		data = handle_line(
			&h,
			request_bytes(
				`{"protocol":19,"request_id":"mutate","op":"activate","id":"controls/checkbox"}`,
			),
			context.allocator,
		)
		testing.expect(
			t,
			s.model.checkbox &&
			s.model.effects == 1 &&
			strings.contains(string(data), `"status":"applied"`),
			string(data),
		); delete(data)
		data = handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"miss","op":"activate","id":"missing"}`),
			context.allocator,
		)
		testing.expect(
			t,
			s.model.checkbox &&
			s.model.effects == 1 &&
			strings.contains(string(data), `"Not_Found"`),
			string(data),
		); delete(data)
	}
}
