package ui_interaction

import base "../ui_base"

// Borrowed for this synchronous traversal only. Must be pure, non-allocating,
// and must not dispatch, retain views, or read a live model/clock.
Hit_Predicate :: proc(id: string, logical_point: [2]f64, user: rawptr) -> bool
hit_test :: proc(
	f: ^Frame,
	drawable_x, drawable_y: f64,
	predicate: Hit_Predicate = nil,
	user: rawptr = nil,
) -> (
	^Target_View,
	Code,
) {
	if f.ui_scale <= 0 {return nil, .Not_Found}
	x, y := drawable_x / f.ui_scale, drawable_y / f.ui_scale
	for i := len(f.targets) - 1; i >= 0; i -= 1 {
		n := &f.targets[i]
		if n.availability == .Applied &&
		   base.contains(n.bounds, x, y) &&
		   base.contains(n.clip, x, y) &&
		   (predicate == nil || predicate(n.description.id, {x, y}, user)) {return n, .Applied}
	}
	return nil, .Not_Found
}
observe_target :: proc(ctx: ^Context, id: string) -> Code {
	if !ready(ctx) {return .Not_Ready}
	selected := ""
	if id != "" {
		n, found := find(&ctx.frame, id); if !found {return .Not_Found}
		if n.availability != .Applied {return n.availability}
		selected = n.description.id
	}
	if ctx.hover_id != selected {ctx.hover_id = selected; base.invalidate(ctx.publication)}
	return .Applied
}

consume_press :: proc(ctx: ^Context, id: string) -> Code {
	if ctx.busy {return .Reentry}
	pressed := ctx.pressed_id; ctx.pressed_id = ""
	if !ready(ctx) {return .Not_Ready}
	if pressed == "" || pressed != id {return .Invalid_Action}
	return .Applied
}

// Normalized device callers share these semantic availability/capture guards.
begin_press :: proc(ctx: ^Context, id: string) -> Code {
	if !ready(ctx) {return .Not_Ready}
	if ctx.pressed_id != "" {return .Conflict}
	n, ok := find(&ctx.frame, id); if !ok {return .Not_Found}
	if n.availability != .Applied {return n.availability}
	ctx.pressed_id = n.description.id
	base.invalidate(ctx.publication)
	return .Applied
}
release_press :: proc(ctx: ^Context, id: string, source: Source) -> Dispatch_Result {
	if code := consume_press(ctx, id); code != .Applied {return {code = code}}
	return dispatch(ctx, {.Activate, id, source, false})
}
cancel_press :: proc(ctx: ^Context) {ctx.pressed_id = ""}
// Loss edges clear pointer-owned state even while publication is blocked.
cancel_pointer :: proc(ctx: ^Context) {
	cancel_press(ctx)
	if ctx.hover_id != "" {ctx.hover_id = ""; base.invalidate(ctx.publication)}
}
observe_pointer :: proc(
	ctx: ^Context,
	drawable_x, drawable_y: f64,
	predicate: Hit_Predicate = nil,
	user: rawptr = nil,
) -> Code {
	if !ready(ctx) {return .Not_Ready}
	n, code := hit_test(&ctx.frame, drawable_x, drawable_y, predicate, user)
	id := ""; if code == .Applied {id = n.description.id}
	return observe_target(ctx, id)
}
