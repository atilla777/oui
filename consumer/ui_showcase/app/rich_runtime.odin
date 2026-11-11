package app

import "core:fmt"
import base "ui:ui_base"
import custom "ui:ui_custom"
import painter "ui:ui_custom/sdl"
import rich "ui:ui_rich"
import rich_fonts "ui:ui_rich/sdl"
import transitions "ui:ui_transitions"

Rich_Page_Runtime :: struct {
	fonts:    ^rich_fonts.Generation,
	combined: ^Rich_Combined_Runtime,
}
Rich_Combined_Runtime :: struct {
	visual:   Transition_Page_Runtime,
	custom:   custom.State,
	painters: ^painter.Generation,
}
Rich_Page_Reader :: struct {
	frame:    rich.Frame,
	fonts:    ^rich_fonts.Generation,
	visual:   transitions.Frame,
	custom:   custom.Frame,
	painters: ^painter.Generation,
}

reader_stamp :: proc(reader: ^Reader) -> base.Frame_Stamp {
	if content, ok := reader.content.(Rich_Page_Reader); ok {return content.frame.stamp}
	return reader.text.stamp
}
new_rich_generation :: proc(
	r: ^Runtime,
	primary: []u8,
	scale: f64,
) -> (
	^rich_fonts.Generation,
	bool,
) {
	if len(r.sources.fallback) ==
	   0 {fmt.eprintln("Rich text page requires explicit --fallback-font"); return nil, false}
	pixels: [12 * 12 * 4]u8
	for y in 0 ..< 12 {for x in 0 ..< 12 {i := (y * 12 + x) * 4; pixels[i], pixels[i + 1], pixels[i + 2] = 255, 197, 48; if (x >= 4 && x <= 7) || (y >= 4 && y <= 7) {pixels[i + 3] = 255}}}
	g, e := rich_fonts.create_generation(
		r.renderer,
		"images-1",
		[]rich_fonts.RGBA_Image{{"star", 12, 12, pixels[:]}},
		[]rich_fonts.Rich_Font_Source{{"own", primary}, {"greek", r.sources.fallback}},
		[]rich_fonts.Rich_Font_Chain{{"own", {"greek"}}},
		[]rich_fonts.Rich_Font_Request {
			{"own", 14, false, false, false},
			{"own", 16, false, false, false},
			{"own", 16, true, false, false},
			{"own", 16, false, true, false},
			{"own", 16, false, false, true},
			{"own", 24, false, false, false},
		},
		scale,
		r.allocator,
	)
	if e.code != .None {fmt.eprintf("Rich font generation code=%v id=%s\n", e.code, e.id)}
	return g, e.code == .None
}
