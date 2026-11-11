package sections

import model "../model"
import "core:math"

compose_performance :: proc(c: ^Page_Composition, m: model.Model, width: f64) {
	label(
		c,
		"performance/title",
		"root",
		"G20-G21 / editor-collection-costs",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"performance/actions",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}, gap = 4},
	)
	button(
		c,
		"performance/instrumentation",
		"performance/instrumentation-label",
		"performance/actions",
		"Metrics on/off" if m.locale == .English else "Замеры вкл/выкл",
	)
	ids := [5]string {
		"diagnostics/duplicate",
		"diagnostics/invalid",
		"diagnostics/resource",
		"diagnostics/ownership",
		"diagnostics/unsupported",
	}
	text_ids := [5]string {
		"diagnostics/duplicate-label",
		"diagnostics/invalid-label",
		"diagnostics/resource-label",
		"diagnostics/ownership-label",
		"diagnostics/unsupported-label",
	}
	labels := [5]string{"Duplicate", "Invalid", "Resource", "Ownership", "Unsupported"}
	if m.locale ==
	   .Russian {labels = {"Дубликат", "Невалидный", "Ресурс", "Владение", "Не поддержано"}}
	for id, i in ids {button(c, id, text_ids[i], "performance/actions", labels[i])}
	label(
		c,
		"performance/status",
		"root",
		"CPU phase samples; SDL heap / GPU time unavailable" if m.locale == .English else "Фазы CPU; память SDL и время GPU недоступны",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 48}},
	)
	left := math.floor(min(650, width * .55))
	node(
		c,
		"performance/editor-overlay",
		"shell/root",
		.Absolute,
		{x = {mode = .Fill}, y = {mode = .Fill}},
	)
	node(
		c,
		"performance/name-panel",
		"performance/editor-overlay",
		.Column,
		{
			x = {mode = .Fixed, value = max(0, width - left - 12)},
			y = {mode = .Fixed, value = 320},
			offset = {left, 248},
			gap = 4,
			overflow = .Clip,
		},
	)
	start := c.n
	name_model := m; name_model.name = m.performance_name; compose_name(c, name_model)
	for &n in c.nodes[start:c.n] {if n.parent == "root" {n.parent = "performance/name-panel"}}
}
