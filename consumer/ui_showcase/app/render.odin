package app

import "core:math"
import base "ui:ui_base"
import painter "ui:ui_custom/sdl"
import editor_sdl "ui:ui_editor/sdl"
import layout "ui:ui_layout"
import rich_fonts "ui:ui_rich/sdl"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import transitions "ui:ui_transitions"
import sdl "vendor:sdl3"

draw_node :: proc(reader: ^Reader, id: string) -> bool {
	if !draw_leaf(reader, id) {return false}
	for n in reader.geometry.nodes {if n.description.parent == id {if !draw_node(reader, n.description.id) {return false}}}
	return backend.paint_node(
		reader.images,
		&reader.paint,
		id,
		true,
		frozen_geometry(reader, id).opacity,
	)
}
frozen_geometry :: proc(reader: ^Reader, id: string) -> base.Frozen_Geometry {
	if v, selected := reader.content.(Rich_Page_Reader);
	   selected {g, found := transitions.geometry(&v.visual, id); if found {return g}}
	if a, selected := reader.content.(Accessibility_Page_Reader);
	   selected {g, found := transitions.geometry(&a.visual, id); if found {return g}}
	if v, selected := reader.content.(Transition_Page_Reader);
	   selected {g, found := transitions.geometry(&v.frame, id); if found {return g}}
	return {scale = 1, opacity = 1}
}
draw_leaf :: proc(reader: ^Reader, id: string) -> bool {
	// Specialized painters (notably the editor) do not all consult layout
	// visibility themselves. The shared owning geometry remains authoritative.
	visible_node, has_node := layout.find(&reader.geometry, id)
	if !has_node {return false}
	if !visible_node.visible {return true}
	if a, selected := reader.content.(Accessibility_Page_Reader); selected && a.c08 != nil {
		if id ==
		   "accessibility/c08-rich" {return rich_fonts.render_node(a.c08.fonts, &a.c08.rich, &reader.paint, id)}
		if id ==
		   "accessibility/c08-value" {return editor_sdl.render(reader.fonts, &a.c08.editor, "")}
	}
	if v, selected := reader.content.(Rich_Page_Reader);
	   selected &&
	   id ==
		   "rich/circle" {return painter.render_node(v.painters, &v.custom, &reader.paint, id).code == .None}
	if a, selected := reader.content.(Accessibility_Page_Reader);
	   selected &&
	   id ==
		   "accessibility/unknown" {return painter.render_node(a.painters, &a.custom, &reader.paint, id).code == .None}
	transform := frozen_geometry(reader, id)
	if transform.scale == 0 || transform.opacity == 0 {return true}
	if !backend.paint_node(
		reader.images,
		&reader.paint,
		id,
		opacity = transform.opacity,
	) {return false}
	if c, ok := reader.content.(Custom_Page_Reader);
	   ok {for v in c.frame.views {if v.node_id == id {return painter.render_node(c.painters, &c.frame, &reader.paint, id).code == .None}}}
	if h, ok := reader.content.(Hold_Page_Reader); ok {
		for p in h.frame.progress {if p.id == id {
				renderer := reader.images.renderer
				saved, valid := backend.save_renderer_state(renderer); if !valid {return false}
				n, found := layout.find(&reader.geometry, id); if !found {return false}
				scale := reader.geometry.ui_scale; clip := n.paint_clip
				physical := sdl.Rect {
					i32(math.floor(clip.x * scale)),
					i32(math.floor(clip.y * scale)),
					i32(math.ceil(clip.w * scale)),
					i32(math.ceil(clip.h * scale)),
				}
				rect := sdl.FRect {
					f32(p.fill.x * scale),
					f32(p.fill.y * scale),
					f32(p.fill.w * scale),
					f32(p.fill.h * scale),
				}
				painted :=
					sdl.SetRenderClipRect(renderer, &physical) &&
					sdl.SetRenderDrawColor(renderer, 65, 180, 120, 255) &&
					sdl.RenderFillRect(renderer, &rect)
				return backend.restore_renderer_state(renderer, saved) && painted
			}}
	}
	if n, ok := reader.content.(Name_Page_Reader); ok {
		if id == "name/value" {
			focus := ""; if n.focused {focus = "name/field"}
			return editor_sdl.render(reader.fonts, &n.frame, focus)
		}
	}
	if g, ok := reader.content.(Gesture_Page_Reader); ok {
		if id ==
		   "name/value" {focus := ""; if g.editing.focused {focus = "name/field"}; return editor_sdl.render(reader.fonts, &g.editing.frame, focus)}
	}
	if p, selected := reader.content.(Performance_Page_Reader); selected && id == "name/value" {
		focus := ""; if p.editing.focused {focus = "name/field"}; return editor_sdl.render(reader.fonts, &p.editing.frame, focus)
	}
	if content, ok := reader.content.(Rich_Page_Reader); ok {
		for block in content.frame.rich_blocks {if block.node_id == id {return rich_fonts.render_node(content.fonts, &content.frame, &reader.paint, id)}}
	} else {for b in reader.text.text_blocks {if b.node_id == id {return fonts.render_node(reader.fonts, &reader.text, &reader.paint, id, transform)}}}
	return true
}
draw_reader :: proc(reader: ^Reader) -> bool {
	if !selected_reader_matches(reader) {return false}
	text_matches := fonts.matches(reader.fonts, &reader.text, &reader.paint)
	if content, selected := reader.content.(Rich_Page_Reader);
	   selected {text_matches = rich_fonts.matches(content.fonts, &content.frame, &reader.paint)}
	if !backend.generation_matches(reader.images, &reader.paint) ||
	   !text_matches ||
	   reader.geometry.stamp != reader.paint.stamp ||
	   reader.interaction.stamp != reader.paint.stamp {return false}
	r := reader.images.renderer
	state, saved := backend.save_renderer_state(r); if !saved {return false}
	ok :=
		backend.pixel_coordinates(r) &&
		sdl.SetRenderClipRect(r, nil) &&
		sdl.SetRenderDrawColor(r, 16, 22, 31, 255) &&
		sdl.RenderClear(r)
	if ok {
		if reader.layers.stamp.lifetime != nil {
			for command in reader.layers.paint {
				switch command.kind {
				case .Draw_Node:
					ok = draw_leaf(
						reader,
						reader.geometry.nodes[command.node_index].description.id,
					)
				case .Draw_Focus:
					ok = backend.paint_node(
						reader.images,
						&reader.paint,
						reader.geometry.nodes[command.node_index].description.id,
						true,
					)
				case .Scrim:
					ok =
						sdl.SetRenderClipRect(r, nil) &&
						sdl.SetRenderDrawBlendMode(r, sdl.BLENDMODE_BLEND) &&
						sdl.SetRenderDrawColor(r, 0, 0, 0, 120) &&
						sdl.RenderFillRect(r, nil)
				}
				if !ok {break}
			}
		} else {for n in reader.geometry.nodes {if n.description.parent == "" {ok = draw_node(reader, n.description.id); break}}}
	}
	if g, selected := reader.content.(Gesture_Page_Reader); selected && ok {
		live := g.frame.live
		if live.phase == .Active && live.owner.kind == .Drag_Source {
			point := live.current
			if live.source !=
			   .Mouse {for v in g.frame.gestures {if v.id == live.owner.id {point = {v.geometry.bounds.x + v.geometry.bounds.w / 2, v.geometry.bounds.y + v.geometry.bounds.h / 2}; break}}}
			scale := reader.geometry.ui_scale
			preview := sdl.FRect {
				f32((point[0] - 48) * scale),
				f32((point[1] - 16) * scale),
				f32(96 * scale),
				f32(32 * scale),
			}
			marker := sdl.FRect {
				f32((point[0] - 3) * scale),
				f32((point[1] - 3) * scale),
				f32(6 * scale),
				f32(6 * scale),
			}
			ok =
				sdl.SetRenderClipRect(r, nil) &&
				sdl.SetRenderDrawColor(r, 255, 218, 110, 255) &&
				sdl.RenderRect(r, &preview) &&
				sdl.RenderFillRect(r, &marker)
		}
	}
	restored := backend.restore_renderer_state(r, state); return ok && restored
}
present :: proc(r: ^Runtime) -> bool {
	if !current(r) {if r.model != nil {block(r)}; return false}
	complete := false; defer {if !complete {diagnostic_failure(r); block(r)}}
	draw_start := sample_begin(r)
	r.error = .Render; if injected(r, .Render) || !draw_reader(&r.live) {return false}
	sample_end(r, .Draw, draw_start)
	read_start := sample_begin(r)
	r.error = .Readback; if injected(r, .Readback) {return false}
	pixels, read := backend.readback(
		r.renderer,
		r.drawable,
	); if !read {return false}; defer sdl.DestroySurface(pixels)
	sample_end(r, .Readback, read_start)
	present_start := sample_begin(r)
	r.error = .Present; if injected(r, .Present) || !sdl.RenderPresent(r.renderer) {return false}
	sample_end(r, .Present, present_start)
	r.error = .None; complete = true; return true
}
