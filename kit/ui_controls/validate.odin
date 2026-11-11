package ui_controls

import interaction "../ui_interaction"
import layers "../ui_layers"
import layout "../ui_layout"
import "core:fmt"
import "core:strings"

@(private)
within :: proc(f: ^interaction.Frame, id, root: string) -> bool {
	for at := id;
	    at !=
	    ""; {if at == root {return true}; n, ok := interaction.find(f, at); if !ok {return false}; at = n.parent}
	return false
}
@(private)
binding :: proc(c: Description, k: int) -> string {
	if k ==
	   0 {return c.node_id}; if k == 1 {return c.decrement_id}; if k == 2 {return c.increment_id}; return c.items[k - 3].node_id
}
@(private)
item_node_matches :: proc(namespace, item, node: string) -> bool {
	first, second: [32]u8
	prefix := fmt.bprintf(
		first[:],
		"%d:",
		len(namespace),
	); suffix := fmt.bprintf(second[:], "%d:", len(item))
	rest := node
	for part in ([]string{prefix, namespace, suffix, item}) {if !strings.has_prefix(rest, part) {return false}; rest = rest[len(part):]}
	return rest == ""
}
@(private)
visible :: proc(f: ^interaction.Frame, g: ^layout.Frame, id: string) -> (bool, bool) {
	if g != nil {n, ok := layout.find(g, id); if !ok {return false, false}; return n.visible, true}
	n, ok := interaction.find(
		f,
		id,
	); if !ok {return false, false}; return n.description.visible, true
}
@(private)
validate :: proc(
	f: ^interaction.Frame,
	l: layers.Layers,
	ds: []Description,
	g: ^layout.Frame = nil,
) -> Error {
	for c, k in ds {
		bad := Error{.Invalid_Control, c.id, c.node_id}
		if e := validate_values(c); e.code != .None {return e}
		n, ok := interaction.find(f, c.node_id); if !ok {return bad}
		for prior in ds[:k] {if prior.id == c.id {return {.Duplicate_Ownership, c.id, c.node_id}}}
		if c.kind == .Checkbox ||
		   c.kind == .Toggle ||
		   c.kind == .Slider ||
		   c.kind == .Select {if n.description.role != "button" {return bad}
		} else if n.description.role == "button" {return bad}
		if c.kind == .Slider {
			if c.track_id !=
			   "" {track, found := interaction.find(f, c.track_id); if !found || track.description.role == "button" || !within(f, c.track_id, c.node_id) {return bad}}
		}
		if c.kind == .Select {
			found :=
				false; for p in l.popups {if p.root_id == c.layer_id && p.owner_scope_id == c.owner_scope_id && p.return_focus_id == c.node_id {found = true}}
			shown, known := visible(
				f,
				g,
				c.layer_id,
			); if !found || !known || shown != c.open {return bad}
		}
		if c.kind == .Tooltip {
			found :=
				false; for tip in l.tooltips {if tip.root_id == c.layer_id && tip.owner_scope_id == c.owner_scope_id {found = true}}
			_, trigger := interaction.find(f, c.trigger_id)
			if !found || !trigger || c.node_id != c.layer_id {return bad}
		}
		if c.kind == .Dialog {
			found :=
				false; for m in l.modals {if m.root_id == c.layer_id && m.initial_focus_id == c.initial_focus_id && m.cancel_allowed == (c.cancel_id != "") {found = true}}
			if found != c.open || c.node_id != c.layer_id {return bad}
			cancel :=
				c.cancel_id ==
				""; for item in c.items {if item.id == c.cancel_id {cancel = true}}; if !cancel {return {.Invalid_Item, c.id, c.node_id}}
		}
		for item in c.items {
			if item.node_id == "" {return {.Invalid_Item, c.id, item.node_id}}
			if c.kind == .List &&
			   !item_node_matches(
					   c.id,
					   item.id,
					   item.node_id,
				   ) {return {.Invalid_Item, c.id, item.node_id}}
			root := c.node_id; if c.kind == .Select || c.kind == .Dialog {root = c.layer_id}
			if !within(f, item.node_id, root) {return {.Invalid_Item, c.id, item.node_id}}
		}
		for j in 0 ..< 3 + len(c.items) {
			id := binding(c, j); if id == "" {continue}
			b, found := interaction.find(
				f,
				id,
			); if !found || (j > 0 && b.description.role != "button") {return {.Invalid_Control, c.id, id}}
			if b.activation_owner != "" {return {.Duplicate_Ownership, c.id, id}}
			for previous in 0 ..< j {if binding(c, previous) == id {return {.Duplicate_Ownership, c.id, id}}}
			for prior in ds[:k] {for index in 0 ..< 3 + len(prior.items) {if binding(prior, index) == id {return {.Duplicate_Ownership, c.id, id}}}}
		}
	}
	return {}
}
@(private)
validate_values :: proc(c: Description) -> Error {
	bad := Error{.Invalid_Control, c.id, c.node_id}
	if c.id == "" || c.kind < .Checkbox || c.kind > .Dialog {return bad}
	if c.kind != .Slider &&
	   (c.track_id != "" ||
			   c.minimum != 0 ||
			   c.maximum != 0 ||
			   c.value != 0 ||
			   c.step != 0 ||
			   c.decrement_id != "" ||
			   c.increment_id != "") {return bad}
	if c.kind != .Checkbox && c.kind != .Toggle && c.checked {return bad}
	if c.kind == .Checkbox ||
	   c.kind == .Toggle ||
	   c.kind == .Slider ||
	   c.kind == .Tooltip {if len(c.items) != 0 || c.selected_id != "" {return bad}}
	if c.kind == .Slider {
		span := i128(c.maximum) - i128(c.minimum)
		if span < 0 ||
		   span > i128(max(i64)) ||
		   c.step <= 0 ||
		   span % i128(c.step) != 0 {return {.Invalid_Range, c.id, c.node_id}}
		if c.value < c.minimum ||
		   c.value > c.maximum ||
		   (i128(c.value) - i128(c.minimum)) % i128(c.step) !=
			   0 {return {.Invalid_Value, c.id, c.node_id}}
	}
	selected := c.selected_id == ""
	for item, k in c.items {if item.id == "" {return {.Invalid_Item, c.id, item.node_id}}; for prior in c.items[:k] {if prior.id == item.id {return {.Invalid_Item, c.id, item.node_id}}}; if item.id == c.selected_id {selected = true}}
	if !selected {return {.Invalid_Item, c.id, c.node_id}}
	return {}
}
