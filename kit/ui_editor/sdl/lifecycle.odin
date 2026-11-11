package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import "core:math"
import sdl "vendor:sdl3"
Lifecycle :: struct {
	start, stop: proc(window: ^sdl.Window, user: rawptr) -> bool,
	size:        proc(window: ^sdl.Window, user: rawptr) -> (i32, i32, bool),
	area:        proc(window: ^sdl.Window, rect: sdl.Rect, cursor: i32, user: rawptr) -> bool,
	user:        rawptr,
}
sync :: proc(
	a: ^Adapter,
	input: ^backend.Input,
	ctx: ^interaction.Context,
	s: ^editor.State,
	window: ^sdl.Window,
) -> bool {
	e: ^editor.View
	if !input.suspended && interaction.ready(ctx) && s.frame.stamp == ctx.frame.stamp {
		for &v in s.frame.editors {if v.node_id == ctx.focus_id && v.availability == .Applied && interaction.guard(ctx, v.node_id, .Keyboard) == .Applied {e = &v; break}}
	}
	if a.capture_id != "" {
		capture, found := editor.find(&s.frame, a.capture_id)
		if e == nil ||
		   !found ||
		   capture.id != e.id ||
		   a.scope_id != s.frame.scope_id {cancel_capture(a)}
	}
	if e == nil {cancel_capture(a); return stop_text(a, window)}
	if !a.text_active {
		ok := false
		if a.lifecycle.start !=
		   nil {ok = a.lifecycle.start(window, a.lifecycle.user)} else if window != nil {ok = sdl.StartTextInput(window)}
		if !ok {return false}; a.text_active = true
	}
	w, h: i32; ok := false
	if a.lifecycle.size !=
	   nil {w, h, ok = a.lifecycle.size(window, a.lifecycle.user)} else if window != nil {ok = sdl.GetWindowSize(window, &w, &h)}
	if !ok ||
	   w <= 0 ||
	   h <= 0 ||
	   ctx.frame.drawable.w <= 0 ||
	   ctx.frame.drawable.h <= 0 {return false}
	xscale := ctx.frame.ui_scale * f64(w) / ctx.frame.drawable.w
	yscale := ctx.frame.ui_scale * f64(h) / ctx.frame.drawable.h
	if !base.finite(xscale) || !base.finite(yscale) {return false}
	content := base.forward_rect(e.geometry, e.content)
	if !editor.valid_geometry(e.geometry) {return false}
	x := clamp(
		math.floor(content.x * xscale),
		0,
		f64(w),
	); y := clamp(math.floor(content.y * yscale), 0, f64(h))
	right := clamp(
		math.ceil((content.x + content.w) * xscale),
		x,
		f64(w),
	); bottom := clamp(math.ceil((content.y + content.h) * yscale), y, f64(h))
	area := sdl.Rect{i32(x), i32(y), max(1, i32(right - x)), max(1, i32(bottom - y))}
	caret: f64; for b, k in e.boundaries {if b == e.caret {caret = e.stops[k]; break}}
	cursor := i32(
		clamp(
			math.round((content.x + (caret - e.scroll) * e.geometry.scale) * xscale - x),
			0,
			f64(area.w),
		),
	)
	if a.lifecycle.area != nil {return a.lifecycle.area(window, area, cursor, a.lifecycle.user)}
	return window != nil && sdl.SetTextInputArea(window, &area, cursor)
}
@(private)
stop_text :: proc(a: ^Adapter, window: ^sdl.Window) -> bool {
	if !a.text_active {return true}
	ok := false
	if a.lifecycle.stop !=
	   nil {ok = a.lifecycle.stop(window, a.lifecycle.user)} else if window != nil {ok = sdl.StopTextInput(window)}
	if ok {a.text_active = false}; return ok
}
close :: proc(a: ^Adapter, window: ^sdl.Window) -> bool {
	cancel_capture(a)
	ok := stop_text(a, window)
	if ok {a^ = {}}
	return ok
}
