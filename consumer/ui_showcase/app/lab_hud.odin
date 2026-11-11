package app

import model "../model"
import sections "../sections"
import base "ui:ui_base"
import interaction "ui:ui_interaction"

compose_lab_hud :: proc(r: ^Runtime, c: ^Page_Composition) {
	h, _ := active_hold(r)
	m := r.model^; m.hud_hp, m.hud_count = m.lab_hp, m.lab_hold_count
	sections.compose_hud(
		{m, r.allocator},
		c,
		{state = {live = h.state.live}, buffer = h.buffer[:]},
	)
	for &text in c.texts[:c.nt] {if text.id == "hud/title" {text.text = lab_text(r, .Hud)}}
	c.holds[0] = {"hud/restore", 1000}; c.nholds = 1
	lab_button(c, "lab/popup", "lab/popup-label", "root", lab_text(r, .Popup))
	lab_button(c, "lab/tooltip", "lab/tooltip-label", "root", lab_text(r, .Explain))
	if h.popup {
		node(
			c,
			"lab/popup-panel",
			"shell/root",
			.Column,
			{
				x = {mode = .Fixed, value = 420},
				y = {mode = .Fixed, value = 120},
				offset = {200, 300},
				padding = {8, 8, 8, 8},
				gap = 4,
			},
		)
		sections.layer_panel(c, "lab/popup-panel")
		label(
			c,
			"lab/popup-body",
			"lab/popup-panel",
			lab_text(r, .Mock),
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}},
		)
		lab_button(
			c,
			"lab/popup-close",
			"lab/popup-close-label",
			"lab/popup-panel",
			lab_text(r, .Close),
		)
		c.popups[0] = {"lab/popup-panel", "", "lab/popup"}; c.np = 1
	}
	if h.tooltip {
		node(
			c,
			"lab/tooltip-panel",
			"shell/root",
			.Column,
			{
				x = {mode = .Fixed, value = 600},
				y = {mode = .Fixed, value = 64},
				offset = {40, 540},
				padding = {4, 4, 4, 4},
			},
		)
		sections.layer_panel(c, "lab/tooltip-panel")
		label(
			c,
			"lab/tooltip-body",
			"lab/tooltip-panel",
			lab_text(r, .Hold_Help),
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		c.texts[c.nt - 1].options.wrap = .WordWrap
		c.tooltips[0] = {"lab/tooltip-panel", ""}; c.ntool = 1
	}
}
lab_hud_action :: proc(r: ^Runtime, id: string) -> bool {
	h, _ := active_hold(r)
	if r.model.revision == max(u64) {return false}
	switch id {
	case "hud/minus", "hud/plus", "hud/restore":
		delta := 0; if id == "hud/minus" {delta = -10}; if id == "hud/plus" {delta = 10}
		if id == "hud/restore" && r.model.effects == max(u64) {return false}
		next, ok := model.reduce_lab_hud(
			{r.model.lab_hp, r.model.lab_hold_count},
			delta,
			id == "hud/restore",
		)
		if !ok {return false}
		r.model.lab_hp, r.model.lab_hold_count = next.hp, next.count
		if id == "hud/restore" {r.model.effects += 1}
	case "lab/popup":
		h.popup = !h.popup
	case "lab/popup-close":
		h.popup = false
	case "lab/tooltip":
		h.tooltip = !h.tooltip
	case:
		return false
	}
	r.model.revision += 1; base.invalidate(&r.publication); return true
}
lab_hud_cancel :: proc(r: ^Runtime, action: interaction.Action) -> interaction.Code {
	h, _ := active_hold(r)
	if !h.popup {return .Invalid_Action}
	if code := interaction.guard_common(&r.interaction, action.source);
	   code != .Applied {return code}
	if base.advance_sequence(&r.publication) != .None {return .Exhausted}
	if !consume(r, reader_stamp(&r.live), r.publication.sequence) {return .Invalid_Action}
	lab_hud_action(r, "lab/popup-close"); return .Applied
}
