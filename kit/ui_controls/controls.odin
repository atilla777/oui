package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import layers "../ui_layers"
import layout "../ui_layout"
import scroll "../ui_scroll"
import "core:mem"
import "core:strings"

Kind :: enum {
	Checkbox,
	Toggle,
	Slider,
	Select,
	Tabs,
	List,
	Tooltip,
	Dialog,
}
Item :: struct {
	id, node_id, label: string,
}
Description :: struct {
	track_id, on_text, off_text, body, id, node_id, label, disabled_reason: string,
	kind:                                                                   Kind,
	checked:                                                                bool,
	value, minimum, maximum, step:                                          i64,
	selected_id:                                                            string,
	items:                                                                  []Item,
	decrement_id, increment_id:                                             string,
	open:                                                                   bool,
	layer_id, owner_scope_id, initial_focus_id, cancel_id, trigger_id:      string,
}
Event_Kind :: enum {
	Bool,
	Integer,
	Item,
	Open,
	Close,
	Result,
}
Event :: struct {
	control_id:         string,
	kind:               Event_Kind,
	checked:            bool,
	value:              i64,
	item_id:            string,
	source:             interaction.Source,
	sequence, frame_id: u64,
}
Result :: struct {
	cancel:   Maybe(layers.Cancel_Requested),
	dispatch: interaction.Dispatch_Result,
	event:    Maybe(Event),
}
Action_Kind :: enum {
	Focus,
	Navigate,
	Activate,
	Cancel,
	Move_Item,
	Adjust,
	Set_Value,
	Move_Left,
	Move_Right,
}
Action :: struct {
	kind:      Action_Kind,
	id:        string,
	source:    interaction.Source,
	backwards: bool,
	value:     i64,
}
Error_Code :: enum {
	None,
	Invalid_Control,
	Invalid_Value,
	Invalid_Range,
	Invalid_Item,
	Duplicate_Ownership,
	Allocation,
	Stale,
}
Error :: struct {
	code:                Error_Code,
	control_id, node_id: string,
}
Frame :: struct {
	gates:     []interaction.Code,
	scope_id:  string,
	controls:  []Description,
	stamp:     base.Frame_Stamp,
	allocator: mem.Allocator,
}
Candidate :: Frame
State :: struct {
	frame: Frame,
}
create :: proc() -> State {return {}}
destroy_description :: proc(c: ^Description, a: mem.Allocator) {
	for v in ([]string{c.track_id, c.on_text, c.off_text, c.body, c.id, c.node_id, c.label, c.disabled_reason, c.selected_id, c.decrement_id, c.increment_id, c.layer_id, c.owner_scope_id, c.initial_focus_id, c.cancel_id, c.trigger_id}) {delete(v, a)}
	for item in c.items {delete(item.id, a); delete(item.node_id, a); delete(item.label, a)}
	delete(c.items, a); c^ = {}
}
destroy_frame :: proc(f: ^Frame) {delete(f.scope_id, f.allocator); for &c in f.controls {destroy_description(
			&c,
			f.allocator,
		)}
	delete(f.controls, f.allocator)
	delete(f.gates, f.allocator)
	base.release(f.stamp)
	f^ = {}}
destroy_candidate :: destroy_frame
destroy :: proc(s: ^State) {destroy_frame(&s.frame); s^ = {}}
prepare :: proc(
	f: ^interaction.Frame,
	l: layers.Layers,
	descriptions: []Description,
	a: mem.Allocator,
	geometry: ^layout.Frame = nil,
) -> (
	Candidate,
	Error,
) {
	if geometry != nil && geometry.stamp != f.stamp {return {}, {code = .Stale}}
	if e := validate(f, l, descriptions, geometry); e.code != .None {return {}, e}
	c := Candidate {
		allocator = a,
	}; complete := false; defer {if !complete {destroy_candidate(&c)}}
	if !base.retain(f.stamp) {return {}, {code = .Allocation}}; c.stamp = f.stamp
	e: mem.Allocator_Error; c.controls, e = make([]Description, len(descriptions), a); if e != nil {return {}, {code = .Allocation}}
	c.scope_id, e = strings.clone(
		layers.active_scope(l),
		a,
	); if e != nil {return {}, {code = .Allocation}}
	for d, k in descriptions {c.controls[k], e = clone_description(d, a); if e != nil {return {}, {code = .Allocation}}}
	c.gates, e = make(
		[]interaction.Code,
		len(descriptions),
		a,
	); if e != nil {return {}, {code = .Allocation}}
	for d, k in descriptions {
		n, _ := interaction.find(f, d.node_id); c.gates[k] = n.availability
		if n.availability == .Invalid_Action && n.description.role == "" && geometry != nil {
			v, found := layout.find(geometry, d.node_id)
			if found {c.gates[k] = .Applied; if !v.enabled {c.gates[k] = .Disabled}; if !v.visible {c.gates[k] = .Not_Visible}}
		}
		if d.kind == .Tooltip {c.gates[k] = .Non_Interactive_Overlay}
	}
	complete = true; return c, {}
}
@(private)
clone_description :: proc(c: Description, a: mem.Allocator) -> (Description, mem.Allocator_Error) {
	r := c; r.items = nil
	e: mem.Allocator_Error
	src := [16]string {
		c.track_id,
		c.on_text,
		c.off_text,
		c.body,
		c.id,
		c.node_id,
		c.label,
		c.disabled_reason,
		c.selected_id,
		c.decrement_id,
		c.increment_id,
		c.layer_id,
		c.owner_scope_id,
		c.initial_focus_id,
		c.cancel_id,
		c.trigger_id,
	}
	dst := [16]^string {
		&r.track_id,
		&r.on_text,
		&r.off_text,
		&r.body,
		&r.id,
		&r.node_id,
		&r.label,
		&r.disabled_reason,
		&r.selected_id,
		&r.decrement_id,
		&r.increment_id,
		&r.layer_id,
		&r.owner_scope_id,
		&r.initial_focus_id,
		&r.cancel_id,
		&r.trigger_id,
	}
	for p in dst {p^ = ""}
	complete := false; defer {if !complete {destroy_description(&r, a)}}
	for v, k in src {dst[k]^, e = strings.clone(v, a); if e != nil {return {}, e}}
	r.items, e = make([]Item, len(c.items), a); if e != nil {return {}, e}
	for item, k in c.items {
		r.items[k].id, e = strings.clone(item.id, a); if e != nil {return {}, e}
		r.items[k].node_id, e = strings.clone(item.node_id, a); if e != nil {return {}, e}
		r.items[k].label, e = strings.clone(item.label, a); if e != nil {return {}, e}
	}
	complete = true; return r, nil
}
commit :: proc(s: ^State, c: ^Candidate) {old := s.frame; s.frame = c^; c^ = {}; destroy_frame(
		&old,
	)}
dispatch :: proc(
	s: ^State,
	ctx: ^interaction.Context,
	a: Action,
	layer_state: ^layers.State = nil,
	scroll_state: ^scroll.State = nil,
) -> Result {
	if code := interaction.guard_common(ctx, a.source);
	   code != .Applied {return {dispatch = {code = code}}}
	if s.frame.stamp != ctx.frame.stamp {return {dispatch = {code = .Not_Ready}}}
	if a.kind == .Move_Item {
		if scroll_state == nil {return {dispatch = {code = .Invalid_Action}}}
		for c, k in s.frame.controls {if c.kind == .List {for item in c.items {if item.node_id == ctx.focus_id {if code := owner_guard(&s.frame, k, ctx, a.source); code != .Applied {return {dispatch = {code = code}}}}}}}
		return {
			dispatch = scroll.dispatch(
				scroll_state,
				ctx,
				{kind = .Move_Item, source = a.source, backwards = a.backwards},
			),
		}
	}
	if a.kind == .Focus ||
	   a.kind ==
		   .Navigate {kind := interaction.Action_Kind.Focus; if a.kind == .Navigate {kind = .Navigate}; return {dispatch = interaction.dispatch_routed(ctx, {kind, a.id, a.source, a.backwards})}}
	if a.kind == .Cancel {
		for c in s.frame.controls {if c.kind == .Select && c.open && c.owner_scope_id == s.frame.scope_id {
				r := interaction.dispatch_routed(
					ctx,
					{.Activate, c.node_id, a.source, false},
				); out := Result {
					dispatch = r,
				}
				if r.has_event {out.event = Event {
						control_id = c.id,
						kind       = .Close,
						source     = a.source,
						sequence   = r.event.sequence,
						frame_id   = ctx.frame.stamp.attempt,
					}}
				return out
			}}
		for c, k in s.frame.controls {if c.kind == .Dialog && c.open && c.layer_id == s.frame.scope_id {
				if code := owner_guard(&s.frame, k, ctx, a.source);
				   code != .Applied {return {dispatch = {code = code}}}
				for item in c.items {if item.id == c.cancel_id && c.cancel_id != "" {
						if code := interaction.guard(ctx, item.node_id, a.source);
						   code != .Applied {return {dispatch = {code = code}}}
						if layer_state == nil {return {dispatch = {code = .Invalid_Action}}}
						if layer_state.frame.stamp != ctx.frame.stamp ||
						   layers.active_scope(layer_state.frame.layers) !=
							   c.layer_id {return {dispatch = {code = .Not_Ready}}}
						lr := layers.dispatch(
							layer_state,
							ctx,
							{kind = .Cancel, source = a.source},
						); out := Result {
							dispatch = lr.dispatch,
							cancel   = lr.cancel,
						}
						if cancelled, ok := lr.cancel.?; ok {out.event = Event {
								control_id = c.id,
								kind       = .Result,
								item_id    = item.id,
								source     = a.source,
								sequence   = cancelled.sequence,
								frame_id   = ctx.frame.stamp.attempt,
							}}
						return out
					}}
				return {dispatch = {code = .Invalid_Action}}
			}}
		if layer_state != nil {
			if layer_state.frame.stamp != ctx.frame.stamp ||
			   layers.active_scope(layer_state.frame.layers) !=
				   s.frame.scope_id {return {dispatch = {code = .Not_Ready}}}
			lr := layers.dispatch(layer_state, ctx, {kind = .Cancel, source = a.source})
			return {dispatch = lr.dispatch, cancel = lr.cancel}
		}
		return {dispatch = {code = .Invalid_Action}}
	}
	for c, k in s.frame.controls {
		if a.kind == .Activate &&
		   c.kind == .Slider &&
		   ((c.decrement_id != "" && c.decrement_id == a.id) ||
				   (c.increment_id != "" && c.increment_id == a.id)) {
			if code := owner_guard(&s.frame, k, ctx, a.source);
			   code != .Applied {return {dispatch = {code = code}}}
			delta := i128(c.step); if c.decrement_id == a.id {delta = -delta}
			value := i64(clamp(i128(c.value) + delta, i128(c.minimum), i128(c.maximum)))
			r := interaction.dispatch_routed(
				ctx,
				{.Activate, a.id, a.source, false},
			); out := Result {
				dispatch = r,
			}
			if r.has_event && value != c.value {out.event = Event {
					control_id = c.id,
					kind       = .Integer,
					value      = value,
					source     = a.source,
					sequence   = r.event.sequence,
					frame_id   = ctx.frame.stamp.attempt,
				}}
			return out
		}
		if a.kind == .Activate {for item in c.items {if item.node_id == a.id {
					if code := owner_guard(&s.frame, k, ctx, a.source);
					   code != .Applied {return {dispatch = {code = code}}}
					if (c.kind == .Select || c.kind == .Dialog) &&
					   !c.open {return {dispatch = {code = .Invalid_Action}}}
					r := interaction.dispatch_routed(
						ctx,
						{.Activate, item.node_id, a.source, false},
					); out := Result {
						dispatch = r,
					}
					kind := Event_Kind.Item; if c.kind == .Dialog {kind = .Result}
					if r.has_event {out.event = Event {
							control_id = c.id,
							kind       = kind,
							item_id    = item.id,
							source     = a.source,
							sequence   = r.event.sequence,
							frame_id   = ctx.frame.stamp.attempt,
						}}
					return out
				}}}
		if c.node_id != a.id {continue}
		if code := owner_guard(&s.frame, k, ctx, a.source);
		   code != .Applied {return {dispatch = {code = code}}}
		if a.kind == .Adjust || a.kind == .Set_Value {
			if c.kind != .Slider {return {dispatch = {code = .Not_Found}}}
			v := a.value
			if a.kind ==
			   .Adjust {if v != -1 && v != 1 {return {dispatch = {code = .Invalid_Action}}}; v = i64(clamp(i128(c.value) + i128(v) * i128(c.step), i128(c.minimum), i128(c.maximum)))}
			if c.step <= 0 ||
			   v < c.minimum ||
			   v > c.maximum ||
			   (i128(v) - i128(c.minimum)) % i128(c.step) !=
				   0 {return {dispatch = {code = .Invalid_Action}}}
			r := interaction.dispatch_routed(
				ctx,
				{.Activate, c.node_id, a.source, false},
			); out := Result {
				dispatch = r,
			}
			if r.has_event && v != c.value {out.event = Event {
					control_id = c.id,
					kind       = .Integer,
					value      = v,
					source     = a.source,
					sequence   = r.event.sequence,
					frame_id   = ctx.frame.stamp.attempt,
				}}
			return out
		}
		if a.kind == .Activate {
			r := interaction.dispatch_routed(
				ctx,
				{.Activate, c.node_id, a.source, false},
			); out := Result {
				dispatch = r,
			}
			if r.has_event && (c.kind == .Checkbox || c.kind == .Toggle) {out.event = Event {
					control_id = c.id,
					kind       = .Bool,
					checked    = !c.checked,
					source     = a.source,
					sequence   = r.event.sequence,
					frame_id   = ctx.frame.stamp.attempt,
				}}
			if r.has_event &&
			   c.kind ==
				   .Select {kind := Event_Kind.Open; if c.open {kind = .Close}; out.event = Event {
					control_id = c.id,
					kind       = kind,
					source     = a.source,
					sequence   = r.event.sequence,
					frame_id   = ctx.frame.stamp.attempt,
				}}
			return out
		}
	}
	if a.kind ==
	   .Activate {return {dispatch = interaction.dispatch_routed(ctx, {.Activate, a.id, a.source, false})}}
	if a.kind == .Adjust || a.kind == .Set_Value {return {dispatch = {code = .Not_Found}}}
	return {dispatch = {code = .Invalid_Action}}
}
