package main

import app "../ui_showcase/app"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import profile "profile"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

_ :: app.Shell
_ :: fmt.tprintf
_ :: os.exists
_ :: strings.contains
_ :: backend.Resource_Ledger
_ :: sdl.Event
_ :: profile.MESSAGE_LIMIT

@(test)
snapshot_oversize_manifest_refuses_before_staging_even_with_valid_large_correlation :: proc(
	t: ^testing.T,
) {
	when #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		id := make([]u8, profile.MESSAGE_LIMIT - 200); defer delete(id)
		for &byte in id {byte = 'x'}
		testing.expect(
			t,
			app.begin_tool_record(s, string(id), "focus", "controls/checkbox", .Agent),
		)
		x := app.execute_tool_action(s, {op = "focus", id = "controls/checkbox"})
		testing.expect(t, x.code == "Applied" && app.rebuild(&s.runtime))
		run, e := os.make_directory_temp(
			"/tmp/opencode",
			"iv15-manifest-limit-*",
			context.allocator,
		)
		if !testing.expect(t, e == nil) {return}; defer delete(run)
		h := Host {
			shell   = s,
			allowed = true,
			run     = run,
		}
		path, error := capture_snapshot(&h, context.allocator); defer delete(path)
		testing.expect(
			t,
			path == "" &&
			error == "Message_Too_Large" &&
			!s.runtime.publication.ready &&
			h.snapshot_index == 0 &&
			h.native_surfaces.live == 0,
		)
		testing.expect(t, !os.exists(fmt.tprintf("%s/snapshot-1", run)))
	}
}

@(test)
snapshot_failure_diagnostic_survives_queries_and_explicit_recovery :: proc(t: ^testing.T) {
	when #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s; enable_capture(s)
		if !testing.expect(t, app.rebuild(&s.runtime)) {return}
		run, e := os.make_directory_temp("/tmp/opencode", "iv15-failure-*", context.allocator)
		if !testing.expect(t, e == nil) {return}; defer delete(run)
		h := Host {
			shell          = s,
			allowed        = true,
			run            = run,
			snapshot_fault = "write",
		}
		data := handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"failed","op":"snapshot"}`),
			context.allocator,
		); delete(data)
		data = handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"why","op":"diagnostics"}`),
			context.allocator,
		)
		testing.expect(
			t,
			strings.contains(string(data), "IO_Failed") && !s.runtime.publication.ready,
			string(data),
		); delete(data)
		testing.expect(t, app.recover(s))
		data = handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"after-r","op":"diagnostics"}`),
			context.allocator,
		)
		testing.expect(
			t,
			strings.contains(string(data), "IO_Failed") &&
			strings.contains(string(data), "historical failure") &&
			s.runtime.publication.ready,
			string(data),
		); delete(data)
	}
}

@(test)
snapshot_full_boundary_faults_never_publish_a_final_partial_or_leak_native_surface :: proc(
	t: ^testing.T,
) {
	when #config(UI_DEMO_TEST, false) {
		for fault in ([]string{"capture", "copy", "generation", "size", "render", "readback", "present", "restore", "encode", "write", "rename", "occupied"}) {
			f: app.Page_Fixture
			if !app.start_page_fixture(t, &f, .Controls) {app.stop_page_fixture(&f); return}
			s := &f.s; enable_capture(s); testing.expect(t, app.rebuild(&s.runtime))
			run, e := os.make_directory_temp("/tmp/opencode", "iv15-fault-*", context.allocator)
			if !testing.expect(t, e == nil) {app.stop_page_fixture(&f); return}
			h := Host {
				shell          = s,
				allowed        = true,
				run            = run,
				snapshot_fault = fault,
			}
			final := fmt.tprintf("%s/snapshot-1", run)
			if fault == "occupied" {
				testing.expect(
					t,
					os.make_directory(final, {.Read_User, .Write_User, .Execute_User}) == nil,
				)
				testing.expect(
					t,
					os.write_entire_file(
						fmt.tprintf("%s/sentinel", final),
						[]u8{42},
						{.Read_User, .Write_User},
					) ==
					nil,
				)
			}
			sdl.SetRenderScale(
				s.renderer,
				1.25,
				1.5,
			); clip := sdl.Rect{4, 6, 90, 70}; sdl.SetRenderClipRect(s.renderer, &clip)
			before, saved := backend.save_renderer_state(s.renderer)
			data := handle_line(
				&h,
				request_bytes(`{"protocol":19,"request_id":"fault","op":"snapshot"}`),
				context.allocator,
			)
			after, restored := backend.save_renderer_state(s.renderer)
			testing.expect(
				t,
				!strings.contains(string(data), `"ok":true`) &&
				!s.runtime.publication.ready &&
				saved &&
				restored &&
				before == after,
				fault,
				string(data),
			)
			testing.expect(
				t,
				!os.exists(fmt.tprintf("%s/snapshot.json", final)) &&
				!os.exists(fmt.tprintf("%s/screenshot.bmp", final)),
				fault,
			)
			testing.expect(
				t,
				h.native_surfaces.live == 0 &&
				h.native_surfaces.created == h.native_surfaces.destroyed,
				fault,
			)
			if fault ==
			   "occupied" {sentinel, se := os.read_entire_file(fmt.tprintf("%s/sentinel", final), context.allocator); testing.expect(t, se == nil && len(sentinel) == 1 && sentinel[0] == 42); delete(sentinel)}
			delete(data); delete(run); app.stop_page_fixture(&f)
		}
	}
}
