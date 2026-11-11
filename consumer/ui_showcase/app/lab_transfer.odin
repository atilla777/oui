package app

import cards "../../gestures_demo/model"
import "core:strings"
import base "ui:ui_base"
import gestures "ui:ui_gestures"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"

lab_transfer_action :: proc(r: ^Runtime, id: string) -> bool {
	v, _ := r.content.(^Lab_Inventory_Runtime)
	if r.model.revision == max(u64) {return false}
	switch id {
	case "lab/reverse":
		r.model.lab_reverse = !r.model.lab_reverse
	case "lab/transfer-cancel":
		if !v.has_pending {return false}; clear_lab_pending(r, v)
	case "lab/transfer-confirm":
		if !v.has_pending ||
		   v.pending_token != v.token ||
		   v.pending_stamp.lifetime != r.publication.lifetime ||
		   !v.pending_stamp.lifetime.alive ||
		   r.model.effects == max(u64) {return false}
		valid := false
		panel := &v.model.panels[v.source_panel]
		for card in panel.cards[:panel.count] {valid ||= card == v.pending.payload_id}
		if !valid {v.outcome = {
				reason = .Unknown_Card,
			}} else {
			next, outcome := cards.reduce(v.model^, v.pending)
			v.model^, v.outcome = next, outcome
			if outcome.applied {r.model.effects += 1}
		}
		clear_lab_pending(r, v)
	case:
		return false
	}
	r.model.revision += 1; base.invalidate(&r.publication); return true
}
clear_lab_pending :: proc(r: ^Runtime, v: ^Lab_Inventory_Runtime) {
	delete(v.pending.source_id, r.allocator); delete(v.pending.target_id, r.allocator)
	delete(v.pending.payload_id, r.allocator); delete(v.pending.payload_type, r.allocator)
	base.release(
		v.pending_stamp,
	); v.pending_stamp = {}; v.pending = {}; v.has_pending = false; v.pending_token = 0
}
accept_lab_gesture :: proc(r: ^Runtime, result: gestures.Result) -> bool {
	v, _ := r.content.(^Lab_Inventory_Runtime)
	if result.code == .Allocation {return lab_allocation_failure(r)}
	if !result.has_proposal {return true}
	p := result.proposal
	if v.has_pending ||
	   v.token == max(u64) ||
	   r.model.revision == max(u64) ||
	   !consume(r, reader_stamp(&r.live), p.sequence) {return false}
	source := -1
	for &panel, index in v.model.panels {for id in panel.cards[:panel.count] {if id == p.payload_id {source = index}}}
	if source < 0 {v.outcome = {
			reason = .Unknown_Card,
		}; return true}
	if v.model.panels[source].id == p.target_id {v.outcome = {
			reason = .Same_Panel,
		}; return true}
	if p.target_id != "panel-left" && p.target_id != "panel-right" {v.outcome = {
			reason = .Unknown_Target,
		}; return true}
	if p.model_revision != v.model.revision {v.outcome = {
			reason = .Stale_Model,
		}; return true}
	request := cards.Drop_Request {
		cycle          = p.cycle,
		sequence       = p.sequence,
		frame_id       = p.frame_id,
		model_revision = p.model_revision,
	}
	complete := false
	defer {if !complete {delete(request.source_id, r.allocator); delete(request.target_id, r.allocator); delete(request.payload_id, r.allocator); delete(request.payload_type, r.allocator)}}
	for pair in ([]struct {
			source: string,
			dest:   ^string,
		}{{p.source_id, &request.source_id}, {p.target_id, &request.target_id}, {p.payload_id, &request.payload_id}, {p.payload_type, &request.payload_type}}) {
		value, ae := strings.clone(
			pair.source,
			r.allocator,
		); if ae != nil {return lab_allocation_failure(r)}; pair.dest^ = value
	}
	stamp := reader_stamp(&r.live); if !base.retain(stamp) {block(r); return false}
	v.token += 1; v.pending_token = v.token; v.pending, v.pending_stamp, v.has_pending, v.source_panel = request, stamp, true, source
	complete = true; r.model.revision += 1; base.invalidate(&r.publication); return true
}
lab_transfer_cancel :: proc(r: ^Runtime, action: interaction.Action) -> interaction.Code {
	result := layers.dispatch(&r.layers, &r.interaction, action)
	if event, has := result.cancel.?;
	   has {if consume(r, reader_stamp(&r.live), event.sequence) {lab_inventory_action(r, "lab/transfer-cancel")}}
	return result.dispatch.code
}
