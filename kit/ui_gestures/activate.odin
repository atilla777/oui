package ui_gestures
import interaction "../ui_interaction"
import scroll "../ui_scroll"
activate_repeat :: proc(
	s: ^State,
	ctx: ^interaction.Context,
	ss: ^scroll.State,
	id: string,
	source: interaction.Source = .Agent,
) -> interaction.Dispatch_Result {
	if code := interaction.guard_common(ctx, source); code != .Applied {return {code = code}}
	if ss == nil ||
	   s.frame.stamp != ctx.frame.stamp ||
	   ss.frame.stamp != s.frame.stamp {return {code = .Not_Ready}}
	d, code := gate(&s.frame, ctx, id, source); if code != .Applied {return {code = code}}
	if d.kind != .Repeat_Scroll {return {code = .Invalid_Action}}
	if s.live.phase != .Idle {return {code = .Conflict}}
	return scroll.dispatch(
		ss,
		ctx,
		{kind = .Scroll_By, id = d.scroll_id, source = source, delta_y = d.step},
	)
}
