package ui_controls

import interaction "../ui_interaction"
import layers "../ui_layers"
import layout "../ui_layout"
import scroll "../ui_scroll"
import style "../ui_style"
import text "../ui_text"
import "core:fmt"
import "core:mem"
import "core:strings"

Composition :: struct {
	control:           Description,
	nodes:             [dynamic]layout.Node,
	targets:           [dynamic]interaction.Target,
	styles:            [dynamic]style.Description,
	texts:             [dynamic]text.Text_Node,
	scroll:            [dynamic]scroll.Description,
	popup:             Maybe(layers.Popup),
	tooltip:           Maybe(layers.Tooltip),
	modal:             Maybe(layers.Modal),
	strings:           [dynamic]string,
	font_id:           string,
	font_declarations: []style.Declaration,
	allocator:         mem.Allocator,
}
compose_control :: proc(
	d: Description,
	parent, layer_parent: string,
	a: mem.Allocator,
	enabled: bool = true,
	visible: bool = true,
	font: style.Font_ID = {"default"},
	font_size: f64 = 16,
) -> (
	Composition,
	Error,
) {
	if e := validate_values(d); e.code != .None {return {}, e}
	p := Composition {
		allocator = a,
		nodes     = make([dynamic]layout.Node, 0, 0, a),
		targets   = make([dynamic]interaction.Target, 0, 0, a),
		styles    = make([dynamic]style.Description, 0, 0, a),
		texts     = make([dynamic]text.Text_Node, 0, 0, a),
		scroll    = make([dynamic]scroll.Description, 0, 0, a),
		strings   = make([dynamic]string, 0, 0, a),
	}
	complete := false; defer {if !complete {destroy_composition(&p)}}
	e: mem.Allocator_Error; p.control, e = clone_description(d, a); if e != nil {return {}, {code = .Allocation}}
	c := &p.control
	if c.node_id ==
	   "" {id, ok := part_id(c.id, "main", a); if !ok {return {}, {code = .Allocation}}; c.node_id = id}
	if c.kind == .Select || c.kind == .Dialog || c.kind == .Tooltip {
		if c.layer_id ==
		   "" {id, ok := part_id(c.id, "layer", a); if !ok {return {}, {code = .Allocation}}; c.layer_id = id}
		if c.kind !=
		   .Select {id, error := strings.clone(c.layer_id, a); if error != nil {return {}, {code = .Allocation}}; delete(c.node_id, a); c.node_id = id}
	}
	for &item in c.items {if item.node_id == "" {id, ok := item_node_id(c.id, item.id, a); if !ok {return {}, {code = .Allocation}}; item.node_id = id}}
	p.font_id, e = strings.clone(font.id, a); if e != nil {return {}, {code = .Allocation}}
	p.font_declarations, e = make(
		[]style.Declaration,
		2,
		a,
	); if e != nil {return {}, {code = .Allocation}}
	p.font_declarations[0] = {
		.Font,
		style.Font_ID{p.font_id},
	}; p.font_declarations[1] = {.Font_Size, font_size}
	root_parent := parent; root_kind := layout.Kind.Column
	l := layout.Layout {
		x = {mode = .Content},
		y = {mode = .Content},
		gap = 4,
	}
	target := c.kind == .Checkbox || c.kind == .Toggle || c.kind == .Slider || c.kind == .Select
	if c.kind == .Tabs {root_kind = .Row}
	if c.kind == .List {root_kind = .Stack; l = {
			x = {mode = .Fixed, value = 180},
			y = {mode = .Fixed, value = 120},
		}}
	if c.kind == .Tooltip || (c.kind == .Dialog && c.open) {root_parent = layer_parent}
	if c.kind == .Select {l.gap = 0}
	role := "box"; if target {role = "button"}
	if !recipe_node(
		&p,
		c.node_id,
		root_parent,
		root_kind,
		"",
		l,
		enabled,
		visible && (c.kind != .Dialog || c.open),
		target,
		role,
		c.checked,
		font_size,
	) {return {}, {code = .Allocation}}
	if c.kind == .Checkbox || c.kind == .Toggle {
		mark := "[ ]"; if c.checked {mark = "[x]"}
		state := ""; if c.kind == .Toggle {state = c.off_text; if c.checked {state = c.on_text}}
		value, error := strings.concatenate([]string{mark, " ", c.label, " ", state}, a)
		if error != nil {return {}, {code = .Allocation}}
		if !remember(&p, value) ||
		   !recipe_child(
				   &p,
				   "label",
				   c.node_id,
				   .Content,
				   value,
				   {},
				   true,
				   true,
				   false,
				   "label",
				   false,
				   font_size,
			   ) {return {}, {code = .Allocation}}
	} else if c.kind == .Slider {
		track, ok := part_id(
			c.id,
			"track",
			a,
		); if !ok {return {}, {code = .Allocation}}; delete(c.track_id, a); c.track_id = track
		buffer: [32]u8; number := fmt.bprintf(buffer[:], "%d", c.value)
		value, error := strings.concatenate(
			[]string{c.label, ": ", number},
			a,
		); if error != nil {return {}, {code = .Allocation}}
		if !remember(&p, value) ||
		   !recipe_child(
				   &p,
				   "value",
				   c.node_id,
				   .Content,
				   value,
				   {},
				   true,
				   true,
				   false,
				   "label",
				   false,
				   font_size,
			   ) {return {}, {code = .Allocation}}
		if !recipe_node(
			&p,
			track,
			c.node_id,
			.Absolute,
			"",
			{x = {mode = .Fixed, value = 120}, y = {mode = .Fixed, value = 10}},
			true,
			true,
			false,
			"box",
			false,
			font_size,
		) {return {}, {code = .Allocation}}
		if !recipe_child(
			&p,
			"rail",
			track,
			.Box,
			"",
			{x = {mode = .Fixed, value = 120}, y = {mode = .Fixed, value = 2}, offset = {0, 4}},
			true,
			true,
			false,
			"box",
			false,
			font_size,
		) {return {}, {code = .Allocation}}
		ratio := f64(
			0,
		); if c.maximum > c.minimum && c.value >= c.minimum && c.value <= c.maximum {ratio = f64(i128(c.value) - i128(c.minimum)) / f64(i128(c.maximum) - i128(c.minimum))}
		if !recipe_child(
			&p,
			"thumb",
			track,
			.Box,
			"",
			{
				x = {mode = .Fixed, value = 8},
				y = {mode = .Fixed, value = 10},
				anchor = {ratio, 0},
				pivot = {ratio, 0},
			},
			true,
			true,
			false,
			"box",
			false,
			font_size,
		) {return {}, {code = .Allocation}}
		if c.decrement_id ==
		   "" {id, success := part_id(c.id, "decrement", a); if !success {return {}, {code = .Allocation}}; c.decrement_id = id}
		if c.increment_id ==
		   "" {id, success := part_id(c.id, "increment", a); if !success {return {}, {code = .Allocation}}; c.increment_id = id}
		if !recipe_node(
			   &p,
			   c.decrement_id,
			   c.node_id,
			   .Content,
			   "-",
			   {},
			   true,
			   true,
			   true,
			   "button",
			   false,
			   font_size,
		   ) ||
		   !recipe_node(
				   &p,
				   c.increment_id,
				   c.node_id,
				   .Content,
				   "+",
				   {},
				   true,
				   true,
				   true,
				   "button",
				   false,
				   font_size,
			   ) {return {}, {code = .Allocation}}
	} else if c.kind == .Select {
		if !recipe_child(
			&p,
			"label",
			c.node_id,
			.Content,
			c.label,
			{},
			true,
			true,
			false,
			"label",
			false,
			font_size,
		) {return {}, {code = .Allocation}}
		if !recipe_node(
			&p,
			c.layer_id,
			layer_parent,
			.Column,
			"",
			{},
			enabled,
			visible && c.open,
			false,
			"box",
			false,
			font_size,
		) {return {}, {code = .Allocation}}
		p.popup = layers.Popup{c.layer_id, c.owner_scope_id, c.node_id}
	} else if c.kind == .Dialog || c.kind == .Tooltip {
		if !recipe_child(
			   &p,
			   "title",
			   c.node_id,
			   .Content,
			   c.label,
			   {},
			   true,
			   true,
			   false,
			   "label",
			   false,
			   font_size,
		   ) ||
		   !recipe_child(
				   &p,
				   "body",
				   c.node_id,
				   .Content,
				   c.body,
				   {},
				   true,
				   true,
				   false,
				   "label",
				   false,
				   font_size,
			   ) {return {}, {code = .Allocation}}
		if c.kind == .Tooltip {p.tooltip = layers.Tooltip{c.layer_id, c.owner_scope_id}}
	}
	items_parent := c.node_id
	if c.kind == .List {
		if !recipe_child(
			&p,
			"content",
			c.node_id,
			.Column,
			"",
			{x = {mode = .Fill}},
			true,
			true,
			false,
			"box",
			false,
			font_size,
		) {return {}, {code = .Allocation}}
		items_parent = p.nodes[len(p.nodes) - 1].id
		if _, error := append(&p.scroll, scroll.Description{c.node_id, items_parent});
		   error != nil {return {}, {code = .Allocation}}
	} else if c.kind == .Select {items_parent = c.layer_id}
	for item in c.items {if !recipe_node(&p, item.node_id, items_parent, .Content, item.label, {}, true, true, true, "button", c.selected_id != "" && c.selected_id == item.id, font_size) {return {}, {code = .Allocation}}}
	if c.kind == .Dialog && c.open {
		if c.initial_focus_id == "" &&
		   len(c.items) >
			   0 {id, error := strings.clone(c.items[0].node_id, a); if error != nil {return {}, {code = .Allocation}}; c.initial_focus_id = id}
		p.modal = layers.Modal{c.layer_id, c.initial_focus_id, c.cancel_id != ""}
	}
	complete = true; return p, {}
}
@(private)
remember :: proc(p: ^Composition, value: string) -> bool {
	if _, e := append(&p.strings, value);
	   e != nil {delete(value, p.allocator); return false}; return true
}
@(private)
recipe_child :: proc(
	p: ^Composition,
	part, parent: string,
	kind: layout.Kind,
	value: string,
	l: layout.Layout,
	enabled, visible, target: bool,
	role: string,
	selected: bool,
	font_size: f64,
) -> bool {
	id, ok := part_id(
		p.control.id,
		part,
		p.allocator,
	); if !ok {return false}; defer delete(id, p.allocator)
	return recipe_node(
		p,
		id,
		parent,
		kind,
		value,
		l,
		enabled,
		visible,
		target,
		role,
		selected,
		font_size,
	)
}
destroy_composition :: proc(p: ^Composition) {
	a := p.allocator
	for n in p.nodes {delete(n.id, a); delete(n.parent, a)}
	for s in p.strings {delete(s, a)}
	delete(
		p.nodes,
	); delete(p.targets); delete(p.styles); delete(p.texts); delete(p.scroll); delete(p.strings)
	delete(
		p.font_id,
		a,
	); delete(p.font_declarations, a); destroy_description(&p.control, a); p^ = {}
}
item_node_id :: proc(namespace, item: string, a: mem.Allocator) -> (string, bool) {
	first, second: [32]u8
	x := fmt.bprintf(
		first[:],
		"%d:",
		len(namespace),
	); y := fmt.bprintf(second[:], "%d:", len(item))
	id, e := strings.concatenate([]string{x, namespace, y, item}, a); return id, e == nil
}
@(private)
part_id :: proc(id, part: string, a: mem.Allocator) -> (string, bool) {
	b: [32]u8; n := fmt.bprintf(b[:], "%d:", len(id))
	value, e := strings.concatenate(
		[]string{"control:", n, id, ":", part},
		a,
	); return value, e == nil
}
@(private)
recipe_node :: proc(
	p: ^Composition,
	id, parent: string,
	kind: layout.Kind,
	value: string,
	l: layout.Layout,
	enabled, visible, target: bool,
	role: string,
	selected: bool,
	font_size: f64,
) -> bool {
	owned, e := strings.clone(id, p.allocator); if e != nil {return false}
	owner, e2 := strings.clone(
		parent,
		p.allocator,
	); if e2 != nil {delete(owned, p.allocator); return false}
	n := layout.Node {
		id      = owned,
		parent  = owner,
		role    = kind,
		layout  = l,
		enabled = enabled,
		visible = visible,
	}
	if _, error := append(&p.nodes, n);
	   error != nil {delete(owned, p.allocator); delete(owner, p.allocator); return false}
	s := style.Description {
		id   = owned,
		role = role,
	}; s.appearance.local.states[.Normal] = p.font_declarations
	if selected {s.states += {.Selected}}
	if _, error := append(&p.styles, s); error != nil {return false}
	if target {if _, error := append(&p.targets, interaction.Target{owned, "button", enabled, visible}); error != nil {return false}}
	if kind ==
	   .Content {if _, error := append(&p.texts, text.Text_Node{owned, value, {p.font_id}, font_size, {}}); error != nil {return false}}
	return true
}
