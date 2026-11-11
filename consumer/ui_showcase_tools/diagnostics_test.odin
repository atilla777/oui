package main

import app "../ui_showcase/app"
import "core:strings"

_ :: app.Shell
_ :: strings.contains

@(test)
v19_deliberate_layout_clip_is_expected_not_a_generic_overflow_waiver :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Layout) {return}
		enable_capture(&f.s)
		if !testing.expect(t, app.rebuild(&f.s.runtime)) {return}
		found := false
		for d in f.s.runtime.live.tools.inspection.diagnostics {if d.id == "layout/clipped" && d.code == "layout.Container_Overflow" {found = true; testing.expect(t, d.expected)}}
		testing.expect(t, found)
	}
}
import "core:testing"

@(test)
v19_published_text_diagnostics_are_normalized_before_failure :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Text) {return}
		s := &f.s; enable_capture(s)
		s.model.text.limit_fixture = 2; s.model.revision += 1
		if !testing.expect(t, app.rebuild(&s.runtime)) {return}
		found := false
		for d in s.runtime.live.tools.inspection.diagnostics {
			found ||= strings.has_prefix(d.code, "text.") && d.id == "text/probe"
		}
		testing.expect(
			t,
			found,
			"owning publication must contain actual normalized text diagnostics",
		)
		h := Host {
			shell   = s,
			allowed = true,
		}
		data := handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"diag","op":"diagnostics"}`),
			context.allocator,
		)
		defer delete(data)
		testing.expect(t, strings.contains(string(data), "text.Pixel_Overflow"), string(data))
	}
}
