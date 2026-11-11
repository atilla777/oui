package sections

import model "../model"
import "core:fmt"
import "core:mem"
import "core:strings"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import text "ui:ui_text"

Table :: struct {
	nodes:     [140]layout.Node,
	texts:     [110]text.Text_Node,
	targets:   [35]interaction.Target,
	n, nt, ni: int,
	tracks:    [3]layout.Track,
	row:       [1]layout.Track,
	bytes:     [34][8][64]u8,
	allocator: mem.Allocator,
}
new_table :: proc(
	m: model.Model,
	a: mem.Allocator,
	metrics: text.Text_Layout_Metrics = {},
	width: f64 = 1280,
) -> (
	^Table,
	bool,
) {
	c, e := new(Table, a); if e != nil {return nil, false}
	c.allocator = a; compose_table(c, m)
	if metrics.measure_line != nil {
		widths: [3]f64; height := f64(0)
		for t in c.texts[:c.nt] {
			if t.id == "table/dataset" || t.id == "table/fixture" {continue}
			column := -1
			for n in c.nodes[:c.n] {if n.id == t.id {l, _ := n.layout.?; column = l.column; break}}
			if column < 0 || column > 2 {continue}
			measured, error := metrics.measure_line(t.text, "own", 14, metrics.user)
			if error != .None {destroy_table(&c); return nil, false}
			widths[column] = max(widths[column], measured.surface_extent.w + 8)
			height = max(height, measured.surface_extent.h + 8)
		}
		widths[0] += max(0, width - 12 - widths[0] - widths[1] - widths[2])
		for value, i in widths {c.tracks[i].value = value}; c.row[0].value = height
		for &n in c.nodes[:c.n] {
			l, _ := n.layout.?
			if n.id == "table/header" || strings.has_prefix(n.id, "table/item-") {l.y = {
					mode  = .Fixed,
					value = height,
				}}
			if n.role == .Content &&
			   (strings.has_prefix(n.id, "table/header/") ||
					   strings.has_prefix(n.id, "table/item-")) {l.padding = {4, 4, 4, 4}}
			n.layout = l
		}
	}
	return c, true
}
destroy_table :: proc(c: ^^Table) {if c^ != nil {free(c^, c^.allocator); c^ = nil}}
table_node :: proc(c: ^Table, id, parent: string, kind: layout.Kind, l: layout.Layout) {
	c.nodes[c.n] = {
		id      = id,
		parent  = parent,
		role    = kind,
		layout  = l,
		enabled = true,
		visible = true,
	}; c.n += 1
}
table_label :: proc(c: ^Table, id, parent, value: string, l: layout.Layout) {
	table_node(
		c,
		id,
		parent,
		.Content,
		l,
	); c.texts[c.nt] = {id, value, {"own"}, 14, {vertical = .Center}}; c.nt += 1
}
table_button :: proc(c: ^Table, id, parent, value: string) {
	table_label(c, id, parent, value, {x = {mode = .Fill}, y = {mode = .Fixed, value = 28}})
	c.targets[c.ni] = {id, "button", true, true}; c.ni += 1
}
// A/B retain item-00..32 and quantity=99 for item-05 in B. Reconciliation
// belongs to ui_scroll, never to a remembered array index in this consumer.
compose_table :: proc(c: ^Table, m: model.Model) {
	dataset := "A / 32"; if m.table_dataset == 1 {dataset = "B / 33"}
	table_button(c, "table/dataset", "root", fmt.bprintf(c.bytes[33][6][:], "G10 / %s", dataset))
	table_button(
		c,
		"table/fixture",
		"root",
		"Full / Removed / Reverse / Short / Empty" if m.locale == .English else "Все / Удаление / Обратно / Коротко / Пусто",
	)
	c.tracks = {
		{mode = .Fixed, value = 400},
		{mode = .Fixed, value = 200},
		{mode = .Fixed, value = 100},
	}
	c.row = {{mode = .Fixed, value = 28}}
	table_node(
		c,
		"table/header",
		"root",
		.Grid,
		{
			x = {mode = .Fill},
			y = {mode = .Fixed, value = 28},
			columns = c.tracks[:],
			rows = c.row[:],
		},
	)
	en := [3]string {
		"Item",
		"Kind",
		"Quantity",
	}; ru := [3]string{"Предмет", "Вид", "Количество"}
	for title, j in en {
		value := title; if m.locale == .Russian {value = ru[j]}
		id := fmt.bprintf(c.bytes[33][j][:], "table/header/%d", j)
		table_label(
			c,
			id,
			"table/header",
			value,
			{x = {mode = .Fill}, y = {mode = .Fill}, column = j},
		)
	}
	table_node(
		c,
		"table/viewport",
		"root",
		.Stack,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 224}, overflow = .Clip},
	)
	table_node(
		c,
		"table/content",
		"table/viewport",
		.Column,
		{x = {mode = .Fill}, y = {mode = .Content}},
	)
	count := 32 + m.table_dataset
	if m.table_fixture == 3 {count = 3}; if m.table_fixture == 4 {count = 0}
	for i in 0 ..< count {
		n := i + 1 - m.table_dataset; if m.table_fixture == 2 {n = count - i - m.table_dataset}
		if m.table_fixture == 1 && n == 5 {continue}
		id := fmt.bprintf(c.bytes[i][0][:], "table/item-%02d", n)
		table_node(
			c,
			id,
			"table/content",
			.Grid,
			{
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 28},
				columns = c.tracks[:],
				rows = c.row[:],
			},
		)
		c.targets[c.ni] = {id, "row", true, true}; c.ni += 1
		quantity := n + 1; if m.table_dataset == 1 && n == 5 {quantity = 99}
		marker := "  "; if m.table_selected == n + 1 {marker = "* "}
		values := [3]string {
			fmt.bprintf(
				c.bytes[i][4][:],
				"%s%s %02d",
				marker,
				"Item" if m.locale == .English else "Предмет",
				n,
			),
			"Supply" if m.locale == .English else "Припасы",
			fmt.bprintf(c.bytes[i][5][:], "%d", quantity),
		}
		for value, j in values {
			cell := fmt.bprintf(c.bytes[i][j + 1][:], "%s/%d", id, j)
			table_label(
				c,
				cell,
				id,
				value,
				{
					x = {mode = .Fill},
					y = {mode = .Fixed, value = 28},
					column = j,
					padding = {4, 0, 4, 0},
				},
			)
		}
	}
}
