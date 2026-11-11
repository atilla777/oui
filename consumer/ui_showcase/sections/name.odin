package sections

import model "../model"

compose_name :: proc(c: ^Page_Composition, m: model.Model) {
	c.initial_focus = "name/field"
	label(
		c,
		"name/title",
		"root",
		"G09 / name-editor",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"name/field",
		"root",
		.Stack,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 36}, padding = {4, 4, 4, 4}},
	)
	label(c, "name/value", "name/field", m.name.draft, {x = {mode = .Fill}, y = {mode = .Fill}})
	c.targets[c.ni] = {"name/field", "editor", true, true}; c.ni += 1
	node(
		c,
		"name/actions",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 4},
	)
	apply, cancel :=
		"Apply",
		"Cancel"; if m.locale == .Russian {apply, cancel = "Применить", "Отмена"}
	button(c, "name/apply", "name/apply-label", "name/actions", apply)
	button(c, "name/cancel", "name/cancel-label", "name/actions", cancel)
	label(
		c,
		"name/applied-title",
		"root",
		"Applied" if m.locale == .English else "Применено",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	label(
		c,
		"name/applied",
		"root",
		m.name.applied,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
}
