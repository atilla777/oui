package main

import app "../ui_showcase/app"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"

_ :: app.Shell
_ :: json.unmarshal
_ :: fmt.tprintf
_ :: os.exists
_ :: strings.contains
_ :: sdl.Event

@(test)
snapshot_is_actual_atomic_bmp_json_and_cannot_overwrite_a_destination :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}
		s := &f.s; s.runtime.tools_state.enabled = true
		if !testing.expect(t, app.rebuild(&s.runtime)) {return}
		run, e := os.make_directory_temp("/tmp/opencode", "iv15-snapshot-*", context.allocator)
		if !testing.expect(t, e == nil) {return}; defer delete(run)
		h := Host {
			shell   = s,
			allowed = true,
			run     = run,
		}
		stamp := app.reader_stamp(
			&s.runtime.live,
		); effects := s.model.effects; focus := s.runtime.interaction.focus_id
		data := handle_line(
			&h,
			request_bytes(`{"protocol":19,"request_id":"pixels","op":"snapshot"}`),
			context.allocator,
		)
		defer delete(data)
		Result :: struct {
			ok:     bool,
			result: struct {
				path, manifest, image: string,
			},
		}
		r: Result; je := json.unmarshal(data, &r, allocator = context.temp_allocator)
		if !testing.expect(
			t,
			je == nil &&
			r.ok &&
			r.result.manifest == "snapshot.json" &&
			r.result.image == "screenshot.bmp",
			string(data),
		) {return}
		manifest, me := os.read_entire_file(
			fmt.tprintf("%s/snapshot.json", r.result.path),
			context.allocator,
		); defer delete(manifest)
		bmp, be := os.read_entire_file(
			fmt.tprintf("%s/screenshot.bmp", r.result.path),
			context.allocator,
		); defer delete(bmp)
		testing.expect(
			t,
			me == nil && be == nil && len(bmp) > 54 && bmp[0] == 'B' && bmp[1] == 'M',
		)
		image := sdl.LoadBMP(
			strings.clone_to_cstring(
				fmt.tprintf("%s/screenshot.bmp", r.result.path),
				context.temp_allocator,
			),
		)
		if testing.expect(
			t,
			image != nil,
		) {testing.expect(t, image.w == 1280 && image.h == 960); sdl.DestroySurface(image)}
		testing.expect(
			t,
			strings.contains(string(manifest), `"section":"controls"`) &&
			strings.contains(string(manifest), fmt.tprintf(`%s%d`, `"frame_id":`, stamp.attempt)),
			string(manifest),
		)
		testing.expect(
			t,
			s.model.effects == effects &&
			app.reader_stamp(&s.runtime.live) == stamp &&
			s.runtime.interaction.focus_id == focus,
		)
		testing.expect(
			t,
			h.native_surfaces.created == 1 &&
			h.native_surfaces.destroyed == 1 &&
			h.native_surfaces.live == 0,
			"native readback surface must be accounted and released",
		)
	}
}
