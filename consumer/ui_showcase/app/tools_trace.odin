package app

import "core:mem"
import "core:strings"
import interaction "ui:ui_interaction"
import backend "ui:ui_sdl"

_ :: mem.Allocator
_ :: strings.clone
_ :: interaction.Code
_ :: backend.Normalized_Input

when TOOLS {
	tool_code_name :: proc(code: interaction.Code) -> string {
		switch code {
		case .Applied:
			return "Applied"
		case .Not_Found:
			return "Not_Found"
		case .Disabled:
			return "Disabled"
		case .Not_Visible:
			return "Hidden"
		case .Invalid_Action:
			return "Invalid_Action"
		case .Not_Ready:
			return "Not_Ready"
		case .Allocation:
			return "Allocation"
		case .Exhausted:
			return "Exhausted"
		case .Conflict:
			return "Conflict"
		case .Reentry:
			return "Reentry"
		case .Blocked_By_Modal:
			return "Blocked_By_Modal"
		case .Non_Interactive_Overlay:
			return "Non_Interactive_Overlay"
		case .Activation_Required:
			return "Activation_Required"
		}
		return "Invalid_Action"
	}
	tool_source_name :: proc(source: interaction.Source) -> string {
		switch source {case .Mouse:
			return "Mouse"; case .Keyboard:
			return "Keyboard"; case .Gamepad:
			return "Gamepad"; case .Agent:
			return "Agent"}
		return ""
	}
	destroy_tool_record :: proc(record: ^Tool_Record, a: mem.Allocator) {
		delete(record.request_id, a); delete(record.op, a); delete(record.target, a); record^ = {}
	}
	clone_tool_record :: proc(source: Tool_Record, a: mem.Allocator) -> (Tool_Record, bool) {
		result := source; result.request_id, result.op, result.target = "", "", ""
		complete := false; defer {if !complete {destroy_tool_record(&result, a)}}
		e: mem.Allocator_Error
		result.request_id, e = strings.clone(source.request_id, a); if e != nil {return {}, false}
		result.op, e = strings.clone(source.op, a); if e != nil {return {}, false}
		result.target, e = strings.clone(source.target, a); if e != nil {return {}, false}
		complete = true; return result, true
	}
	begin_tool_record :: proc(
		s: ^Shell,
		request_id, op, target: string,
		source: interaction.Source,
	) -> bool {
		t := s.runtime.tools_state.trace
		if t == nil {return true}
		if t.has_pending {return false}
		record, ok := clone_tool_record(
			{
				request_id = request_id,
				op = op,
				target = target,
				source = tool_source_name(source),
				screen_epoch = s.runtime.tools_state.epoch,
				dispatch_code = "Applied",
				application_status = "none",
			},
			t.allocator,
		)
		if !ok {return false}
		t.pending, t.has_pending, t.before_revision = record, true, s.model.revision
		t.before_sequence = s.runtime.publication.sequence
		return true
	}
	trace_target :: proc(
		r: ^Runtime,
		id: string,
		source: interaction.Source,
		sequence: u64,
	) -> bool {
		t := r.tools_state.trace; if t == nil || !t.has_pending {return true}
		// Copy before application consumption; a refusal cannot lose an effect.
		if t.pending.target != id && t.pending.source != "Agent" {
			owned, e := strings.clone(id, t.allocator); if e != nil {return false}
			delete(t.pending.target, t.allocator); t.pending.target = owned
		}
		t.pending.source, t.pending.sequence = tool_source_name(source), sequence
		return true
	}
	set_tool_dispatch :: proc(r: ^Runtime, code: interaction.Code) {
		t :=
			r.tools_state.trace; if t != nil && t.has_pending {t.pending.dispatch_code = tool_code_name(code)}
	}
	finish_tool_record :: proc(r: ^Runtime, code: string = "") {
		t := r.tools_state.trace; if t == nil || !t.has_pending {return}
		// A guarded UI proposal can be delivered without an application event
		// (for example plain Activate on a slider). Preserve its dispatch
		// sequence as well as the reducer-consumed sequences recorded earlier.
		if r.publication.sequence !=
		   t.before_sequence {t.pending.sequence = r.publication.sequence}
		if code != "" {t.pending.dispatch_code = code}
		if r.model != nil && r.model.revision != t.before_revision {
			t.pending.application_status = "applied"
			if v, selected := r.content.(^Lab_Menu_Runtime);
			   selected && (v.confirm || v.discard) {t.pending.application_status = "pending"}
		} else if t.pending.sequence != 0 && t.pending.dispatch_code == "Applied" {
			t.pending.application_status, t.pending.reason = "rejected", "Application_Rejected"
		}
		destroy_tool_record(&t.last, t.allocator)
		t.last, t.has_last = t.pending, true; t.pending, t.has_pending = {}, false
	}
	begin_native_record :: proc(s: ^Shell, n: backend.Normalized_Input) -> bool {
		t := s.runtime.tools_state.trace; if t == nil {return true}
		source := interaction.Source.Keyboard; id := ""
		if n.has_action {source, id = n.action.source, n.action.id} else {
			#partial switch n.event.type {
			case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP, .MOUSE_MOTION, .MOUSE_WHEEL:
				source = .Mouse
			case .GAMEPAD_BUTTON_DOWN, .GAMEPAD_BUTTON_UP, .GAMEPAD_AXIS_MOTION:
				source = .Gamepad
			case .KEY_DOWN, .KEY_UP, .TEXT_INPUT:
				source = .Keyboard
			case:
				if h, selected := active_hold(&s.runtime);
				   selected {source = h.state.live.source} else {return true}
			}
		}
		return begin_tool_record(s, "", "native-input", id, source)
	}
	destroy_tool_trace :: proc(s: ^Shell) {
		t := s.tools.runtime.trace; if t == nil {return}
		destroy_tool_record(&t.last, t.allocator); destroy_tool_record(&t.pending, t.allocator)
		free(t, t.allocator); s.tools.runtime.trace = nil
	}
}
