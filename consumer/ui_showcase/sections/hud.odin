package sections

import "core:fmt"
import hold "ui:ui_hold"

Hud_View :: struct {
	state:  struct {
		live: hold.Hold_State,
	},
	buffer: []u8,
}
compose_hud :: proc(r: Page_Input, c: ^Page_Composition, h: Hud_View) {
	label(
		c,
		"hud/title",
		"root",
		"G13 / hold-progress",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	label(
		c,
		"hud/status",
		"root",
		fmt.bprintf(
			h.buffer[:],
			"HP %d/100 | %d ms | %v | count=%d",
			r.model.hud_hp,
			h.state.live.elapsed_ms,
			h.state.live.phase,
			r.model.hud_count,
		),
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(c, "hud/hp-bar", "root", .Box, {x = {mode = .Fill}, y = {mode = .Fixed, value = 20}})
	node(
		c,
		"hud/actions",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 4},
	)
	button(c, "hud/minus", "hud/minus-label", "hud/actions", "-10")
	button(c, "hud/plus", "hud/plus-label", "hud/actions", "+10")
	node(c, "hud/restore", "root", .Stack, {x = {mode = .Fill}, y = {mode = .Fixed, value = 40}})
	label(
		c,
		"hud/restore-label",
		"hud/restore",
		"Hold to restore (1000 ms)" if r.model.locale == .English else "Удерживайте для восстановления (1000 мс)",
		{x = {mode = .Fill}, y = {mode = .Fill}},
	)
	c.targets[c.ni] = {"hud/restore", "button", true, true}; c.ni += 1
	node(c, "hud/hold-bar", "root", .Box, {x = {mode = .Fill}, y = {mode = .Fixed, value = 16}})
	c.initial_focus = "hud/restore"
}
