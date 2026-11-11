package app

import model "../model"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Atlas_File_Mutation :: struct {
	path:       string,
	called, ok: bool,
}
change_manifest :: proc(user: rawptr) {
	m := cast(^Atlas_File_Mutation)user; m.called = true; m.ok = os.write_entire_file(m.path, "{}") == nil
}
@(test)
g06_reload_recheck_failure_retains_generation_and_never_replays_count :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		1280,
		960,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	font, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(font)
	manifest, me := os.read_entire_file(
		"resources/atlas/a/manifest.json",
		context.allocator,
	); if !testing.expect(t, me == nil) {return}; defer delete(manifest)
	png, ie := os.read_entire_file(
		"resources/atlas/a/geometry.png",
		context.allocator,
	); if !testing.expect(t, ie == nil) {return}; defer delete(png)
	dir, de := os.make_directory_temp(
		"/tmp/opencode",
		"iv131-atlas-page-",
		context.allocator,
	); if !testing.expect(t, de == nil) {return}; defer delete(dir)
	path := fmt.aprintf(
		"%s/manifest.json",
		dir,
	); image := fmt.aprintf("%s/geometry.png", dir); defer delete(path); defer delete(image)
	defer {os.remove(path); os.remove(image); os.remove(dir)}
	if !testing.expect(
		t,
		os.write_entire_file(path, manifest) == nil && os.write_entire_file(image, png) == nil,
	) {return}
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	s := Shell {
		model = model.initial(),
		font_data = font,
		renderer = renderer,
		allocator = mem.tracking_allocator(&tracking),
		drawable = {1280, 960},
		sources = {assets = path, alternate_assets = path},
	}
	s.model.page = .Atlas; defer destroy_shell(&s)
	if !testing.expect(t, enter(&s)) {return}
	old := s.runtime.images
	testing.expect(t, os.write_entire_file(path, "{}") == nil)
	testing.expect(
		t,
		dispatch(&s, {.Activate, "atlas/count", .Agent, false}) &&
		s.model.atlas.count == 1 &&
		s.runtime.images == old,
	)
	testing.expect(
		t,
		!dispatch(&s, {.Activate, "atlas/reload", .Agent, false}) &&
		!s.runtime.publication.ready &&
		s.runtime.images == old,
	)
	effects := s.model.effects
	testing.expect(
		t,
		!dispatch(&s, {.Activate, "atlas/count", .Agent, false}) && s.model.atlas.count == 1,
	)
	testing.expect(t, os.write_entire_file(path, manifest) == nil)
	testing.expect(
		t,
		recover(&s) &&
		current(&s.runtime) &&
		present(&s.runtime) &&
		s.model.atlas.count == 1 &&
		s.model.effects == effects,
	)
	mutation := Atlas_File_Mutation {
		path = path,
	}; s.runtime.atlas_before_commit = change_manifest; s.runtime.atlas_test_user = &mutation
	testing.expect(
		t,
		!dispatch(&s, {.Activate, "atlas/reload", .Agent, false}) &&
		mutation.called &&
		mutation.ok &&
		!s.runtime.publication.ready,
	)
	effects = s.model.effects
	testing.expect(t, os.write_entire_file(path, manifest) == nil)
	testing.expect(
		t,
		recover(&s) &&
		current(&s.runtime) &&
		s.model.atlas.count == 1 &&
		s.model.effects == effects,
	)
	destroy_shell(&s)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
