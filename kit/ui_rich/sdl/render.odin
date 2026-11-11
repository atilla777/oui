package ui_rich_sdl

import ui ".."
import base "../../ui_base"
import backend "../../ui_sdl"
import style "../../ui_style"
import "core:math"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Render_Backend :: struct {
	surface: proc(font: ^ttf.Font, value: string, color: base.Color, user: rawptr) -> ^sdl.Surface,
	texture: proc(renderer: ^sdl.Renderer, surface: ^sdl.Surface, user: rawptr) -> ^sdl.Texture,
	draw:    proc(
		renderer: ^sdl.Renderer,
		texture: ^sdl.Texture,
		source, dest: ^sdl.FRect,
		user: rawptr,
	) -> bool,
}
native_surface :: proc(
	font: ^ttf.Font,
	value: string,
	color: base.Color,
	user: rawptr,
) -> ^sdl.Surface {return ttf.RenderText_Blended(
		font,
		raw_data(value),
		uint(len(value)),
		{color[0], color[1], color[2], color[3]},
	)}
native_texture :: proc(
	renderer: ^sdl.Renderer,
	surface: ^sdl.Surface,
	user: rawptr,
) -> ^sdl.Texture {return sdl.CreateTextureFromSurface(renderer, surface)}
native_draw :: proc(
	renderer: ^sdl.Renderer,
	texture: ^sdl.Texture,
	source, dest: ^sdl.FRect,
	user: rawptr,
) -> bool {return sdl.RenderTexture(renderer, texture, source, dest)}
render_node :: proc(
	g: ^Generation,
	frame: ^ui.Frame,
	paint: ^style.Frame,
	id: string,
	transform: base.Frozen_Geometry = {scale = 1, opacity = 1},
	draw_backend: Render_Backend = {native_surface, native_texture, native_draw},
	user: rawptr = nil,
) -> bool {
	if id == "" ||
	   !matches(g, frame, paint) ||
	   draw_backend.surface == nil ||
	   draw_backend.texture == nil ||
	   draw_backend.draw == nil {return false}
	if !base.finite_nonnegative(transform.scale) ||
	   !base.finite(transform.offset[0]) ||
	   !base.finite(transform.offset[1]) ||
	   !base.finite_nonnegative(transform.opacity) ||
	   transform.opacity > 1 {return false}
	found :=
		false; for block in frame.rich_blocks {if block.node_id == id {found = true}}; if !found {return false}
	if transform.scale == 0 || transform.opacity == 0 {return true}
	state, saved := backend.save_renderer_state(g.renderer); if !saved {return false}
	ok :=
		backend.pixel_coordinates(g.renderer) &&
		draw_node(g, frame, paint, id, transform, draw_backend, user)
	restored := backend.restore_renderer_state(g.renderer, state)
	return ok && restored
}

matches :: proc(g: ^Generation, frame: ^ui.Frame, paint: ^style.Frame) -> bool {
	if g == nil ||
	   !frame.bound ||
	   frame.stamp.attempt == 0 ||
	   frame.stamp != paint.stamp ||
	   frame.drawable != paint.drawable ||
	   frame.ui_scale != paint.ui_scale ||
	   frame.ui_scale != g.scale ||
	   g.images == nil ||
	   paint.resource_revision != g.images.revision ||
	   !backend.output_matches(g.renderer, frame.drawable) {return false}
	for block in frame.rich_blocks {
		if rich_font(g, block.base_style) == nil {return false}
		found := false
		for p in paint.presentation {if p.id == block.node_id {
				color, valid := p.computed[.Foreground].value.(base.Color)
				if !valid || color != block.base_style.color {return false}
				found = true
			}}
		if !found {return false}
		for chain in block.font_chains {
			font := rich_font(
				g,
				chain.style,
			); if font == nil || len(font.ids) != len(chain.resources) {return false}
			for resource, index in chain.resources {if resource != font.ids[index] {return false}}
		}
		for line in block.lines {for fragment in line.fragments {
				style := block.base_style; value := "…"
				if !fragment.synthetic {
					if fragment.run_index < 0 ||
					   fragment.run_index >= len(block.document.runs) ||
					   fragment.decoded_range.start < 0 ||
					   fragment.decoded_range.start > fragment.decoded_range.end ||
					   fragment.decoded_range.end > len(block.document.decoded) {return false}
					run := block.document.runs[fragment.run_index]
					if run.image_id !=
					   "" {if !rich_image(run.image_id, g) {return false}; continue}
					style =
						run.style; value = block.document.decoded[fragment.decoded_range.start:fragment.decoded_range.end]
				}
				metric, e := rich_measure(
					value,
					style,
					g,
				); if e != .None || metric != fragment.metrics {return false}
			}}
	}
	return true
}
draw_node :: proc(
	g: ^Generation,
	frame: ^ui.Frame,
	paint: ^style.Frame,
	id: string,
	transform: base.Frozen_Geometry,
	draw_backend: Render_Backend,
	user: rawptr,
) -> bool {
	for block in frame.rich_blocks {if block.node_id == id {
			presentation: style.Presentation
			for p in paint.presentation {if p.id == id {presentation = p; break}}
			if !presentation.drawable {return true}
			clip := backend.pixel_rect(presentation.content_clip, frame.ui_scale)
			if !sdl.SetRenderClipRect(g.renderer, &clip) {return false}
			for line in block.lines {
				if !line.displayed {continue}
				for fragment in line.fragments {
					style := block.base_style; value := "…"; image_id := ""
					if !fragment.synthetic {
						run :=
							block.document.runs[fragment.run_index]; style, image_id = run.style, run.image_id
						value = block.document.decoded[fragment.decoded_range.start:fragment.decoded_range.end]
					}
					rect := base.forward_rect(transform, fragment.rect)
					dest := sdl.FRect {
						f32(math.round(rect.x * frame.ui_scale)),
						f32(math.round(rect.y * frame.ui_scale)),
						f32(rect.w * frame.ui_scale),
						f32(rect.h * frame.ui_scale),
					}
					if image_id != "" {
						image, found := resolve_image(g, image_id); if !found {return false}
						alpha: u8; if !sdl.GetTextureAlphaMod(image.texture, &alpha) {return false}
						ok :=
							sdl.SetTextureAlphaMod(
								image.texture,
								u8(math.floor(f64(alpha) * transform.opacity + .5)),
							) &&
							draw_backend.draw(g.renderer, image.texture, &image.rect, &dest, user)
						restored := sdl.SetTextureAlphaMod(
							image.texture,
							alpha,
						); if !ok || !restored {return false}; continue
					}
					if value == "" {continue}
					font := rich_font(g, style); if font == nil {return false}
					color := style.color
					color[3] = u8(
						clamp(math.floor(f64(color[3]) * transform.opacity + .5), 0, 255),
					)
					surface := draw_backend.surface(
						font.instances[0].font,
						value,
						color,
						user,
					); if surface == nil {return false}; defer sdl.DestroySurface(surface)
					if f64(surface.w) / frame.ui_scale != fragment.metrics.width ||
					   f64(surface.h) / frame.ui_scale != fragment.metrics.height {return false}
					texture := draw_backend.texture(
						g.renderer,
						surface,
						user,
					); if texture == nil {return false}; defer sdl.DestroyTexture(texture)
					if !sdl.SetTextureBlendMode(texture, sdl.BLENDMODE_BLEND) ||
					   !draw_backend.draw(g.renderer, texture, nil, &dest, user) {return false}
				}
			}
			return true
		}}
	return false
}
