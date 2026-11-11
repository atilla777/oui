package app

import access_model "../../accessibility_demo/model"
import "core:fmt"
import "core:mem"
import assessment "ui:ui_accessibility/inspect"
import projection "ui:ui_accessibility/projection"
import base "ui:ui_base"
import custom "ui:ui_custom"
import painter "ui:ui_custom/sdl"
import editor "ui:ui_editor"
import gestures "ui:ui_gestures"
import hold "ui:ui_hold"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import scroll "ui:ui_scroll"
import style "ui:ui_style"
import text "ui:ui_text"
import transitions "ui:ui_transitions"
import wire "ui:ui_wire"

Accessibility_Page_Runtime :: struct {
	extra_editor:   editor.State,
	extra_gestures: gestures.State,
	visual:         Transition_Page_Runtime,
	hold:           Hold_Page_Runtime,
	custom:         custom.State,
	painters:       ^painter.Generation,
	buffer:         [256]u8,
}
Accessibility_Page_Reader :: struct {
	c08:        ^C08_Reader,
	visual:     transitions.Frame,
	assessment: ^Assessment_Generation,
	hold:       hold.Frame,
	custom:     custom.Frame,
	painters:   ^painter.Generation,
}
Assessment_Generation :: struct {
	value:      assessment.Accessibility_Inspection,
	references: u64,
	allocator:  mem.Allocator,
}
release_assessment :: proc(p: ^^Assessment_Generation) {
	if p == nil || p^ == nil {return}; v := p^; p^ = nil
	v.references -= 1; if v.references == 0 {assessment.destroy_accessibility_inspection(&v.value); free(v, v.allocator)}
}
cancel_accessibility :: proc(r: ^Runtime) -> bool {
	if r.model == nil ||
	   r.page != .Accessibility ||
	   r.model.accessibility.pending_token == 0 {return true}
	m := &r.model.accessibility
	if m.mode == .Dialog {return accessibility_apply(r, {kind = .Cancel, token = m.pending_token})}
	return accessibility_apply(r, {kind = .Hold_Cancelled, cycle = m.pending_cycle})
}
accessibility_apply :: proc(r: ^Runtime, action: access_model.Action) -> bool {
	if r.page != .Accessibility ||
	   r.model.revision == max(u64) ||
	   r.model.effects == max(u64) {return false}
	x := access_model.reduce(&r.model.accessibility, action)
	if x.error != .None || !x.changed {return false}
	r.model.revision += 1; if x.has_request {r.model.effects += 1}
	base.invalidate(&r.publication); return true
}
accessibility_action :: proc(r: ^Runtime, e: interaction.Button_Activated) -> bool {
	switch e.id {
	case "accessibility/mode":
		mode := access_model.Mode.Dialog; if r.model.accessibility.mode == .Dialog {mode = .Hold}
		return accessibility_apply(r, {kind = .Set_Mode, mode = mode})
	case "accessibility/thresholds":
		return accessibility_apply(r, {kind = .Thresholds})
	case "accessibility/strict":
		return accessibility_apply(r, {kind = .Strict})
	case "accessibility/reduced":
		return accessibility_apply(r, {kind = .Reduced})
	case "accessibility/target":
		v, _ := active_transition(r); v.presence_timing = false
		return accessibility_apply(r, {kind = .Target})
	case "accessibility/presence":
		v, _ := active_transition(r); v.presence_timing = true
		return accessibility_apply(r, {kind = .Presence})
	case "accessibility/action":
		return accessibility_apply(r, {kind = .Open, source = e.source, sequence = e.sequence})
	}
	return false
}
accessibility_hold :: proc(r: ^Runtime, stamp: base.Frame_Stamp, x: hold.Result) {
	if r.page != .Accessibility {return}
	for index in 0 ..< x.count {
		signal := x.signals[index]
		if signal.id != "accessibility/action" {continue}
		switch signal.kind {
		case .Started:
			accessibility_apply(
				r,
				{kind = .Hold_Started, cycle = signal.cycle, source = signal.source},
			)
		case .Cancelled:
			accessibility_apply(
				r,
				{kind = .Hold_Cancelled, cycle = signal.cycle, source = signal.source},
			)
		case .Completed:
			if x.dispatch.has_event &&
			   consume(
				   r,
				   stamp,
				   x.dispatch.event.sequence,
			   ) {accessibility_apply(r, {kind = .Hold_Completed, cycle = signal.cycle, token = r.model.accessibility.pending_token, source = signal.source, sequence = x.dispatch.event.sequence})}
		case .Progress:
		}
	}
}
capture_assessment :: proc(
	r: ^Runtime,
	g: ^layout.Frame,
	i: ^interaction.Frame,
	paint: ^style.Frame,
	texts: ^text.Frame,
	customs: ^custom.Frame,
	held: ^hold.Frame,
	visual: ^transitions.Frame,
	layer_frame: ^layers.Frame,
	c08: ^C08_Reader,
	scrolled: []scroll.Region,
	focus: string,
) -> (
	assessment.Accessibility_Inspection,
	bool,
) {
	// Explicit synchronous DTO conversion: no enum casts, debugger, or retained
	// borrowed frame. capture_accessibility owns records and the common reader.
	nodes, ae := make(
		[]wire.Resolved_Node,
		len(g.nodes),
		r.allocator,
	); if ae != nil {return {}, false}; defer delete(nodes, r.allocator)
	for n, k in g.nodes {
		role, ok := wire.role(
			n.description.role,
		); if n.description.role == .Content {role, ok = .Label, true}; if !ok {return {}, false}
		nodes[k] = {
			description = {
				id = n.description.id,
				parent = n.description.parent,
				role = role,
				layout = n.description.layout,
				enabled = n.enabled,
				visible = n.visible,
			},
			bounds = n.bounds,
			content = n.content,
			clip = n.clip,
			paint_clip = n.paint_clip,
			measured = n.measured,
			enabled = n.enabled,
			visible = n.visible,
			focused = n.description.id ==
			focus,
		}
		if target, found := interaction.find(i, n.description.id);
		   found {if target.description.role != "" {nodes[k].description.role = .Button}; code, valid := wire.code(target.availability); if !valid {return {}, false}; nodes[k].availability = code}
		for block in texts.text_blocks {if block.node_id == n.description.id {nodes[k].description.text = block.original_text}}
		for p in paint.presentation {if p.id == n.description.id {nodes[k].style = {
					font_size    = p.computed[.Font_Size].value.(f64),
					foreground   = p.computed[.Foreground].value.(style.Color),
					background   = p.computed[.Background].value.(style.Color),
					border       = p.computed[.Border].value.(style.Color),
					border_width = p.border_width,
					focus_width  = p.focus_width,
				}}}
	}
	descriptions: [1]custom.Description; count := 0
	for v in customs.views {if count == len(descriptions) {return {}, false}; descriptions[count] = v.description; count += 1}
	f := projection.Frame {
		rich_blocks            = c08.rich.rich_blocks,
		editors                = c08.editor.editors,
		scroll                 = scrolled,
		gesture_model_revision = r.model.revision,
		layer_paint            = layer_frame.paint[:],
		transition_mode        = true,
		reduced_motion         = visual.reduced_motion,
		transitions            = visual.tracks,
		presences              = visual.presences,
		geometry               = visual.entries,
		nodes                  = nodes,
		id                     = g.id,
		stamp                  = g.stamp,
		drawable               = g.drawable,
		ui_scale               = g.ui_scale,
		presentation           = paint.presentation,
		text_blocks            = texts.text_blocks,
		hold                   = held.hold,
		progress               = held.progress,
		custom                 = descriptions[:count],
	}
	descriptions_g: [1]gestures.Description
	for v, k in c08.gestures.gestures {if k >= len(descriptions_g) {return {}, false}; descriptions_g[k] = v.description}
	f.gestures = descriptions_g[:len(c08.gestures.gestures)]
	if len(layer_frame.layers.modals) >
	   0 {f.modal = layer_frame.layers.modals[len(layer_frame.layers.modals) - 1]}
	policy := assessment.default_accessibility_policy(
		
	); if r.model.accessibility.strict_thresholds {policy = {7, {32, 32}}}
	result, e := assessment.capture_accessibility(
		{
			frame = &f,
			common = {
				frame = g,
				interaction = i,
				ready = true,
				model_revision = r.model.revision,
				published_revision = r.model.revision,
			},
		},
		policy,
		r.allocator,
		r.model.accessibility.policy_revision,
		r.model.accessibility.policy_revision,
	)
	if e != .None {fmt.eprintf("accessibility capture=%v\n", e)}
	return result, e == .None
}
compose_accessibility_status :: proc(r: ^Runtime, c: ^Page_Composition) {
	if p, selected := r.live.content.(Accessibility_Page_Reader); selected {
		v := assessment.accessibility_strict_result(&p.assessment.value)
		selected_ok := v.legacy.ok
		mode := "Normal"
		if r.model.accessibility.strict {selected_ok = v.ok; mode = "Strict"}
		if r.model.locale ==
		   .Russian {mode = "Обычный"; if r.model.accessibility.strict {mode = "Строгий"}}
		a, _ := r.content.(^Accessibility_Page_Runtime)
		format := "Previous capture: %s selected-ok=%t common-ok=%t\nPass=%d Warning=%d Unassessed=%d coverage=%t\ncounter=%d requests=%d"
		if r.model.locale ==
		   .Russian {format = "Предыдущая оценка: %s selected-ok=%t common-ok=%t\nPass=%d Warning=%d Unassessed=%d coverage=%t\ncounter=%d requests=%d"}
		message := fmt.bprintf(
			a.buffer[:],
			format,
			mode,
			selected_ok,
			v.legacy.ok,
			v.pass_count,
			v.warning_count,
			v.unassessed_count,
			v.coverage_complete,
			r.model.accessibility.counter,
			r.model.accessibility.requests,
		)
		for &t in c.texts[:c.nt] {if t.id == "accessibility/status" {t.text = message}}
	}
}
