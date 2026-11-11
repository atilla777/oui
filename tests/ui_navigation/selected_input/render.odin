package main

import "core:fmt"
import "core:strings"
import base "ui:ui_base"
import controls_sdl "ui:ui_controls/sdl"
import hold_sdl "ui:ui_hold/sdl"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import style "ui:ui_style"
import text "ui:ui_text"
import sdl "vendor:sdl3"

Render_Config :: struct {
	fault:                         Render_Fault,
	renderer:                      ^sdl.Renderer,
	font_data:                     []u8,
	font_revision, image_revision: string,
	russian:                       bool,
	font_ledger, image_ledger:     ^backend.Resource_Ledger,
}
RENDER_TEST :: #config(SELECTED_RENDER_TEST, false)
Render_Fault :: enum {
	None,
	Precommit,
	Readback,
}
render_injected :: proc(r: ^Runtime, f: Render_Fault) -> bool {when RENDER_TEST {return(
			r.render.fault ==
			f \
		)}
	return false}
readback_current :: proc(r: ^Runtime) -> (^sdl.Surface, bool) {
	if !render_current(r) {return nil, false}
	pixels, ok := backend.readback(r.render.renderer, r.reader.render.paint.drawable)
	if ok && render_injected(r, .Readback) {sdl.DestroySurface(pixels); pixels = nil; ok = false}
	if !ok {block_render(r)}; return pixels, ok
}
Render_Frame :: struct {
	samples: []base.Geometry_Entry,
	paint:   style.Frame,
	text:    text.Frame,
	images:  ^backend.Generation,
	fonts:   ^fonts.Generation,
}
destroy_render_frame :: proc(f: ^Render_Frame) {for entry in f.samples {delete(
			entry.id,
			f.paint.allocator,
		)}
	delete(f.samples, f.paint.allocator)
	style.destroy_frame(&f.paint)
	text.destroy_frame(&f.text)
	backend.release_generation(&f.images)
	fonts.release_generation(&f.fonts)
	f^ = {}}
Render_Stage :: struct {
	geometry: layout.Frame,
	frame:    Render_Frame,
}
destroy_render_stage :: proc(s: ^Render_Stage) {layout.destroy_frame(&s.geometry)
	destroy_render_frame(&s.frame)}
prepare_geometry :: proc(
	r: ^Runtime,
	nodes: []layout.Node,
	stamp: base.Frame_Stamp,
) -> (
	Render_Stage,
	bool,
) {
	s: Render_Stage; complete := false; defer {if !complete {destroy_render_stage(&s)}}
	if r.render.renderer == nil {
		g, e := layout.prepare(
			nodes,
			{drawable = {400, 300}, ui_scale = 1},
			{},
			context.allocator,
			stamp,
		); if e.code != .None {return {}, false}; s.geometry = g; complete = true; return s, true
	}
	config := r.render
	if old := r.reader.render.images;
	   old != nil && old.renderer == config.renderer && old.revision == config.image_revision {
		if !backend.retain_generation(old) {return {}, false}; s.frame.images = old
	} else {
		pixels := [4]u8 {
			240,
			240,
			240,
			255,
		}; images := [1]backend.RGBA_Image{{"tile", 1, 1, pixels[:]}}
		g, e := backend.create_generation(
			config.renderer,
			config.image_revision,
			images[:],
			context.allocator,
			config.image_ledger,
		); if e.code != .None {return {}, false}; s.frame.images = g
	}
	if old := r.reader.render.fonts;
	   old != nil && old.renderer == config.renderer && old.revision == config.font_revision {
		if !fonts.retain_generation(old) {return {}, false}; s.frame.fonts = old
	} else {
		sources := [1]fonts.Font_Source{{"fixture", 12, config.font_data}}
		g, e := fonts.create_generation(
			config.renderer,
			config.font_revision,
			sources[:],
			1,
			context.allocator,
			config.font_ledger,
		); if e.code != .None {return {}, false}; s.frame.fonts = g
	}
	label_count := 8; if r.modal {label_count = 9}
	all, e := make(
		[]layout.Node,
		len(nodes) + label_count + 1,
	); if e != nil {return {}, false}; defer delete(all); copy(all, nodes)
	ids := [9]string {
		"check-label",
		"slider-label",
		"hold-label",
		"select-label",
		"item-label",
		"a-label",
		"b-label",
		"c-label",
		"ok-label",
	}
	parents := [9]string {
		"check",
		"slider",
		"hold",
		"select",
		"pb",
		"4:list1:a",
		"4:list1:b",
		"4:list1:c",
		"ok",
	}
	for &n in all[:len(nodes)] {for parent in parents {if n.id == parent && (n.role == .Box || n.role == .Stack) {n.role = .Absolute}}}
	words := [9]string {
		"Yes",
		"Value",
		"Hold",
		"Select",
		"Item",
		"A",
		"B",
		"C",
		"OK",
	}; if config.russian {words = {"Да", "Уровень", "Удержать", "Выбор", "Элемент", "А", "Б", "В", "ОК"}}
	words[0] = "[ ] Yes"; if r.checked {words[0] = "[x] Yes"}; if config.russian {words[0] = "[ ] Да"; if r.checked {words[0] = "[x] Да"}}
	value_buffer: [64]u8; format := "Value: %d"; if config.russian {format = "Уровень: %d"}; words[1] = fmt.bprintf(value_buffer[:], format, r.value)
	labels: [9]text.Text_Node
	for id, k in ids[:label_count] {all[len(nodes) + k] = {
			id = id,
			parent = parents[k],
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 88},
				y = {mode = .Fixed, value = 24},
				offset = {4, 2},
			},
		}; labels[k] = {
			id        = id,
			text      = words[k],
			font      = {"fixture"},
			font_size = 12,
		}}
	all[len(nodes) + label_count] = {
		id = "image",
		parent = "base",
		role = .Box,
		enabled = true,
		visible = true,
		layout = layout.Layout {
			x = {mode = .Fixed, value = 40},
			y = {mode = .Fixed, value = 40},
			offset = {300, 0},
		},
	}
	tc, te := text.prepare(
		labels[:label_count],
		all,
		{drawable = {400, 300}, ui_scale = 1},
		fonts.metrics(s.frame.fonts),
		context.allocator,
		stamp,
	); if te.code != .None {fmt.eprintf("selected render text prepare: %v\n", te); return {}, false}
	s.geometry =
		tc.geometry; tc.geometry = {}; s.frame.text = tc.text; tc.text = {}; text.destroy_candidate(&tc)
	complete = true; return s, true
}
finish_render_stage :: proc(
	r: ^Runtime,
	s: ^Render_Stage,
	original, logical, final: ^layout.Frame,
	focus: string,
	samples: []base.Geometry_Entry,
) -> bool {
	if r.render.renderer == nil {return true}
	for entry in samples {v := entry.geometry; if v.opacity > 1 || !base.finite(v.offset[0]) || !base.finite(v.offset[1]) {return false}}
	for &b in s.frame.text.text_blocks {
		before, _ := layout.find(original, b.node_id); after, _ := layout.find(logical, b.node_id)
		dy := after.content.y - before.content.y; dx := after.content.x - before.content.x
		for &line in b.lines {line.logical_rect.x += dx; line.logical_rect.y += dy; line.baseline += dy}
	}
	ds, e := make(
		[]style.Description,
		len(final.nodes),
	); if e != nil {return false}; defer delete(ds)
	decls, de := make(
		[][8]style.Declaration,
		len(final.nodes),
	); if de != nil {return false}; defer delete(decls)
	for n, k in final.nodes {
		color := style.Color{0, 0, 0, 0}; switch n.description.id {case "base":
			color = {24, 32, 48, 255}; case "check":
			color = {180, 30, 30, 255}; case "slider":
			color = {20, 160, 40, 255}; case "hold":
			color = {30, 60, 180, 255}; case "list":
			color = {70, 70, 70, 255}; case "popup":
			color = {20, 60, 220, 255}; case "modal":
			color = {210, 110, 20, 255}; case "tip":
			color = {240, 220, 20, 128}}
		decls[k] = {
			{.Background, color},
			{.Foreground, style.Color{255, 255, 255, 255}},
			{.Font, style.Font_ID{"fixture"}},
			{.Font_Size, f64(12)},
			{.Focus_Color, style.Color{255, 255, 255, 255}},
			{.Focus_Width, f64(2)},
			{.Border_Width, f64(0)},
			{.Image, style.Image_Off{}},
		}
		ds[k] = {
			id   = n.description.id,
			role = "box",
		}; ds[k].appearance.local.states[.Normal] = decls[k][:]
		if n.description.id ==
		   "image" {ds[k].visual.kind = .Image; ds[k].visual.intrinsic = style.Extent{1, 1}; decls[k][7] = {.Image, style.Image_ID{"tile"}}}
		if n.description.id == focus {ds[k].states += {.Focused}}
	}
	// The selected image node and metadata use this exact retained generation.
	paint, pe := style.prepare(
		final,
		ds,
		{},
		{
			revision = r.render.image_revision,
			images = []style.Image_Metadata{{"tile", {1, 1}, nil}},
		},
		context.allocator,
	); if pe.code != .None {fmt.eprintf("selected render style prepare: %v\n", pe); return false}
	s.frame.paint = paint
	s.frame.samples, e = make([]base.Geometry_Entry, len(samples)); if e != nil {return false}
	for entry, k in samples {s.frame.samples[k].geometry = entry.geometry; s.frame.samples[k].input_enabled = entry.input_enabled; s.frame.samples[k].id, e = strings.clone(entry.id); if e != nil {return false}}
	valid :=
		backend.generation_matches(s.frame.images, &s.frame.paint) &&
		fonts.matches(s.frame.fonts, &s.frame.text, &s.frame.paint)
	if !valid {fmt.eprintf("selected render generation mismatch\n")}
	return valid
}
block_render :: proc(r: ^Runtime) {hold_sdl.block(&r.hold_input, &r.ctx); controls_sdl.block(
		&r.controls_input,
		&r.ctx,
	)}
render_current :: proc(r: ^Runtime) -> bool {
	f := &r.reader.render; renderer := r.render.renderer
	if renderer == nil ||
	   f.images == nil ||
	   f.fonts == nil ||
	   f.images.renderer != renderer ||
	   f.fonts.renderer != renderer ||
	   !base.is_current(&r.p, r.reader.geometry.stamp) ||
	   f.paint.stamp != r.reader.geometry.stamp ||
	   r.reader.layers.stamp != f.paint.stamp ||
	   !backend.generation_matches(f.images, &f.paint) ||
	   !fonts.matches(f.fonts, &f.text, &f.paint) {block_render(r); return false}
	state, saved := backend.save_renderer_state(
		renderer,
	); if !saved {block_render(r); return false}
	ok :=
		backend.pixel_coordinates(renderer) &&
		sdl.SetRenderClipRect(renderer, nil) &&
		sdl.SetRenderDrawColor(renderer, 16, 22, 31, 255) &&
		sdl.RenderClear(renderer)
	for command in r.reader.layers.paint {
		if !ok {break}
		if command.kind == .Scrim {
			area := sdl.FRect{0, 0, f32(f.paint.drawable.w), f32(f.paint.drawable.h)}
			ok =
				sdl.SetRenderClipRect(renderer, nil) &&
				sdl.SetRenderDrawBlendMode(renderer, sdl.BLENDMODE_BLEND) &&
				sdl.SetRenderDrawColor(renderer, 0, 0, 0, 128) &&
				sdl.RenderFillRect(renderer, &area); continue
		}
		if command.node_index < 0 ||
		   command.node_index >= len(r.reader.geometry.nodes) {ok = false; break}
		id := r.reader.geometry.nodes[command.node_index].description.id
		transform := base.Frozen_Geometry {
			scale   = 1,
			opacity = 1,
		}; for entry in f.samples {if entry.id == id {transform = entry.geometry}}
		if transform.scale == 0 || transform.opacity == 0 {continue}
		ok = backend.paint_node(
			f.images,
			&f.paint,
			id,
			command.kind == .Draw_Focus,
			transform.opacity,
		)
		if ok &&
		   command.kind ==
			   .Draw_Node {for b in f.text.text_blocks {if b.node_id == id {ok = fonts.render_node(f.fonts, &f.text, &f.paint, id, transform); break}}}
	}
	restored := backend.restore_renderer_state(renderer, state)
	if !ok || !restored {block_render(r); return false}; return true
}
