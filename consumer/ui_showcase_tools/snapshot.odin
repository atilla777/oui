package main

import app "../ui_showcase/app"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import linux "core:sys/linux"
import profile "profile"
import debug "ui:ui_debug"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

Identity :: struct {
	available: bool,
	revision:  string,
}
Font_Identity :: struct {
	id, revision:    string,
	size, scale:     f64,
	native_revision: u32,
}
snapshot_output_matches :: proc(
	h: ^Host,
	reader: ^app.Reader,
	window_width, window_height: i32,
) -> bool {
	s := h.shell
	if !backend.output_matches(s.renderer, reader.geometry.drawable) {return false}
	if s.window != nil {
		w, height: i32
		if !sdl.GetWindowSize(s.window, &w, &height) ||
		   w != window_width ||
		   height != window_height {return false}
		flags := sdl.GetWindowFlags(s.window)
		if .HIDDEN in flags || .MINIMIZED in flags {return false}
	}
	return(
		app.current(&s.runtime) &&
		app.reader_stamp(&s.runtime.live) == app.reader_stamp(reader) &&
		s.runtime.live.images == reader.images &&
		s.runtime.live.fonts == reader.fonts \
	)
}
capture_snapshot :: proc(h: ^Host, a: mem.Allocator) -> (path: string, error: string) {
	reader, ready := selected_reader(h)
	if !h.allowed || h.run == "" || reader == nil || !ready {return "", "Not_Ready"}
	s := h.shell
	complete := false
	defer {
		if !complete {app.block(&s.runtime)}
		if hold, selected := app.active_hold(&s.runtime); selected {hold.input.has_base = false}
		if visual, selected := app.active_transition(&s.runtime);
		   selected {visual.clock.has_base = false}
		if gesture, selected := s.runtime.content.(^app.Gesture_Page_Runtime);
		   selected {gesture.input.clock.has_base = false}
		if inventory, selected := s.runtime.content.(^app.Lab_Inventory_Runtime);
		   selected {inventory.input.clock.has_base = false}
		if editor, selected := app.active_name(&s.runtime); selected {editor.has_clock = false}
	}
	fault := ""; when #config(UI_DEMO_TEST, false) {fault = h.snapshot_fault}
	stamp := app.reader_stamp(reader)
	if reader.tools.inspection.frame.stamp != stamp ||
	   reader.tools.inspection.model_revision !=
		   stamp.model_revision {return "", "Metadata_Mismatch"}
	if fault == "capture" {return "", "Allocation"}
	if fault == "copy" {return "", "Allocation"}
	frozen, copied := app.copy_reader(reader, a)
	if !copied {return "", "Allocation"}; defer app.destroy_reader(&frozen)
	if fault == "generation" ||
	   frozen.images == nil ||
	   frozen.fonts == nil ||
	   frozen.images.renderer != s.renderer ||
	   frozen.fonts.renderer != s.renderer ||
	   sdl.GetRenderTarget(s.renderer) != nil ||
	   !app.selected_reader_matches(&frozen) {return "", "Generation_Mismatch"}
	window_width, window_height: i32
	if s.window != nil &&
	   !sdl.GetWindowSize(s.window, &window_width, &window_height) {return "", "Resize_Mismatch"}
	if fault == "size" ||
	   !snapshot_output_matches(
			   h,
			   &frozen,
			   window_width,
			   window_height,
		   ) {return "", "Resize_Mismatch"}
	saved, state_ok := backend.save_renderer_state(s.renderer)
	if !state_ok {return "", "Restore_Failed"}
	restored := false
	defer {if !restored &&
		   !backend.restore_renderer_state(s.renderer, saved) {error = "Restore_Failed"}}
	if fault == "render" || !app.draw_reader(&frozen) {return "", "Render_Failed"}
	if fault == "readback" ||
	   !backend.pixel_coordinates(s.renderer) ||
	   !sdl.SetRenderClipRect(s.renderer, nil) {return "", "Readback_Failed"}
	pixels := sdl.RenderReadPixels(s.renderer, nil)
	if pixels == nil {return "", "Readback_Failed"}; defer sdl.DestroySurface(pixels)
	if !backend.resource_can_acquire(&h.native_surfaces) {return "", "Exhausted"}
	backend.resource_acquired(
		&h.native_surfaces,
	); defer backend.resource_released(&h.native_surfaces)
	if f64(pixels.w) != frozen.geometry.drawable.w ||
	   f64(pixels.h) != frozen.geometry.drawable.h ||
	   !snapshot_output_matches(
			   h,
			   &frozen,
			   window_width,
			   window_height,
		   ) {return "", "Resize_Mismatch"}
	if fault == "present" || !sdl.RenderPresent(s.renderer) {return "", "Present_Failed"}
	if !snapshot_output_matches(
		h,
		&frozen,
		window_width,
		window_height,
	) {return "", "Resize_Mismatch"}
	if fault == "restore" ||
	   !backend.restore_renderer_state(s.renderer, saved) {return "", "Restore_Failed"}
	restored = true
	nodes := make([]Node, len(frozen.geometry.nodes), context.temp_allocator)
	for node, index in frozen.geometry.nodes {nodes[index], _ = node_projection(&frozen, true, node.description.id)}
	font_ids := make([]Font_Identity, len(frozen.fonts.fonts), context.temp_allocator)
	for font, index in frozen.fonts.fonts {font_ids[index] = {font.id, font.revision, font.size, font.scale, font.native_revision}}
	rich, painters := Identity{}, Identity{}
	if v, selected := frozen.content.(app.Rich_Page_Reader);
	   selected {rich = {v.fonts != nil, v.fonts.revision}; painters = {v.painters != nil, v.painters.revision}}
	if v, selected := frozen.content.(app.Custom_Page_Reader);
	   selected {painters = {v.painters != nil, v.painters.revision}}
	if v, selected := frozen.content.(app.Accessibility_Page_Reader);
	   selected {painters = {v.painters != nil, v.painters.revision}}
	window := struct {
		available: bool,
		w, h:      i32,
	}{s.window != nil, window_width, window_height}
	ratio := struct {
		available: bool,
		x, y:      f64,
	}{}
	if window_width > 0 &&
	   window_height >
		   0 {ratio = {true, frozen.geometry.drawable.w / f64(window_width), frozen.geometry.drawable.h / f64(window_height)}}
	if fault == "encode" {return "", "Encoding_Failed"}
	manifest := debug.encode_object(
		[]debug.Object_Field {
			{"profile", "showcase-v19"},
			{"protocol", 19},
			{"section", frozen.tools.observation.selected_section},
			{"screen_epoch", frozen.tools.screen_epoch},
			{"frame_id", stamp.attempt},
			{"model_revision", stamp.model_revision},
			{"published_revision", stamp.model_revision},
			{"build_revision", #config(UI_BUILD_REVISION, "unknown")},
			{"build_dirty", #config(UI_BUILD_DIRTY, true)},
			{"backend", string(sdl.GetRendererName(s.renderer))},
			{"locale", frozen.tools.observation.locale},
			{"window", window},
			{"drawable", frozen.geometry.drawable},
			{"window_to_drawable", ratio},
			{"scale", frozen.geometry.ui_scale},
			{"pixel_perfect", frozen.tools.observation.pixel_perfect},
			{"resources", Identity{true, frozen.images.revision}},
			{"theme", Identity{frozen.paint.theme_revision != "", frozen.paint.theme_revision}},
			{"fonts", font_ids},
			{"rich_fonts", rich},
			{"painters", painters},
			{"clock", struct {
					mode:      string,
					sample_ms: i64,
				}{"test-time" if h.test_time else "interactive", frozen.tools.sample_ms}},
			{"nodes", nodes},
			{"diagnostics", frozen.tools.inspection.diagnostics},
			{"observation", frozen.tools.observation},
		},
		a,
	)
	if manifest == nil {return "", "Encoding_Failed"}; defer delete(manifest, a)
	if len(manifest) + 1 > profile.MESSAGE_LIMIT {return "", "Message_Too_Large"}
	if h.snapshot_index == max(u64) {return "", "Exhausted"}; h.snapshot_index += 1
	staging, io_error := os.make_directory_temp(h.run, ".incomplete-*", a)
	if io_error != nil {return "", "IO_Failed"}; defer delete(staging, a)
	if os.chmod(staging, {.Read_User, .Write_User, .Execute_User}) != nil {return "", "IO_Failed"}
	image_path := fmt.tprintf("%s/screenshot.bmp", staging)
	if fault == "write" ||
	   !sdl.SaveBMP(pixels, strings.clone_to_cstring(image_path, context.temp_allocator)) ||
	   os.chmod(image_path, {.Read_User, .Write_User}) != nil ||
	   os.write_entire_file(
		   fmt.tprintf("%s/snapshot.json", staging),
		   manifest,
		   {.Read_User, .Write_User},
	   ) !=
		   nil {return "", "IO_Failed"}
	final, allocation := strings.clone(fmt.tprintf("%s/snapshot-%d", h.run, h.snapshot_index), a)
	if allocation != nil {return "", "Allocation"}
	if fault == "rename" ||
	   linux.renameat2(
		   linux.AT_FDCWD,
		   strings.clone_to_cstring(staging, context.temp_allocator),
		   linux.AT_FDCWD,
		   strings.clone_to_cstring(final, context.temp_allocator),
		   {.NOREPLACE},
	   ) !=
		   .NONE {delete(final, a); return "", "IO_Failed"}
	complete = true; return final, ""
}
