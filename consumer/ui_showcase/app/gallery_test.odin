package app

import model "../model"
import "core:os"
import "core:testing"
import controls "ui:ui_controls"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
g01_catalogue_exposes_frozen_metadata :: proc(t: ^testing.T) {
	m := model.initial(); m.locale = .English; c: Page_Composition; defer destroy_composition(&c)
	testing.expect(t, compose_page(&c, m, context.allocator))
	status, limitation := false, false
	for txt in c.texts[:c.nt] {
		if txt.text == "experimental" {status = true}
		if txt.text == model.SECTIONS[0].limitations {limitation = true}
	}
	testing.expect(t, status && limitation)
}

@(test)
g04_profile_page_has_controlled_workflow :: proc(t: ^testing.T) {
	m := model.initial(); m.page = .Profiles
	c: Page_Composition; defer destroy_composition(&c)
	testing.expect(t, compose_page(&c, m, context.allocator))
	for id in ([]string{"profiles/list", "profiles/tabs", "profiles/mode", "profiles/apply", "profiles/cancel", "profiles/reset"}) {
		found := false
		for n in c.nodes[:c.n] {if n.id == id {found = true}}
		testing.expect(t, found, id)
	}
}

@(test)
g04_native_publisher_profile_apply_cancel :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		1280,
		960,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	s := Shell {
		model     = model.initial(),
		font_data = data,
		renderer  = renderer,
		allocator = context.allocator,
		drawable  = {1280, 960},
	}
	s.model.page = .Profiles
	defer destroy_shell(&s)
	if !testing.expect(t, enter(&s)) {return}
	testing.expect(t, present(&s.runtime))
	before := s.model.profiles.draft.show_help
	testing.expect(t, dispatch(&s, {.Activate, "profiles/help", .Agent, false}))
	testing.expect(t, s.model.profiles.draft.show_help != before)
	testing.expect(t, dispatch(&s, {.Activate, "profiles/cancel", .Agent, false}))
	testing.expect(t, s.model.profiles.draft.show_help == before)
	testing.expect(t, dispatch(&s, {.Activate, "profiles/help", .Agent, false}))
	testing.expect(t, dispatch(&s, {.Activate, "profiles/apply", .Agent, false}))
	testing.expect(t, s.model.profiles.applied[0].show_help != before)
	testing.expect(t, dispatch(&s, {.Activate, "profiles/help", .Agent, false}))
	to_b, ok := controls.item_node_id(
		"profiles/list",
		"borealis",
		context.allocator,
	); if !testing.expect(t, ok) {return}; defer delete(to_b)
	testing.expect(t, dispatch(&s, {.Activate, to_b, .Agent, false}))
	testing.expect(t, s.model.profiles.dialog == .Dirty_Departure)
	testing.expect(t, s.runtime.interaction.focus_id != "profiles/help")
	revision := s.model.revision
	testing.expect(
		t,
		!dispatch(&s, {.Activate, "shell/catalogue", .Agent, false}) &&
		s.model.revision == revision,
	)
	testing.expect(t, dispatch(&s, {.Cancel, "", .Agent, false}))
	testing.expect(t, s.model.profiles.dialog == .None && s.model.profiles.selected_id == "aurora")
	first, first_ok := controls.item_node_id(
		"profiles/list",
		"aurora",
		context.allocator,
	); if !testing.expect(t, first_ok) {return}; defer delete(first)
	testing.expect(t, dispatch(&s, {.Focus, first, .Agent, false}))
	s.input.window_id = 17; event: sdl.Event; event.key = {
		type     = .KEY_DOWN,
		windowID = 17,
		key      = sdl.K_DOWN,
	}
	effects := s.model.effects
	testing.expect(t, handle_input(&s, event, {1280, 960}))
	testing.expect(
		t,
		s.runtime.interaction.focus_id == to_b &&
		s.model.profiles.selected_id == "aurora" &&
		s.model.effects == effects,
	)
	testing.expect(t, dispatch(&s, {.Activate, "profiles/cancel", .Agent, false}))
	testing.expect(t, dispatch(&s, {.Focus, "profiles/intensity", .Agent, false}))
	testing.expect(t, len(s.runtime.live.layers.layers.tooltips) == 1 && present(&s.runtime))
	appearance, appearance_ok := controls.item_node_id(
		"profiles/tabs",
		"appearance",
		context.allocator,
	); if !testing.expect(t, appearance_ok) {return}; defer delete(appearance)
	testing.expect(t, dispatch(&s, {.Activate, appearance, .Agent, false}))
	testing.expect(
		t,
		dispatch(&s, {.Activate, "profiles/mode", .Agent, false}) && s.runtime.select_open,
	)
	effects = s.model.effects
	testing.expect(
		t,
		dispatch(&s, {.Cancel, "", .Agent, false}) &&
		!s.runtime.select_open &&
		s.model.profiles.dialog == .None &&
		s.model.effects == effects,
	)
	testing.expect(
		t,
		dispatch(&s, {.Activate, "profiles/reset", .Agent, false}) &&
		s.model.profiles.dialog == .Reset,
	)
	testing.expect(
		t,
		dispatch(&s, {.Cancel, "", .Agent, false}) && s.model.profiles.dialog == .None,
	)
	general, general_ok := controls.item_node_id(
		"profiles/tabs",
		"general",
		context.allocator,
	); if !testing.expect(t, general_ok) {return}; defer delete(general)
	testing.expect(t, dispatch(&s, {.Activate, general, .Agent, false}))
	testing.expect(t, dispatch(&s, {.Activate, "profiles/help", .Agent, false}))
	testing.expect(
		t,
		dispatch(&s, {.Activate, to_b, .Agent, false}) &&
		s.model.profiles.dialog == .Dirty_Departure,
	)
	apply_go, apply_ok := controls.item_node_id(
		"profiles/dialog",
		"apply-and-go",
		context.allocator,
	); if !testing.expect(t, apply_ok) {return}; defer delete(apply_go)
	testing.expect(
		t,
		dispatch(&s, {.Activate, apply_go, .Agent, false}) &&
		s.model.profiles.selected_id == "borealis" &&
		s.model.profiles.dialog == .None,
	)
	testing.expect(t, dispatch(&s, {.Activate, "profiles/help", .Agent, false}))
	testing.expect(
		t,
		dispatch(&s, {.Activate, first, .Agent, false}) &&
		s.model.profiles.dialog == .Dirty_Departure,
	)
	discard_go, discard_ok := controls.item_node_id(
		"profiles/dialog",
		"discard-and-go",
		context.allocator,
	); if !testing.expect(t, discard_ok) {return}; defer delete(discard_go)
	testing.expect(
		t,
		dispatch(&s, {.Activate, discard_go, .Agent, false}) &&
		s.model.profiles.selected_id == "aurora" &&
		s.model.profiles.dialog == .None &&
		current(&s.runtime) &&
		present(&s.runtime),
	)
}
