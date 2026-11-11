package app

import model "../model"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"

Section_Result :: struct {
	code:                       interaction.Code,
	sequence:                   u64,
	status, application_status: string,
	ready:                      bool,
}
native_destination :: proc(id: string) -> (model.Page, bool) {
	switch id {
	case "shell/catalogue":
		return .Catalogue, true
	case "shell/layout":
		return .Layout, true
	case "shell/controls":
		return .Controls, true
	}
	for section in model.SECTIONS {if id == section.id {return section.page, true}}
	for section in model.LAB_SECTIONS {if id == section.id {return section.page, true}}
	return {}, false
}
// One application reducer, after common/scope/sequence admission. Native callers
// carry their already consumed publication sequence, never allocate another one.
reduce_destination :: proc(r: ^Runtime, destination: model.Page) -> bool {
	if v, selected := r.content.(^Lab_Menu_Runtime); selected && v.settings {
		if v.confirm || v.discard || r.model.revision == max(u64) {return false}
		v.leave_page, v.destination = true, destination
		if lab_dirty(r) {v.discard = true} else {r.model.page = destination}
		r.model.revision += 1; base.invalidate(&r.publication); return true
	}
	return model.apply(r.model, {kind = .Section, page = destination})
}
// An application intention, not activation of an absent catalogue button.
request_section :: proc(
	s: ^Shell,
	selector: string,
	source: interaction.Source,
) -> Section_Result {
	destination, known := model.section_page(selector)
	if !known {return {code = .Not_Found, status = "rejected", application_status = "none"}}
	r := &s.runtime
	if r.model == nil ||
	   !current(r) {return {code = .Not_Ready, status = "rejected", application_status = "none"}}
	if code := interaction.guard_common(&r.interaction, source); code != .Applied {
		return {code = code, status = "rejected", application_status = "none"}
	}
	if destination ==
	   s.model.page {return {code = .Applied, status = "unchanged", application_status = "none", ready = true}}
	settings := false
	if v, selected := r.content.(^Lab_Menu_Runtime); selected && v.settings {
		if v.confirm ||
		   v.discard {return {code = .Blocked_By_Modal, status = "rejected", application_status = "none"}}
		settings = true
	}
	if !settings && layers.active_scope(r.layers.frame.layers) != "" {
		return {code = .Blocked_By_Modal, status = "rejected", application_status = "none"}
	}
	if s.model.revision == max(u64) || (!settings && s.model.effects == max(u64)) {
		return {code = .Exhausted, status = "rejected", application_status = "none"}
	}
	stamp := reader_stamp(&r.live); page := s.model.page
	if base.advance_sequence(&r.publication) !=
	   .None {return {code = .Exhausted, status = "rejected", application_status = "none"}}
	result := Section_Result {
		code               = .Applied,
		sequence           = r.publication.sequence,
		status             = "applied",
		application_status = "applied",
	}
	if !consume(r, stamp, result.sequence) || !reduce_destination(r, destination) {
		result.code, result.status, result.application_status =
			.Invalid_Action, "rejected", "rejected"
	} else if s.model.page ==
	   page {result.status, result.application_status = "pending", "pending"}
	result.ready = finish_input(s, page, true)
	return result
}
