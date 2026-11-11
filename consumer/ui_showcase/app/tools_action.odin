package app

import "core:fmt"
import collections "ui:ui_collections"
import hold "ui:ui_hold"
import interaction "ui:ui_interaction"
import scroll "ui:ui_scroll"

// Import-only aliases have no state or executable path in ordinary composition.
_ :: fmt.tprintf
_ :: interaction.Code
_ :: hold.Action
_ :: collections.Action
_ :: scroll.Action

when TOOLS {
	Tool_Action :: struct {
		op, id:      string,
		backwards:   bool,
		delta_y:     f64,
		duration_ms: i64,
		test_time:   bool,
	}
	Tool_Result :: struct {
		code:                          string,
		sequence:                      u64,
		has_event, ready:              bool,
		application:                   string,
		effects_before, effects_after: u64,
	}
	execute_tool_action :: proc(s: ^Shell, action: Tool_Action) -> Tool_Result {
		r := &s.runtime
		result := Tool_Result {
			code           = "Not_Ready",
			application    = "none",
			effects_before = s.model.effects,
			effects_after  = s.model.effects,
		}
		if r.model == nil || !current(r) {
			// Same pending release/loss mechanism as the native adapter. Never
			// authorize a mutation or implicitly recover a failed publication.
			if action.op == "release-hold" || action.op == "cancel-hold" {
				if h, selected := active_hold(r); selected && h.state.live.source == .Agent {
					h.input.has_base =
						false; h.input.has_pending = true; h.input.pending_cycle = h.state.live.cycle
					h.input.pending = {
						kind   = .Release if action.op == "release-hold" else .Cancel,
						source = .Agent,
						reason = .Explicit,
					}
				}
			}
			return result
		}
		page := s.model.page; revision, sequence := s.model.revision, r.publication.sequence
		stamp := reader_stamp(&r.live)
		code := interaction.Code.Invalid_Action
		switch action.op {
		case "focus", "navigate", "activate", "cancel":
			kind := interaction.Action_Kind.Activate
			if action.op == "focus" {kind = .Focus}
			if action.op == "navigate" {kind = .Navigate}
			if action.op == "cancel" {kind = .Cancel}
			code = route(r, {kind, action.id, .Agent, action.backwards})
			if code == .Activation_Required {
				if target, found := interaction.find(&r.interaction.frame, action.id);
				   found && target.activation_owner == "hold" {
					result.code = "Hold_Required"; result.ready = true; return result
				}
			}
		case "scroll":
			code = .Not_Found
			if v, selected := r.content.(^Lab_Inventory_Runtime); selected {
				for &state in v.states {for view in state.frame.collections {if view.description.scroll_id == action.id {
							code =
								collections.dispatch(&state, &r.interaction, {kind = .Scroll_By, collection_id = view.description.id, source = .Agent, delta_y = action.delta_y}).dispatch.code
						}}}
			} else if v, has_collection := active_collection(r); has_collection {
				for view in v.state.frame.collections {if view.description.scroll_id == action.id {
						code =
							collections.dispatch(&v.state, &r.interaction, {kind = .Scroll_By, collection_id = view.description.id, source = .Agent, delta_y = action.delta_y}).dispatch.code
					}}
			} else {
				code =
					scroll.dispatch(&r.scroll, &r.interaction, {kind = .Scroll_By, id = action.id, source = .Agent, delta_y = action.delta_y}).code
			}
		case "begin-hold", "advance-hold", "release-hold", "cancel-hold":
			if action.op == "advance-hold" {
				when !#config(
					UI_DEMO_TEST,
					false,
				) {result.code = "Interactive_Clock"; result.ready = true; return result}
				if !action.test_time {result.code = "Interactive_Clock"; result.ready = true; return result}
			}
			h, selected := active_hold(r)
			if !selected {result.code = "Unsupported_Action"; result.ready = true; return result}
			if action.op != "begin-hold" &&
			   (h.state.live.phase == .Idle || h.state.live.source != .Agent) {
				result.code = "Invalid_Action"; result.ready = true; return result
			}
			kind := hold.Action_Kind.Begin
			if action.op == "advance-hold" {kind = .Advance}
			if action.op == "release-hold" {kind = .Release}
			if action.op == "cancel-hold" {kind = .Cancel}
			if action.op == "advance-hold" &&
			   (action.duration_ms < 0 ||
					   action.duration_ms >
						   max(i64) -
							   r.tools_state.sample_ms) {result.code = "Exhausted"; result.ready = true; return result}
			x := hold.dispatch(
				&h.state,
				&r.interaction,
				{
					kind = kind,
					id = action.id,
					source = .Agent,
					duration_ms = action.duration_ms,
					reason = .Explicit,
				},
			)
			code = x.code
			if code == .Applied &&
			   action.op == "advance-hold" {r.tools_state.sample_ms += action.duration_ms}
			if x.dispatch.has_event {code = x.dispatch.code}
			accept_hold(r, stamp, x)
		case:
			result.code = "Unsupported_Action"; result.ready = true; return result
		}
		result.sequence = r.publication.sequence
		result.has_event =
			result.sequence != sequence &&
			(action.op == "activate" || action.op == "advance-hold" || action.op == "cancel")
		if code == .Applied && s.model.revision != revision {result.application = "applied"}
		if v, selected := r.content.(^Lab_Menu_Runtime);
		   selected &&
		   (v.confirm || v.discard) &&
		   s.model.revision != revision {result.application = "pending"}
		if code == .Applied &&
		   (action.op == "activate" || result.has_event) &&
		   s.model.revision == revision {result.application = "rejected"}
		set_tool_dispatch(r, code)
		result.ready = finish_input(s, page, true)
		result.effects_after = s.model.effects
		result.code = tool_code_name(code)
		if code == .Not_Visible {result.code = "Hidden"}
		return result
	}
}
