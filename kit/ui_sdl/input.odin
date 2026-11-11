package ui_sdl

import base "../ui_base"
import interaction "../ui_interaction"
import sdl "vendor:sdl3"

Input :: struct {
	directions_down:                                           [4]bool,
	hidden, unfocused:                                         bool,
	window_id:                                                 sdl.WindowID,
	gamepad:                                                   ^sdl.Gamepad,
	gamepad_id:                                                sdl.JoystickID,
	south_down, east_down, back_down, suspended, device_error: bool,
	mouse_down:                                                bool,
	keys_down:                                                 bit_set[Input_Key],
}
Input_Key :: enum {
	Return,
	Space,
	Escape,
	Tab,
	Left,
	Right,
	Up,
	Down,
	Home,
	End,
	Backspace,
	Delete,
	A,
	C,
	V,
	X,
	Keypad_Enter,
}
@(private)
input_key :: proc(key: sdl.Keycode) -> (Input_Key, bool) {
	switch key {
	case sdl.K_RETURN:
		return .Return, true
	case sdl.K_SPACE:
		return .Space, true
	case sdl.K_ESCAPE:
		return .Escape, true
	case sdl.K_TAB:
		return .Tab, true
	case sdl.K_LEFT:
		return .Left, true
	case sdl.K_RIGHT:
		return .Right, true
	case sdl.K_UP:
		return .Up, true
	case sdl.K_DOWN:
		return .Down, true
	case sdl.K_HOME:
		return .Home, true
	case sdl.K_END:
		return .End, true
	case sdl.K_BACKSPACE:
		return .Backspace, true
	case sdl.K_DELETE:
		return .Delete, true
	case sdl.K_A:
		return .A, true
	case sdl.K_C:
		return .C, true
	case sdl.K_V:
		return .V, true
	case sdl.K_X:
		return .X, true
	case sdl.K_KP_ENTER:
		return .Keypad_Enter, true
	}
	return {}, false
}
Input_Result :: struct {
	dispatch: interaction.Dispatch_Result,
	consumed: bool,
}
// One synchronous value per SDL event. Selected family adapters receive this
// value and borrow the same Input; they never normalize/open devices again.
Normalized_Input :: struct {
	event:                                           sdl.Event,
	action:                                          interaction.Action,
	x, y:                                            f64,
	has_action, pointer_button, down, consumed:      bool,
	accepted, front, suspended, loss, pointer_valid: bool,
}
// Device bookkeeping and loss cleanup precede specialization, even when not
// ready. No activation/navigation/focus/press acquisition happens in this stage.
normalize_event :: proc(
	input: ^Input,
	ctx: ^interaction.Context,
	event: sdl.Event,
	window: base.Extent,
) -> (
	n: Normalized_Input,
) {
	n.event, n.suspended = event, input.suspended
	#partial switch event.type {
	case .TEXT_INPUT:
		n.accepted = event.text.windowID == input.window_id
	case .TEXT_EDITING:
		n.accepted = event.edit.windowID == input.window_id
	case .MOUSE_MOTION:
		if !input.suspended && event.motion.windowID == input.window_id {
			n.accepted = true
			x, y, ok := pointer_pixels(
				f64(event.motion.x),
				f64(event.motion.y),
				window,
				ctx.frame.drawable,
			)
			n.x, n.y, n.pointer_valid = x, y, ok
		}
	case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
		if event.button.windowID != input.window_id || event.button.button != 1 {return}
		n.accepted, n.down = true, event.type == .MOUSE_BUTTON_DOWN
		n.front = n.down && !input.mouse_down
		input.mouse_down = n.down
		if input.suspended {interaction.cancel_press(ctx); return}
		x, y, ok := pointer_pixels(
			f64(event.button.x),
			f64(event.button.y),
			window,
			ctx.frame.drawable,
		)
		if !ok {interaction.cancel_press(ctx); return}
		n.x, n.y, n.pointer_button, n.consumed = x, y, true, true
		n.pointer_valid = true
	case .MOUSE_WHEEL:
		n.accepted = event.wheel.windowID == input.window_id
		if n.accepted {
			n.x, n.y, n.pointer_valid = pointer_pixels(
				f64(event.wheel.mouse_x),
				f64(event.wheel.mouse_y),
				window,
				ctx.frame.drawable,
			)
		}
	case .GAMEPAD_ADDED:
		if input.gamepad == nil {
			input.gamepad = sdl.OpenGamepad(event.gdevice.which)
			if input.gamepad ==
			   nil {input.device_error = true} else {input.gamepad_id = event.gdevice.which}
		}
	case .GAMEPAD_REMOVED:
		if event.gdevice.which == input.gamepad_id {
			n.accepted, n.loss = true, true
			close_input(input); interaction.cancel_press(ctx)
		}
	case .GAMEPAD_BUTTON_DOWN, .GAMEPAD_BUTTON_UP:
		if input.gamepad_id == 0 || event.gbutton.which != input.gamepad_id {return}
		n.accepted = true
		button := sdl.GamepadButton(event.gbutton.button)
		down := event.type == .GAMEPAD_BUTTON_DOWN
		n.down, n.front = down, down
		if button == .SOUTH || button == .EAST || button == .BACK {
			previous := &input.south_down
			if button == .EAST {previous = &input.east_down}
			if button == .BACK {previous = &input.back_down}
			front := down && !previous^; previous^ = down
			n.front = front
			if input.suspended {return}
			if !front {return}
			n.action = {
				kind   = .Cancel,
				source = .Gamepad,
			}
			if button == .SOUTH {n.action = {.Activate, ctx.focus_id, .Gamepad, false}}
			n.has_action, n.consumed = true, true
			return
		}
		direction := -1
		if button == .DPAD_UP {direction = 0}; if button == .DPAD_DOWN {direction = 1}
		if button == .DPAD_LEFT {direction = 2}; if button == .DPAD_RIGHT {direction = 3}
		if direction >=
		   0 {n.front = down && !input.directions_down[direction]; input.directions_down[direction] = down}
		if down && n.front && !input.suspended {
			if button == .DPAD_DOWN ||
			   button ==
				   .DPAD_RIGHT {n.action = {.Navigate, "", .Gamepad, false}; n.has_action, n.consumed = true, true}
			if button == .DPAD_UP ||
			   button ==
				   .DPAD_LEFT {n.action = {.Navigate, "", .Gamepad, true}; n.has_action, n.consumed = true, true}
		}
	case .WINDOW_FOCUS_LOST, .WINDOW_HIDDEN, .WINDOW_MOUSE_LEAVE:
		if event.window.windowID == input.window_id {
			n.accepted, n.loss = true, true
			interaction.cancel_pointer(ctx)
			if event.type == .WINDOW_HIDDEN {input.hidden = true}
			if event.type == .WINDOW_FOCUS_LOST {input.unfocused = true}
			input.suspended = input.hidden || input.unfocused
			n.suspended = input.suspended
		}
	case .WINDOW_FOCUS_GAINED, .WINDOW_SHOWN:
		if event.window.windowID == input.window_id {
			if event.type == .WINDOW_SHOWN {input.hidden = false} else {input.unfocused = false}
			input.suspended = input.hidden || input.unfocused
			n.suspended, n.accepted = input.suspended, true
		}
	case .KEY_DOWN, .KEY_UP:
		if event.key.windowID != input.window_id {return}
		n.accepted, n.down = true, event.type == .KEY_DOWN
		n.front = n.down && !event.key.repeat
		if key, known := input_key(event.key.key); known {
			n.front = n.front && key not_in input.keys_down
			if n.down {input.keys_down += {key}} else {input.keys_down -= {key}}
		}
		// Preserve ordinary menu dispatch for non-repeat SDL key-down events.
		// Selected capture families instead use the once-normalized front field.
		if input.suspended || !n.down || !n.front || event.key.repeat {return}
		action: interaction.Action
		if event.key.key == sdl.K_TAB {
			action = {.Navigate, "", .Keyboard, event.key.mod & sdl.KMOD_SHIFT != {}}
		} else if event.key.key == sdl.K_RETURN || event.key.key == sdl.K_SPACE {
			action = {.Activate, ctx.focus_id, .Keyboard, false}
		} else if event.key.key == sdl.K_ESCAPE {
			action = {
				kind   = .Cancel,
				source = .Keyboard,
			}
		} else {return}
		n.action, n.has_action, n.consumed = action, true, true
	}
	return
}

// Called once for an event not consumed by a selected family. The ordinary
// wrapper below preserves the pre-extraction menu path.
dispatch_input :: proc(ctx: ^interaction.Context, n: Normalized_Input) -> Input_Result {
	if n.accepted &&
	   n.pointer_valid &&
	   n.event.type ==
		   .MOUSE_MOTION {return {{code = interaction.observe_pointer(ctx, n.x, n.y)}, false}}
	if n.pointer_button {
		target, code := interaction.hit_test(&ctx.frame, n.x, n.y)
		id := ""; if code == .Applied {id = target.description.id}
		if n.down {if !n.front {return {consumed = true}}; return {{code = interaction.begin_pointer_press(ctx, id)}, true}}
		return {interaction.release_press(ctx, id, .Mouse), true}
	}
	if n.has_action {return {interaction.dispatch(ctx, n.action), n.consumed}}
	return {}
}
input_event :: proc(
	input: ^Input,
	ctx: ^interaction.Context,
	event: sdl.Event,
	window: base.Extent,
) -> Input_Result {
	return dispatch_input(ctx, normalize_event(input, ctx, event, window))
}

// No UI-scale conversion here: common hit-testing owns drawable -> logical.
pointer_pixels :: proc(x, y: f64, window, drawable: base.Extent) -> (f64, f64, bool) {
	for v in ([6]f64{x, y, window.w, window.h, drawable.w, drawable.h}) {if !base.finite(v) {return 0, 0, false}}
	if window.w <= 0 || window.h <= 0 || drawable.w <= 0 || drawable.h <= 0 {return 0, 0, false}
	return x * drawable.w / window.w, y * drawable.h / window.h, true
}
close_input :: proc(input: ^Input) {
	if input.gamepad != nil {sdl.CloseGamepad(input.gamepad)}
	input.gamepad, input.gamepad_id = nil, 0
	input.south_down, input.east_down, input.back_down = false, false, false
	input.directions_down = {}
}
