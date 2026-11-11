package ui_interaction

import base "../ui_base"
import layout "../ui_layout"
import "core:mem"
import "core:strings"

Source :: enum {
	Mouse,
	Keyboard,
	Gamepad,
	Agent,
}
Code :: enum {
	Applied,
	Not_Found,
	Disabled,
	Not_Visible,
	Invalid_Action,
	Not_Ready,
	Allocation,
	Exhausted,
	Conflict,
	Reentry,
	Blocked_By_Modal,
	Non_Interactive_Overlay,
	Activation_Required,
}
Action_Kind :: enum {
	Focus,
	Navigate,
	Activate,
	Cancel,
}
Action :: struct {
	kind:      Action_Kind,
	id:        string,
	source:    Source,
	backwards: bool,
}
Button_Activated :: struct {
	id:       string,
	source:   Source,
	sequence: u64,
}
Dispatch_Result :: struct {
	code:      Code,
	event:     Button_Activated,
	has_event: bool,
}
Target :: struct {
	id, role:         string,
	enabled, visible: bool,
}
Target_View :: struct {
	activation_owner: string,
	kind:             layout.Kind,
	description:      Target,
	parent:           string,
	bounds, clip:     base.Rect,
	availability:     Code,
}
Frame :: struct {
	drawable:  base.Extent,
	targets:   []Target_View,
	stamp:     base.Frame_Stamp,
	ui_scale:  f64,
	allocator: mem.Allocator,
}
Candidate :: Frame
Delivery :: struct {
	target_id, current_id: string,
	source:                Source,
	sequence, frame_id:    u64,
}
Propagation :: enum {
	Continue,
	Stop,
}
Handler :: proc(delivery: Delivery, user: rawptr) -> Propagation
Dispose :: proc(user: rawptr)
Handler_Token :: distinct u64
Registration :: struct {
	kind:     layout.Kind,
	token:    Handler_Token,
	id, role: string,
	handler:  Handler,
	user:     rawptr,
	dispose:  Dispose,
}
Capture_Claim :: struct {
	node_id, owner_id: string,
}
Context :: struct {
	publication:                    ^base.Publication,
	allocator:                      mem.Allocator,
	frame:                          Frame,
	focus_id, hover_id, pressed_id: string,
	registrations:                  [dynamic]Registration,
	last_handler_token:             Handler_Token,
	busy:                           bool,
}
create :: proc(a: mem.Allocator, p: ^base.Publication) -> Context {return {
		allocator = a,
		publication = p,
		registrations = make([dynamic]Registration, 0, 0, a),
	}}
destroy_frame :: proc(f: ^Frame) {
	for n in f.targets {delete(n.activation_owner, f.allocator); delete(n.description.id, f.allocator); delete(n.description.role, f.allocator); delete(n.parent, f.allocator)}
	delete(f.targets, f.allocator); base.release(f.stamp); f^ = {}
}
destroy_candidate :: destroy_frame
find :: proc(f: ^Frame, id: string) -> (^Target_View, bool) {for &n in f.targets {if n.description.id ==
		   id {return &n, true}}
	return nil, false}
prepare :: proc(
	geometry: ^layout.Frame,
	targets: []Target,
	claims: []Capture_Claim,
	a: mem.Allocator,
) -> (
	Candidate,
	Code,
) {
	f, code := prepare_internal(geometry, targets, claims, a)
	if code != .Applied {destroy_frame(&f); return {}, code}
	return f, code
}
@(private)
prepare_internal :: proc(
	geometry: ^layout.Frame,
	targets: []Target,
	claims: []Capture_Claim,
	a: mem.Allocator,
) -> (
	f: Candidate,
	code: Code,
) {
	for c, i in claims {
		if c.node_id == "" || c.owner_id == "" {return {}, .Conflict}
		if _, ok := layout.find(geometry, c.node_id); !ok {return {}, .Not_Found}
		for prior in claims[:i] {if prior.node_id == c.node_id && prior.owner_id != c.owner_id {return {}, .Conflict}}
	}
	// Reject ambiguous descriptions before any owning role can be overwritten.
	for target, i in targets {
		if _, ok := layout.find(geometry, target.id);
		   !ok || target.id == "" {return {}, .Not_Found}
		for prior in targets[:i] {if prior.id == target.id {return {}, .Conflict}}
	}
	f = {
		drawable  = geometry.drawable,
		allocator = a,
		ui_scale  = geometry.ui_scale,
	}
	if !base.retain(geometry.stamp) {return f, .Allocation}
	f.stamp = geometry.stamp
	e: mem.Allocator_Error
	f.targets, e = make([]Target_View, len(geometry.nodes), a)
	if e != nil {return f, .Allocation}
	for n, i in geometry.nodes {
		v := &f.targets[i]
		v.bounds, v.clip = n.bounds, n.paint_clip
		v.kind = n.description.role
		v.description.id, e = strings.clone(
			n.description.id,
			a,
		); if e != nil {return f, .Allocation}
		v.parent, e = strings.clone(n.description.parent, a); if e != nil {return f, .Allocation}
		v.availability = .Invalid_Action
		for target in targets {if target.id == n.description.id {
				v.description.role, e = strings.clone(
					target.role,
					a,
				); if e != nil {return f, .Allocation}
				v.description.enabled, v.description.visible = target.enabled, target.visible
				v.availability = .Applied
				if !target.enabled || !n.enabled {v.availability = .Disabled}
				if !target.visible || !n.visible {v.availability = .Not_Visible}
			}}
	}
	return f, .Applied
}
retained_id :: proc(f: ^Frame, id: string) -> string {
	if n, ok := find(f, id); ok && n.availability == .Applied {return n.description.id}
	return ""
}
// Call only in a validated typed publisher's infallible commit section.
commit :: proc(ctx: ^Context, candidate: ^Candidate, initial_focus: string = "") {
	ctx.focus_id = retained_id(candidate, ctx.focus_id)
	if ctx.focus_id == "" {ctx.focus_id = retained_id(candidate, initial_focus)}
	ctx.hover_id = retained_id(candidate, ctx.hover_id)
	ctx.pressed_id = retained_id(candidate, ctx.pressed_id)
	old := ctx.frame
	ctx.frame = candidate^; candidate^ = {}
	destroy_frame(&old)
}
ready :: proc(ctx: ^Context) -> bool {return(
		!ctx.busy &&
		ctx.publication != nil &&
		base.is_current(ctx.publication, ctx.frame.stamp) \
	)}
// Non-mutating common gate for selected family dispatchers. Availability is
// frozen in the typed candidate, never recomputed from a live family model.
guard :: proc(ctx: ^Context, id: string, source: Source) -> Code {
	if code := guard_common(ctx, source); code != .Applied {return code}
	n, found := find(&ctx.frame, id)
	if !found {return .Not_Found}
	return n.availability
}
guard_common :: proc(ctx: ^Context, source: Source) -> Code {
	if !ready(ctx) {return .Not_Ready}
	if source < .Mouse || source > .Agent {return .Invalid_Action}
	return .Applied
}
dispatch :: proc(ctx: ^Context, action: Action) -> Dispatch_Result {
	return dispatch_internal(ctx, action, "")
}
@(private)
dispatch_internal :: proc(ctx: ^Context, action: Action, owner: string) -> Dispatch_Result {
	if !ready(ctx) {return {code = .Not_Ready}}
	if action.source < .Mouse ||
	   action.source > .Agent ||
	   action.kind < .Focus ||
	   action.kind > .Cancel {return {code = .Invalid_Action}}
	if action.kind == .Cancel {return {code = .Invalid_Action}}
	id := action.id
	if action.kind == .Navigate {
		count := len(ctx.frame.targets); start := -1
		for n, i in ctx.frame.targets {if n.description.id == ctx.focus_id {start = i}}
		if action.backwards && start < 0 {start = 0}
		for step in 1 ..= count {
			i := (start + step) % count
			if action.backwards {i = (start - step + count) % count}
			if ctx.frame.targets[i].availability != .Applied {continue}
			id = ctx.frame.targets[i].description.id; break
		}
		if id == "" {return {code = .Invalid_Action}}
	}
	if code := guard(ctx, id, action.source); code != .Applied {return {code = code}}
	n, _ := find(&ctx.frame, id)
	if action.kind == .Focus || action.kind == .Navigate {
		ctx.focus_id = n.description.id
		base.invalidate(ctx.publication)
		return {code = .Applied}
	}
	if n.activation_owner != owner {return {code = .Activation_Required}}
	if base.advance_sequence(ctx.publication) != .None {return {code = .Exhausted}}
	return {
		code = .Applied,
		event = {n.description.id, action.source, ctx.publication.sequence},
		has_event = true,
	}
}
find_handler :: proc(ctx: ^Context, id: string) -> (Registration, bool) {
	for r in ctx.registrations {if r.id == id {return r, true}}
	return {}, false
}
register_handler :: proc(
	ctx: ^Context,
	id: string,
	handler: Handler,
	user: rawptr = nil,
	dispose: Dispose = nil,
) -> (
	Handler_Token,
	Code,
) {
	if !ready(ctx) {return 0, .Not_Ready}
	n, ok := find(&ctx.frame, id); if !ok {return 0, .Not_Found}
	if handler == nil {return 0, .Invalid_Action}
	if _, found := find_handler(ctx, id); found {return 0, .Conflict}
	if ctx.last_handler_token == max(Handler_Token) {return 0, .Exhausted}
	r := Registration {
		kind    = n.kind,
		token   = ctx.last_handler_token + 1,
		handler = handler,
		user    = user,
		dispose = dispose,
	}
	e: mem.Allocator_Error
	r.id, e = strings.clone(id, ctx.allocator); if e != nil {return 0, .Allocation}
	r.role, e = strings.clone(
		n.description.role,
		ctx.allocator,
	); if e != nil {delete(r.id, ctx.allocator); return 0, .Allocation}
	if _, ae := append(&ctx.registrations, r);
	   ae !=
	   nil {delete(r.id, ctx.allocator); delete(r.role, ctx.allocator); return 0, .Allocation}
	ctx.last_handler_token = r.token
	return r.token, .Applied
}
remove_registration :: proc(ctx: ^Context, i: int) {
	r := ctx.registrations[i]
	ordered_remove(&ctx.registrations, i)
	if r.dispose != nil {r.dispose(r.user)}
	delete(r.id, ctx.allocator); delete(r.role, ctx.allocator)
}
unsubscribe :: proc(ctx: ^Context, token: Handler_Token) -> Code {
	if ctx.busy {return .Reentry}
	ctx.busy = true; defer {ctx.busy = false}
	for r, i in ctx.registrations {if r.token == token {remove_registration(ctx, i); return .Applied}}
	return .Not_Found
}
reconcile_registrations :: proc(ctx: ^Context) {
	ctx.busy = true; defer {ctx.busy = false}
	for i := len(ctx.registrations) - 1; i >= 0; i -= 1 {
		r := ctx.registrations[i]; n, ok := find(&ctx.frame, r.id)
		if !ok || n.description.role != r.role || n.kind != r.kind {remove_registration(ctx, i)}
	}
}
dispatch_routed :: proc(ctx: ^Context, action: Action) -> Dispatch_Result {
	return route_result(ctx, dispatch(ctx, action))
}
@(private)
route_result :: proc(ctx: ^Context, r: Dispatch_Result) -> Dispatch_Result {
	if !r.has_event {return r}
	ctx.busy = true; defer {ctx.busy = false}
	id := r.event.id
	for id != "" {
		n, ok := find(&ctx.frame, id); if !ok {break}
		if registration, found := find_handler(ctx, id); found {
			if registration.handler(
				   {r.event.id, id, r.event.source, r.event.sequence, ctx.frame.stamp.attempt},
				   registration.user,
			   ) ==
			   .Stop {break}
		}
		id = n.parent
	}
	return r
}
destroy :: proc(ctx: ^Context) {
	ctx.busy = true
	for len(ctx.registrations) > 0 {remove_registration(ctx, len(ctx.registrations) - 1)}
	delete(ctx.registrations); destroy_frame(&ctx.frame); ctx^ = {}
}
