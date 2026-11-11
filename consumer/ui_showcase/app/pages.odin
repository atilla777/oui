package app

import model "../model"
import sections "../sections"
import "core:fmt"
import "core:mem"
import controls "ui:ui_controls"
import layout "ui:ui_layout"
import style "ui:ui_style"
import text "ui:ui_text"

Page_Composition :: sections.Page_Composition
compose_page :: proc(
	c: ^Page_Composition,
	m: model.Model,
	a: mem.Allocator,
	atlas: []style.Atlas_Region = nil,
	table_metrics: text.Text_Layout_Metrics = {},
	table_width: f64 = 1280,
) -> bool {
	c.page_allocator = a
	w := EN; if m.locale == .Russian {w = RU}
	node(c, "shell/root", "", .Stack, {x = {mode = .Fill}, y = {mode = .Fill}})
	node(
		c,
		"root",
		"shell/root",
		.Column,
		{x = {mode = .Fill}, y = {mode = .Fill}, padding = {6, 6, 6, 6}, gap = 4},
	)
	label(c, "shell/title", "root", w.title, {x = {mode = .Fill}, y = {mode = .Fixed, value = 18}})
	node(
		c,
		"shell/nav",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 25}, gap = 4},
	)
	if m.page !=
	   .Catalogue {button(c, "shell/catalogue", "shell/catalogue-label", "shell/nav", w.catalogue)}
	if m.page != .Layout {button(c, "shell/layout", "shell/layout-label", "shell/nav", w.layout)}
	if m.page !=
	   .Controls {button(c, "shell/controls", "shell/controls-label", "shell/nav", w.controls)}
	if m.page == .Layout {
		more, safe :=
			"More", "Safe area"; if m.locale == .Russian {more, safe = "Ещё", "Safe area"}
		button(c, "layout/more", "layout/more-label", "shell/nav", more)
		button(c, "layout/safe-area", "layout/safe-area-label", "shell/nav", safe)
	}
	node(
		c,
		"shell/settings",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 25}, gap = 4},
	)
	button(c, "shell/language", "shell/language-label", "shell/settings", w.language)
	scale_label := fmt.bprintf(c.buffer[:], "%s %g", w.scale, m.scale)
	button(c, "shell/scale", "shell/scale-label", "shell/settings", scale_label)
	mode := w.normal; if m.pixel_perfect {mode = w.pixel}
	button(c, "shell/mode", "shell/mode-label", "shell/settings", mode)
	help := w.help
	if m.page ==
	   .Catalogue {help = "experimental: kit; legacy: old UI"; if m.locale == .Russian {help = "experimental: комплект; legacy: старый UI"}}
	label(c, "shell/help", "root", help, {x = {mode = .Fill}, y = {mode = .Fixed, value = 18}})
	c.initial_focus = "shell/layout"
	if m.page == .Catalogue {
		sections := model.SECTIONS
		rows := 2; if m.catalogue_lab {rows = 0}
		for i in 0 ..< rows {
			index :=
				m.catalogue_offset +
				i; if index >= len(sections) {break}; section := sections[index]
			row_ids := [2]string{"catalogue/row0", "catalogue/row1"}
			title_ids := [2]string{"catalogue/title0", "catalogue/title1"}
			status_ids := [2]string{"catalogue/status0", "catalogue/status1"}
			limit_ids := [2]string{"catalogue/limit0", "catalogue/limit1"}
			node(
				c,
				row_ids[i],
				"root",
				.Column,
				{x = {mode = .Fill}, y = {mode = .Content}, gap = 1},
			)
			node(
				c,
				section.id,
				row_ids[i],
				.Stack,
				{x = {mode = .Fill}, y = {mode = .Fixed, value = 20}},
			)
			label(
				c,
				title_ids[i],
				section.id,
				section.id,
				{x = {mode = .Fill}, y = {mode = .Fill}},
			)
			c.targets[c.ni] = {section.id, "button", true, true}; c.ni += 1
			label(
				c,
				status_ids[i],
				row_ids[i],
				section.status,
				{x = {mode = .Fill}, y = {mode = .Fixed, value = 18}},
			)
			label(
				c,
				limit_ids[i],
				row_ids[i],
				model.section_limitations(section, m.locale),
				{x = {mode = .Fill}, y = {mode = .Fixed, value = 36}},
			)
			c.texts[c.nt - 1].options = {
				wrap              = .WordWrap,
				overflow          = .Clip,
				overflow_expected = true,
			}
		}
		node(
			c,
			"catalogue/pages",
			"root",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 25}, gap = 4},
		)
		previous, next :=
			"Previous",
			"Next"; if m.locale == .Russian {previous, next = "Назад", "Далее"}
		if !m.catalogue_lab {
			button(
				c,
				"catalogue/previous",
				"catalogue/previous-label",
				"catalogue/pages",
				previous,
			)
			button(c, "catalogue/next", "catalogue/next-label", "catalogue/pages", next)
		}
	}
	if m.page == .Catalogue && m.catalogue_lab {
		node(
			c,
			"lab/catalogue-group",
			"root",
			.Column,
			{x = {mode = .Fill}, y = {mode = .Content}, gap = 4},
		)
		ids := [4]string {
			"lab/menu-label",
			"lab/settings-entry-label",
			"lab/hud-label",
			"lab/inventory-label",
		}
		values := [4]string{"Menu", "Settings", "HUD", "Inventory"}
		if m.locale ==
		   .Russian {values = {"Меню", "Настройки", "HUD", "Инвентарь"}}
		for section, index in model.LAB_SECTIONS {lab_button(c, section.id, ids[index], "lab/catalogue-group", values[index])}
	}
	if m.page == .Layout {
		c.initial_focus = "shell/controls"
		c.rows = {{mode = .Fill, value = 1}, {mode = .Fill, value = 1}}
		c.columns = c.rows
		c.outer_rows = {
			{mode = .Fixed, value = 54},
			{mode = .Fixed, value = 54},
			{mode = .Fixed, value = 54},
		}
		node(
			c,
			"layout/fixtures",
			"root",
			.Grid,
			{
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 174},
				gap = 4,
				rows = c.outer_rows[:],
				columns = c.columns[:],
			},
		)
		for id, i in ([]string{"layout/row", "layout/column", "layout/stack", "layout/grid", "layout/absolute", "layout/clip"}) {
			kind := layout.Kind.Row
			switch i {case 1:
				kind = .Column; case 2:
				kind = .Stack; case 3:
				kind = .Grid; case 4:
				kind = .Absolute; case 5:
				kind = .Stack}
			l := layout.Layout {
				x = {mode = .Fill},
				y = {mode = .Fill},
				row = i / 2,
				column = i % 2,
				gap = 2,
				padding = {2, 2, 2, 2},
			}
			if i == 3 {l.rows = c.rows[:]; l.columns = c.columns[:]}
			if kind == .Stack || kind == .Absolute {l.gap = 0}
			if i == 5 {l.overflow = .Clip; l.x = {
					mode  = .Fixed,
					value = 150,
				}}
			node(c, id, "layout/fixtures", kind, l)
		}
		label(
			c,
			"layout/row-a",
			"layout/row",
			"Row A",
			{x = {mode = .Fixed, value = 55}, y = {mode = .Fill}},
		)
		label(c, "layout/row-b", "layout/row", "B", {x = {mode = .Fill}, y = {mode = .Fill}})
		label(
			c,
			"layout/column-a",
			"layout/column",
			"Column A",
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 22}},
		)
		label(c, "layout/column-b", "layout/column", "B", {x = {mode = .Fill}, y = {mode = .Fill}})
		label(
			c,
			"layout/bottom",
			"layout/stack",
			"Stack: bottom",
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		label(
			c,
			"layout/top",
			"layout/stack",
			"top",
			{x = {mode = .Fixed, value = 48}, y = {mode = .Fixed, value = 22}, align_self = .End},
		)
		label(
			c,
			"layout/grid-a",
			"layout/grid",
			"Grid A",
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		label(
			c,
			"layout/grid-b",
			"layout/grid",
			"B",
			{x = {mode = .Fill}, y = {mode = .Fill}, row = 1, column = 1},
		)
		label(
			c,
			"layout/anchored",
			"layout/absolute",
			"Absolute",
			{
				x = {mode = .Fixed, value = 70},
				y = {mode = .Fixed, value = 22},
				anchor = {1, 0.5},
				pivot = {1, 0.5},
				offset = {-2, 0},
			},
		)
		label(
			c,
			"layout/clipped",
			"layout/clip",
			w.clip,
			{x = {mode = .Fixed, value = 260}, y = {mode = .Fill}},
		)
		c.targets[c.ni] = {"layout/clipped", "fixture", true, true}; c.ni += 1
	} else if m.page == .Controls {
		c.initial_focus = "controls/checkbox"
		ds := [3]controls.Description {
			{
				id = "controls/checkbox",
				node_id = "controls/checkbox",
				kind = .Checkbox,
				label = w.checkbox,
				checked = m.checkbox,
			},
			{
				id = "controls/toggle",
				node_id = "controls/toggle",
				kind = .Toggle,
				label = w.toggle,
				checked = m.toggle,
				on_text = w.on,
				off_text = w.off,
			},
			{
				id = "controls/slider",
				node_id = "controls/slider",
				kind = .Slider,
				label = w.slider,
				value = m.slider,
				minimum = 0,
				maximum = 100,
				step = 1,
			},
		}
		for d, i in ds {
			r, e := controls.compose_control(d, "root", "root", a, font = {"own"}, font_size = 14)
			if e.code != .None {return false}; c.recipes[i] = r
			for n in r.nodes {c.nodes[c.n] = n; c.n += 1}
			for v in r.texts {c.texts[c.nt] = v; c.nt += 1}
			for v in r.targets {c.targets[c.ni] = v; c.ni += 1}
			for v in r.styles {c.styles[c.ns] = v; c.ns += 1}
		}
	}
	if m.page == .Profiles {
		c.initial_focus = "profiles/help"
		node(
			c,
			"profiles/body",
			"root",
			.Column,
			{x = {mode = .Fill}, y = {mode = .Content}, gap = 4},
		)
		node(
			c,
			"profiles/general",
			"profiles/body",
			.Column,
			{x = {mode = .Fill}, y = {mode = .Content}, gap = 4},
		)
		c.nodes[c.n - 1].visible = m.profiles.active_tab == "general"
		node(
			c,
			"profiles/appearance",
			"profiles/body",
			.Column,
			{x = {mode = .Fill}, y = {mode = .Content}, gap = 4},
		)
		c.nodes[c.n - 1].visible = m.profiles.active_tab == "appearance"
		state := m.profiles
		p, ok := sections.compose_profiles(&state, m.locale == .English, c.select_open, a)
		if !ok {return false}; c.profiles = p
		for r in c.profiles.items[:c.profiles.count] {
			for n in r.nodes {c.nodes[c.n] = n; c.n += 1}
			for v in r.texts {c.texts[c.nt] = v; c.nt += 1}
			for v in r.targets {c.targets[c.ni] = v; c.ni += 1}
			for v in r.styles {c.styles[c.ns] = v; c.ns += 1}
			if v, yes := r.popup.?; yes {c.popups[c.np] = v; c.np += 1}
			if v, yes := r.tooltip.?; yes {c.tooltips[c.ntool] = v; c.ntool += 1}
			if v, yes := r.modal.?; yes {c.modals[c.nm] = v; c.nm += 1}
		}
		node(
			c,
			"profiles/actions",
			"profiles/body",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}, gap = 4},
		)
		apply, cancel, reset, reason := "Apply", "Cancel", "Reset", "Not available in this fixture"
		if m.locale ==
		   .Russian {apply, cancel, reset, reason = "Применить", "Отмена", "Сбросить", "Недоступно в этом примере"}
		button(c, "profiles/apply", "profiles/apply-label", "profiles/actions", apply)
		button(c, "profiles/cancel", "profiles/cancel-label", "profiles/actions", cancel)
		button(c, "profiles/reset", "profiles/reset-label", "profiles/actions", reset)
		label(
			c,
			"profiles/reason",
			"profiles/appearance",
			reason,
			{x = {mode = .Fill}, y = {mode = .Content}},
		)
		status := "Applied"; if c.profiles.dirty {status = "Not applied"}; if m.locale == .Russian {status = "Применено"; if c.profiles.dirty {status = "Не применено"}}
		label(
			c,
			"profiles/status",
			"profiles/body",
			status,
			{x = {mode = .Fill}, y = {mode = .Content}},
		)
	}
	if m.page == .Text_Input {sections.compose_name(c, m)}
	if m.page == .Accessibility && !sections.compose_accessibility(c, m, {m, a}) {return false}
	if m.page == .Diagnostics_Performance {sections.compose_performance(c, m, table_width)}
	if m.page == .Composition {sections.compose_nested_route(c, m)}
	if m.page == .Transitions {sections.compose_transitions(c, m)}
	if !sections.compose_content(&c.content, m, atlas) {return false}
	if m.page == .Scroll_Table {
		ok: bool; c.table, ok = sections.new_table(m, a, table_metrics, table_width); if !ok {return false}
		for n in c.table.nodes[:c.table.n] {c.nodes[c.n] = n; c.n += 1}
		for v in c.table.texts[:c.table.nt] {c.texts[c.nt] = v; c.nt += 1}
		for v in c.table.targets[:c.table.ni] {c.targets[c.ni] = v; c.ni += 1}
		c.initial_focus = "table/dataset"
	}
	if m.page == .Layout &&
	   m.layout_details {for &n in c.nodes[:c.n] {if n.id == "layout/fixtures" {n.visible = false}}}
	for n in c.content.nodes[:c.content.n] {c.nodes[c.n] = n; c.n += 1}
	for v in c.content.texts[:c.content.nt] {c.texts[c.nt] = v; c.nt += 1}
	for v in c.content.targets[:c.content.ni] {c.targets[c.ni] = v; c.ni += 1}
	for v in c.content.styles[:c.content.ns] {c.styles[c.ns] = v; c.ns += 1}
	if c.content.ni > 0 && m.page != .Layout {c.initial_focus = c.content.targets[0].id}
	return true
}
node :: sections.page_node
label :: sections.page_label
button :: sections.page_button
destroy_composition :: sections.destroy_page
