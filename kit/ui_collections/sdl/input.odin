package ui_collections_sdl

import ui ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import sdl "vendor:sdl3"

Result :: struct {
	result:   ui.Result,
	consumed: bool,
}
// Consumes the caller's single normalized event. No device state or focus owner.
handle :: proc(s: ^ui.State, ctx: ^interaction.Context, n: backend.Normalized_Input) -> Result {
	if !n.accepted || n.loss || n.suspended {return {}}
	if n.event.type == .MOUSE_WHEEL {
		if !n.pointer_valid || ctx.frame.ui_scale <= 0 || len(s.frame.collections) != 1 {return {}}
		cs := s.frame.collections[0]
		viewport, found := interaction.find(&ctx.frame, cs.description.scroll_id)
		if !found ||
		   !base.contains(viewport.bounds, n.x / ctx.frame.ui_scale, n.y / ctx.frame.ui_scale) ||
		   !base.contains(
				   viewport.clip,
				   n.x / ctx.frame.ui_scale,
				   n.y / ctx.frame.ui_scale,
			   ) {return {}}
		delta := -f64(n.event.wheel.y) * 30
		if n.event.wheel.direction == .FLIPPED {delta = -delta}
		return {
			ui.dispatch(
				s,
				ctx,
				{
					kind = .Scroll_By,
					collection_id = cs.description.id,
					source = .Mouse,
					delta_y = delta,
				},
			),
			true,
		}
	}
	if n.down && n.front {
		direction: ui.Direction; directional := false
		#partial switch n.event.type {
		case .KEY_DOWN:
			switch n.event.key.key {
			case sdl.K_UP:
				direction, directional = .Up, true
			case sdl.K_DOWN:
				direction, directional = .Down, true
			case sdl.K_LEFT:
				direction, directional = .Left, true
			case sdl.K_RIGHT:
				direction, directional = .Right, true
			}
		case .GAMEPAD_BUTTON_DOWN:
			#partial switch sdl.GamepadButton(n.event.gbutton.button) {
			case .DPAD_UP:
				direction, directional = .Up, true
			case .DPAD_DOWN:
				direction, directional = .Down, true
			case .DPAD_LEFT:
				direction, directional = .Left, true
			case .DPAD_RIGHT:
				direction, directional = .Right, true
			}
		}
		if collection, _, valid := ui.decode_item_node_id(ctx.focus_id); valid && directional {
			source :=
				interaction.Source.Keyboard; if n.event.type == .GAMEPAD_BUTTON_DOWN {source = .Gamepad}
			return {
				ui.dispatch(
					s,
					ctx,
					{
						kind = .Move_Direction,
						collection_id = collection,
						direction = direction,
						source = source,
					},
				),
				true,
			}
		}
		if n.has_action && n.action.kind == .Navigate {
			id, code := ui.tab_target(&s.frame, &ctx.frame, ctx.focus_id, n.action.backwards)
			if code != .Applied {return {result = {dispatch = {code = code}}, consumed = true}}
			collection, item, valid := ui.decode_item_node_id(id)
			if valid {return {ui.dispatch(s, ctx, {kind = .Focus, collection_id = collection, item_id = item, source = n.action.source}), true}}
			return {
				result = {
					dispatch = interaction.dispatch(ctx, {.Focus, id, n.action.source, false}),
				},
				consumed = true,
			}
		}
	}
	if n.pointer_button {
		if !interaction.ready(ctx) || s.frame.stamp != ctx.frame.stamp {
			if !n.down {interaction.cancel_press(ctx)}
			return {result = {dispatch = {code = .Not_Ready}}, consumed = true}
		}
		if !n.pointer_valid {if !n.down {interaction.cancel_press(ctx)}; return {}}
		target, hit_code := interaction.hit_test(&ctx.frame, n.x, n.y)
		if hit_code != .Applied {if !n.down {interaction.cancel_press(ctx)}; return {}}
		collection, item, valid := ui.decode_item_node_id(target.description.id)
		if !valid || target.activation_owner != "collections" {return {}}
		if n.down {
			if !n.front {return {consumed = true}}
			if code := interaction.begin_pointer_press(ctx, target.description.id);
			   code != .Applied {return {result = {dispatch = {code = code}}, consumed = true}}
			return {consumed = true, result = {dispatch = {code = .Applied}}}
		}
		if code := interaction.consume_press(ctx, target.description.id);
		   code != .Applied {return {result = {dispatch = {code = code}}, consumed = true}}
		return {
			ui.dispatch(
				s,
				ctx,
				{kind = .Activate, collection_id = collection, item_id = item, source = .Mouse},
			),
			true,
		}
	}
	if n.has_action && n.action.kind == .Activate {
		collection, item, valid := ui.decode_item_node_id(n.action.id); if !valid {return {}}
		if !n.front {return {consumed = true}}
		return {
			ui.dispatch(
				s,
				ctx,
				{
					kind = .Activate,
					collection_id = collection,
					item_id = item,
					source = n.action.source,
				},
			),
			true,
		}
	}
	return {}
}
