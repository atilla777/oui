package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import "core:strings"

dispatch :: proc(s: ^State, ctx: ^interaction.Context, action: Action) -> Result {
	if code := interaction.guard_common(ctx, action.source);
	   code != .Applied {return {code = code}}
	if s.frame.stamp != ctx.frame.stamp {return {code = .Not_Ready}}
	r := Result {
		code = .Applied,
	}
	h := &s.live
	switch action.kind {
	case .Begin:
		if h.phase != .Idle {return r}
		if code := interaction.guard(ctx, action.id, action.source);
		   code != .Applied {return {code = code}}
		n, _ := interaction.find(&ctx.frame, action.id)
		if n.activation_owner != "hold" {return {code = .Activation_Required}}
		threshold := i64(0)
		for d in s.frame.holds {if d.id == action.id {threshold = d.threshold_ms}}
		if threshold <= 0 || h.cycle == max(u64) {return {code = .Invalid_Action}}
		id, e := strings.clone(action.id, s.allocator); if e != nil {return {code = .Allocation}}
		cycle := h.cycle + 1
		delete(h.id, s.allocator)
		h^ = {id, action.source, .Holding, 0, threshold, cycle}
		interaction.dispatch(ctx, {.Focus, action.id, action.source, false})
		signal(&r, h^, .Started)
	case .Advance:
		if action.duration_ms < 0 {return {code = .Invalid_Action}}
		if h.phase != .Holding || action.duration_ms == 0 {return r}
		if code := interaction.guard(ctx, h.id, h.source); code != .Applied {return {code = code}}
		n, _ := interaction.find(&ctx.frame, h.id)
		if n.activation_owner != "hold" {return {code = .Activation_Required}}
		if action.duration_ms > max(i64) - h.elapsed_ms {return {code = .Invalid_Action}}
		complete := action.duration_ms >= h.threshold_ms - h.elapsed_ms
		if complete && ctx.publication.sequence == max(u64) {return {code = .Invalid_Action}}
		h.elapsed_ms += min(action.duration_ms, h.threshold_ms - h.elapsed_ms)
		signal(&r, h^, .Progress)
		if complete {
			h.phase = .Completed_Waiting_Release
			signal(&r, h^, .Completed)
			s.last_result = r
			r.dispatch = interaction.dispatch_owned(
				ctx,
				{.Activate, h.id, h.source, false},
				"hold",
			)
		}
	case .Release:
		if h.phase == .Idle {return r}
		if action.source != h.source ||
		   (action.id != "" && action.id != h.id) {return {code = .Invalid_Action}}
		if h.phase == .Holding {signal(&r, h^, .Cancelled, .Early_Release)}
		h.phase, h.elapsed_ms = .Idle, 0
	case .Cancel:
		if action.reason <= .None ||
		   action.reason > .Threshold_Changed {return {code = .Invalid_Action}}
		if h.phase != .Holding {return r}
		signal(&r, h^, .Cancelled, action.reason)
		h.phase, h.elapsed_ms = .Idle, 0
	case:
		return {code = .Invalid_Action}
	}
	s.last_result = r
	base.invalidate(ctx.publication)
	return r
}
@(private)
signal :: proc(r: ^Result, h: Hold_State, kind: Signal_Kind, reason: Cancel_Reason = .None) {
	p := f64(0); if h.threshold_ms > 0 {p = f64(h.elapsed_ms) / f64(h.threshold_ms)}
	r.signals[r.count] = {kind, h.id, h.source, h.cycle, p, reason}
	r.count += 1
}
