package ui_hold_sdl

import hold ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import sdl "vendor:sdl3"

Adapter :: struct {
	key:                     sdl.Keycode,
	pending:                 hold.Action,
	pending_cycle:           u64,
	has_pending:             bool,
	last_ms:                 i64,
	cycle:                   u64,
	has_base, deterministic: bool,
}
Result :: struct {
	result:   hold.Result,
	consumed: bool,
}
// Typed publishers call this on EVERY failed prepare/copy/precommit/render path.
block :: proc(a: ^Adapter, ctx: ^interaction.Context) {a.has_base = false; base.invalidate(
		ctx.publication,
	)
	interaction.cancel_press(ctx)}
handle :: proc(
	a: ^Adapter,
	s: ^hold.State,
	ctx: ^interaction.Context,
	n: backend.Normalized_Input,
) -> Result {
	if !n.accepted {return {}}
	if s.live.phase != .Idle {
		reason := hold.Cancel_Reason.None
		if n.loss {
			#partial switch n.event.type {
			case .GAMEPAD_REMOVED:
				if s.live.source == .Gamepad {reason = .Gamepad_Removed}
			case .WINDOW_FOCUS_LOST:
				reason = .Window_Focus_Lost
			case .WINDOW_HIDDEN:
				reason = .Window_Hidden
			case .WINDOW_MOUSE_LEAVE:
				if s.live.source == .Mouse {reason = .Pointer_Left}
			}
		}
		if n.event.type == .MOUSE_MOTION && s.live.source == .Mouse {
			target, found := interaction.find(&ctx.frame, s.live.id)
			if !found ||
			   !n.pointer_valid ||
			   ctx.frame.ui_scale <= 0 ||
			   !base.contains(target.bounds, n.x / ctx.frame.ui_scale, n.y / ctx.frame.ui_scale) ||
			   !base.contains(
					   target.clip,
					   n.x / ctx.frame.ui_scale,
					   n.y / ctx.frame.ui_scale,
				   ) {reason = .Pointer_Left}
		}
		if reason != .None {
			action := hold.Action {
				kind   = .Cancel,
				reason = reason,
				source = s.live.source,
			}
			if reason == .Gamepad_Removed &&
			   s.live.phase == .Completed_Waiting_Release {action.kind = .Release}
			return request(a, s, ctx, action)
		}
		if !n.down &&
		   ((n.event.type == .MOUSE_BUTTON_UP && s.live.source == .Mouse) ||
				   (n.event.type == .GAMEPAD_BUTTON_UP &&
						   s.live.source == .Gamepad &&
						   sdl.GamepadButton(n.event.gbutton.button) ==
							   .SOUTH)) {return request(a, s, ctx, {kind = .Release, source = s.live.source})}
	}
	if n.pointer_button && n.down && n.front && !n.suspended {
		target, code := interaction.hit_test(&ctx.frame, n.x, n.y)
		if code ==
		   .Applied {for d in s.frame.holds {if d.id == target.description.id {return {hold.dispatch(s, ctx, {kind = .Begin, id = d.id, source = .Mouse}), true}}}}
	}
	if n.event.type == .KEY_UP &&
	   n.event.key.key == a.key &&
	   s.live.source == .Keyboard &&
	   s.live.phase != .Idle {
		a.has_base = false
		action := hold.Action {
			kind   = .Release,
			source = .Keyboard,
		}
		if !interaction.ready(
			ctx,
		) {a.pending = action; a.pending_cycle = s.live.cycle; a.has_pending = true; return {consumed = true}}
		return {hold.dispatch(s, ctx, action), true}
	}
	if n.has_action && n.action.kind == .Activate {
		for d in s.frame.holds {if d.id == n.action.id {
				if !n.front || n.suspended {return {consumed = true}}
				if s.live.phase == .Idle {a.key = n.event.key.key}
				return {
					hold.dispatch(s, ctx, {kind = .Begin, id = d.id, source = n.action.source}),
					true,
				}
			}}
	}
	return {}
}
@(private)
request :: proc(
	a: ^Adapter,
	s: ^hold.State,
	ctx: ^interaction.Context,
	action: hold.Action,
) -> Result {
	a.has_base = false
	if !interaction.ready(
		ctx,
	) {a.pending = action; a.pending_cycle = s.live.cycle; a.has_pending = true; return {consumed = true}}
	return {hold.dispatch(s, ctx, action), true}
}
step :: proc(a: ^Adapter, s: ^hold.State, ctx: ^interaction.Context, now_ms: i64) -> hold.Result {
	if now_ms < 0 {return {code = .Invalid_Action}}
	if !interaction.ready(ctx) {a.has_base = false; return {code = .Not_Ready}}
	if a.has_pending {
		a.has_pending = false; a.has_base = false
		if a.pending_cycle == s.live.cycle {return hold.dispatch(s, ctx, a.pending)}
	}
	if a.deterministic || s.live.phase != .Holding {a.has_base = false; return {code = .Applied}}
	if !a.has_base ||
	   a.cycle !=
		   s.live.cycle {a.last_ms, a.cycle, a.has_base = now_ms, s.live.cycle, true; return {code = .Applied}}
	if now_ms < a.last_ms {return {code = .Invalid_Action}}
	r := hold.dispatch(
		s,
		ctx,
		{kind = .Advance, source = s.live.source, duration_ms = now_ms - a.last_ms},
	)
	if r.code == .Applied {a.last_ms = now_ms}
	return r
}
