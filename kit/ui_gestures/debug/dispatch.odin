package ui_gestures_debug
import gestures ".."
import interaction "../../ui_interaction"
import scroll "../../ui_scroll"
import wire "../../ui_wire"
// Preserve the old wire guard priority: a ready, already active Begin is Busy
// before resolving its target, rather than exposing a new internal Conflict.
dispatch_request :: proc(
	s: ^gestures.State,
	ctx: ^interaction.Context,
	ss: ^scroll.State,
	r: Request,
) -> (
	gestures.Result,
	Gesture_Reply,
	bool,
) {
	a, valid := action(r, &s.frame)
	result: gestures.Result
	before := s.live.phase
	if code := interaction.guard_common(ctx, .Agent);
	   code !=
	   .Applied {result.code = code} else if s.frame.stamp != ctx.frame.stamp {result.code = .Not_Ready} else if !valid {result.code = .Invalid_Action} else if a.kind == .Begin && before != .Idle {result.code = .Conflict} else {result = gestures.dispatch(s, ctx, ss, a)}
	p, ok := reply(result, a, before); return result, p, ok
}
// Ordinary Activate on the existing Repeat_Scroll button is one scroll action,
// not a gesture Begin/End pair and not a base Button_Activated event.
activate_repeat :: proc(
	s: ^gestures.State,
	ctx: ^interaction.Context,
	ss: ^scroll.State,
	id: string,
) -> (
	handled: bool,
	code: wire.Code,
	representable: bool,
) {
	for d in s.frame.gestures {if d.node_id == id && d.kind == .Repeat_Scroll {
			c := interaction.guard(
				ctx,
				id,
				.Agent,
			); if c != .Applied {mapped, ok := wire.code(c); return true, mapped, ok}
			if s.frame.stamp != ctx.frame.stamp || ss == nil {return true, .Not_Ready, true}
			if s.live.phase != .Idle {return true, .Gesture_Busy, true}
			result := scroll.dispatch(
				ss,
				ctx,
				{kind = .Scroll_By, id = d.scroll_id, source = .Agent, delta_y = d.step},
			)
			mapped, ok := wire.code(result.code); return true, mapped, ok
		}}
	return false, {}, true
}
