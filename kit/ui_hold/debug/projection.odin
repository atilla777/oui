package ui_hold_debug
import hold ".."
import debug "../../ui_debug"
import common "../../ui_inspect"
import interaction "../../ui_interaction"
import wire "../../ui_wire"
import "core:mem"
Dispatch_Result :: struct {
	code:      wire.Code,
	event:     interaction.Button_Activated,
	has_event: bool,
	cancel:    Maybe(Cancel_Requested),
}
Cancel_Requested :: struct {
	root_id:  string,
	source:   interaction.Source,
	sequence: u64,
}
Hold_Result :: struct {
	code:     wire.Code,
	signals:  [3]hold.Signal,
	count:    int,
	dispatch: Dispatch_Result,
}
project_frame :: proc(f: ^hold.Frame, m: ^debug.Frame_Metadata, a: mem.Allocator) -> bool {
	if len(f.holds) == 0 && len(f.progress) == 0 {return true}
	c, ok := wire.code(
		f.result.code,
	); dc, dok := wire.code(f.result.dispatch.code); if !ok || !dok {return false}
	m.hold = debug.Encoded_Value(debug.encode(f.hold, a)); if m.hold == nil {return false}
	r := Hold_Result {
		c,
		f.result.signals,
		f.result.count,
		{dc, f.result.dispatch.event, f.result.dispatch.has_event, nil},
	}
	m.hold_result = debug.Encoded_Value(debug.encode(r, a)); return m.hold_result != nil
}
project_node :: proc(f: ^hold.Frame, n: ^debug.Wire_Node, a: mem.Allocator) -> bool {
	for &p in f.progress {if p.id == n.resolved.description.id {n.progress = debug.Encoded_Value(debug.encode(p, a)); if n.progress == nil {return false}; break}}
	for &h in f.holds {if h.id == n.resolved.description.id {n.hold = debug.Encoded_Value(debug.encode(h, a)); if n.hold == nil {return false}; break}}
	return true
}
actions :: proc(
	i: ^common.Inspection,
	f: ^hold.Frame,
	id: string,
) -> (
	[common.Action]debug.Action_Status,
	bool,
) {
	r: [common.Action]debug.Action_Status
	has := false; for h in f.holds {if h.id == id {has = true; break}}
	for a in common.Action {
		s := common.action_status(i, id, a); c, ok := wire.code(s.code)
		if s.code == .Activation_Required && a == .Activate && has {c, ok = .Hold_Required, true}
		if !ok && s.capability {return {}, false}
		r[a] = {s.capability, s.suitable, c}
	}
	begin := &r[.Begin]; begin.suitable = has; begin.code = .Invalid_Action
	if begin.capability {
		if !common.is_ready(
			i,
		) {begin.code = .Not_Ready} else if f.hold.phase != .Idle {begin.code = .Applied} else {
			n, found := interaction.find(&i.interaction, id); begin.code = .Not_Found
			if found {c, ok := wire.code(n.availability); if !ok {return {}, false}; begin.code = c; if c == .Applied && (!has || f.hold.cycle == max(u64)) {begin.code = .Invalid_Action}}
		}
	}
	for a in ([]common.Action{.Release, .Advance, .Hold_Cancel}) {
		r[a].suitable = true; r[a].code = .Invalid_Action
		if r[a].capability {if !common.is_ready(i) {r[a].code = .Not_Ready} else if a != .Release || f.hold.phase == .Idle || f.hold.source == .Agent {r[a].code = .Applied}}
	}
	return r, true
}
