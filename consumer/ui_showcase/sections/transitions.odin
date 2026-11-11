package sections

import model "../model"
import "core:fmt"
import controls "ui:ui_controls"

compose_transitions :: proc(c: ^Page_Composition, m: model.Model) {
	en := m.locale == .English
	label(
		c,
		"transitions/title",
		"root",
		"G17 / card-presence",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"transitions/actions",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 4},
	)
	ids := [5]string {
		"transitions/a",
		"transitions/b",
		"transitions/presence",
		"transitions/reduced",
		"transitions/easing",
	}
	labels := [5]string{"Target A", "Target B", "Show / Hide", "Reduced motion", "Easing"}
	if !en {labels = {"Цель A", "Цель B", "Показать / скрыть", "Без движения", "Кривая"}}
	text_ids := TRANSITION_LABELS
	for id, i in ids {button(c, id, text_ids[i], "transitions/actions", labels[i])}
	node(
		c,
		"transitions/stage",
		"root",
		.Row,
		{
			x = {mode = .Fill},
			y = {mode = .Fixed, value = 340},
			gap = 180,
			padding = {24, 32, 24, 32},
		},
	)
	node(
		c,
		"transitions/card",
		"transitions/stage",
		.Column,
		{
			x = {mode = .Fixed, value = 320},
			y = {mode = .Fixed, value = 240},
			padding = {12, 12, 12, 12},
			gap = 12,
		},
	)
	label(
		c,
		"transitions/caption",
		"transitions/card",
		"A (0,0) / B (120,24)",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 28}},
	)
	node(
		c,
		"transitions/count-row",
		"transitions/card",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 4},
	)
	button(
		c,
		"transitions/count",
		"transitions/count-label",
		"transitions/count-row",
		fmt.bprintf(
			c.transition_buffer[:],
			"%s %d",
			"Count" if en else "Счёт",
			m.transition.count,
		),
	)
	button(
		c,
		"transitions/hold",
		"transitions/hold-label",
		"transitions/count-row",
		"Hold 1s" if en else "Держать 1с",
	)
	c.holds[0] = {"transitions/hold", 1000}; c.nholds = 1
	r, e := controls.compose_control(
		{
			id = "transitions/slider",
			node_id = "transitions/slider",
			kind = .Slider,
			label = "Slider" if en else "Ползунок",
			minimum = 0,
			maximum = 100,
			step = 1,
			value = m.transition.slider,
		},
		"transitions/card",
		"root",
		c.page_allocator,
		font = {"own"},
		font_size = 14,
	)
	if e.code == .None {
		c.recipes[0] = r
		for n in r.nodes {c.nodes[c.n] = n; c.n += 1}; for t in r.texts {c.texts[c.nt] = t; c.nt += 1}; for t in r.targets {c.targets[c.ni] = t; c.ni += 1}; for s in r.styles {c.styles[c.ns] = s; c.ns += 1}
	}
	node(
		c,
		"transitions/progress",
		"transitions/card",
		.Box,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 12}},
	)
	label(
		c,
		"transitions/marker",
		"transitions/stage",
		"Marker" if en else "Метка",
		{x = {mode = .Fixed, value = 120}, y = {mode = .Fixed, value = 32}},
	)
	c.initial_focus = "transitions/a"
}
TRANSITION_LABELS :: [5]string {
	"transitions/a-label",
	"transitions/b-label",
	"transitions/presence-label",
	"transitions/reduced-label",
	"transitions/easing-label",
}
