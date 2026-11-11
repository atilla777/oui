package sections

import collections "ui:ui_collections"
import layout "ui:ui_layout"

compose_collection_page :: proc(
	r: Page_Input,
	c: ^Page_Composition,
	frame: ^collections.Frame,
	materialized: []layout.Node,
	width: f64,
) -> bool {
	d := frame.collections[0].description
	label(
		c,
		"collections/title",
		"root",
		"G11 / 10 000 / List-Grid",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	for group in 0 ..< 2 {
		parents := [2]string{"collections/data-actions", "collections/reveal-actions"}
		node(
			c,
			parents[group],
			"root",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}, gap = 4},
		)
		if r.model.page == .Diagnostics_Performance {l := c.nodes[c.n - 1].layout.?; l.x = {
				mode  = .Fixed,
				value = width,
			}; c.nodes[c.n - 1].layout = l}
		ids := [7]string {
			"collections/mode",
			"collections/reverse",
			"collections/delete",
			"collections/restore",
			"collections/start",
			"collections/middle",
			"collections/end",
		}
		labels := [7]string {
			"List / Grid",
			"Reverse",
			"Delete",
			"Restore",
			"Start",
			"Middle",
			"End",
		}
		if r.model.locale ==
		   .Russian {labels = {"Список / Сетка", "Обратно", "Удалить", "Вернуть", "Начало", "Середина", "Конец"}}
		label_ids := [7]string {
			"collections/mode-label",
			"collections/reverse-label",
			"collections/delete-label",
			"collections/restore-label",
			"collections/start-label",
			"collections/middle-label",
			"collections/end-label",
		}
		for id, i in ids {if (group == 0 && i < 4) || (group == 1 && i >= 4) {
				button(c, id, label_ids[i], parents[group], labels[i])
				if r.model.page == .Diagnostics_Performance &&
				   id == "collections/mode" &&
				   width < 600 {
					for &n in c.nodes[:c.n] {if n.id == id {l := n.layout.?; l.x = {
								mode  = .Fixed,
								value = 140,
							}; n.layout = l}}
				}
			}}
	}
	node(
		c,
		d.scroll_id,
		"root",
		.Stack,
		{x = {mode = .Fixed, value = width}, y = {mode = .Fixed, value = 224}, overflow = .Clip},
	)
	c.targets[c.ni] = {d.scroll_id, "", true, true}; c.ni += 1
	node(c, d.content_id, d.scroll_id, .Column, collections.content_layout(frame))
	for row in materialized {
		if c.n == len(c.nodes) {return false}
		c.nodes[c.n] = row
		_, item, valid := collections.decode_item_node_id(row.id)
		if valid {
			c.nodes[c.n].role = .Content
			if c.ni == len(c.targets) || c.nt == len(c.texts) {return false}
			c.targets[c.ni] = {row.id, "button", row.enabled, true}; c.ni += 1
			c.texts[c.nt] = {row.id, item, {"own"}, 14, {vertical = .Center}}; c.nt += 1
		}
		c.n += 1
	}
	c.initial_focus = "collections/mode"; return true
}
