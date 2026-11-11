package app

import "core:testing"
import base "ui:ui_base"
import hold "ui:ui_hold"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import style "ui:ui_style"
import transitions "ui:ui_transitions"

@(test)
g17_foreground_and_border_are_visible_changing_tracks_not_constant_metadata :: proc(
	t: ^testing.T,
) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Transitions) {return}
	before_fg, before_border: style.Color
	for p in f.s.runtime.live.paint.presentation {
		if p.id == "transitions/caption" {before_fg = p.computed[.Foreground].value.(style.Color)}
		if p.id == "transitions/card" {before_border = p.computed[.Border].value.(style.Color)}
	}
	testing.expect(
		t,
		dispatch(&f.s, {.Activate, "transitions/reduced", .Agent, false}) &&
		dispatch(&f.s, {.Activate, "transitions/b", .Agent, false}),
	)
	fg, border := before_fg, before_border
	for p in f.s.runtime.live.paint.presentation {
		if p.id == "transitions/caption" {fg = p.computed[.Foreground].value.(style.Color)}
		if p.id == "transitions/card" {border = p.computed[.Border].value.(style.Color)}
	}
	testing.expect(
		t,
		fg != before_fg && border != before_border && present(&f.s.runtime),
		"G17 foreground and border must actually change on screen",
	)
}

@(test)
g17_card_current_hit_presence_and_retained_marker :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Transitions) {return}; s := &f.s
	card, found := layout.find(&s.runtime.live.geometry, "transitions/card")
	if !testing.expect(t, found, "G17 must publish a real card, not shell-only success") {return}
	marker, _ := layout.find(&s.runtime.live.geometry, "transitions/marker")
	testing.expect(t, dispatch(s, {.Activate, "transitions/reduced", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "transitions/b", .Agent, false}))
	after, _ := layout.find(&s.runtime.live.geometry, "transitions/card")
	marker_after, _ := layout.find(&s.runtime.live.geometry, "transitions/marker")
	testing.expect(t, card.bounds == after.bounds && marker.bounds == marker_after.bounds)
	// B offset(120,24), scale .8 about card center: old left corner no longer hits.
	_, old_hit := hit_pointer(&s.runtime, card.bounds.x + 8, card.bounds.y + 8)
	testing.expect(t, old_hit != .Applied)
	testing.expect(t, present(&s.runtime))
	testing.expect(t, dispatch(s, {.Activate, "transitions/presence", .Agent, false}))
	before := s.model
	testing.expect(
		t,
		!dispatch(s, {.Activate, "transitions/count", .Agent, false}) && s.model == before,
	)
}

@(test)
g17_c05_native_inverse_slider_hold_and_historical_reader :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Transitions) {return}; s := &f.s; r := &s.runtime
	testing.expect(t, dispatch(s, {.Activate, "transitions/reduced", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "transitions/b", .Agent, false}))
	v, _ := r.live.content.(Transition_Page_Reader)
	control := r.controls.frame.controls[0]
	track, _ := layout.find(&r.live.geometry, control.track_id)
	visual, _ := transitions.geometry(&v.frame, control.track_id)
	point := base.forward_point(
		visual,
		{track.bounds.x + track.bounds.w * .25, track.bounds.y + track.bounds.h / 2},
	)
	page_pointer(s, .MOUSE_BUTTON_DOWN, point.x, point.y)
	page_pointer(s, .MOUSE_BUTTON_UP, point.x, point.y)
	testing.expect(t, s.model.transition.slider == 25)
	v, _ = r.live.content.(Transition_Page_Reader)
	target, _ := transitions.geometry(&v.frame, "transitions/hold")
	page_pointer(
		s,
		.MOUSE_BUTTON_DOWN,
		target.bounds.x + target.bounds.w / 2,
		target.bounds.y + target.bounds.h / 2,
	)
	h, _ := active_hold(r)
	if !testing.expect(t, h.state.live.phase == .Holding) {return}
	x := hold.dispatch(
		&h.state,
		&r.interaction,
		{kind = .Advance, source = .Mouse, duration_ms = 999},
	)
	accept_hold(
		r,
		reader_stamp(&r.live),
		x,
	); testing.expect(t, rebuild(r) && s.model.transition.count == 0)
	x = hold.dispatch(
		&h.state,
		&r.interaction,
		{kind = .Advance, source = .Mouse, duration_ms = 1},
	)
	accept_hold(
		r,
		reader_stamp(&r.live),
		x,
	); testing.expect(t, rebuild(r) && s.model.transition.count == 1)
	old, copied := copy_reader(
		&r.live,
		r.allocator,
	); if !testing.expect(t, copied) {return}; defer destroy_reader(&old)
	testing.expect(t, dispatch(s, {.Activate, "shell/catalogue", .Agent, false}))
	testing.expect(t, draw_reader(&old) && !base.is_current(&r.publication, reader_stamp(&old)))
}

@(test)
g17_progress_is_the_sampled_visual_fraction :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Transitions) {return}; s := &f.s
	testing.expect(t, dispatch(s, {.Activate, "transitions/reduced", .Agent, false}))
	n, _ := layout.find(&s.runtime.live.geometry, "transitions/progress")
	for p in s.runtime.live.paint.presentation {if p.id == "transitions/progress" {testing.expect(t, p.area.w == n.bounds.w * .25)}}
}

@(test)
g17_c05_slider_hold_and_clock_are_one_frozen_publication :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Transitions) {return}; s := &f.s
	_, slider := interaction.find(&s.runtime.interaction.frame, "transitions/slider")
	if !testing.expect(
		t,
		slider,
		"C05 requires the transformed slider in this actual page",
	) {return}
	testing.expect(t, dispatch(s, {.Activate, "transitions/reduced", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "transitions/b", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "transitions/reduced", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "transitions/a", .Agent, false}))
	testing.expect(t, advance_page_clock(s, 1000) && advance_page_clock(s, 1700))
	v, selected := s.runtime.live.content.(Transition_Page_Reader)
	if !testing.expect(t, selected) {return}
	g, found := transitions.geometry(&v.frame, "transitions/card")
	testing.expect(t, found && g.scale == .9 && g.opacity == .8)
	n, _ := layout.find(&s.runtime.live.geometry, "transitions/slider")
	frozen, _ := transitions.geometry(&v.frame, "transitions/slider")
	testing.expect(t, n.bounds != frozen.bounds)
	testing.expect(t, present(&s.runtime))
}
