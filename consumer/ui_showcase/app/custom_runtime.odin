package app

import "core:math"
import base "ui:ui_base"
import custom "ui:ui_custom"
import painter "ui:ui_custom/sdl"
import interaction "ui:ui_interaction"

Custom_Page_Runtime :: struct {
	state:          custom.State,
	painters:       ^painter.Generation,
	popup, tooltip: bool,
}
Custom_Page_Reader :: struct {
	frame:    custom.Frame,
	painters: ^painter.Generation,
}
CUSTOM_CIRCLES :: [2]string{"node:4:left7:content6:circle", "node:5:right7:content6:circle"}
circle_validate :: proc(payload: []u8) -> bool {return(
		len(payload) == 2 &&
		payload[0] == 1 &&
		payload[1] == 72 \
	)}
circle_measure :: proc(payload: []u8, _: custom.Constraints) -> (base.Extent, bool) {return {
		72,
		72,
	},
	circle_validate(payload)}
circle_hit :: proc(_: []u8, p: [2]f64, s: base.Extent) -> bool {
	radius := math.min(s.w, s.h) / 2
	dx, dy := p.x - s.w / 2, p.y - s.h / 2
	return dx * dx + dy * dy < radius * radius
}
circle_draw :: proc(c: painter.Canvas, _: []u8, v: painter.Custom_View) -> bool {
	r := v.presentation.area
	return painter.canvas_fill_circle(
		c,
		{r.x + r.w / 2, r.y + r.h / 2},
		min(r.w, r.h) / 2,
		v.presentation.computed[.Foreground].value.(base.Color),
	)
}
custom_route :: proc(r: ^Runtime, a: interaction.Action) -> (interaction.Code, bool) {
	if r.page == .Rich_Text && a.kind == .Activate && a.id == "rich/circle" {
		stamp := reader_stamp(&r.live)
		x := interaction.dispatch_owned(&r.interaction, a, "custom")
		if x.has_event {accept_base(r, stamp, x.event)}
		return x.code, true
	}
	if c, ok := r.content.(^Custom_Page_Runtime); ok {
		if a.kind == .Cancel &&
		   c.popup {c.popup = false; base.invalidate(&r.publication); return .Applied, true}
		for id in CUSTOM_CIRCLES {if a.id == id && a.kind == .Activate {
				stamp := reader_stamp(&r.live)
				x := interaction.dispatch_owned(&r.interaction, a, "custom")
				if x.has_event {accept_base(r, stamp, x.event)}
				return x.code, true
			}}
	}
	return .Invalid_Action, false
}
