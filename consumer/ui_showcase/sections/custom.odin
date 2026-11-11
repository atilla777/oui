package sections

import model "../model"
import "core:fmt"
import "core:mem"
import composition "ui:ui_composition"
import layout "ui:ui_layout"
import style "ui:ui_style"

compose_custom :: proc(
	c: ^Page_Composition,
	m: model.Model,
	popup, tooltip: bool,
	a: mem.Allocator,
) -> bool {
	en := m.locale == .English
	label(
		c,
		"custom/title",
		"root",
		"G16 / two-panels-circle",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"custom/actions",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}, gap = 4},
	)
	button(
		c,
		"custom/style",
		"custom/style-label",
		"custom/actions",
		"Style" if en else "Стиль",
	)
	button(
		c,
		"custom/slot",
		"custom/slot-label",
		"custom/actions",
		"Footer" if en else "Подвал",
	)
	button(
		c,
		"custom/disabled",
		"custom/disabled-label",
		"custom/actions",
		"Disabled" if en else "Недоступность",
	)
	button(
		c,
		"custom/popup",
		"custom/popup-label",
		"custom/actions",
		"Popup shield" if en else "Щит popup",
	)
	button(
		c,
		"custom/tooltip",
		"custom/tooltip-label",
		"custom/actions",
		"Tooltip" if en else "Подсказка",
	)
	node(
		c,
		"custom/panels",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 256}, gap = 12},
	)
	for side, i in ([]string{"left", "right"}) {
		title := composition.Node {
			node = {
				id = "caption",
				role = .Content,
				enabled = true,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 240},
					y = {mode = .Fixed, value = 28},
				},
			},
		}
		circle := composition.Node {
			node = {
				id = "circle",
				role = .Box,
				enabled = !m.custom_disabled,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 72},
					y = {mode = .Fixed, value = 72},
				},
			},
		}
		note := composition.Node {
			node = {
				id = "note",
				role = .Content,
				enabled = true,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 240},
					y = {mode = .Fixed, value = 28},
				},
			},
		}
		declarations := [2]style.Declaration {
			{.Background, style.Color{25, 40, 60, 255}},
			{.Foreground, style.Color{90, 200, 240, 255}},
		}
		if i == 1 {declarations[1].value = style.Color{220, 150, 65, 255}}
		if i == 0 &&
		   m.custom_style {declarations[0].value = style.Color{65, 35, 50, 255}; declarations[1].value = style.Color{240, 120, 190, 255}}
		appearance := style.Appearance{}; appearance.local.states[.Normal] = declarations[:]
		slots := [3]composition.Slot {
			{name = "title", nodes = []composition.Node{title}},
			{name = "content", nodes = []composition.Node{circle}},
			{name = "footer", nodes = []composition.Node{note}},
		}
		if i == 0 && m.custom_slot_absent {slots[2].nodes = nil}
		p, e := composition.compose_panel(
			side,
			"custom/panels",
			{x = {mode = .Fill}, y = {mode = .Fill}, padding = {12, 12, 12, 12}, gap = 8},
			appearance,
			slots[:],
			a,
		)
		if e != .None {return false}; c.panels[i] = p
		for v in p.nodes {
			c.nodes[c.n] = v.node; c.n += 1
			c.styles[c.ns] = {
				id         = v.node.id,
				appearance = v.appearance,
			}; c.ns += 1
			if v.node.role == .Box {
				c.targets[c.ni] = {v.node.id, "button", !m.custom_disabled, true}; c.ni += 1
				// Circle foreground override is explicit, not inherited by comparing RGBA.
				c.custom_colors[i] = declarations[1]
				c.styles[c.ns - 1].appearance.local.states[.Normal] = c.custom_colors[i:i + 1]
				if i == 0 {c.initial_focus = v.node.id}
			} else if v.node.role == .Content {
				text := "Left panel" if i == 0 else "Right panel"
				if !en {text = "Левая панель" if i == 0 else "Правая панель"}
				if v.node.id == "node:4:left6:footer4:note" ||
				   v.node.id ==
					   "node:5:right6:footer4:note" {text = fmt.bprintf(c.custom_buffers[i][:], "count=%d", m.custom_counts[i])}
				c.texts[c.nt] = {v.node.id, text, {"own"}, 14, {}}; c.nt += 1
			}
		}
	}
	for &d, index in c.styles[:c.ns] {
		n := 0
		for v in d.appearance.local.states[.Normal] {c.custom_declarations[index][n] = v; n += 1}
		c.custom_declarations[index][n] = {.Font, style.Font_ID{"own"}}; n += 1
		c.custom_declarations[index][n] = {.Font_Size, f64(14)}; n += 1
		d.appearance.local.states[.Normal] = c.custom_declarations[index][:n]
	}
	if popup {
		node(
			c,
			"custom/popup-root",
			"shell/root",
			.Stack,
			{
				x = {mode = .Fixed, value = 300},
				y = {mode = .Fixed, value = 240},
				align_self = .Center,
			},
		)
		button(
			c,
			"custom/close",
			"custom/close-label",
			"custom/popup-root",
			"Close popup" if en else "Закрыть popup",
		)
		c.popups[0] = {"custom/popup-root", "", "custom/popup"}; c.np = 1
	}
	if tooltip {
		node(
			c,
			"custom/tooltip-root",
			"shell/root",
			.Stack,
			{
				x = {mode = .Fixed, value = 200},
				y = {mode = .Fixed, value = 28},
				margin = {16, 448, 0, 0},
			},
		)
		label(
			c,
			"custom/tooltip-text",
			"custom/tooltip-root",
			"No input" if en else "Без ввода",
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		c.tooltips[0] = {"custom/tooltip-root", ""}; c.ntool = 1
	}
	return true
}
