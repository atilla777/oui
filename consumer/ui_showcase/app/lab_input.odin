package app

import model "../model"
import base "ui:ui_base"
import collections "ui:ui_collections"
import collection_sdl "ui:ui_collections/sdl"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"

// A departure request is owned by the settings guard, not a background base
// activation. No destination is executed before that guard's decision. Both
// physical and semantic requests converge here, and the upper decision blocks it.
lab_departure_route :: proc(r: ^Runtime, action: interaction.Action) -> (interaction.Code, bool) {
	v, selected := r.content.(^Lab_Menu_Runtime)
	if !selected ||
	   !v.settings ||
	   v.confirm ||
	   v.discard ||
	   action.kind != .Activate {return .Not_Found, false}
	destination: model.Page
	switch action.id {
	case "shell/catalogue":
		destination = .Catalogue
	case "shell/layout":
		destination = .Layout
	case "shell/controls":
		destination = .Controls
	case:
		return .Not_Found, false
	}
	if code := interaction.guard_common(&r.interaction, action.source);
	   code != .Applied {return code, true}
	target, found := interaction.find(&r.interaction.frame, action.id)
	if !found || target.availability != .Blocked_By_Modal {return .Invalid_Action, true}
	if r.model.revision == max(u64) ||
	   base.advance_sequence(&r.publication) != .None {return .Exhausted, true}
	if !consume(r, reader_stamp(&r.live), r.publication.sequence) {return .Invalid_Action, true}
	if !reduce_destination(r, destination) {return .Invalid_Action, true}
	return .Applied, true
}
lab_departure_pointer :: proc(r: ^Runtime, n: backend.Normalized_Input) -> bool {
	v, selected := r.content.(^Lab_Menu_Runtime); if !selected {return false}
	if n.loss {v.departure_press = ""; return false}
	if !n.pointer_button {return false}
	if !current(r) || !v.settings || v.confirm || v.discard || !n.pointer_valid {
		v.departure_press = ""; return false
	}
	id := ""
	for candidate in ([]string{"shell/catalogue", "shell/layout", "shell/controls"}) {
		node, found := layout.find(&r.live.geometry, candidate)
		if found &&
		   node.visible &&
		   node.enabled &&
		   base.contains(node.bounds, n.x / r.model.scale, n.y / r.model.scale) &&
		   base.contains(
			   node.paint_clip,
			   n.x / r.model.scale,
			   n.y / r.model.scale,
		   ) {id = candidate; break}
	}
	if n.down {
		if id == "" {return false}
		if n.front {v.departure_press, v.departure_attempt = id, r.publication.attempt}
		return true
	}
	press := v.departure_press; v.departure_press = ""
	if press == "" {return false}
	if id == press &&
	   v.departure_attempt ==
		   r.publication.attempt {lab_departure_route(r, {.Activate, id, .Mouse, false})}
	return true
}

// One combined logical order, borrowing the already layer-ordered interaction.
// Collection rows are one logical stop per list, not separate physical handlers.
lab_inventory_navigation :: proc(r: ^Runtime, action: interaction.Action) -> interaction.Code {
	v, _ := r.content.(^Lab_Inventory_Runtime)
	if code := interaction.guard_common(&r.interaction, action.source);
	   code != .Applied {return code}
	stops: [96]string; count, start := 0, -1
	active, _, inside := collections.decode_item_node_id(r.interaction.focus_id)
	for target in r.interaction.frame.targets {
		id := target.description.id
		if _, _, row := collections.decode_item_node_id(id); row {continue}
		stop := ""
		for &state in v.states {
			cs := state.frame.collections[0]
			if id == cs.description.scroll_id && state.frame.owner_gate == .Applied {
				stop = cs.focus_node_id
				if inside && active == cs.description.id {start = count}
			}
		}
		if stop == "" && target.availability == .Applied {stop = id}
		if stop == "" {continue}
		if stop == r.interaction.focus_id {start = count}
		stops[count] = stop; count += 1
	}
	if count == 0 {return .Not_Found}
	if action.backwards && start < 0 {start = 0}
	chosen := (start + 1) % count
	if action.backwards {chosen = (start - 1 + count) % count}
	id := stops[chosen]
	collection, item, row := collections.decode_item_node_id(id)
	if row {
		for &state in v.states {if state.frame.collections[0].description.id == collection {
				result := collections.dispatch(
					&state,
					&r.interaction,
					{
						kind = .Focus,
						collection_id = collection,
						item_id = item,
						source = action.source,
					},
				)
				if result.dispatch.code == .Allocation {lab_allocation_failure(r)}
				return result.dispatch.code
			}}
	}
	return interaction.dispatch(&r.interaction, {.Focus, id, action.source, false}).code
}
lab_collection_input :: proc(r: ^Runtime, n: backend.Normalized_Input) -> bool {
	v, _ := r.content.(^Lab_Inventory_Runtime)
	if n.has_action &&
	   n.action.kind == .Navigate {lab_inventory_navigation(r, n.action); return true}
	selected := ""
	if n.event.type == .MOUSE_WHEEL && n.pointer_valid {
		if !interaction.ready(&r.interaction) {return false}
		for &state in v.states {
			cs := state.frame.collections[0]
			if state.frame.owner_gate == .Applied &&
			   base.contains(
				   cs.viewport,
				   n.x / r.model.scale,
				   n.y / r.model.scale,
			   ) {selected = cs.description.id; break}
		}
	} else if n.pointer_button && n.pointer_valid {
		target, code := hit_pointer(r, n.x, n.y)
		if code ==
		   .Applied {collection, _, valid := collections.decode_item_node_id(target.description.id); if valid {selected = collection}}
	} else {
		collection, _, valid := collections.decode_item_node_id(r.interaction.focus_id)
		if valid {selected = collection}
	}
	if selected == "" {return false}
	for &state in v.states {if state.frame.collections[0].description.id == selected {
			x := collection_sdl.handle(&state, &r.interaction, n)
			if x.result.dispatch.code == .Allocation {lab_allocation_failure(r); return true}
			if x.consumed {lab_inventory_select(r, x.result)}
			return x.consumed
		}}
	return false
}
