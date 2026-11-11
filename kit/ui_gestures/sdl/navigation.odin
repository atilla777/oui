package ui_gestures_sdl
import gestures ".."
import interaction "../../ui_interaction"
import scroll "../../ui_scroll"
import backend "../../ui_sdl"
import sdl "vendor:sdl3"

@(private)
navigation :: proc(
	a: ^Adapter,
	input: ^backend.Input,
	ctx: ^interaction.Context,
	s: ^gestures.State,
	ss: ^scroll.State,
	n: backend.Normalized_Input,
) -> Result {
	e := n.event
	keyboard := e.type == .KEY_DOWN || e.type == .KEY_UP
	gamepad := e.type == .GAMEPAD_BUTTON_DOWN || e.type == .GAMEPAD_BUTTON_UP
	if !keyboard && !gamepad {return {}}
	source := interaction.Source.Keyboard; if gamepad {source = .Gamepad}
	active := s.live.phase != .Idle
	confirm := keyboard && (e.key.key == sdl.K_RETURN || e.key.key == sdl.K_SPACE)
	confirm ||= gamepad && sdl.GamepadButton(e.gbutton.button) == .SOUTH
	id := ""
	for d in s.frame.gestures {if d.node_id == ctx.focus_id && d.availability == .Applied && (d.kind == .Drag_Source || d.kind == .Repeat_Scroll) {id = d.id; break}}
	if confirm && (active || id != "") {
		if !n.down {
			if active &&
			   s.live.source == source &&
			   s.live.owner.kind == .Repeat_Scroll &&
			   (gamepad || e.key.key == a.trigger_key) {return terminate(a, ctx, s, ss, .End)}
			return {consumed = true}
		}
		if !n.front ||
		   input.suspended ||
		   !interaction.ready(ctx) ||
		   a.pending != nil {return {consumed = true}}
		if !active && id != "" {
			if keyboard {a.trigger_key = e.key.key}
			a.clock.has_base = false; interaction.cancel_press(ctx)
			return apply(s, ctx, ss, {kind = .Begin, id = id, source = source})
		}
		if active &&
		   s.live.source == source &&
		   s.live.owner.kind == .Drag_Source {return terminate(a, ctx, s, ss, .End)}
		return {consumed = true}
	}
	if !active {return {}}
	if !n.down || !n.front || input.suspended || s.live.source != source {return {consumed = true}}
	cancel := keyboard && e.key.key == sdl.K_ESCAPE
	cancel ||= gamepad && sdl.GamepadButton(e.gbutton.button) == .EAST
	if cancel {return terminate(a, ctx, s, ss, .Cancel, .Explicit)}
	aim := keyboard && e.key.key == sdl.K_TAB
	backwards := keyboard && e.key.mod & sdl.KMOD_SHIFT != {}
	if gamepad {
		b := sdl.GamepadButton(e.gbutton.button)
		aim = b == .DPAD_UP || b == .DPAD_DOWN || b == .DPAD_LEFT || b == .DPAD_RIGHT
		backwards = b == .DPAD_UP || b == .DPAD_LEFT
	}
	if aim && interaction.ready(ctx) && s.live.owner.kind == .Drag_Source && a.pending == nil {
		if target := next_target(&s.frame, s.live.target_id, s.live.owner.scope_id, backwards);
		   target !=
		   "" {return apply(s, ctx, ss, {kind = .Aim, id = target, source = source, cycle = s.live.cycle})}
	}
	return {consumed = true}
}
@(private)
next_target :: proc(f: ^gestures.Frame, current, scope: string, backwards: bool) -> string {
	start := -1
	for d, j in f.gestures {if d.id == current {start = j}}
	count := len(f.gestures); if backwards && start < 0 {start = 0}
	for step in 1 ..= count {
		index := (start + step) % count; if backwards {index = (start - step + count) % count}
		d := &f.gestures[index]
		if d.kind == .Drop_Target &&
		   d.scope_id == scope &&
		   d.availability == .Applied {return d.id}
	}
	return ""
}
@(private)
terminate :: proc(
	a: ^Adapter,
	ctx: ^interaction.Context,
	s: ^gestures.State,
	ss: ^scroll.State,
	kind: gestures.Action_Kind,
	reason: gestures.Cancel_Reason = .None,
) -> Result {
	a.clock.has_base = false
	if pending, has := a.pending.?;
	   has && pending.cycle == s.live.cycle && pending.kind == .Cancel {return {consumed = true}}
	action := gestures.Action {
		kind   = kind,
		reason = reason,
		source = s.live.source,
		cycle  = s.live.cycle,
	}
	if kind == .Cancel {a.pending_point = nil}
	if !interaction.ready(ctx) {a.pending = action; return {consumed = true}}
	return apply(s, ctx, ss, action)
}
