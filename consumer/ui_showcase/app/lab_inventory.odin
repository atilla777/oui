package app

import cards "../../gestures_demo/model"
import sections "../sections"
import "core:fmt"
import base "ui:ui_base"
import collections "ui:ui_collections"
import gestures "ui:ui_gestures"
import gesture_sdl "ui:ui_gestures/sdl"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"

Lab_Inventory_Runtime :: struct {
	selection_buffer:     [256]u8,
	gesture:              gestures.State,
	input:                gesture_sdl.Adapter,
	pending:              cards.Drop_Request,
	pending_stamp:        base.Frame_Stamp,
	has_pending:          bool,
	token, pending_token: u64,
	source_panel:         int,
	outcome:              cards.Outcome,
	states:               [2]collections.State,
	items:                [2][12]collections.Collection_Item,
	model:                ^cards.State,
}
Lab_Inventory_Reader :: struct {
	gesture: gestures.Frame,
	frames:  [2]collections.Frame,
}
Lab_Inventory_Candidates :: struct {
	values: [2]collections.Candidate,
	nodes:  [2][]layout.Node,
}
LAB_LISTS :: [2]string{"lab-left", "lab-right"}
LAB_CARD_TYPES := [1]string{"card"}
LAB_VIEWPORTS :: [2]string{"lab/left-viewport", "lab/right-viewport"}
LAB_CONTENTS :: [2]string{"lab/left-content", "lab/right-content"}
destroy_lab_inventory_candidates :: proc(r: ^Runtime, p: ^Lab_Inventory_Candidates) {
	for &value in p.values {collections.destroy_candidate(&value)}
	for nodes in p.nodes {collections.destroy_nodes(nodes, r.allocator)}
	p^ = {}
}
compose_lab_inventory :: proc(
	r: ^Runtime,
	c: ^Page_Composition,
	stamp: base.Frame_Stamp,
	p: ^Lab_Inventory_Candidates,
) -> bool {
	v, _ := r.content.(^Lab_Inventory_Runtime)
	if v.model == nil {return false}
	label(
		c,
		"lab/inventory-title",
		"root",
		lab_text(r, .Inventory),
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	node(
		c,
		"lab/headers",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 8},
	)
	label(
		c,
		"panel-left",
		"lab/headers",
		lab_text(r, .Backpack),
		{x = {mode = .Fill}, y = {mode = .Fill}},
	)
	label(
		c,
		"panel-right",
		"lab/headers",
		lab_text(r, .Chest),
		{x = {mode = .Fill}, y = {mode = .Fill}},
	)
	height := min(128, max(0, r.drawable.h / r.model.scale - 380))
	node(
		c,
		"lab/lists",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = height}, gap = 8},
	)
	w := max(0, (r.drawable.w / r.model.scale - 20) / 2)
	lists, viewports, contents := LAB_LISTS, LAB_VIEWPORTS, LAB_CONTENTS
	for index in 0 ..< 2 {
		panel := v.model.panels[index]
		selected := ""
		for i in 0 ..< panel.count {
			at := i; if r.model.lab_reverse {at = panel.count - i - 1}
			id := panel.cards[at]; v.items[index][i] = {id, id, true, true, ""}
			if id == r.model.lab_selected {selected = id}
		}
		d := collections.Collection_Description {
			id            = lists[index],
			scroll_id     = viewports[index],
			content_id    = contents[index],
			items         = v.items[index][:panel.count],
			data_revision = v.model.revision,
			reset_epoch   = 1,
			height        = 32,
			gap           = 4,
			overscan_rows = 1,
			selected_id   = selected,
		}
		offset := f64(
			0,
		); if len(v.states[index].frame.collections) > 0 {offset = v.states[index].frame.collections[0].offset}
		error: collections.Update_Error
		p.values[index], error = collections.prepare(
			&v.states[index],
			stamp,
			d,
			{6 + f64(index) * (w + 8), 172, w, height},
			offset,
			a = r.allocator,
			focus_id = r.interaction.focus_id,
		)
		if error.code != .None {return false}
		p.nodes[index], error = collections.materialize(&p.values[index].frame, r.allocator)
		if error.code != .None {return false}
		node(
			c,
			d.scroll_id,
			"lab/lists",
			.Stack,
			{x = {mode = .Fill}, y = {mode = .Fill}, overflow = .Clip},
		)
		c.targets[c.ni] = {d.scroll_id, "", true, true}; c.ni += 1
		node(
			c,
			d.content_id,
			d.scroll_id,
			.Column,
			collections.content_layout(&p.values[index].frame),
		)
		for row in p.nodes[index] {
			c.nodes[c.n] = row
			_, item, valid := collections.decode_item_node_id(row.id)
			if valid {
				c.nodes[c.n].role = .Content
				c.targets[c.ni] = {row.id, "button", row.enabled, true}; c.ni += 1
				c.texts[c.nt] = {row.id, item, {"own"}, 14, {vertical = .Center}}; c.nt += 1
				c.texts[c.nt - 1].text = lab_card_name(r, item)
			}
			c.n += 1
		}
	}
	lab_button(c, "lab/reverse", "lab/reverse-label", "root", lab_text(r, .Reverse))
	if r.model.lab_selected != "" {
		node(
			c,
			"lab/selection-row",
			"root",
			.Row,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, gap = 4},
		)
		source := ""
		for &panel, index in v.model.panels {for id in panel.cards[:panel.count] {if id == r.model.lab_selected {source = lab_text(r, .Backpack if index == 0 else .Chest)}}}
		label(
			c,
			"lab/selected",
			"lab/selection-row",
			fmt.bprintf(
				v.selection_buffer[:],
				"%s / %s / %s",
				r.model.lab_selected,
				lab_card_name(r, r.model.lab_selected),
				source,
			),
			{x = {mode = .Fill}, y = {mode = .Fill}},
		)
		lab_button(c, "lab/drag-handle", "lab/drag-label", "lab/selection-row", lab_text(r, .Drag))
	}
	message := Lab_String.Transfer_Ready
	if v.outcome.applied {message = .Transfer_Done} else if v.outcome.reason == .Same_Panel {message = .Transfer_Same} else if v.outcome.reason == .Stale_Model {message = .Transfer_Stale} else if v.outcome.reason != .None {message = .Transfer_Refused} else if v.gesture.result.reason != .None {message = .Transfer_Cancelled}
	label(
		c,
		"lab/transfer-status",
		"root",
		lab_text(r, message),
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
	)
	for id in ([]string{"panel-left", "panel-right"}) {
		c.targets[c.ni] = {id, "", true, true}; c.ni += 1
		c.gestures[c.ngestures] = {
			id           = id,
			node_id      = id,
			kind         = .Drop_Target,
			accept_types = LAB_CARD_TYPES[:],
		}; c.ngestures += 1
	}
	if r.model.lab_selected != "" {
		c.gestures[c.ngestures] = {
			id           = r.model.lab_selected,
			node_id      = "lab/drag-handle",
			kind         = .Drag_Source,
			payload_id   = r.model.lab_selected,
			payload_type = "card",
		}; c.ngestures += 1
	}
	if v.has_pending {
		node(
			c,
			"lab/transfer-modal",
			"shell/root",
			.Column,
			{x = {mode = .Fill}, y = {mode = .Fill}, padding = {100, 240, 100, 100}, gap = 6},
		)
		sections.layer_panel(c, "lab/transfer-modal")
		label(
			c,
			"lab/transfer-title",
			"lab/transfer-modal",
			lab_text(r, .Transfer_Question),
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}},
		)
		label(
			c,
			"lab/transfer-item",
			"lab/transfer-modal",
			v.pending.payload_id,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
		)
		lab_button(
			c,
			"lab/transfer-cancel",
			"lab/transfer-cancel-label",
			"lab/transfer-modal",
			lab_text(r, .Cancel),
		)
		lab_button(
			c,
			"lab/transfer-confirm",
			"lab/transfer-confirm-label",
			"lab/transfer-modal",
			lab_text(r, .Transfer_Confirm),
		)
		c.modals[c.nm] = {"lab/transfer-modal", "lab/transfer-cancel", true}; c.nm += 1
	}
	if len(p.values[0].frame.nodes) >
	   0 {c.initial_focus = p.values[0].frame.collections[0].focus_node_id}
	return true
}
validate_lab_inventory :: proc(r: ^Runtime, p: ^Lab_Inventory_Candidates) -> bool {
	v, _ := r.content.(^Lab_Inventory_Runtime)
	for &candidate, index in p.values {if !collections.validate_candidate(&r.publication, &v.states[index], &candidate) {return false}}
	return true
}
lab_inventory_select :: proc(r: ^Runtime, result: collections.Result) -> bool {
	v, _ := r.content.(^Lab_Inventory_Runtime)
	if e, has := result.event.?; has {
		if r.model.revision == max(u64) ||
		   !consume(r, reader_stamp(&r.live), e.sequence) {return false}
		for &panel in v.model.panels {for id in panel.cards[:panel.count] {if id == e.item_id {
					r.model.lab_selected =
						id; r.model.revision += 1; base.invalidate(&r.publication); return true
				}}}
		return false
	}
	return true
}
lab_inventory_route :: proc(r: ^Runtime, action: interaction.Action) -> (interaction.Code, bool) {
	v, selected := r.content.(^Lab_Inventory_Runtime); if !selected {return .Not_Found, false}
	if action.kind == .Navigate {return lab_inventory_navigation(r, action), true}
	if action.kind != .Activate && action.kind != .Focus {return .Not_Found, false}
	id := action.id; if id == "" {id = r.interaction.focus_id}
	collection, item, valid := collections.decode_item_node_id(id)
	if !valid {return .Not_Found, false}
	lists := LAB_LISTS
	for &state, index in v.states {if lists[index] == collection {
			result := collections.dispatch(
				&state,
				&r.interaction,
				{
					kind = .Focus if action.kind == .Focus else .Activate,
					collection_id = collection,
					item_id = item,
					source = action.source,
				},
			)
			if result.dispatch.code ==
			   .Allocation {lab_allocation_failure(r); return .Allocation, true}
			lab_inventory_select(r, result); return result.dispatch.code, true
		}}
	return .Not_Found, false
}
lab_inventory_action :: proc(r: ^Runtime, id: string) -> bool {
	return lab_transfer_action(r, id)
}
