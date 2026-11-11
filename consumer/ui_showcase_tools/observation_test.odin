package main

import app "../ui_showcase/app"
import "core:strings"

_ :: app.Shell
_ :: strings.contains
import "core:testing"

@(test)
v19_metadata_mismatch_is_not_current_authority_or_a_mutation_permission :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s; enable_capture(s)
		if !testing.expect(t, app.rebuild(&s.runtime)) {return}
		s.runtime.live.tools.inspection.frame.stamp.model_revision += 1
		h := Host {
			shell   = s,
			allowed = true,
		}
		data := handle_line(
			&h,
			request_bytes(
				`{"protocol":19,"request_id":"mismatch","op":"activate","id":"controls/checkbox"}`,
			),
			context.allocator,
		)
		defer delete(data)
		testing.expect(
			t,
			strings.contains(string(data), `"Metadata_Mismatch"`) &&
			!s.model.checkbox &&
			s.model.effects == 0 &&
			!s.runtime.publication.ready,
			string(data),
		)
	}
}

@(test)
v19_custom_action_status_matches_real_owner_without_probe_dispatch :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Custom) {return}; s := &f.s; enable_capture(s)
		if !testing.expect(t, app.rebuild(&s.runtime)) {return}
		before := s.runtime.publication.sequence
		reader := &s.runtime.live
		n, found := node_projection(reader, true, "node:4:left7:content6:circle")
		if !testing.expect(t, found) {return}
		allowed := false; for a in n.actions {if a.action == "activate" {allowed = a.allowed}}
		testing.expect(
			t,
			allowed && before == s.runtime.publication.sequence && s.model.custom_counts[0] == 0,
		)
		x := app.execute_tool_action(s, {op = "activate", id = n.id})
		testing.expect(t, x.code == "Applied" && s.model.custom_counts[0] == 1)
	}
}
