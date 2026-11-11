package app

import "core:mem"
import "core:strings"
import base "ui:ui_base"
import editor "ui:ui_editor"
import gestures "ui:ui_gestures"
import layout "ui:ui_layout"
import rich "ui:ui_rich"
import rich_fonts "ui:ui_rich/sdl"
import fonts "ui:ui_sdl_text"

// One explicit, immutable assessment fixture, not an arbitrary family composer.
// The fixed rich box is bound with existing rich stages to the ONE final layout.
// Editor/gesture examples are assessment-only; interactive flows remain G09/G14.
C08_Reader :: struct {
	rich:       rich.Frame,
	fonts:      ^rich_fonts.Generation,
	editor:     editor.Frame,
	gestures:   gestures.Frame,
	references: u64,
	allocator:  mem.Allocator,
}
release_c08 :: proc(p: ^^C08_Reader) {
	if p == nil || p^ == nil {return}; v := p^; p^ = nil
	v.references -= 1
	if v.references != 0 {return}
	rich.destroy_frame(&v.rich); rich_fonts.release_generation(&v.fonts)
	editor.destroy_frame(&v.editor); gestures.destroy_frame(&v.gestures)
	free(v, v.allocator)
}
prepare_c08_reader :: proc(
	r: ^Runtime,
	g: ^layout.Frame,
	primary: ^fonts.Generation,
	ec: ^editor.Candidate,
	gc: ^gestures.Candidate,
) -> (
	^C08_Reader,
	bool,
) {
	v, ae := new(C08_Reader, r.allocator); if ae != nil {return nil, false}
	v.allocator, v.references = r.allocator, 1
	complete := false; defer {if !complete {release_c08(&v)}}
	sources := []rich_fonts.Rich_Font_Source{{"own", primary.fonts[0].data}}
	v.fonts, _ = rich_fonts.create_generation(
		r.renderer,
		r.images.revision,
		nil,
		sources,
		[]rich_fonts.Rich_Font_Chain{{"own", nil}},
		[]rich_fonts.Rich_Font_Request {
			{"own", 14, false, false, false},
			{"own", 14, true, false, false},
		},
		r.model.scale,
		r.allocator,
	)
	if v.fonts == nil {return nil, false}
	if !base.retain(g.stamp) {return nil, false}
	v.rich = {
		stamp     = g.stamp,
		drawable  = g.drawable,
		ui_scale  = g.ui_scale,
		allocator = r.allocator,
	}
	v.rich.rich_blocks, ae = make(
		[]rich.Rich_Block,
		1,
		r.allocator,
	); if ae != nil {return nil, false}
	b := &v.rich.rich_blocks[0]
	b.node_id, ae = strings.clone(
		"accessibility/c08-rich",
		r.allocator,
	); if ae != nil {return nil, false}
	b.base_style = {
		size  = 14,
		color = {240, 240, 240, 255},
	}
	b.base_style.font_id, ae = strings.clone("own", r.allocator); if ae != nil {return nil, false}
	source := "C08: [b]Rich[/b] contrast runs"; if r.model.locale == .Russian {source = "C08: [b]Rich[/b] контраст по фрагментам"}
	e: rich.Rich_Error
	b.document, e = rich.parse_rich_text(
		source,
		b.base_style,
		r.allocator,
	); if e.code != .None {return nil, false}
	metrics := rich_fonts.rich_metrics(v.fonts)
	if rich.rich_resolve_resources(b, metrics, r.allocator).code != .None {return nil, false}
	n, found := layout.find(g, b.node_id); if !found {return nil, false}
	if rich.rich_layout_block(b, n.content.w, metrics, r.allocator, n.content.x, g.ui_scale).code !=
		   .None ||
	   rich.resolve_rich_display(b, n.content, g.ui_scale, metrics, r.allocator).code !=
		   .None {return nil, false}
	v.rich.bound = true
	ok: bool
	v.editor, ok = editor.try_copy_frame(&ec.frame, r.allocator); if !ok {return nil, false}
	v.gestures, ok = gestures.try_copy_frame(&gc.frame, r.allocator); if !ok {return nil, false}
	complete = true; return v, true
}
