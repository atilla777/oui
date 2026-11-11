package app

import access_model "../../accessibility_demo/model"
import profile "../../controls_demo/model"
import gesture_model "../../gestures_demo/model"
import collection_model "../../virtualized_collections_demo/model"
import model "../model"
import "core:fmt"
import "core:mem"
import "core:strconv"
import "core:strings"
import base "ui:ui_base"
import collection_sdl "ui:ui_collections/sdl"
import controls "ui:ui_controls"
import controls_sdl "ui:ui_controls/sdl"
import custom "ui:ui_custom"
import painter "ui:ui_custom/sdl"
import editor "ui:ui_editor"
import editor_sdl "ui:ui_editor/sdl"
import gesture_sdl "ui:ui_gestures/sdl"
import hold_sdl "ui:ui_hold/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import scroll "ui:ui_scroll"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"

Shell :: struct {
	tools:                         Tools_Shell,
	inventory:                     gesture_model.State,
	performance_collection:        collection_model.State,
	cleanup_pending, exit_pending: bool,
	gesture:                       gesture_model.State,
	collection:                    collection_model.State,
	model:                         model.Model,
	runtime:                       Runtime,
	input:                         backend.Input,
	font_data:                     []u8, // Host-owned, borrowed until shell destruction.
	sources:                       Resource_Source,
	renderer:                      ^sdl.Renderer,
	window:                        ^sdl.Window,
	allocator:                     mem.Allocator,
	drawable:                      base.Extent,
	ledger:                        ^backend.Resource_Ledger,
	fail_entry:                    bool, // Read only in test builds.
}
enter :: proc(s: ^Shell) -> bool {
	if !close_page_input(s) {return false}
	if !cancel_accessibility(&s.runtime) {return false}
	when TOOLS {if s.tools.runtime.enabled {
			if s.tools.epoch == max(u64) {block(&s.runtime); return false}
			if s.runtime.live.tools != nil {
				destroy_reader(
					&s.tools.history,
				); s.tools.history = s.runtime.live; s.runtime.live = {}
			}
			s.tools.epoch += 1
		}}
	destroy(&s.runtime)
	if s.model.page ==
	   .Accessibility {s.model.accessibility.last_sequence, s.model.accessibility.last_cycle = 0, 0}
	when TEST {if s.fail_entry {s.fail_entry = false; s.runtime.error = .Entry; return false}}
	if !init(
		&s.runtime,
		s.renderer,
		s.font_data,
		&s.model,
		s.allocator,
		s.ledger,
		s.sources,
	) {s.runtime.error = .Entry; return false}
	s.runtime.drawable = s.drawable
	when TOOLS {s.runtime.tools_state = s.tools.runtime
		s.runtime.tools_state.epoch = s.tools.epoch}
	if v, ok := s.runtime.content.(^Lab_Inventory_Runtime); ok {
		if s.inventory.panels[0].id == "" {s.inventory = gesture_model.initial()}
		s.inventory.last_sequence, s.inventory.last_cycle = 0, 0
		v.model = &s.inventory
	}
	if g, ok := s.runtime.content.(^Gesture_Page_Runtime); ok {
		if s.gesture.panels[0].id == "" {s.gesture = gesture_model.initial()}
		// Watermarks belong to the old UI lifetime, not to card membership.
		s.gesture.last_sequence, s.gesture.last_cycle = 0, 0
		g.model = &s.gesture
	}
	if n, ok := active_collection(&s.runtime); ok {
		state := &s.collection; if s.model.page == .Diagnostics_Performance {state = &s.performance_collection}
		if state.reset_epoch == 0 {state^ = collection_model.create()}
		n.model = state
	}
	return rebuild(&s.runtime) && sync_name(s)
}
recover :: proc(s: ^Shell) -> bool {
	if s.cleanup_pending {
		if !close_page_input(s) {return false}
		return enter(s)
	}
	if n, ok := active_name(&s.runtime);
	   ok {if n.native_error == .Text_Lifecycle {n.native_error = .None}}
	if s.runtime.model == nil || s.runtime.page != s.model.page {return enter(s)}
	s.runtime.drawable =
		s.drawable; if s.model.page == .Atlas {s.runtime.force_reload = true}; return rebuild(&s.runtime) && sync_name(s)
}
consume :: proc(r: ^Runtime, stamp: base.Frame_Stamp, sequence: u64) -> bool {
	if stamp != r.interaction.frame.stamp ||
	   stamp != reader_stamp(&r.live) ||
	   stamp.lifetime == nil ||
	   stamp.model_revision != r.model.revision ||
	   sequence == 0 ||
	   sequence != r.publication.sequence ||
	   sequence <= r.last_sequence {return false}
	r.last_sequence = sequence
	when TOOLS {if t := r.tools_state.trace;
		   t != nil && t.has_pending {t.pending.sequence = sequence}}
	return true
}
accept_base :: proc(
	r: ^Runtime,
	stamp: base.Frame_Stamp,
	event: interaction.Button_Activated,
) -> bool {
	when TOOLS {if !trace_target(
			r,
			event.id,
			event.source,
			event.sequence,
		) {block(r); return false}}
	if r.model.page == .Composition &&
	   (event.id == "composition/parent" || event.id == "composition/child") {
		q := r.composition_route
		if q.sequence != event.sequence {return false}
		if event.id == "composition/child" &&
		   (!q.child || q.parent == r.model.composition.stop) {return false}
		if event.id == "composition/parent" && (!q.parent || q.child) {return false}
	}
	if !consume(r, stamp, event.sequence) {return false}
	if lab_menu(r.page) && lab_menu_action(r, event.id) {return true}
	if r.page == .Lab_Hud && lab_hud_action(r, event.id) {return true}
	if r.page == .Lab_Inventory && lab_inventory_action(r, event.id) {return true}
	if diagnostic_probe(r, event.id) {return true}
	if r.page == .Accessibility && accessibility_action(r, event) {return true}
	if c, ok := r.content.(^Custom_Page_Runtime); ok {
		if event.id == "custom/popup" ||
		   event.id == "custom/close" ||
		   event.id == "custom/tooltip" {
			if r.model.revision == max(u64) {return false}
			if event.id ==
			   "custom/tooltip" {c.tooltip = !c.tooltip} else {c.popup = event.id == "custom/popup" && !c.popup}
			r.model.revision += 1; return true
		}
	}
	if r.model.page == .Layers {
		if strings.has_prefix(event.id, "layers/") {return layer_change(r, event.id)}
		return accept_shell(r, event.id)
	}
	if _, selected := active_collection(r);
	   selected && strings.has_prefix(event.id, "collections/") {
		a: collection_model.Action
		switch event.id {case "collections/mode":
			a.kind = .Switch; case "collections/reverse":
			a.kind = .Reverse; case "collections/delete":
			a.kind = .Delete; case "collections/restore":
			a.kind = .Restore; case:
			return accept_shell(r, event.id)}
		return apply_collection(r, a)
	}
	if r.model.page == .Scroll_Table && strings.has_prefix(event.id, "table/item-") {
		n, valid := strconv.parse_int(event.id[len("table/item-"):])
		if !valid {return false}
		return model.apply(r.model, {kind = .Gallery, integer = i64(n + 1), id = "table/select"})
	}
	if r.model.page == .Text_Input || r.model.page == .Diagnostics_Performance {
		if event.id == "name/apply" {return name_intent(r, .Submit)}
		if event.id == "name/cancel" {return name_intent(r, .Cancel)}
	}
	if r.model.page == .Profiles {
		a := profile.Action{}
		switch event.id {case "profiles/apply":
			a.kind = .Apply
		case "profiles/cancel":
			a.kind = .Cancel
		case "profiles/reset":
			a.kind = .Request_Reset
		case:
			return accept_shell(r, event.id)}
		return apply_profile(r, a)
	}
	return accept_shell(r, event.id)
}
accept_shell :: proc(r: ^Runtime, id: string) -> bool {
	if destination, known := native_destination(id);
	   known {return reduce_destination(r, destination)}
	intent: model.Intent
	switch id {
	case "rich/circle":
		intent.kind = .Gallery; intent.id = "rich/limit"
	case "performance/instrumentation":
		intent.kind = .Gallery; intent.id = id
	case "transitions/a",
	     "transitions/b",
	     "transitions/reduced",
	     "transitions/presence",
	     "transitions/easing",
	     "transitions/count",
	     "transitions/hold":
		if v, selected := r.content.(^Transition_Page_Runtime); selected {
			if id == "transitions/a" ||
			   id == "transitions/b" ||
			   id == "transitions/easing" {v.presence_timing = false}
			if id == "transitions/presence" {v.presence_timing = true}
		}
		intent.kind = .Gallery; intent.id = id
	case "custom/style",
	     "custom/slot",
	     "custom/disabled",
	     "node:4:left7:content6:circle",
	     "node:5:right7:content6:circle":
		intent.kind = .Gallery; intent.id = id
	case "world/object-left",
	     "world/object-right",
	     "world/object-up",
	     "world/object-down",
	     "world/camera-left",
	     "world/camera-right",
	     "world/camera-up",
	     "world/camera-down",
	     "world/zoom",
	     "world/policy",
	     "world/reset":
		intent.kind = .Gallery; intent.id = id
	case "composition/parent", "composition/child", "composition/stop", "composition/presence":
		intent.kind = .Gallery; intent.id = id
	case "shell/catalogue":
		intent.kind = .Catalogue
	case "shell/layout":
		intent.kind = .Layout
	case "shell/controls":
		intent.kind = .Controls
	case "shell/language":
		intent.kind = .Language
	case "shell/scale":
		intent.kind = .Scale
	case "shell/mode":
		intent.kind = .Mode
	case "catalogue/next":
		intent.kind = .Catalogue_Next
	case "catalogue/previous":
		intent.kind = .Catalogue_Previous
	case "catalogue/lab":
		intent.kind = .Catalogue_Lab
	case "atlas/theme",
	     "hud/minus",
	     "hud/plus",
	     "hud/restore",
	     "table/dataset",
	     "table/fixture",
	     "atlas/button",
	     "layout/more",
	     "layout/safe-area",
	     "styling/fallback",
	     "styling/theme",
	     "styling/selected",
	     "styling/disabled",
	     "styling/count",
	     "atlas/assets",
	     "atlas/reload",
	     "atlas/selected",
	     "atlas/disabled",
	     "atlas/count",
	     "text/key",
	     "text/limit",
	     "rich/limit":
		intent.kind = .Gallery; intent.id = id
	case:
		for section in model.SECTIONS {if id == section.id {intent.kind = .Section; intent.page = section.page; return model.apply(r.model, intent)}}
		for section in model.LAB_SECTIONS {if id == section.id {intent.kind = .Section; intent.page = section.page; return model.apply(r.model, intent)}}
		return false
	}
	if !model.apply(
		r.model,
		intent,
	) {fmt.eprintln("Setting rejected: fractional Pixel_Perfect, unchanged value or exhausted model revision"); return false}
	return true
}
accept_control :: proc(r: ^Runtime, stamp: base.Frame_Stamp, event: controls.Event) -> bool {
	when TOOLS {if !trace_target(
			r,
			event.control_id,
			event.source,
			event.sequence,
		) {block(r); return false}}
	if event.frame_id != r.controls.frame.stamp.attempt ||
	   !consume(r, stamp, event.sequence) {return false}
	if lab_menu(r.page) {return lab_control(r, event)}
	if r.page == .Accessibility &&
	   event.kind == .Result &&
	   event.control_id == "accessibility/dialog" {
		kind := access_model.Action_Kind.Cancel; if event.item_id == "confirm" {kind = .Confirm}
		return accessibility_apply(
			r,
			{
				kind = kind,
				token = r.model.accessibility.pending_token,
				sequence = event.sequence,
				source = event.source,
			},
		)
	}
	if r.model.page == .Transitions &&
	   event.control_id == "transitions/slider" &&
	   event.kind ==
		   .Integer {return model.apply(r.model, {kind = .Gallery, id = "transitions/slider", integer = event.value})}
	if r.model.page == .Layers {
		if event.control_id != "layers/check" ||
		   event.kind != .Bool ||
		   r.model.revision == max(u64) ||
		   r.model.effects == max(u64) {return false}
		r.model.layer_checked =
			event.checked; r.model.revision += 1; r.model.effects += 1; return true
	}
	if r.model.page == .Profiles {
		if event.control_id == "profiles/mode" && (event.kind == .Open || event.kind == .Close) {
			if r.model.revision ==
			   max(
				   u64,
			   ) {return false}; r.select_open = event.kind == .Open; r.model.revision += 1; return true
		}
		a := profile.Action {
			id       = event.item_id,
			checked  = event.checked,
			value    = event.value,
			frame_id = event.frame_id,
		}
		switch event.control_id {
		case "profiles/help":
			a.kind = .Show_Help
		case "profiles/enabled":
			a.kind = .Enabled
		case "profiles/intensity":
			a.kind = .Intensity
		case "profiles/list":
			a.kind = .Select_Profile
		case "profiles/tabs":
			a.kind = .Tab
		case "profiles/mode":
			a.kind = .Mode
		case "profiles/dialog":
			a.kind = .Dialog_Result
		case:
			return false
		}
		accepted := apply_profile(r, a); if accepted {r.select_open = false}; return accepted
	}
	intent := model.Intent {
		boolean = event.checked,
		integer = event.value,
	}
	if event.kind == .Bool &&
	   event.control_id ==
		   "controls/checkbox" {intent.kind = .Checkbox} else if event.kind == .Bool && event.control_id == "controls/toggle" {intent.kind = .Toggle} else if event.kind == .Integer && event.control_id == "controls/slider" {intent.kind = .Slider} else {return false}
	return model.apply(r.model, intent)
}
control_target :: proc(r: ^Runtime, id: string) -> bool {
	for c in r.controls.frame.controls {
		if c.node_id == id || c.decrement_id == id || c.increment_id == id {return true}
		for item in c.items {if item.node_id == id {return true}}
	}
	return false
}
route :: proc(r: ^Runtime, action: interaction.Action) -> interaction.Code {
	code := route_impl(r, action)
	when TOOLS {set_tool_dispatch(r, code)}
	return code
}
route_impl :: proc(r: ^Runtime, action: interaction.Action) -> interaction.Code {
	if code, handled := lab_departure_route(r, action); handled {return code}
	if r.page == .Lab_Inventory && action.kind == .Cancel {return lab_transfer_cancel(r, action)}
	if code, handled := lab_inventory_route(r, action); handled {return code}
	if lab_menu(r.page) && action.kind == .Cancel {return lab_menu_cancel(r, action)}
	if r.page == .Lab_Hud && action.kind == .Cancel {return lab_hud_cancel(r, action)}
	if code, handled := custom_route(r, action); handled {return code}
	if r.model.page == .Layers && action.kind == .Cancel {return layer_cancel(r, action)}
	if code, consumed := collection_route(r, action); consumed {return code}
	stamp := reader_stamp(&r.live)
	if (action.kind == .Activate && control_target(r, action.id)) ||
	   (action.kind == .Cancel && uses_controls(r.model.page)) {
		kind := controls.Action_Kind.Activate; if action.kind == .Cancel {kind = .Cancel}
		result := controls.dispatch(
			&r.controls,
			&r.interaction,
			{kind = kind, id = action.id, source = action.source},
			&r.layers,
			&r.scroll,
		)
		if event, ok := result.event.?; ok {accept_control(r, stamp, event)}
		return result.dispatch.code
	}
	if lab_menu(r.page) ||
	   r.page == .Lab_Inventory ||
	   r.page == .Lab_Hud ||
	   r.model.page == .Layers ||
	   r.model.page == .Custom ||
	   r.model.page == .Accessibility {
		result := layers.dispatch(&r.layers, &r.interaction, action)
		if result.dispatch.has_event {accept_base(r, stamp, result.dispatch.event)}
		return result.dispatch.code
	}
	if r.model.page == .Composition {
		r.composition_route.child, r.composition_route.parent, r.composition_route.sequence =
			false, false, 0
		result := interaction.dispatch_routed(&r.interaction, action)
		if result.has_event {accept_base(r, stamp, result.event)}
		return result.code
	}
	result := interaction.dispatch(&r.interaction, action)
	if result.has_event {accept_base(r, stamp, result.event)}
	return result.code
}
finish_input :: proc(s: ^Shell, old_page: model.Page, was_ready: bool) -> bool {
	when TOOLS {finish_tool_record(&s.runtime)}
	if (lab_menu(old_page) || old_page == .Lab_Inventory || old_page == .Lab_Hud) &&
	   s.runtime.error != .None &&
	   !s.runtime.publication.ready {return false}
	if s.model.page != old_page {return enter(s)}
	if lab_menu(old_page) && was_ready && !s.runtime.publication.ready {
		if !sync_name(s) {return false}
	}
	if was_ready && !s.runtime.publication.ready {if !rebuild(&s.runtime) {return false}}
	if n, ok := active_name(&s.runtime); ok {
		if was_ready && n.input.pending_click_id != "" {
			result := editor_sdl.take_pointer(
				&n.input,
				&s.runtime.interaction,
				&n.state,
				fonts.metrics(s.runtime.fonts),
			)
			defer editor.destroy_result(&result.editor)
			if !accept_name(
				&s.runtime,
				reader_stamp(&s.runtime.live),
				&result.editor,
			) {return false}
			if !s.runtime.publication.ready && !rebuild(&s.runtime) {return false}
		}
	}
	return sync_name(s)
}
dispatch :: proc(s: ^Shell, action: interaction.Action) -> bool {
	r := &s.runtime
	if r.model == nil {return false}
	if !current(r) {block(r); return false}
	page := s.model.page; was_ready := r.publication.ready
	code := route(r, action)
	return finish_input(s, page, was_ready) && code == .Applied
}
handle_input :: proc(s: ^Shell, event: sdl.Event, window: base.Extent) -> bool {
	r := &s.runtime
	was_ready := r.publication.ready; page := s.model.page; stamp := reader_stamp(&r.live)
	n := backend.normalize_event(&s.input, &r.interaction, event, window)
	if !n.accepted {return true}
	when TOOLS {if !begin_native_record(s, n) {block(r); return false}}
	defer {when TOOLS {finish_tool_record(&s.runtime)}}
	if r.model == nil {return true} 	// Physical release/loss bookkeeping above still ran.
	if was_ready && !current(r) {block(r); was_ready = false}
	if lab_departure_pointer(r, n) {return finish_input(s, page, was_ready)}
	if v, ok := r.content.(^Lab_Inventory_Runtime); ok {
		x := gesture_sdl.event(&v.input, &s.input, &r.interaction, &v.gesture, nil, n)
		if !accept_lab_gesture(r, x.gesture) {block(r); return false}
		if x.consumed {return finish_input(s, page, was_ready)}
		if lab_collection_input(r, n) {return finish_input(s, page, was_ready)}
	}
	if c, ok := r.content.(^Custom_Page_Runtime); ok {
		id := ""
		if n.pointer_valid &&
		   (n.pointer_button ||
				   n.event.type ==
					   .MOUSE_MOTION) {target, code := hit_pointer(r, n.x, n.y); if code == .Applied {id = target.description.id}}
		x := painter.handle(&c.state, &r.interaction, n, id, true)
		if x.consumed {if x.dispatch.has_event {accept_base(r, stamp, x.dispatch.event)}; return finish_input(s, page, was_ready)}
	}
	gesture_consumed, gesture_handled := false, false
	if g, ok := r.content.(^Gesture_Page_Runtime); ok {
		if g.state.live.phase != .Idle || n.loss {
			x := gesture_sdl.event(&g.input, &s.input, &r.interaction, &g.state, &r.scroll, n)
			if !accept_gesture_page(r, x.gesture) {block(r); return false}
			gesture_consumed, gesture_handled = x.consumed, true
		}
	}
	if h, ok := active_hold(r); ok {
		specialized := n
		if (page == .Layers || page == .Lab_Hud) && n.pointer_button && n.down {
			_, code := hit_pointer(
				r,
				n.x,
				n.y,
			); if code != .Applied {specialized.front, specialized.pointer_button = false, false}
		}
		special := hold_sdl.handle(&h.input, &h.state, &r.interaction, specialized)
		if special.consumed {accept_hold(r, stamp, special.result); return finish_input(s, page, was_ready)}
	}
	if collection, ok := active_collection(r); ok {
		e := collection_sdl.handle(&collection.state, &r.interaction, n)
		if e.consumed {accept_collection(r, stamp, e.result); return finish_input(s, page, was_ready)}
	}
	if name, ok := active_name(r); ok {
		if !gesture_consumed || n.loss {
			e := editor_sdl.event(
				&name.input,
				&s.input,
				&r.interaction,
				&name.state,
				n,
				fonts.metrics(r.fonts),
			)
			defer editor.destroy_result(&e.editor)
			if e.error == .Allocation || (e.has_editor && e.editor.code == .Allocation) {
				name.native_error = .Allocation; name.rejection = .Allocation; block(r); return false
			}
			if e.consumed {name.native_error = e.error}
			if e.has_editor && !accept_name(r, stamp, &e.editor) {block(r); return false}
			if was_ready &&
			   (e.error != .None || e.editor.rejection != .None) {base.invalidate(&r.publication)}
			if e.consumed {return finish_input(s, page, was_ready)}
		}
	}
	if gesture_consumed {return finish_input(s, page, was_ready)}
	if !gesture_handled {
		if g, ok := r.content.(^Gesture_Page_Runtime); ok {
			x := gesture_sdl.event(&g.input, &s.input, &r.interaction, &g.state, &r.scroll, n)
			if !accept_gesture_page(r, x.gesture) {block(r); return false}
			if x.consumed {return finish_input(s, page, was_ready)}
		}
	}
	if uses_controls(page) {
		allowed := true
		if page == .Profiles &&
		   r.adapter.capture_id == "" &&
		   (n.pointer_button || n.event.type == .MOUSE_MOTION) {
			target, code := layers.hit_test(
				&r.live.layers,
				&r.live.geometry,
				&r.interaction.frame,
				n.x,
				n.y,
			)
			allowed = code == .Applied && target.description.id == "profiles/intensity"
		}
		if allowed || n.loss || (n.pointer_button && !n.down) {
			special := controls_sdl.handle(
				&r.adapter,
				&r.controls,
				&r.interaction,
				&r.live.geometry,
				n,
				transition_geometry(r),
			)
			if special.consumed {
				if value, ok := special.result.event.?; ok {accept_control(r, stamp, value)}
				return finish_input(s, page, was_ready)
			}
		}
	}
	if n.loss || n.suspended {return finish_input(s, page, was_ready)}
	if !was_ready {return true}
	if page == .Scroll_Table || page == .Layers || page == .Gestures {
		if n.event.type == .MOUSE_WHEEL && n.pointer_valid {
			x, y := n.x / r.interaction.frame.ui_scale, n.y / r.interaction.frame.ui_scale
			if page == .Layers {
				h, _ := r.content.(^Hold_Page_Runtime)
				if h.popup {popup, _ := layout.find(&r.live.geometry, LAYER_POPUPS[h.depth]); if base.contains(popup.bounds, x, y) && base.contains(popup.paint_clip, x, y) {return finish_input(s, page, was_ready)}}
			}
			for region in r.scroll.frame.regions {
				if region.availability != .Applied {continue}
				p := region.viewport
				if base.contains(p, x, y) {
					height := f64(
						28,
					); for item in region.items {if item.id == region.anchor_id {height = item.height; break}}
					delta :=
						-f64(n.event.wheel.y) *
						3 *
						height; if n.event.wheel.direction == .FLIPPED {delta = -delta}
					scroll.dispatch(
						&r.scroll,
						&r.interaction,
						{kind = .Scroll_By, id = region.id, source = .Mouse, delta_y = delta},
					)
					return finish_input(s, page, was_ready)
				}
			}
		}
		if n.front {
			direction := 0; source := interaction.Source.Keyboard
			if n.event.type ==
			   .KEY_DOWN {if n.event.key.key == sdl.K_UP {direction = -1}; if n.event.key.key == sdl.K_DOWN {direction = 1}}
			if n.event.type ==
			   .GAMEPAD_BUTTON_DOWN {source = .Gamepad; b := sdl.GamepadButton(n.event.gbutton.button); if b == .DPAD_UP {direction = -1}; if b == .DPAD_DOWN {direction = 1}}
			if direction != 0 && strings.has_prefix(r.interaction.focus_id, "table/item-") {
				scroll.dispatch(
					&r.scroll,
					&r.interaction,
					{
						kind = .Move_Item,
						id = "table/viewport",
						source = source,
						backwards = direction < 0,
					},
				)
				return finish_input(s, page, was_ready)
			}
		}
	}
	if page == .Profiles && n.front {
		direction := 0; source := interaction.Source.Keyboard
		if event.type ==
		   .KEY_DOWN {if event.key.key == sdl.K_UP {direction = -1}; if event.key.key == sdl.K_DOWN {direction = 1}}
		if event.type ==
		   .GAMEPAD_BUTTON_DOWN {source = .Gamepad; b := sdl.GamepadButton(event.gbutton.button); if b == .DPAD_UP {direction = -1}; if b == .DPAD_DOWN {direction = 1}}
		if direction !=
		   0 {for c in r.controls.frame.controls {if c.kind == .List {for item in c.items {if item.node_id == r.interaction.focus_id {
							result := controls.dispatch(
								&r.controls,
								&r.interaction,
								{kind = .Move_Item, source = source, backwards = direction < 0},
								&r.layers,
								&r.scroll,
							)
							return(
								finish_input(s, page, was_ready) &&
								result.dispatch.code == .Applied \
							)
						}}}}}
	}
	if n.has_action {
		route(r, n.action)
	} else if n.pointer_button {
		target, code := hit_pointer(r, n.x, n.y)
		id := ""; if code == .Applied {id = target.description.id}
		if control_target(r, id) {
			if n.down {if n.front {interaction.begin_pointer_press(&r.interaction, id)}} else if interaction.consume_press(&r.interaction, id) == .Applied {route(r, {.Activate, id, .Mouse, false})}
		} else if uses_controls(page) ||
		   page == .Rich_Text ||
		   page == .Collections ||
		   page == .Composition ||
		   page == .Transitions {
			if n.down {if n.front {interaction.begin_pointer_press(&r.interaction, id)}} else if interaction.consume_press(&r.interaction, id) == .Applied {route(r, {.Activate, id, .Mouse, false})}
		} else {
			result := backend.dispatch_input(&r.interaction, n)
			if result.dispatch.has_event {accept_base(r, stamp, result.dispatch.event)}
		}
	} else if uses_controls(page) && n.event.type == .MOUSE_MOTION && n.pointer_valid {
		target, code := hit_pointer(
			r,
			n.x,
			n.y,
		); id := ""; if code == .Applied {id = target.description.id}; interaction.observe_target(&r.interaction, id)
	} else {
		result := backend.dispatch_input(&r.interaction, n)
		if result.dispatch.has_event {accept_base(r, stamp, result.dispatch.event)}
	}
	return finish_input(s, page, was_ready)
}
hit_pointer :: proc(r: ^Runtime, x, y: f64) -> (^interaction.Target_View, interaction.Code) {
	if v, selected := r.content.(Rich_Page_Runtime);
	   selected {return interaction.hit_test(&r.interaction.frame, x, y, custom.hit_predicate, &v.combined.custom.frame)}
	if c, ok := r.content.(^Custom_Page_Runtime);
	   ok {return layers.hit_test(&r.live.layers, &r.live.geometry, &r.interaction.frame, x, y, custom.hit_predicate, &c.state.frame)}
	if uses_controls(
		r.model.page,
	) {return layers.hit_test(&r.live.layers, &r.live.geometry, &r.interaction.frame, x, y)}
	return interaction.hit_test(&r.interaction.frame, x, y)
}
destroy_shell :: proc(s: ^Shell) -> bool {
	if !close_page_input(s) {return false}
	_, performance := s.runtime.content.(^Performance_Page_Runtime)
	backend.close_input(&s.input)
	measured: Phase_Sample; destroy(&s.runtime, &measured)
	when TOOLS {destroy_reader(&s.tools.history)}
	if performance {fmt.printf("performance destroy available=%t ns=%d scope=runtime-family-readers-generations excludes=app-models-shared-input-observer\n", measured.available, measured.ns)}
	destroy_name_values(&s.model.name, s.allocator)
	destroy_name_values(&s.model.lab_name, s.allocator)
	destroy_name_values(&s.model.performance_name, s.allocator)
	destroy_name_values(&s.model.gesture_name, s.allocator)
	when TOOLS {destroy_tool_trace(s)}
	return true
}

apply_profile :: proc(r: ^Runtime, a: profile.Action) -> bool {
	if r.model.revision == max(u64) || r.model.effects == max(u64) {return false}
	result := profile.reduce(&r.model.profiles, a)
	if result.error != .None || !result.changed {return false}
	r.model.revision += 1; r.model.effects += 1; return true
}
