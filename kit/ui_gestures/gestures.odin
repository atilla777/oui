package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import scroll "../ui_scroll"
import "core:mem"

Kind :: enum {
	Drag_Source,
	Drop_Target,
	Repeat_Scroll,
	Pan_Scroll,
}
Phase :: enum {
	Idle,
	Armed,
	Active,
}
Cancel_Reason :: enum {
	None,
	Explicit,
	Below_Threshold,
	No_Target,
	Rejected_Target,
	Pointer_Left,
	Window_Focus_Lost,
	Window_Hidden,
	Gamepad_Removed,
	Removed,
	Unavailable,
	Mode_Changed,
	Update_Failed,
}
Description :: struct {
	id, node_id, scope_id:    string,
	kind:                     Kind,
	payload_id, payload_type: string,
	accept_types:             []string,
	scroll_id:                string,
	step:                     f64,
	delay_ms, interval_ms:    i64,
}
Live :: struct {
	allocator:       mem.Allocator,
	owner:           Description,
	source:          interaction.Source,
	phase:           Phase,
	cycle:           u64,
	target_id:       string,
	target_accepted: bool,
	elapsed_ms:      i64,
	start, current:  [2]f64,
	start_offset:    f64,
	model_revision:  u64,
	reason:          Cancel_Reason,
}
Drop_Proposal :: struct {
	source_id, target_id, payload_id, payload_type: string,
	cycle, sequence, frame_id, model_revision:      u64,
}
Action_Kind :: enum {
	Begin,
	Aim,
	Move,
	Advance,
	End,
	Cancel,
}
Action :: struct {
	kind:        Action_Kind,
	id:          string,
	source:      interaction.Source,
	cycle:       u64,
	point:       [2]f64,
	duration_ms: i64,
	reason:      Cancel_Reason,
}
Signal_Kind :: enum {
	Began,
	Activated,
	Moved,
	Advanced,
	Ended,
	Cancelled,
}
Signal :: struct {
	kind:                Signal_Kind,
	owner_id, target_id: string,
	source:              interaction.Source,
	phase:               Phase,
	cycle:               u64,
	elapsed_ms:          i64,
	reason:              Cancel_Reason,
}
Result :: struct {
	signals:      [2]Signal,
	count:        int,
	code:         interaction.Code,
	cycle:        u64,
	phase:        Phase,
	reason:       Cancel_Reason,
	has_proposal: bool,
	proposal:     Drop_Proposal,
}
View :: struct {
	scroll_viewport:           base.Rect,
	scroll_offset, max_offset: f64,
	ancestors:                 []string,
	using description:         Description,
	availability:              interaction.Code,
	geometry:                  base.Frozen_Geometry,
	parent:                    string,
}
Frame :: struct {
	gestures:       []View,
	live:           Live,
	result:         Result,
	scope_id:       string,
	model_revision: u64,
	stamp:          base.Frame_Stamp,
	ui_scale:       f64,
	drawable:       base.Extent,
	allocator:      mem.Allocator,
}
State :: struct {
	identity:             ^base.Lifetime,
	frame:                Frame,
	live:                 Live,
	result:               Result,
	version, clock_epoch: u64,
	allocator:            mem.Allocator,
}
Candidate :: struct {
	identity: base.Frame_Stamp,
	frame:    Frame,
	live:     Live,
	owner:    ^State,
	version:  u64,
}
Error_Code :: enum {
	None,
	Invalid,
	Allocation,
	Stale,
	Exhausted,
}
Error :: struct {
	code: Error_Code,
	id:   string,
}
create :: proc(a := context.allocator) -> State {return {allocator = a}}
prepare :: proc(
	s: ^State,
	g: ^layout.Frame,
	i: ^interaction.Frame,
	sf: ^scroll.Frame,
	ds: []Description,
	model_revision: u64,
	a := context.allocator,
	scope_id: string = "",
	geometry: base.Geometry_View = {},
) -> (
	Candidate,
	Error,
) {
	if s.identity == nil {
		life, ae := new(base.Lifetime, s.allocator); if ae != nil {return {}, {code = .Allocation}}
		life^ = {
			references = 1,
			alive      = true,
			allocator  = s.allocator,
		}; s.identity = life
	}
	identity := base.Frame_Stamp {
		lifetime = s.identity,
	}; if !base.retain(identity) {return {}, {code = .Allocation}}
	c := Candidate {
		identity = identity,
		owner = s,
		version = s.version,
		frame = Frame{allocator = a},
	}
	e := prepare_into(&c, s, g, i, sf, ds, model_revision, scope_id, geometry)
	if e.code != .None {destroy_candidate(&c); return {}, e}
	return c, {}
}
validate_candidate :: proc(p: ^base.Publication, s: ^State, c: ^Candidate) -> bool {return(
		c.owner == s &&
		s.identity != nil &&
		s.identity.alive &&
		c.identity.lifetime == s.identity &&
		c.version == s.version &&
		s.version != max(u64) &&
		base.validate(p, c.frame.stamp) == .None \
	)}
commit :: proc(s: ^State, c: ^Candidate) {
	old, live := s.frame, s.live
	s.frame, s.live = c.frame, c.live; c.frame, c.live = {}, {}; base.release(c.identity); c^ = {}
	s.result = s.frame.result; rebind(&s.result, s.live)
	s.version += 1
	destroy_frame(&old); destroy_live(&live, s.allocator)
}
dispatch :: proc(
	s: ^State,
	ctx: ^interaction.Context,
	ss: ^scroll.State,
	action: Action,
) -> Result {return dispatch_gesture(s, ctx, ss, action)}
destroy_frame :: proc(f: ^Frame) {
	for &v in f.gestures {destroy_description(&v.description, f.allocator); delete(v.parent, f.allocator); for id in v.ancestors {delete(id, f.allocator)}; delete(v.ancestors, f.allocator)}
	delete(
		f.gestures,
		f.allocator,
	); delete(f.scope_id, f.allocator); destroy_live(&f.live, f.allocator); base.release(f.stamp); f^ = {}
}
destroy_candidate :: proc(c: ^Candidate) {a := c.frame.allocator; destroy_frame(&c.frame)
	destroy_live(&c.live, a)
	base.release(c.identity)
	c^ = {}}
destroy :: proc(s: ^State) {
	destroy_frame(&s.frame); destroy_live(&s.live, s.allocator)
	if s.identity != nil {s.identity.alive = false; base.release({lifetime = s.identity})}
	s^ = {}
}
find :: proc(f: ^Frame, id: string) -> (^View, bool) {for &v in f.gestures {if v.id ==
		   id {return &v, true}}
	return nil, false}
