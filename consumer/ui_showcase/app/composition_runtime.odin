package app

import interaction "ui:ui_interaction"

// Callbacks record bounded intentions only. The reducer runs after dispatch has
// released its borrowed frame; one activation creates one application outcome.
Composition_Route :: struct {
	child, parent: bool,
	sequence:      u64,
	disposals:     u64,
}
composition_handler :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {
	r := cast(^Runtime)user
	r.composition_route.sequence = d.sequence
	if d.current_id ==
	   "composition/child" {r.composition_route.child = true; if r.model.composition.stop {return .Stop}}
	if d.current_id == "composition/parent" {r.composition_route.parent = true}
	return .Continue
}
composition_dispose :: proc(user: rawptr) {
	r := cast(^Runtime)user
	if r.composition_route.disposals < max(u64) {r.composition_route.disposals += 1}
}
register_composition :: proc(r: ^Runtime) -> bool {
	if r.model.page != .Composition {return true}
	for id in ([]string{"composition/parent", "composition/child"}) {
		if id == "composition/child" && !r.model.composition.child_present {continue}
		if _, found := interaction.find_handler(&r.interaction, id); found {continue}
		_, code := interaction.register_handler(
			&r.interaction,
			id,
			composition_handler,
			r,
			composition_dispose,
		)
		if code != .Applied {return false}
	}
	return true
}
