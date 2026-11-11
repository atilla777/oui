package main

import app "../ui_showcase/app"
import "core:fmt"
import "core:mem"
import "core:os"

_ :: app.Shell
_ :: fmt.tprintf
_ :: mem.Allocator
_ :: os.exists

@(test)
v19_pending_record_allocation_refusal_preserves_previous_completed_outcome :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
		fault := app.Allocation_Fault {
			backing = mem.tracking_allocator(&tracking),
		}
		trace := app.Tool_Trace {
			allocator = {app.refuse_allocation, &fault},
		}
		defer {app.destroy_tool_record(&trace.last, trace.allocator)
			app.destroy_tool_record(&trace.pending, trace.allocator)}
		s: app.Shell; s.runtime.tools_state.trace = &trace
		testing.expect(t, app.begin_tool_record(&s, "previous-id", "focus", "stable-id", .Agent))
		app.finish_tool_record(&s.runtime, "Applied")
		stable := tracking.current_memory_allocated
		for n in 1 ..= 3 {
			fault.requests, fault.refuse = 0, n
			testing.expect(
				t,
				!app.begin_tool_record(&s, "new-id", "activate", "another-id", .Agent),
			)
			testing.expect(
				t,
				!trace.has_pending &&
				trace.has_last &&
				trace.last.request_id == "previous-id" &&
				tracking.current_memory_allocated == stable &&
				len(tracking.bad_free_array) == 0,
			)
		}
	}
}

@(test)
v19_publication_scratch_does_not_accumulate_in_outer_loop_temp :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s)) {return}
		scratch: mem.Dynamic_Arena; mem.dynamic_arena_init(&scratch); defer mem.dynamic_arena_destroy(&scratch)
		tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, mem.dynamic_arena_allocator(&scratch)); defer mem.tracking_allocator_destroy(&tracking)
		old := context.temp_allocator; context.temp_allocator = mem.tracking_allocator(&tracking)
		defer {mem.free_all(context.temp_allocator); context.temp_allocator = old}
		for _ in 0 ..< 8 {testing.expect(t, app.rebuild(&s.runtime))}
		testing.expect(
			t,
			tracking.current_memory_allocated == 0,
			"publication scratch must end at publication, not accumulate until process exit",
		)
	}
}

@(test)
v19_each_snapshot_allocation_refuses_without_final_package_or_live_owners :: proc(t: ^testing.T) {
	when #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		run, e := os.make_directory_temp(
			"/tmp/opencode",
			"iv15-snapshot-alloc-*",
			context.allocator,
		)
		if !testing.expect(t, e == nil) {return}; defer delete(run)
		h := Host {
			shell   = s,
			allowed = true,
			run     = run,
		}
		tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
		fault := app.Allocation_Fault {
			backing = mem.tracking_allocator(&tracking),
		}
		a := mem.Allocator{app.refuse_allocation, &fault}
		path, error := capture_snapshot(&h, a)
		if !testing.expect(t, error == "" && path != "") {return}; delete(path, a)
		requests := fault.requests
		testing.expect(t, requests > 0 && tracking.current_memory_allocated == 0)
		for n in 1 ..= requests {
			fault.requests, fault.refuse = 0, n
			before := h.snapshot_index
			path, error = capture_snapshot(&h, a)
			testing.expect(
				t,
				error != "" && path == "" && !s.runtime.publication.ready,
				fmt.tprintf("snapshot allocation %d", n),
			)
			delete(path, a)
			if h.snapshot_index !=
			   before {testing.expect(t, !os.exists(fmt.tprintf("%s/snapshot-%d", run, h.snapshot_index)))}
			testing.expect(
				t,
				tracking.current_memory_allocated == 0 &&
				len(tracking.bad_free_array) == 0 &&
				h.native_surfaces.live == 0 &&
				h.native_surfaces.created == h.native_surfaces.destroyed,
				fmt.tprintf("snapshot cleanup %d", n),
			)
			fault.refuse = 0
			if !testing.expect(t, app.recover(s)) {return}
		}
	}
}
import "core:testing"

@(test)
v19_each_observed_capture_owner_allocation_refuses_without_leaks :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		fallback, e := os.read_entire_file(
			"resources/fallback.ttf",
			context.allocator,
		)
		if !testing.expect(t, e == nil) {return}; defer delete(fallback)
		if !app.start_page_fixture(t, &f, .Rich_Text, fallback = fallback) {return}
		s := &f.s; if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		testing.expect(
			t,
			app.begin_tool_record(s, "owned-correlation", "focus", "rich/circle", .Agent),
		)
		app.finish_tool_record(&s.runtime, "Applied")
		tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
		fault := app.Allocation_Fault {
			backing = mem.tracking_allocator(&tracking),
		}
		old := s.runtime.allocator; defer {s.runtime.allocator = old}
		s.runtime.allocator = {app.refuse_allocation, &fault}
		c: app.Page_Composition
		for text in s.runtime.live.text.text_blocks {c.texts[c.nt].id, c.texts[c.nt].text = text.node_id, text.original_text; c.nt += 1}
		g, ok := app.prepare_tools_generation(
			&s.runtime,
			&s.runtime.live,
			&c,
			s.runtime.interaction.focus_id,
		)
		if !testing.expect(t, ok) {return}
		requests := fault.requests; app.release_tools_generation(&g)
		testing.expect(t, requests > 0 && tracking.current_memory_allocated == 0)
		for n in 1 ..= requests {
			fault.requests, fault.refuse = 0, n
			g, ok = app.prepare_tools_generation(
				&s.runtime,
				&s.runtime.live,
				&c,
				s.runtime.interaction.focus_id,
			)
			testing.expect(
				t,
				!ok && g == nil,
				"capture allocation refusal must not publish partial owner",
				fmt.tprintf("%d", n),
			)
			app.release_tools_generation(&g)
			testing.expect(
				t,
				tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
				"capture cleanup",
				fmt.tprintf("%d", n),
			)
		}
	}
}

@(test)
v19_one_record_replacement_has_constant_live_ownership :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s)) {return}
		tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
		trace := s.tools.runtime.trace; trace.allocator = mem.tracking_allocator(&tracking)
		defer {app.destroy_tool_record(&trace.last, trace.allocator)
			app.destroy_tool_record(&trace.pending, trace.allocator)
			trace.allocator = s.allocator}
		stable: i64
		for i in 0 ..< 64 {
			testing.expect(
				t,
				app.begin_tool_record(s, "constant-id", "focus", "controls/checkbox", .Agent),
			)
			app.finish_tool_record(&s.runtime, "Applied")
			if i == 0 {stable = tracking.current_memory_allocated}
			testing.expect(
				t,
				stable == tracking.current_memory_allocated &&
				!trace.has_pending &&
				trace.has_last,
			)
		}
	}
}
