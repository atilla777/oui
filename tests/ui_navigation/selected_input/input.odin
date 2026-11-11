package main

import base "ui:ui_base"
import controls "ui:ui_controls"
import controls_sdl "ui:ui_controls/sdl"
import hold "ui:ui_hold"
import hold_sdl "ui:ui_hold/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import scroll "ui:ui_scroll"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

input :: proc(r: ^Runtime, e: sdl.Event, window: base.Extent = {400, 300}) -> Input_Result {
	n := backend.normalize_event(&r.device, &r.ctx, e, window)
	if n.accepted && n.pointer_valid {r.pointer = {n.x, n.y}; r.has_pointer = true}
	if !n.accepted {return {}}
	id := ""; code := interaction.Code.Not_Found
	matched :=
		r.reader.geometry.stamp == r.ctx.frame.stamp && r.layers.frame.stamp == r.ctx.frame.stamp
	if matched &&
	   n.pointer_valid {target, c := layers.hit_test(&r.layers.frame, &r.reader.geometry, &r.ctx.frame, n.x, n.y); code = c; if target != nil {id = target.description.id}}
	specialized := n
	if !matched {specialized.has_action = false; specialized.front = false; specialized.pointer_button = n.pointer_button && !n.down}
	if n.pointer_button && n.down && code != .Applied {specialized.pointer_button = false}
	hr := hold_sdl.handle(&r.hold_input, &r.hold, &r.ctx, specialized)
	if hr.consumed {return {hold = hr.result, consumed = true}}
	cr := controls_sdl.handle(
		&r.controls_input,
		&r.controls,
		&r.ctx,
		&r.reader.geometry,
		specialized,
	)
	if cr.consumed {return {control = cr.result, consumed = true}}
	if n.loss || n.suspended {return {}}
	if !matched {if n.pointer_button && !n.down {interaction.cancel_press(&r.ctx)}; return {control = {dispatch = {code = .Not_Ready}}, consumed = n.consumed}}
	if e.type == .MOUSE_WHEEL && n.pointer_valid {
		if !interaction.ready(&r.ctx) {return {scroll = {code = .Not_Ready}, consumed = true}}
		v, c := layers.hit_test(&r.layers.frame, &r.reader.geometry, &r.reader.wheel, n.x, n.y)
		if c != .Applied || v == nil {return {scroll = {code = .Not_Found}, consumed = true}}
		region, found := scroll.find(&r.scroll.frame, v.description.id)
		if !found ||
		   len(region.items) == 0 {return {scroll = {code = .Invalid_Action}, consumed = true}}
		height :=
			region.items[0].height; for item in region.items {if item.id == region.anchor_id {height = item.height; break}}
		if height <= 0 {return {scroll = {code = .Invalid_Action}, consumed = true}}
		delta := -f64(e.wheel.y) * 3 * height; if e.wheel.direction == .FLIPPED {delta = -delta}
		return {
			scroll = scroll.dispatch(
				&r.scroll,
				&r.ctx,
				{kind = .Scroll_By, id = v.description.id, source = .Mouse, delta_y = delta},
			),
			consumed = true,
		}
	}
	if n.front {
		kind :=
			controls.Action_Kind.Move_Item; arrow, backwards := false, false; source := interaction.Source.Keyboard
		if e.type == .KEY_DOWN {switch e.key.key {case sdl.K_UP:
				arrow = true; backwards = true; case sdl.K_DOWN:
				arrow = true; case sdl.K_LEFT:
				arrow = true; kind = .Move_Left; case sdl.K_RIGHT:
				arrow = true; kind = .Move_Right}}
		if e.type ==
		   .GAMEPAD_BUTTON_DOWN {source = .Gamepad; #partial switch sdl.GamepadButton(e.gbutton.button) {case .DPAD_UP:
				arrow = true; backwards = true; case .DPAD_DOWN:
				arrow = true; case .DPAD_LEFT:
				arrow = true; kind = .Move_Left; case .DPAD_RIGHT:
				arrow = true; kind = .Move_Right}}
		if arrow {for c in r.controls.frame.controls {if c.kind == .List {for item in c.items {if item.node_id == r.ctx.focus_id {return {control = controls.dispatch(&r.controls, &r.ctx, {kind = kind, source = source, backwards = backwards}, &r.layers, &r.scroll), consumed = true}}}}}}
	}
	if n.has_action {
		a := controls.Action {
			source    = n.action.source,
			id        = n.action.id,
			backwards = n.action.backwards,
		}
		switch n.action.kind {case .Focus:
			a.kind = .Focus; case .Navigate:
			a.kind = .Navigate; case .Activate:
			a.kind = .Activate; case .Cancel:
			a.kind = .Cancel}
		return {
			control = controls.dispatch(&r.controls, &r.ctx, a, &r.layers, &r.scroll),
			consumed = true,
		}
	}
	if n.pointer_button {
		if n.down {if !n.front {return {consumed = true}}; if code != .Applied {return {control = {dispatch = {code = code}}, consumed = true}}; return {control = {dispatch = {code = interaction.begin_pointer_press(&r.ctx, id)}}, consumed = true}}
		if c := interaction.consume_press(&r.ctx, id);
		   c != .Applied {return {control = {dispatch = {code = c}}, consumed = true}}
		return {
			control = controls.dispatch(
				&r.controls,
				&r.ctx,
				{kind = .Activate, id = id, source = .Mouse},
				&r.layers,
				&r.scroll,
			),
			consumed = true,
		}
	}
	if e.type == .MOUSE_MOTION && n.pointer_valid {
		if !interaction.ready(&r.ctx) {return {control = {dispatch = {code = .Not_Ready}}}}
		if r.ctx.hover_id !=
		   id {r.ctx.hover_id = interaction.retained_id(&r.ctx.frame, id); base.invalidate(&r.p)}
	}
	return {}
}
hold_step :: proc(r: ^Runtime, now: i64) -> hold.Result {
	if r.reader.geometry.stamp != r.ctx.frame.stamp ||
	   r.layers.frame.stamp !=
		   r.ctx.frame.stamp {hold_sdl.block(&r.hold_input, &r.ctx); controls_sdl.block(&r.controls_input, &r.ctx); return {code = .Not_Ready}}
	// Revalidate the remembered pointer against the newly frozen projection before
	// charging explicit wall time. This is not another physical edge/normalizer.
	if r.has_pointer && r.hold.live.phase == .Holding && r.hold.live.source == .Mouse {
		e: sdl.Event; e.motion.type = .MOUSE_MOTION
		x := hold_sdl.handle(
			&r.hold_input,
			&r.hold,
			&r.ctx,
			{event = e, accepted = true, pointer_valid = true, x = r.pointer[0], y = r.pointer[1]},
		)
		if x.consumed {return x.result}
	}
	return hold_sdl.step(&r.hold_input, &r.hold, &r.ctx, now)
}
