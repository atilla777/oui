package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import text "../../ui_text"
import "core:strings"
cancel_capture :: proc(a: ^Adapter) {
	delete(
		a.capture_id,
		a.allocator,
	); delete(a.scope_id, a.allocator); delete(a.pending_click_id, a.allocator)
	a.capture_id, a.scope_id, a.pending_click_id = "", "", ""
}
pointer_event :: proc(
	a: ^Adapter,
	input: ^backend.Input,
	ctx: ^interaction.Context,
	s: ^editor.State,
	n: backend.Normalized_Input,
	metrics: text.Text_Layout_Metrics,
) -> Result {
	if !n.accepted {return {}}
	if n.loss &&
	   a.capture_id !=
		   "" {cancel_capture(a); interaction.cancel_press(ctx); return {consumed = true}}
	if n.event.type == .MOUSE_BUTTON_UP &&
	   a.capture_id !=
		   "" {cancel_capture(a); interaction.cancel_press(ctx); return {consumed = true}}
	if n.event.type == .MOUSE_MOTION && a.capture_id != "" {
		if !n.pointer_valid {cancel_capture(a); return {consumed = true}}
		a.point = {n.x / ctx.frame.ui_scale, n.y / ctx.frame.ui_scale}
		return drag_tick(a, input, ctx, s, 0, metrics)
	}
	if !n.pointer_button ||
	   !n.down ||
	   !n.front ||
	   !n.pointer_valid ||
	   input.suspended ||
	   !interaction.ready(ctx) ||
	   s.frame.stamp != ctx.frame.stamp {return {}}
	point := [2]f64{n.x / ctx.frame.ui_scale, n.y / ctx.frame.ui_scale}
	front, hit_code := interaction.hit_test(&ctx.frame, n.x, n.y)
	if hit_code != .Applied {return {}}
	for k := len(s.frame.editors) - 1; k >= 0; k -= 1 {
		e := &s.frame.editors[k]
		if e.node_id != front.description.id {continue}
		if e.availability != .Applied ||
		   interaction.guard(ctx, e.node_id, .Mouse) != .Applied ||
		   !base.contains(e.geometry.bounds, point[0], point[1]) ||
		   !base.contains(e.geometry.clip, point[0], point[1]) {continue}
		capture, ae := strings.clone(
			e.id,
			a.allocator,
		); if ae != nil {return {consumed = true, error = .Allocation}}
		scope, se := strings.clone(
			s.frame.scope_id,
			a.allocator,
		); if se != nil {delete(capture, a.allocator); return {consumed = true, error = .Allocation}}
		pending, pe := strings.clone(
			e.id,
			a.allocator,
		); if pe != nil {delete(capture, a.allocator); delete(scope, a.allocator); return {consumed = true, error = .Allocation}}
		cancel_capture(a); a.capture_id, a.scope_id, a.pending_click_id = capture, scope, pending
		a.point, a.geometry = point, e.geometry
		interaction.cancel_press(ctx)
		if ctx.focus_id !=
		   e.node_id {r := interaction.dispatch(ctx, {kind = .Focus, id = e.node_id, source = .Mouse}); if r.code != .Applied {cancel_capture(a)}; return {consumed = true}}
		return take_pointer(a, ctx, s, metrics)
	}
	return {}
}
take_pointer :: proc(
	a: ^Adapter,
	ctx: ^interaction.Context,
	s: ^editor.State,
	metrics: text.Text_Layout_Metrics,
) -> Result {
	if a.pending_click_id == "" {return {}}
	defer {delete(a.pending_click_id, a.allocator); a.pending_click_id = ""}
	e, found := editor.find(&s.frame, a.pending_click_id)
	if !found ||
	   !interaction.ready(ctx) ||
	   s.frame.stamp != ctx.frame.stamp ||
	   e.availability != .Applied ||
	   ctx.focus_id != e.node_id ||
	   s.frame.scope_id != a.scope_id {cancel_capture(a); return {consumed = true}}
	point, mapped := base.inverse_point(e.geometry, a.point)
	if !mapped {cancel_capture(a); return {consumed = true}}
	a.anchor = editor.editor_hit(e^, point[0]); a.geometry = e.geometry
	return {
		editor = editor.dispatch(
			s,
			ctx,
			{id = e.id, kind = .Select, source = .Mouse, anchor = a.anchor, caret = a.anchor},
			metrics,
		),
		has_editor = true,
		consumed = true,
	}
}
drag_tick :: proc(
	a: ^Adapter,
	input: ^backend.Input,
	ctx: ^interaction.Context,
	s: ^editor.State,
	dt: f64,
	metrics: text.Text_Layout_Metrics,
) -> Result {
	if a.capture_id == "" {return {}}
	if input.suspended ||
	   !interaction.ready(ctx) ||
	   s.frame.stamp != ctx.frame.stamp {return {consumed = true}}
	e, found := editor.find(&s.frame, a.capture_id)
	if !found ||
	   e.availability != .Applied ||
	   ctx.focus_id != e.node_id ||
	   s.frame.scope_id != a.scope_id {cancel_capture(a); return {consumed = true}}
	if e.geometry != a.geometry &&
	   (!base.contains(e.geometry.bounds, a.point[0], a.point[1]) ||
			   !base.contains(
					   e.geometry.clip,
					   a.point[0],
					   a.point[1],
				   )) {cancel_capture(a); return {consumed = true}}
	point, mapped := base.inverse_point(e.geometry, a.point)
	if !mapped {cancel_capture(a); return {consumed = true}}
	a.geometry = e.geometry
	caret, scroll, valid := editor.editor_drag(e^, point[0], dt)
	if !valid || (caret == e.caret && scroll == e.scroll) {return {consumed = true}}
	return {
		editor = editor.dispatch(
			s,
			ctx,
			{
				id = e.id,
				kind = .Select,
				source = .Mouse,
				anchor = a.anchor,
				caret = caret,
				pointer_scroll = scroll,
			},
			metrics,
		),
		has_editor = true,
		consumed = true,
	}
}
