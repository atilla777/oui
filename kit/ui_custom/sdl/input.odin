package ui_custom_sdl

import ui ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"

Result :: struct {
	dispatch: interaction.Dispatch_Result,
	consumed: bool,
}
// selected=true means the caller already ran its layer traversal with the same
// ui.hit_predicate. This adapter never imports layers or owns physical edges.
handle :: proc(
	s: ^ui.State,
	ctx: ^interaction.Context,
	n: backend.Normalized_Input,
	selected_id: string = "",
	selected: bool = false,
) -> Result {
	if !n.accepted {return {}}
	// The one normalizer already performs the applicable common loss cleanup.
	if n.loss || n.suspended {return {}}
	pointer := n.pointer_button || n.event.type == .MOUSE_MOTION
	if s.frame.stamp != ctx.frame.stamp || !interaction.ready(ctx) {
		if n.pointer_button && !n.down {interaction.cancel_press(ctx)}
		if pointer || n.has_action {return {{code = .Not_Ready}, true}}
		return {}
	}
	if pointer {
		if !n.pointer_valid {if n.pointer_button && !n.down {interaction.cancel_press(ctx)}; return {{code = .Invalid_Action}, true}}
		id := selected_id
		if !selected {
			target, code := interaction.hit_test(&ctx.frame, n.x, n.y, ui.hit_predicate, &s.frame)
			id = ""; if code == .Applied {id = target.description.id}
		}
		if n.event.type ==
		   .MOUSE_MOTION {return {{code = interaction.observe_target(ctx, id)}, true}}
		if n.down {
			if !n.front {return {{code = .Invalid_Action}, true}}
			return {{code = interaction.begin_pointer_press(ctx, id)}, true}
		}
		if custom_id(&s.frame, id) {
			if code := interaction.consume_press(ctx, id);
			   code != .Applied {return {{code = code}, true}}
			return {
				interaction.dispatch_owned(ctx, {.Activate, id, .Mouse, false}, "custom"),
				true,
			}
		}
		if code := interaction.consume_press(ctx, id);
		   code != .Applied {return {{code = code}, true}}
		return {interaction.dispatch_routed(ctx, {.Activate, id, .Mouse, false}), true}
	}
	if n.has_action && n.action.kind == .Activate && custom_id(&s.frame, n.action.id) {
		if !n.front {return {{code = .Invalid_Action}, true}}
		return {interaction.dispatch_owned(ctx, n.action, "custom"), true}
	}
	return {}
}
custom_id :: proc(frame: ^ui.Frame, id: string) -> bool {for view in frame.views {if view.node_id ==
			   id &&
		   view.hit != nil {return true}}
	return false}
reconcile_pointer :: proc(
	s: ^ui.State,
	ctx: ^interaction.Context,
	selected_id: string,
) -> interaction.Code {
	if s.frame.stamp != ctx.frame.stamp {return .Not_Ready}
	pressed := ctx.pressed_id
	code := interaction.observe_target(ctx, selected_id)
	if code != .Applied {return code}
	if pressed != "" &&
	   pressed != selected_id {interaction.cancel_press(ctx); base.invalidate(ctx.publication)}
	return .Applied
}
