package main

import "core:fmt"
import "core:mem"
import model "model"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import style "ui:ui_style"
import text "ui:ui_text"
import sdl "vendor:sdl3"

TEST :: #config(STANDALONE_MENU_TEST, false)
Fault :: enum {
	None,
	Prepare,
	Resource,
	Copy,
	Publish,
	Render,
	Readback,
	Present,
}
Reader :: struct {
	geometry:    layout.Frame,
	interaction: interaction.Frame,
	text:        text.Frame,
	paint:       style.Frame,
	images:      ^backend.Generation,
	fonts:       ^fonts.Generation,
}
Runtime :: struct {
	model:                   model.Model,
	publication:             base.Publication,
	interaction:             interaction.Context,
	input:                   backend.Input,
	live:                    Reader,
	images:                  ^backend.Generation,
	fonts:                   ^fonts.Generation,
	allocator:               mem.Allocator,
	renderer:                ^sdl.Renderer,
	drawable:                base.Extent,
	scale:                   f64,
	rebuilds, last_sequence: u64,
	error:                   Fault,
	fault:                   Fault, // Only read inside compile-time TEST branches; no release setter.
}
init :: proc(
	r: ^Runtime,
	renderer: ^sdl.Renderer,
	data: []u8,
	scale: f64,
	a: mem.Allocator,
	ledger: ^backend.Resource_Ledger = nil,
) -> bool {
	r.allocator, r.renderer, r.scale = a, renderer, scale
	p, e := base.create(a); if e != .None {return false}; r.publication = p
	r.interaction = interaction.create(a, &r.publication)
	complete := false; defer {if !complete {destroy(r)}}
	images, ie := backend.create_generation(
		renderer,
		"images-1",
		nil,
		a,
		ledger,
	); if ie.code != .None {return false}; r.images = images
	sources := [1]fonts.Font_Source{{"own", 16, data}}
	f, fe := fonts.create_generation(
		renderer,
		"font-1",
		sources[:],
		scale,
		a,
		ledger,
	); if fe.code != .None {return false}; r.fonts = f
	complete = true; return true
}
destroy_reader :: proc(reader: ^Reader) {
	layout.destroy_frame(&reader.geometry); interaction.destroy_frame(&reader.interaction)
	text.destroy_frame(&reader.text); style.destroy_frame(&reader.paint)
	backend.release_generation(
		&reader.images,
	); fonts.release_generation(&reader.fonts); reader^ = {}
}
destroy :: proc(r: ^Runtime) {
	backend.close_input(&r.input); destroy_reader(&r.live)
	fonts.release_generation(&r.fonts); backend.release_generation(&r.images)
	interaction.destroy(&r.interaction); base.destroy(&r.publication); r^ = {}
}
copy_reader :: proc(source: ^Reader, a: mem.Allocator) -> (Reader, bool) {
	copy: Reader; complete := false; defer {if !complete {destroy_reader(&copy)}}
	ok: bool
	copy.geometry, ok = layout.try_copy_frame(&source.geometry, a); if !ok {return {}, false}
	copy.interaction, ok = interaction.try_copy_frame(
		&source.interaction,
		a,
	); if !ok {return {}, false}
	copy.text, ok = text.try_copy_frame(&source.text, a); if !ok {return {}, false}
	copy.paint, ok = style.try_copy_frame(&source.paint, a); if !ok {return {}, false}
	if !backend.retain_generation(source.images) {return {}, false}; copy.images = source.images
	if !fonts.retain_generation(source.fonts) {return {}, false}; copy.fonts = source.fonts
	complete = true; return copy, true
}
rebuild :: proc(r: ^Runtime) -> bool {
	r.error = .Prepare
	stamp, begin := base.begin_attempt(
		&r.publication,
		r.model.revision,
	); if begin != .None {return false}
	complete := false; defer {if !complete {interaction.cancel_press(&r.interaction)}}
	if r.rebuilds == max(u64) {return false}
	if injected(r, .Prepare) {return false}
	font_candidate := r.fonts
	if r.fonts.scale != r.scale {
		source := r.fonts.fonts[0]
		sources := [1]fonts.Font_Source{{source.id, source.size, source.data}}
		f, e := fonts.create_generation(
			r.renderer,
			"font-1",
			sources[:],
			r.scale,
			r.allocator,
			r.fonts.ledger,
		)
		if e.code != .None {r.error = .Resource; return false}; font_candidate = f
	} else if !fonts.retain_generation(font_candidate) {r.error = .Resource; return false}
	defer fonts.release_generation(&font_candidate)
	if injected(r, .Resource) {r.error = .Resource; return false}
	words := EN; if r.model.locale == .Russian {words = RU}
	first, second := "action", "open"
	title, first_label, second_label := words.main, words.action, words.open
	if r.model.page ==
	   .Submenu {first, second = "language", "back"; title, first_label, second_label = words.submenu, words.language, words.back}
	focus := r.interaction.focus_id
	if focus != first && focus != second {focus = first}
	buffer: [96]u8
	count := fmt.bprintf(buffer[:], words.counter, r.model.count)
	nodes := [7]layout.Node {
		{
			id = "root",
			role = .Column,
			layout = layout.Layout {
				x = {mode = .Fill},
				y = {mode = .Fill},
				padding = {8, 8, 8, 8},
				gap = 6,
			},
			enabled = true,
			visible = true,
		},
		{
			id = "title",
			parent = "root",
			role = .Content,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fixed, value = 22}},
			enabled = true,
			visible = true,
		},
		{
			id = "count",
			parent = "root",
			role = .Content,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fixed, value = 20}},
			enabled = true,
			visible = true,
		},
		{
			id = first,
			parent = "root",
			role = .Stack,
			layout = layout.Layout {
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 32},
				padding = {6, 3, 6, 3},
			},
			enabled = true,
			visible = true,
		},
		{
			id = "first-label",
			parent = first,
			role = .Content,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
			enabled = true,
			visible = true,
		},
		{
			id = second,
			parent = "root",
			role = .Stack,
			layout = layout.Layout {
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 32},
				padding = {6, 3, 6, 3},
			},
			enabled = true,
			visible = true,
		},
		{
			id = "second-label",
			parent = second,
			role = .Content,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
			enabled = true,
			visible = true,
		},
	}
	labels := [4]text.Text_Node {
		{"title", title, {"own"}, 16, {vertical = .Center}},
		{"count", count, {"own"}, 16, {vertical = .Center}},
		{"first-label", first_label, {"own"}, 16, {horizontal = .Center, vertical = .Center}},
		{"second-label", second_label, {"own"}, 16, {horizontal = .Center, vertical = .Center}},
	}
	c, ce := text.prepare(
		labels[:],
		nodes[:],
		{drawable = r.drawable, ui_scale = r.scale},
		fonts.metrics(font_candidate),
		r.allocator,
		stamp,
	)
	if ce.code !=
	   .None {fmt.eprintf("text prepare: %v\n", ce); return false}; defer text.destroy_candidate(&c)
	targets := [2]interaction.Target{{first, "button", true, true}, {second, "button", true, true}}
	ic, ie := interaction.prepare(&c.geometry, targets[:], nil, r.allocator)
	if ie != .Applied {return false}; defer interaction.destroy_candidate(&ic)
	ds: [7]style.Description
	plain := [4]style.Declaration {
		{.Background, style.Color{0, 0, 0, 0}},
		{.Border_Width, f64(0)},
		{.Font, style.Font_ID{"own"}},
		{.Font_Size, f64(16)},
	}
	button := [4]style.Declaration {
		{.Background, style.Color{35, 66, 96, 255}},
		{.Border, style.Color{155, 185, 210, 255}},
		{.Focus_Color, style.Color{255, 218, 110, 255}},
		{.Focus_Width, f64(3)},
	}
	for n, i in nodes {
		ds[i] = {
			id   = n.id,
			role = "plain",
		}
		ds[i].appearance.local.states[.Normal] = plain[:]
		if n.id == first || n.id == second {
			ds[i].role = "button"; ds[i].appearance.local.states[.Normal] = button[:]
			if n.id == focus {ds[i].states += {.Focused}}
			if n.id == r.interaction.hover_id {ds[i].states += {.Hovered}}
			if n.id == r.interaction.pressed_id {ds[i].states += {.Pressed}}
		}
	}
	paint, pe := style.prepare(
		&c.geometry,
		ds[:],
		{revision = "menu-theme-1"},
		{revision = r.images.revision},
		r.allocator,
	)
	if pe.code !=
	   .None {fmt.eprintf("style prepare: %v\n", pe); return false}; defer style.destroy_frame(&paint)
	r.error = .Publish
	if !text.validate_candidate(&r.publication, &c) ||
	   r.images.renderer != r.renderer ||
	   font_candidate.renderer != r.renderer ||
	   !interaction.validate_candidate(&r.publication, &ic) ||
	   !style.validate_candidate(&r.publication, &paint) ||
	   !backend.generation_matches(r.images, &paint) ||
	   !fonts.matches(font_candidate, &c.text, &paint) {return false}
	source := Reader{c.geometry, ic, c.text, paint, r.images, font_candidate} // Borrowed composite; never destroy source.
	r.error = .Copy
	if injected(r, .Copy) {return false}
	reader, copied := copy_reader(
		&source,
		r.allocator,
	); if !copied {return false}; defer destroy_reader(&reader)
	r.error = .Publish
	if injected(r, .Publish) {return false}
	if r.model.revision != stamp.model_revision ||
	   base.enter_commit(&r.publication, stamp) != .None {return false}
	// All fallible work is complete. Only infallible ownership swaps follow.
	old, old_fonts := r.live, r.fonts
	r.live = reader; reader = {}
	r.fonts = font_candidate; font_candidate = nil
	interaction.commit(&r.interaction, &ic, first)
	base.finish_commit(&r.publication, stamp)
	r.rebuilds += 1; r.error = .None; complete = true
	interaction.reconcile_registrations(&r.interaction)
	destroy_reader(&old); fonts.release_generation(&old_fonts)
	return true
}
accept :: proc(r: ^Runtime, event: interaction.Button_Activated) -> bool {
	if event.sequence == 0 ||
	   event.sequence != r.publication.sequence ||
	   event.sequence <= r.last_sequence {return false}
	r.last_sequence = event.sequence
	intent: model.Intent
	switch event.id {
	case "action":
		intent = .Action
	case "open":
		intent = .Open
	case "language":
		intent = .Language
	case "back":
		intent = .Back
	case:
		return false
	}
	return model.apply(&r.model, intent)
}
draw_reader :: proc(reader: ^Reader) -> bool {
	return(
		backend.render(reader.images, &reader.paint) &&
		fonts.render(reader.fonts, &reader.text, &reader.paint) \
	)
}
present :: proc(r: ^Runtime) -> bool {
	if !base.is_current(&r.publication, r.live.text.stamp) {return false}
	complete := false
	defer {if !complete {base.invalidate(&r.publication); interaction.cancel_press(&r.interaction)}}
	r.error = .Render
	if injected(r, .Render) {return false}
	if !draw_reader(&r.live) {return false}
	r.error = .Readback
	if injected(r, .Readback) {return false}
	pixels, read := backend.readback(r.renderer, r.drawable)
	if !read {return false}; defer sdl.DestroySurface(pixels)
	r.error = .Present
	if injected(r, .Present) {return false}
	if !sdl.RenderPresent(r.renderer) {return false}
	r.error = .None; complete = true; return true
}

injected :: proc(r: ^Runtime, stage: Fault) -> bool {
	when TEST {if r.fault == stage {r.fault = .None; return true}}
	return false
}
handle_input :: proc(r: ^Runtime, event: sdl.Event, window: base.Extent) -> bool {
	was_ready := interaction.ready(&r.interaction)
	result := backend.input_event(&r.input, &r.interaction, event, window)
	if result.dispatch.has_event {accept(r, result.dispatch.event)}
	// A failed attempt is not retried by arbitrary native input. R is host recovery.
	if was_ready && !interaction.ready(&r.interaction) {return rebuild(r)}
	return true
}
