package ui_gestures_sdl
import gestures ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import scroll "../../ui_scroll"
import backend "../../ui_sdl"
import sdl "vendor:sdl3"
Clock :: struct {
	last_ms:                 i64,
	cycle, epoch:            u64,
	has_base, deterministic: bool,
}
Adapter :: struct {
	clock:         Clock,
	pending:       Maybe(gestures.Action),
	pending_point: Maybe([2]f64),
	trigger_key:   sdl.Keycode,
}
Result :: struct {
	gesture:               gestures.Result,
	consumed, has_gesture: bool,
}
event :: proc(
	a: ^Adapter,
	input: ^backend.Input,
	ctx: ^interaction.Context,
	s: ^gestures.State,
	ss: ^scroll.State,
	n: backend.Normalized_Input,
) -> Result {
	if !n.accepted {return {}}
	if n.event.type == .WINDOW_FOCUS_GAINED ||
	   n.event.type == .WINDOW_SHOWN {a.clock.has_base = false}
	if n.loss && s.live.phase != .Idle {
		reason := gestures.Cancel_Reason.None
		#partial switch n.event.type {
		case .WINDOW_FOCUS_LOST:
			reason = .Window_Focus_Lost
		case .WINDOW_HIDDEN:
			reason = .Window_Hidden
		case .WINDOW_MOUSE_LEAVE:
			if s.live.source == .Mouse {reason = .Pointer_Left}
		case .GAMEPAD_REMOVED:
			if s.live.source == .Gamepad {reason = .Gamepad_Removed}
		}
		if reason != .None {
			a.clock.has_base = false; a.pending, a.pending_point = nil, nil
			ok := gestures.block(s, ctx.publication, reason)
			code := interaction.Code.Applied; if !ok {code = .Exhausted}
			result := s.result; result.code = code
			return {consumed = true, has_gesture = true, gesture = result}
		}
	}
	if x := navigation(a, input, ctx, s, ss, n); x.consumed {return x}
	l := &s.live
	active := l.phase != .Idle
	if active &&
	   l.source == .Mouse &&
	   (n.event.type == .MOUSE_MOTION || n.event.type == .MOUSE_BUTTON_UP) {
		inside :=
			n.pointer_valid &&
			n.x >= 0 &&
			n.y >= 0 &&
			n.x < ctx.frame.drawable.w &&
			n.y < ctx.frame.drawable.h
		if inside && n.event.type == .MOUSE_MOTION && l.owner.kind == .Repeat_Scroll {
			v, found := gestures.find(&s.frame, l.owner.id)
			inside =
				found &&
				base.contains(
					v.geometry.bounds,
					n.x / ctx.frame.ui_scale,
					n.y / ctx.frame.ui_scale,
				) &&
				base.contains(v.geometry.clip, n.x / ctx.frame.ui_scale, n.y / ctx.frame.ui_scale)
		}
		if !inside {
			a.clock.has_base = false; a.pending, a.pending_point = nil, nil
			ok := gestures.block(s, ctx.publication, .Pointer_Left)
			code := interaction.Code.Applied; if !ok {code = .Exhausted}
			result := s.result; result.code = code
			return {consumed = true, has_gesture = true, gesture = result}
		}
	}
	if active &&
	   (n.event.type == .MOUSE_WHEEL ||
			   (n.event.type == .MOUSE_MOTION && l.source != .Mouse)) {return {consumed = true}}
	if n.pointer_button && n.down {
		if active {return {consumed = true}}
		if !n.front ||
		   !n.pointer_valid ||
		   input.suspended ||
		   !interaction.ready(ctx) ||
		   s.frame.stamp != ctx.frame.stamp {return {}}
		node, code := interaction.hit_test(&ctx.frame, n.x, n.y)
		if code != .Applied {return {}}
		for d in s.frame.gestures {
			if d.node_id != node.description.id ||
			   d.kind == .Drop_Target ||
			   d.availability != .Applied {continue}
			interaction.cancel_press(ctx); a.clock.has_base = false
			return apply(
				s,
				ctx,
				ss,
				{
					kind = .Begin,
					id = d.id,
					source = .Mouse,
					point = {n.x / ctx.frame.ui_scale, n.y / ctx.frame.ui_scale},
				},
			)
		}
	}
	if active && l.source == .Mouse && n.event.type == .MOUSE_MOTION {
		if !n.pointer_valid {return {consumed = true}}
		if a.pending != nil {return {consumed = true}}
		if l.owner.kind == .Repeat_Scroll {return {consumed = true}}
		if !interaction.ready(ctx) {return {consumed = true}}
		return apply(
			s,
			ctx,
			ss,
			{
				kind = .Move,
				cycle = l.cycle,
				source = .Mouse,
				point = {n.x / ctx.frame.ui_scale, n.y / ctx.frame.ui_scale},
			},
		)
	}
	if active && l.source == .Mouse && n.pointer_button && !n.down {
		a.clock.has_base = false
		end := gestures.Action {
			kind   = .End,
			cycle  = l.cycle,
			source = .Mouse,
		}
		if l.owner.kind != .Repeat_Scroll && n.pointer_valid {
			point := [2]f64{n.x / ctx.frame.ui_scale, n.y / ctx.frame.ui_scale}
			if point != l.current {
				a.pending, a.pending_point = end, point
				if !interaction.ready(ctx) {return {consumed = true}}
				a.pending_point = nil
				return apply(
					s,
					ctx,
					ss,
					{kind = .Move, cycle = l.cycle, source = .Mouse, point = point},
				)
			}
		}
		if !interaction.ready(ctx) {a.pending = end; return {consumed = true}}
		return apply(s, ctx, ss, end)
	}
	return {}
}
step :: proc(
	a: ^Adapter,
	input: ^backend.Input,
	ctx: ^interaction.Context,
	s: ^gestures.State,
	ss: ^scroll.State,
	now_ms: i64,
) -> Result {
	if !interaction.ready(ctx) ||
	   input.suspended ||
	   s.frame.stamp != ctx.frame.stamp {a.clock.has_base = false; return {}}
	if pending, has := a.pending.?; has {
		a.clock.has_base = false
		if pending.cycle != s.live.cycle ||
		   pending.source != s.live.source ||
		   s.live.phase == .Idle {a.pending, a.pending_point = nil, nil; return {}}
		if point, move := a.pending_point.?; move && pending.kind == .End {
			a.pending_point = nil
			return apply(
				s,
				ctx,
				ss,
				{kind = .Move, cycle = pending.cycle, source = pending.source, point = point},
			)
		}
		a.pending, a.pending_point = nil, nil
		return apply(s, ctx, ss, pending)
	}
	if now_ms < 0 {return {gesture = {code = .Invalid_Action}}}
	c := &a.clock
	if s.live.phase != .Active ||
	   s.live.owner.kind != .Repeat_Scroll ||
	   s.live.source == .Agent ||
	   c.deterministic {c.has_base = false; return {}}
	if !c.has_base || c.cycle != s.live.cycle || c.epoch != s.clock_epoch {
		c.last_ms, c.cycle, c.epoch, c.has_base = now_ms, s.live.cycle, s.clock_epoch, true
		return {}
	}
	if now_ms < c.last_ms {return {gesture = {code = .Invalid_Action}}}
	r := apply(
		s,
		ctx,
		ss,
		{
			kind = .Advance,
			source = s.live.source,
			cycle = s.live.cycle,
			duration_ms = now_ms - c.last_ms,
		},
	)
	if r.gesture.code == .Applied {c.last_ms = now_ms}
	return r
}
@(private)
apply :: proc(
	s: ^gestures.State,
	ctx: ^interaction.Context,
	ss: ^scroll.State,
	action: gestures.Action,
) -> Result {return {
		gesture = gestures.dispatch(s, ctx, ss, action),
		consumed = true,
		has_gesture = true,
	}}
close :: proc(a: ^Adapter) {a^ = {}}
