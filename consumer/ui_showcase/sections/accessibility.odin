package sections

import model "../model"
import "core:fmt"
import controls "ui:ui_controls"
import style "ui:ui_style"

compose_accessibility :: proc(c: ^Page_Composition, m: model.Model, a: Page_Input) -> bool {
	en := m.locale == .English
	label(
		c,
		"accessibility/title",
		"root",
		"G18 / assessment-confirm",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"accessibility/settings",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 4},
	)
	ids := [5]string {
		"accessibility/mode",
		"accessibility/thresholds",
		"accessibility/strict",
		"accessibility/reduced",
		"accessibility/action",
	}
	texts := [5]string {
		"accessibility/mode-label",
		"accessibility/thresholds-label",
		"accessibility/strict-label",
		"accessibility/reduced-label",
		"accessibility/action-label",
	}
	labels := [5]string {
		"Hold / Dialog",
		"4.5:1,24 / 7:1,32",
		"Normal / Strict",
		"Reduced motion",
		"Confirm action",
	}
	if !en {labels = {"Удержание / Диалог", "4.5:1,24 / 7:1,32", "Обычный / Строгий", "Без движения", "Подтвердить"}}
	labels[2] = "Normal" if en else "Обычный"
	if m.accessibility.strict {labels[2] = "Strict" if en else "Строгий"}
	for id, i in ids {button(c, id, texts[i], "accessibility/settings", labels[i])}
	button(
		c,
		"accessibility/target",
		"accessibility/target-label",
		"accessibility/settings",
		"A / B",
	)
	button(
		c,
		"accessibility/presence",
		"accessibility/presence-label",
		"accessibility/settings",
		"Show / Hide" if en else "Показать / скрыть",
	)
	if m.accessibility.mode == .Hold {c.holds[0] = {"accessibility/action", 1000}; c.nholds = 1}
	node(c, "accessibility/body", "root", .Row, {x = {mode = .Fill}, y = {mode = .Fill}, gap = 24})
	node(
		c,
		"accessibility/samples",
		"accessibility/body",
		.Column,
		{x = {mode = .Fixed, value = 600}, y = {mode = .Fill}, gap = 4},
	)
	sample_labels := [3]string {
		"Good: black/white Pass",
		"Bad: same colors Warning",
		"Custom background: Unassessed",
	}
	if !en {sample_labels = {"Pass: чёрный текст на белом", "Warning: одинаковые цвета", "Unassessed: пользовательский фон"}}
	for id, i in ([]string{"accessibility/good", "accessibility/bad", "accessibility/unknown"}) {
		label(
			c,
			id,
			"accessibility/samples",
			sample_labels[i],
			{x = {mode = .Fixed, value = 460}, y = {mode = .Fixed, value = 48}},
		)
		c.accessibility_paint[i] = {
			{.Foreground, style.Color{0, 0, 0, 255}},
			{.Background, style.Color{255, 255, 255, 255}},
			{.Font, style.Font_ID{"own"}},
			{.Font_Size, f64(14)},
			{.Border_Width, f64(0)},
		}
		if i == 1 {c.accessibility_paint[i][0] = {.Foreground, style.Color{255, 255, 255, 255}}}
		c.styles[c.ns] = {
			id = id,
		}; c.styles[c.ns].appearance.local.states[.Normal] = c.accessibility_paint[i][:]; c.ns += 1
	}
	label(
		c,
		"accessibility/bad-description",
		"accessibility/samples",
		"Warning: white on white is deliberately invisible" if en else "Warning: белый на белом намеренно невидим",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 40}},
	)
	label(
		c,
		"accessibility/unknown-description",
		"accessibility/samples",
		"Unassessed: the custom circle backdrop is not guessed" if en else "Unassessed: контраст пользовательского круга не угадывается",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 40}},
	)
	label(
		c,
		"accessibility/explanation",
		"accessibility/samples",
		"Pass / Warning / Unassessed; warnings do not disable ordinary actions" if en else "Pass / Warning / Unassessed; предупреждения не запрещают действия",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 40}},
	)
	node(
		c,
		"accessibility/targets",
		"accessibility/samples",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 40}, gap = 8},
	)
	node(
		c,
		"accessibility/target24",
		"accessibility/targets",
		.Box,
		{x = {mode = .Fixed, value = 24}, y = {mode = .Fixed, value = 24}},
	)
	c.targets[c.ni] = {"accessibility/target24", "button", true, true}; c.ni += 1
	node(
		c,
		"accessibility/target-clip",
		"accessibility/targets",
		.Column,
		{x = {mode = .Fixed, value = 20}, y = {mode = .Fixed, value = 40}, overflow = .Clip},
	)
	node(
		c,
		"accessibility/clipped-target",
		"accessibility/target-clip",
		.Box,
		{x = {mode = .Fixed, value = 40}, y = {mode = .Fixed, value = 40}},
	)
	c.targets[c.ni] = {"accessibility/clipped-target", "button", true, true}; c.ni += 1
	label(
		c,
		"accessibility/targets-description",
		"accessibility/targets",
		"24x24; clipped 40x40 -> visible 20x40" if en else "24x24; обрезка 40x40 -> видно 20x40",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	label(
		c,
		"accessibility/status",
		"accessibility/samples",
		fmt.bprintf(
			c.accessibility_buffer[:],
			"counter=%d requests=%d token=%d strict=%t thresholds=%t reduced=%t",
			m.accessibility.counter,
			m.accessibility.requests,
			m.accessibility.pending_token,
			m.accessibility.strict,
			m.accessibility.strict_thresholds,
			m.accessibility.reduced,
		),
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 64}},
	)
	c.texts[c.nt - 1].options.wrap = .WordWrap
	{
		initial, ok := controls.item_node_id(
			"accessibility/dialog",
			"cancel",
			a.allocator,
		); if !ok {return false}; defer delete(initial, a.allocator)
		items := [2]controls.Item {
			{id = "confirm", label = "Confirm" if en else "Подтвердить"},
			{id = "cancel", label = "Cancel" if en else "Отмена"},
		}
		r, e := controls.compose_control(
			{
				id = "accessibility/dialog",
				node_id = "accessibility/dialog",
				kind = .Dialog,
				label = "Confirm?" if en else "Подтвердить?",
				open = m.accessibility.mode == .Dialog && m.accessibility.pending_token != 0,
				items = items[:],
				cancel_id = "cancel",
				initial_focus_id = initial,
			},
			"root",
			"shell/root",
			a.allocator,
			font = {"own"},
			font_size = 14,
		)
		if e.code !=
		   .None {fmt.eprintf("accessibility dialog compose=%v\n", e.code); return false}; c.recipes[0] = r
		for &n in r.nodes {if n.id == r.control.node_id {n.layout = {
					x = {mode = .Fixed, value = 320},
					y = {mode = .Content},
					padding = {16, 16, 16, 16},
					gap = 12,
					align_self = .Center,
				}}}
		c.accessibility_paint[3] = {
			{.Foreground, style.Color{240, 240, 240, 255}},
			{.Background, style.Color{30, 42, 60, 255}},
			{.Font, style.Font_ID{"own"}},
			{.Font_Size, f64(14)},
			{.Border_Width, f64(1)},
		}
		for &s in r.styles {if s.id == r.control.node_id {s.appearance.local.states[.Normal] = c.accessibility_paint[3][:]}}
		for n in r.nodes {c.nodes[c.n] = n; c.n += 1}; for t in r.texts {c.texts[c.nt] = t; c.nt += 1}; for t in r.targets {c.targets[c.ni] = t; c.ni += 1}; for s in r.styles {c.styles[c.ns] = s; c.ns += 1}
		if modal, has := r.modal.?; has {c.modals[0] = modal; c.nm = 1}
	}
	node(
		c,
		"transitions/card",
		"accessibility/samples",
		.Column,
		{
			x = {mode = .Fixed, value = 320},
			y = {mode = .Fixed, value = 128},
			gap = 12,
			padding = {12, 12, 12, 12},
		},
	)
	// Explicit fixed assessment-only projection samples; not a rich editor.
	node(
		c,
		"accessibility/c08-panel",
		"accessibility/body",
		.Column,
		{x = {mode = .Fill}, y = {mode = .Fill}, gap = 8},
	)
	label(
		c,
		"accessibility/c08-title",
		"accessibility/c08-panel",
		"C08 assessment-only; editing G09 / gestures G14" if en else "C08: оценка; редактирование G09 / жесты G14",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"accessibility/c08-rich",
		"accessibility/c08-panel",
		.Box,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}},
	)
	node(
		c,
		"accessibility/c08-editor",
		"accessibility/c08-panel",
		.Stack,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 36}, padding = {4, 4, 4, 4}},
	)
	label(
		c,
		"accessibility/c08-value",
		"accessibility/c08-editor",
		"Имя",
		{x = {mode = .Fill}, y = {mode = .Fill}},
	)
	c.targets[c.ni] = {"accessibility/c08-editor", "editor", false, true}; c.ni += 1
	for &n in c.nodes[:c.n] {if n.id == "accessibility/c08-editor" {n.enabled = false}}
	node(
		c,
		"accessibility/c08-scroll",
		"accessibility/c08-panel",
		.Column,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 96}, overflow = .Clip},
	)
	node(
		c,
		"accessibility/c08-content",
		"accessibility/c08-scroll",
		.Column,
		{x = {mode = .Fill}, y = {mode = .Content}, gap = 4},
	)
	for id in ([]string{"accessibility/c08-row1", "accessibility/c08-row2", "accessibility/c08-row3", "accessibility/c08-row4"}) {label(c, id, "accessibility/c08-content", "Scroll assessment" if en else "Оценка scroll", {x = {mode = .Fill}, y = {mode = .Fixed, value = 32}})}
	c.layer_scroll[0] = {"accessibility/c08-scroll", "accessibility/c08-content"}; c.nscroll = 1
	node(
		c,
		"accessibility/c08-gesture",
		"accessibility/c08-panel",
		.Box,
		{x = {mode = .Fixed, value = 32}, y = {mode = .Fixed, value = 32}},
	)
	c.targets[c.ni] = {"accessibility/c08-gesture", "button", false, true}; c.ni += 1
	for &n in c.nodes[:c.n] {if n.id == "accessibility/c08-gesture" {n.enabled = false}}
	label(
		c,
		"accessibility/motion",
		"transitions/card",
		"Reduced motion sample" if en else "Образец движения",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 28}},
	)
	node(
		c,
		"transitions/progress",
		"transitions/card",
		.Box,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 12}},
	)
	for &t in c.texts[:c.nt] {if t.id == "accessibility/status" || t.id == "accessibility/bad-description" || t.id == "accessibility/unknown-description" || t.id == "accessibility/explanation" {t.options.wrap = .WordWrap}}
	c.initial_focus = "accessibility/action"; return true
}
