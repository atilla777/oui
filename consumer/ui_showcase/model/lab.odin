package showcase_model

import "core:mem"
import "core:strings"

Lab_Settings_Error :: enum {
	None,
	Stale,
	Allocation,
	Exhausted,
}

// Consumer-local atomic owning model transitions. Input/token/glyph approval
// belongs to the caller; no renderer, family state or callbacks are involved.
apply_lab_settings :: proc(m: ^Model, revision: u64, a: mem.Allocator) -> Lab_Settings_Error {
	if revision != m.lab_name.value_revision {return .Stale}
	if m.effects == max(u64) {return .Exhausted}
	copy, error := strings.clone(m.lab_name.draft, a); if error != nil {return .Allocation}
	if m.lab_name.owned_applied {delete(m.lab_name.applied, a)}
	m.lab_name.applied, m.lab_name.owned_applied = copy, true
	m.lab_applied_enabled, m.lab_applied_amount = m.lab_enabled, m.lab_amount
	m.effects += 1; return .None
}
restore_lab_settings :: proc(m: ^Model, a: mem.Allocator) -> Lab_Settings_Error {
	if m.lab_name.value_revision == max(u64) {return .Exhausted}
	copy, error := strings.clone(m.lab_name.applied, a); if error != nil {return .Allocation}
	if m.lab_name.owned_draft {delete(m.lab_name.draft, a)}
	m.lab_name.draft, m.lab_name.owned_draft = copy, true
	m.lab_name.value_revision += 1
	m.lab_enabled, m.lab_amount = m.lab_applied_enabled, m.lab_applied_amount
	return .None
}
Lab_Hud :: struct {
	hp:    int,
	count: u64,
}
reduce_lab_hud :: proc(state: Lab_Hud, delta: int, restore: bool) -> (Lab_Hud, bool) {
	if state.hp < 0 ||
	   state.hp > 100 ||
	   (delta != 10 && delta != -10 && delta != 0) ||
	   (restore && delta != 0) {return state, false}
	next := state
	if restore {
		if state.count == max(u64) {return state, false}
		next.hp = 100; next.count += 1
	} else {next.hp = clamp(state.hp + delta, 0, 100)}
	return next, true
}
