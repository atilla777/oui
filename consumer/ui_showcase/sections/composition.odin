package sections

import model "../model"
import "core:fmt"
import style "ui:ui_style"

compose_nested_route :: proc(c: ^Page_Composition, m: model.Model) {
	c.route_paint = {
		{.Background, style.Color{80, 160, 200, 255}},
		{.Border_Width, f64(0)},
		{.Font, style.Font_ID{"own"}},
		{.Font_Size, f64(14)},
	}
	c.styles[c.ns] = {
		id = "composition/decor",
	}; c.styles[c.ns].appearance.local.states[.Normal] = c.route_paint[:]; c.ns += 1
	en := m.locale == .English
	label(
		c,
		"composition/title",
		"root",
		"G15 / nested-route",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"composition/parent",
		"root",
		.Column,
		{x = {mode = .Fill}, y = {mode = .Content}, padding = {8, 8, 8, 8}, gap = 6},
	)
	c.targets[c.ni] = {"composition/parent", "button", true, true}; c.ni += 1
	label(
		c,
		"composition/heading",
		"composition/parent",
		"Composite parent button" if en else "Составная родительская кнопка",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 28}},
	)
	node(
		c,
		"composition/decor",
		"composition/parent",
		.Box,
		{x = {mode = .Fixed, value = 40}, y = {mode = .Fixed, value = 4}},
	)
	if m.composition.child_present {
		node(
			c,
			"composition/child-row",
			"composition/parent",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 36}},
		)
		button(
			c,
			"composition/child",
			"composition/child-label",
			"composition/child-row",
			"Child button" if en else "Дочерняя кнопка",
		)
	}
	label(
		c,
		"composition/counts",
		"root",
		fmt.bprintf(
			c.route_buffer[:],
			"parent=%d | child=%d",
			m.composition.parent_count,
			m.composition.child_count,
		),
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"composition/actions",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 36}, gap = 4},
	)
	stop := "Stop: on" if en else "Stop: включён"
	if !m.composition.stop {stop = "Stop: off" if en else "Stop: выключен"}
	button(c, "composition/stop", "composition/stop-label", "composition/actions", stop)
	presence := "Remove child" if en else "Удалить дочернюю"
	if !m.composition.child_present {presence = "Re-add child" if en else "Вернуть дочернюю"}
	button(
		c,
		"composition/presence",
		"composition/presence-label",
		"composition/actions",
		presence,
	)
	c.initial_focus = "composition/child" if m.composition.child_present else "composition/parent"
}
