package ui_editor

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import text "../ui_text"
import "core:mem"
import "core:strings"

Rejection :: Editor_Rejection
Resolution_Kind :: enum {
	Unchanged,
	Accepted,
	Rejected,
	External,
}
Resolution :: struct {
	kind:      Resolution_Kind,
	sequence:  u64,
	rejection: Rejection,
}
Description :: struct {
	id, node_id, text_node_id, label, value: string,
	max_graphemes:                           Maybe(int),
	revision:                                u64,
	resolution:                              Resolution,
}
Run :: struct {
	start, end:     int,
	x, advance:     f64,
	surface_extent: base.Extent,
}
View :: struct {
	geometry:                                        base.Frozen_Geometry,
	using description:                               Description,
	boundaries:                                      []int,
	stops:                                           []f64,
	runs:                                            []Run,
	caret, anchor, count:                            int,
	scroll, extent, ascent, line_advance, font_size: f64,
	font_id, font_revision:                          string,
	content, clip:                                   base.Rect,
	availability:                                    interaction.Code,
	rejection:                                       Rejection,
}
Proposal :: struct {
	id, value:                         string,
	base_revision, sequence, frame_id: u64,
	caret, anchor:                     int,
	source:                            interaction.Source,
	allocator:                         mem.Allocator,
}
Cursor :: struct {
	id:            string,
	caret, anchor: int,
	scroll:        f64,
}
Frame :: struct {
	drawable:  base.Extent,
	scope_id:  string,
	ui_scale:  f64,
	editors:   []View,
	stamp:     base.Frame_Stamp,
	allocator: mem.Allocator,
}
State :: struct {
	identity:  ^base.Lifetime,
	frame:     Frame,
	pending:   Maybe(Proposal),
	cursor:    Cursor,
	version:   u64,
	allocator: mem.Allocator,
}
Candidate :: struct {
	identity: base.Frame_Stamp,
	frame:    Frame,
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
	code:        Error_Code,
	rejection:   Rejection,
	id:          string,
	byte_offset: int,
}
Action_Kind :: enum {
	Insert,
	Backspace,
	Delete,
	Move,
	Select,
	Submit,
	Cancel,
}
Direction :: enum {
	Left,
	Right,
	Home,
	End,
}
Action :: struct {
	pointer_scroll: Maybe(f64),
	id, text:       string,
	kind:           Action_Kind,
	source:         interaction.Source,
	anchor, caret:  int,
	direction:      Direction,
	extend:         bool,
}
Intent :: enum {
	None,
	Submit,
	Cancel,
}
Result :: struct {
	code:               interaction.Code,
	rejection:          Rejection,
	proposal:           Maybe(Proposal),
	intent:             Intent,
	sequence, frame_id: u64,
}
create :: proc(a := context.allocator) -> State {return {allocator = a}}
destroy_proposal :: proc(p: ^Proposal) {delete(p.id, p.allocator); delete(p.value, p.allocator)
	p^ = {}}
destroy_result :: proc(r: ^Result) {if p, ok := r.proposal.?; ok {destroy_proposal(&p)}; r^ = {}}
destroy_frame :: proc(f: ^Frame) {
	for e in f.editors {
		for v in ([]string{e.id, e.node_id, e.text_node_id, e.label, e.value, e.font_id, e.font_revision}) {delete(v, f.allocator)}
		delete(
			e.boundaries,
			f.allocator,
		); delete(e.stops, f.allocator); delete(e.runs, f.allocator)
	}
	delete(f.scope_id, f.allocator); delete(f.editors, f.allocator); base.release(f.stamp); f^ = {}
}
destroy_candidate :: proc(c: ^Candidate) {destroy_frame(&c.frame); base.release(c.identity); c^ =
		{}}
destroy :: proc(s: ^State) {destroy_frame(&s.frame); if p, ok := s.pending.?; ok {destroy_proposal(
			&p,
		)}
	delete(s.cursor.id, s.allocator)
	if s.identity != nil {s.identity.alive = false; base.release({lifetime = s.identity})}
	s^ = {}}
find :: proc(f: ^Frame, id: string) -> (^View, bool) {for &v in f.editors {if v.id == id ||
		   v.node_id == id {return &v, true}}
	return nil, false}
prepare :: proc(
	s: ^State,
	g: ^layout.Frame,
	i: ^interaction.Frame,
	tf: ^text.Frame,
	ds: []Description,
	metrics: text.Text_Layout_Metrics,
	a := context.allocator,
	scope_id: string = "",
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
		}
	if !base.retain(identity) {return {}, {code = .Allocation}}
	c := Candidate {
			identity = identity,
			owner = s,
			version = s.version,
			frame = Frame{allocator = a},
		}
	err := prepare_into(&c, s, g, i, tf, ds, metrics)
	if err.code == .None {
		value, ae := strings.clone(scope_id, a)
		if ae != nil {err.code = .Allocation} else {c.frame.scope_id = value}
	}
	if err.code != .None {destroy_candidate(&c); return {}, err}
	return c, {}
}
validate_candidate :: proc(p: ^base.Publication, s: ^State, c: ^Candidate) -> bool {
	return(
		c.owner == s &&
		s.identity != nil &&
		s.identity.alive &&
		c.identity.lifetime == s.identity &&
		c.version == s.version &&
		s.version != max(u64) &&
		base.validate(p, c.frame.stamp) == .None \
	)
}
// Only call inside the checked typed publication commit section.
commit :: proc(s: ^State, c: ^Candidate) {
	old := s.frame; s.frame = c.frame; c.frame = {}; base.release(c.identity); c^ = {}
	if p, ok := s.pending.?; ok {destroy_proposal(&p)}; s.pending = nil
	delete(s.cursor.id, s.allocator); s.cursor = {}; s.version += 1
	destroy_frame(&old)
}
dispatch :: proc(
	s: ^State,
	ctx: ^interaction.Context,
	action: Action,
	metrics: text.Text_Layout_Metrics,
) -> Result {return dispatch_editor(s, ctx, action, metrics)}
