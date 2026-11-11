package sections

import "core:fmt"
import controls "ui:ui_controls"
import style "ui:ui_style"

LAYER_ROOTS := [3]string{"root", "layers/a", "layers/b"}
LAYER_COUNTS := [3]string{"layers/base-count", "layers/a-count", "layers/b-count"}
LAYER_HOLDS := [3]string{"layers/base-hold", "layers/a-hold", "layers/b-hold"}
LAYER_VIEWPORTS := [3]string{"layers/base-list", "layers/a-list", "layers/b-list"}
LAYER_CONTENTS := [3]string{"layers/base-content", "layers/a-content", "layers/b-content"}
LAYER_POPUPS := [3]string{"layers/base-popup", "layers/a-popup", "layers/b-popup"}
LAYER_PANEL := [4]style.Declaration {
	{.Background, style.Color{32, 45, 65, 255}},
	{.Border, style.Color{170, 195, 215, 255}},
	{.Border_Width, f64(2)},
	{.Font_Size, f64(14)},
}
layer_panel :: proc(c: ^Page_Composition, id: string) {c.styles[c.ns] = {
		id = id,
	}; c.styles[c.ns].appearance.local.states[.Normal] = LAYER_PANEL[:]; c.ns += 1}
Layer_View :: struct {
	depth:                          int,
	popup, tooltip, cancel_allowed: bool,
	counts:                         ^[3][256]u8,
}
compose_layer_page :: proc(r: Page_Input, c: ^Page_Composition, h: Layer_View) -> bool {
	label(
		c,
		"layers/title",
		"root",
		"G12 / nested-scopes",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(c, "layers/open", "root", .Stack, {x = {mode = .Fill}, y = {mode = .Fixed, value = 32}})
	label(
		c,
		"layers/open-label",
		"layers/open",
		"Open A" if r.model.locale == .English else "Открыть A",
		{x = {mode = .Fill}, y = {mode = .Fill}},
	)
	c.targets[c.ni] = {"layers/open", "button", true, true}; c.ni += 1
	recipe, e := controls.compose_control(
		{
			id = "layers/check",
			node_id = "layers/check",
			kind = .Checkbox,
			label = "Enabled" if r.model.locale == .English else "Включено",
			checked = r.model.layer_checked,
		},
		"root",
		"root",
		r.allocator,
		font = {"own"},
		font_size = 14,
	)
	if e.code != .None {return false}; c.recipes[0] = recipe
	for n in recipe.nodes {c.nodes[c.n] = n; c.n += 1}; for t in recipe.texts {c.texts[c.nt] = t; c.nt += 1}; for target in recipe.targets {c.targets[c.ni] = target; c.ni += 1}; for s in recipe.styles {c.styles[c.ns] = s; c.ns += 1}
	rows := [3][8]string {
		{
			"layers/base-0",
			"layers/base-1",
			"layers/base-2",
			"layers/base-3",
			"layers/base-4",
			"layers/base-5",
			"layers/base-6",
			"layers/base-7",
		},
		{
			"layers/a-0",
			"layers/a-1",
			"layers/a-2",
			"layers/a-3",
			"layers/a-4",
			"layers/a-5",
			"layers/a-6",
			"layers/a-7",
		},
		{
			"layers/b-0",
			"layers/b-1",
			"layers/b-2",
			"layers/b-3",
			"layers/b-4",
			"layers/b-5",
			"layers/b-6",
			"layers/b-7",
		},
	}
	for scope in 0 ..= h.depth {
		root := LAYER_ROOTS[scope]
		if scope > 0 {
			node(
				c,
				root,
				"shell/root",
				.Column,
				{x = {mode = .Fill}, y = {mode = .Fill}, padding = {80, 160, 80, 160}, gap = 4},
			)
			layer_panel(
				c,
				root,
			); c.modals[c.nm] = {root, LAYER_COUNTS[scope], h.cancel_allowed}; c.nm += 1
		}
		label_ids := [3]string {
			"layers/base-count-label",
			"layers/a-count-label",
			"layers/b-count-label",
		}
		node(
			c,
			LAYER_COUNTS[scope],
			root,
			.Stack,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}},
		)
		label(
			c,
			label_ids[scope],
			LAYER_COUNTS[scope],
			fmt.bprintf(
				h.counts[scope][:],
				"Count / Счётчик %d",
				r.model.layer_counts[scope],
			),
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		c.targets[c.ni] = {LAYER_COUNTS[scope], "button", true, true}; c.ni += 1
		node(
			c,
			LAYER_VIEWPORTS[scope],
			root,
			.Stack,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 112}, overflow = .Clip},
		)
		node(
			c,
			LAYER_CONTENTS[scope],
			LAYER_VIEWPORTS[scope],
			.Column,
			{x = {mode = .Fill}, y = {mode = .Content}},
		)
		for id in rows[scope] {label(c, id, LAYER_CONTENTS[scope], id, {x = {mode = .Fill}, y = {mode = .Fixed, value = 28}}); c.targets[c.ni] = {id, "row", true, true}; c.ni += 1}
		c.layer_scroll[c.nscroll] = {LAYER_VIEWPORTS[scope], LAYER_CONTENTS[scope]}; c.nscroll += 1
		node(
			c,
			LAYER_HOLDS[scope],
			root,
			.Stack,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 36}},
		)
		hold_labels := [3]string {
			"layers/base-hold-label",
			"layers/a-hold-label",
			"layers/b-hold-label",
		}
		label(
			c,
			hold_labels[scope],
			LAYER_HOLDS[scope],
			"Hold 1000 ms" if r.model.locale == .English else "Удерживать 1000 мс",
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		c.targets[c.ni] = {LAYER_HOLDS[scope], "button", true, true}; c.ni += 1
		c.holds[c.nholds] = {LAYER_HOLDS[scope], 1000}; c.nholds += 1
	}
	root := LAYER_ROOTS[h.depth]
	// ui_layers identifies the base scope by an empty owner ID; root is only
	// its structural node. Modal scopes use their actual modal root IDs.
	owner := root; if h.depth == 0 {owner = ""}
	node(
		c,
		"layers/actions",
		root,
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 4},
	)
	if h.depth ==
	   1 {button(c, "layers/open-b", "layers/open-b-label", "layers/actions", "Open B" if r.model.locale == .English else "Открыть B")}
	if h.depth >
	   0 {button(c, "layers/close", "layers/close-label", "layers/actions", "Close" if r.model.locale == .English else "Закрыть")}
	button(
		c,
		"layers/popup",
		"layers/popup-label",
		"layers/actions",
		"Popup" if r.model.locale == .English else "Панель",
	)
	button(
		c,
		"layers/tooltip",
		"layers/tooltip-label",
		"layers/actions",
		"Tooltip" if r.model.locale == .English else "Подсказка",
	)
	button(
		c,
		"layers/policy",
		"layers/policy-label",
		"layers/actions",
		"Cancel: Yes" if h.cancel_allowed else "Cancel: No",
	)
	if h.popup {
		id := LAYER_POPUPS[h.depth]
		node(
			c,
			id,
			"shell/root",
			.Column,
			{
				x = {mode = .Fixed, value = 300},
				y = {mode = .Fixed, value = 140},
				offset = {500, 180},
				padding = {8, 8, 8, 8},
				gap = 4,
			},
		); layer_panel(c, id)
		label(
			c,
			"layers/popup-title",
			id,
			"Popup shield / Возврат фокуса",
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
		)
		button(c, "layers/popup-close", "layers/popup-close-label", id, "Close / Закрыть")
		c.popups[c.np] = {id, owner, "layers/popup"}; c.np += 1
	}
	if h.tooltip {
		node(
			c,
			"layers/tip",
			"shell/root",
			.Stack,
			{
				x = {mode = .Fixed, value = 350},
				y = {mode = .Fixed, value = 40},
				offset = {200, 600},
			},
		); layer_panel(c, "layers/tip")
		label(
			c,
			"layers/tip-label",
			"layers/tip",
			"Noninteractive / Без ввода",
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		c.tooltips[c.ntool] = {"layers/tip", owner}; c.ntool += 1
	}
	c.initial_focus = "layers/open"; if h.depth > 0 {c.initial_focus = LAYER_COUNTS[h.depth]}
	return true
}
