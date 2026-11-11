package app

import sections "../sections"
import base "ui:ui_base"
import gesture_sdl "ui:ui_gestures/sdl"
import hold "ui:ui_hold"
import hold_sdl "ui:ui_hold/sdl"
import transitions "ui:ui_transitions"

Hold_Page_Runtime :: struct {
	state:                          hold.State,
	input:                          hold_sdl.Adapter,
	buffer:                         [256]u8,
	counts:                         [3][256]u8,
	depth:                          int,
	popup, tooltip, cancel_allowed: bool,
}
Hold_Page_Reader :: struct {
	frame: hold.Frame,
}
active_hold :: proc(r: ^Runtime) -> (^Hold_Page_Runtime, bool) {
	if a, selected := r.content.(^Accessibility_Page_Runtime); selected {return &a.hold, true}
	if h, ok := r.content.(^Hold_Page_Runtime); ok {return h, true}
	if v, ok := r.content.(^Transition_Page_Runtime); ok {return &v.hold, true}
	return nil, false
}
compose_hud :: proc(r: ^Runtime, c: ^Page_Composition) {
	h, _ := r.content.(^Hold_Page_Runtime)
	sections.compose_hud(
		{r.model^, r.allocator},
		c,
		{state = {live = h.state.live}, buffer = h.buffer[:]},
	)
}
accept_hold :: proc(r: ^Runtime, stamp: base.Frame_Stamp, result: hold.Result) {
	if r.page == .Accessibility {accessibility_hold(r, stamp, result); return}
	if result.dispatch.has_event {accept_base(r, stamp, result.dispatch.event)}
}
advance_page_clock :: proc(s: ^Shell, now_ms: i64) -> bool {
	r := &s.runtime
	if v, selected := active_transition(r); selected {
		was_ready := r.publication.ready
		if h, owns_hold := active_hold(r); owns_hold {
			result := hold_sdl.step(&h.input, &h.state, &r.interaction, now_ms)
			accept_hold(r, reader_stamp(&r.live), result)
			if !finish_input(s, s.model.page, was_ready) {return false}
		}
		active := false; for track in v.state.frame.tracks {active ||= track.phase != .Completed}
		delta, ok := transitions.step_transition_clock(
			&v.clock,
			now_ms,
			r.publication.ready && active && !s.input.suspended,
			v.state.clock_epoch,
		)
		if !ok {return false}; if delta == 0 {return true}
		v.step = {
			delta_ms = delta,
		}; return rebuild(r)
	}
	if g, selected := r.content.(^Gesture_Page_Runtime); selected {
		was_ready := r.publication.ready
		result := gesture_sdl.step(&g.input, &s.input, &r.interaction, &g.state, &r.scroll, now_ms)
		if !accept_gesture_page(r, result.gesture) {block(r); return false}
		return finish_input(s, s.model.page, was_ready)
	}
	if h, selected := active_hold(r); selected {
		was_ready := r.publication.ready
		result := hold_sdl.step(&h.input, &h.state, &r.interaction, now_ms)
		accept_hold(r, reader_stamp(&r.live), result)
		return finish_input(s, s.model.page, was_ready)
	}
	return true
}
