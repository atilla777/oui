package ui_controls_sdl

import controls ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import "core:math"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"

Adapter :: struct {
	capture_id, capture_scope:    string,
	allocator:                    mem.Allocator,
	capture_bounds, capture_clip: base.Rect,
	capture_geometry:             base.Frozen_Geometry,
}
Result :: struct {
	result:   controls.Result,
	consumed: bool,
}
create :: proc(a: mem.Allocator) -> Adapter {return {allocator = a}}
cancel :: proc(a: ^Adapter) {delete(a.capture_id, a.allocator); delete(
		a.capture_scope,
		a.allocator,
	)
	a.capture_id = ""
	a.capture_scope = ""}
destroy :: proc(a: ^Adapter) {cancel(a); a^ = {}}
reconcile :: proc(
	a: ^Adapter,
	s: ^controls.State,
	ctx: ^interaction.Context,
	g: ^layout.Frame,
	pointer: [2]f64 = {},
	has_pointer: bool = false,
	view: base.Geometry_View = {},
) {
	if a.capture_id == "" {return}
	for c in s.frame.controls {if c.id == a.capture_id && c.kind == .Slider && a.capture_scope == s.frame.scope_id && interaction.guard(ctx, c.node_id, .Mouse) == .Applied && s.frame.stamp == ctx.frame.stamp && g.stamp == ctx.frame.stamp {
			id :=
				c.node_id; if c.track_id != "" {id = c.track_id}; track, found := layout.find(g, id); if !found {break}
			visual, valid := track_geometry(g, id, view); if !valid {break}
			moved :=
				track.bounds != a.capture_bounds ||
				track.paint_clip != a.capture_clip ||
				visual != a.capture_geometry
			if moved &&
			   has_pointer &&
			   (g.ui_scale <= 0 ||
					   !base.contains(
							   visual.bounds,
							   pointer[0] / g.ui_scale,
							   pointer[1] / g.ui_scale,
						   ) ||
					   !base.contains(
							   visual.clip,
							   pointer[0] / g.ui_scale,
							   pointer[1] / g.ui_scale,
						   )) {break}
			a.capture_bounds =
				track.bounds; a.capture_clip = track.paint_clip; a.capture_geometry = visual; return
		}}
	cancel(a)
}
// Call on every failed publication, not only when a later input notices Not_Ready.
block :: proc(a: ^Adapter, ctx: ^interaction.Context) {cancel(a); interaction.cancel_press(ctx)
	base.invalidate(ctx.publication)}
handle :: proc(
	a: ^Adapter,
	s: ^controls.State,
	ctx: ^interaction.Context,
	g: ^layout.Frame,
	n: backend.Normalized_Input,
	view: base.Geometry_View = {},
) -> Result {
	if !n.accepted {return {}}
	if n.loss || n.suspended {cancel(a); return {}}
	if n.pointer_button &&
	   !n.down &&
	   a.capture_id != "" {cancel(a); interaction.cancel_press(ctx); return {consumed = true}}
	if (n.pointer_button || n.event.type == .MOUSE_MOTION) &&
	   g.stamp !=
		   ctx.frame.stamp {cancel(a); return {result = {dispatch = {code = .Not_Ready}}, consumed = true}}
	reconcile(a, s, ctx, g, {n.x, n.y}, n.pointer_valid, view)
	if n.event.type == .MOUSE_MOTION && a.capture_id != "" {
		for c in s.frame.controls {if c.id == a.capture_id {
				action, ok := pointer_action(
					c,
					g,
					n,
					false,
					view,
				); if !ok {cancel(a); return {consumed = true}}
				return {controls.dispatch(s, ctx, action), true}
			}}
	}
	if n.front && !n.suspended {
		for c in s.frame.controls {if c.kind == .Slider && c.node_id == ctx.focus_id {
				action := controls.Action {
					kind   = .Adjust,
					id     = c.node_id,
					value  = 0,
					source = .Keyboard,
				}
				if n.event.type == .KEY_DOWN {switch n.event.key.key {
					case sdl.K_LEFT:
						action.value = -1
					case sdl.K_RIGHT:
						action.value = 1
					case sdl.K_HOME:
						action.kind = .Set_Value; action.value = c.minimum
					case sdl.K_END:
						action.kind = .Set_Value; action.value = c.maximum
					}}
				if n.event.type ==
				   .GAMEPAD_BUTTON_DOWN {action.source = .Gamepad; button := sdl.GamepadButton(n.event.gbutton.button); if button == .DPAD_LEFT {action.value = -1}; if button == .DPAD_RIGHT {action.value = 1}}
				if action.value != 0 ||
				   action.kind == .Set_Value {return {controls.dispatch(s, ctx, action), true}}
			}}
	}
	if n.pointer_button && n.down && n.front && interaction.ready(ctx) && a.capture_id == "" {
		target, code := interaction.hit_test(&ctx.frame, n.x, n.y)
		if code ==
		   .Applied {for c in s.frame.controls {if c.node_id == target.description.id && c.kind == .Slider {
					action, ok := pointer_action(
						c,
						g,
						n,
						true,
						view,
					); if !ok {return {consumed = true}}
					id, e := strings.clone(
						c.id,
						a.allocator,
					); if e != nil {return {result = {dispatch = {code = .Allocation}}, consumed = true}}
					scope, se := strings.clone(
						s.frame.scope_id,
						a.allocator,
					); if se != nil {delete(id, a.allocator); return {result = {dispatch = {code = .Allocation}}, consumed = true}}
					r := controls.dispatch(s, ctx, action)
					if r.dispatch.code ==
					   .Applied {a.capture_id = id; a.capture_scope = scope; track_id := c.node_id; if c.track_id != "" {track_id = c.track_id}; track, _ := layout.find(g, track_id); a.capture_bounds = track.bounds; a.capture_clip = track.paint_clip; a.capture_geometry, _ = track_geometry(g, track_id, view); interaction.cancel_press(ctx)} else {delete(id, a.allocator); delete(scope, a.allocator)}
					return {r, true}
				}}}
	}
	return {}
}
@(private)
pointer_action :: proc(
	c: controls.Description,
	g: ^layout.Frame,
	n: backend.Normalized_Input,
	begin: bool,
	view: base.Geometry_View,
) -> (
	controls.Action,
	bool,
) {
	if !n.pointer_valid ||
	   g.ui_scale <= 0 ||
	   !base.finite(n.x) ||
	   !base.finite(n.y) {return {}, false}
	id := c.node_id; if c.track_id != "" {id = c.track_id}
	track, found := layout.find(
		g,
		id,
	); if !found || track.bounds.w <= 0 || c.step <= 0 {return {}, false}
	x, y := n.x / g.ui_scale, n.y / g.ui_scale
	visual, valid := track_geometry(g, id, view); if !valid {return {}, false}
	if begin && !base.contains(visual.clip, x, y) {return {}, false}
	point, inverted := base.inverse_point(visual, {x, y}); if !inverted {return {}, false}
	x, y = point[0], point[1]
	steps := (i128(c.maximum) - i128(c.minimum)) / i128(c.step)
	fraction := clamp((x - track.bounds.x) / track.bounds.w, 0, 1)
	value := i64(
		i128(c.minimum) +
		clamp(i128(math.floor(fraction * f64(steps) + 0.5)), i128(0), steps) * i128(c.step),
	)
	return {kind = .Set_Value, id = c.node_id, source = .Mouse, value = value}, true
}

// Borrowed numerical projection only; no transition owner/import/clock here.
track_geometry :: proc(
	g: ^layout.Frame,
	id: string,
	view: base.Geometry_View,
) -> (
	base.Frozen_Geometry,
	bool,
) {
	n, found := layout.find(g, id); if !found {return {}, false}
	if view.entries == nil &&
	   view.stamp.lifetime ==
		   nil {return {scale = 1, opacity = 1, bounds = n.bounds, content = n.content, clip = n.paint_clip, content_clip = n.clip}, true}
	if view.stamp != g.stamp {return {}, false}
	result: base.Frozen_Geometry; seen := false
	for e in view.entries {if e.id == id {
			if seen ||
			   !e.input_enabled ||
			   e.geometry.scale <= 0 ||
			   !base.finite(e.geometry.scale) ||
			   e.geometry.opacity <= 0 ||
			   e.geometry.opacity > 1 ||
			   !base.finite(e.geometry.opacity) ||
			   !base.finite(e.geometry.offset[0]) ||
			   !base.finite(e.geometry.offset[1]) {return {}, false}
			for r in ([4]base.Rect{e.geometry.bounds, e.geometry.content, e.geometry.clip, e.geometry.content_clip}) {if !base.finite(r.x) || !base.finite(r.y) || !base.finite_nonnegative(r.w) || !base.finite_nonnegative(r.h) || !base.finite(r.x + r.w) || !base.finite(r.y + r.h) {return {}, false}}
			result, seen = e.geometry, true
		}}
	return result, seen
}
