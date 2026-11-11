package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:strings"

Phase :: enum {
	Idle,
	Holding,
	Completed_Waiting_Release,
}
Cancel_Reason :: enum {
	None,
	Early_Release,
	Explicit,
	Pointer_Left,
	UI_Focus_Lost,
	Window_Focus_Lost,
	Window_Hidden,
	Gamepad_Removed,
	Removed,
	Unavailable,
	Mode_Changed,
	Threshold_Changed,
}
Hold_State :: struct {
	id:                       string,
	source:                   interaction.Source,
	phase:                    Phase,
	elapsed_ms, threshold_ms: i64,
	cycle:                    u64,
}
Signal_Kind :: enum {
	Started,
	Progress,
	Completed,
	Cancelled,
}
Signal :: struct {
	kind:     Signal_Kind,
	id:       string,
	source:   interaction.Source,
	cycle:    u64,
	progress: f64,
	reason:   Cancel_Reason,
}
Result :: struct {
	code:     interaction.Code,
	signals:  [3]Signal,
	count:    int,
	dispatch: interaction.Dispatch_Result,
}
Description :: struct {
	id:           string,
	threshold_ms: i64,
}
Progress_Description :: struct {
	id:             string,
	value, maximum: f64,
}
Progress :: struct {
	id:             string,
	value, maximum: f64,
	fill:           base.Rect,
}
Frame :: struct {
	holds:     []Description,
	progress:  []Progress,
	hold:      Hold_State,
	result:    Result,
	stamp:     base.Frame_Stamp,
	allocator: mem.Allocator,
}
State :: struct {
	frame:       Frame,
	live:        Hold_State,
	last_result: Result,
	allocator:   mem.Allocator,
}
Candidate :: struct {
	frame:   Frame,
	live_id: string,
}
Error_Code :: enum {
	None,
	Invalid_Hold,
	Invalid_Progress,
	Allocation,
	Stale,
}
Error :: struct {
	code: Error_Code,
	id:   string,
}
Action_Kind :: enum {
	Begin,
	Release,
	Cancel,
	Advance,
}
Action :: struct {
	kind:        Action_Kind,
	id:          string,
	source:      interaction.Source,
	duration_ms: i64,
	reason:      Cancel_Reason,
}
create :: proc(a: mem.Allocator) -> State {return {allocator = a}}
destroy_frame :: proc(f: ^Frame) {a := f.allocator; for h in f.holds {delete(h.id, a)}; for p in f.progress {delete(
			p.id,
			a,
		)}
	delete(f.holds, a)
	delete(f.progress, a)
	delete(f.hold.id, a)
	base.release(f.stamp)
	f^ = {}}
destroy :: proc(s: ^State) {destroy_frame(&s.frame); delete(s.live.id, s.allocator); s^ = {}}
destroy_candidate :: proc(c: ^Candidate) {delete(c.live_id, c.frame.allocator); destroy_frame(
		&c.frame,
	)
	c^ = {}}
prepare :: proc(
	s: ^State,
	ctx: ^interaction.Context,
	g: ^layout.Frame,
	targets: ^interaction.Frame,
	progress: []Progress_Description,
	holds: []Description,
	a: mem.Allocator,
) -> (
	Candidate,
	Error,
) {
	if g.stamp != targets.stamp {return {}, {code = .Stale}}
	for p, i in progress {
		if !base.finite_nonnegative(p.value) ||
		   !base.finite_nonnegative(p.maximum) ||
		   p.maximum == 0 ||
		   p.value > p.maximum {return {}, {.Invalid_Progress, p.id}}
		if _, ok := layout.find(g, p.id); !ok {return {}, {.Invalid_Progress, p.id}}
		for prior in progress[:i] {if prior.id == p.id {return {}, {.Invalid_Progress, p.id}}}
	}
	for h, i in holds {
		n, ok := interaction.find(targets, h.id)
		if !ok ||
		   n.description.role != "button" ||
		   h.threshold_ms <= 0 {return {}, {.Invalid_Hold, h.id}}
		if n.activation_owner != "" &&
		   n.activation_owner != "hold" {return {}, {.Invalid_Hold, h.id}}
		for prior in holds[:i] {if prior.id == h.id {return {}, {.Invalid_Hold, h.id}}}
	}
	c: Candidate
	c.frame.allocator = a
	complete := false
	defer {if !complete {destroy_candidate(&c)}}
	if !base.retain(g.stamp) {return {}, {code = .Allocation}}
	c.frame.stamp = g.stamp
	e: mem.Allocator_Error
	c.frame.progress, e = make(
		[]Progress,
		len(progress),
		a,
	); if e != nil {return {}, {code = .Allocation}}
	for p, i in progress {
		n, _ := layout.find(g, p.id)
		fill := n.content; fill.w *= p.value / p.maximum
		c.frame.progress[i] = {
			value   = p.value,
			maximum = p.maximum,
			fill    = base.snap(fill, g.ui_scale),
		}
		c.frame.progress[i].id, e = strings.clone(
			p.id,
			a,
		); if e != nil {return {}, {code = .Allocation}}
	}
	c.frame.holds, e = make(
		[]Description,
		len(holds),
		a,
	); if e != nil {return {}, {code = .Allocation}}
	for h, i in holds {c.frame.holds[i].threshold_ms = h.threshold_ms; c.frame.holds[i].id, e = strings.clone(h.id, a); if e != nil {return {}, {code = .Allocation}}}
	c.frame.hold = s.live; c.frame.hold.id = ""
	c.frame.hold.id, e = strings.clone(s.live.id, a); if e != nil {return {}, {code = .Allocation}}
	c.live_id, e = strings.clone(s.live.id, a); if e != nil {return {}, {code = .Allocation}}
	c.frame.result = s.last_result
	if s.live.phase == .Holding {
		reason := Cancel_Reason.None
		n, found := interaction.find(targets, s.live.id)
		threshold := i64(0); for h in holds {if h.id == s.live.id {threshold = h.threshold_ms}}
		if !found {reason = .Removed
		} else if n.availability != .Applied {reason = .Unavailable
		} else if threshold == 0 {reason = .Mode_Changed
		} else if threshold != s.live.threshold_ms {reason = .Threshold_Changed
		} else if ctx.focus_id != s.live.id {reason = .UI_Focus_Lost}
		if reason != .None {
			c.frame.result = {
				code = .Applied,
			}
			signal(&c.frame.result, c.frame.hold, .Cancelled, reason)
			c.frame.hold.phase, c.frame.hold.elapsed_ms = .Idle, 0
		}
	}
	rebind_result(&c.frame.result, c.frame.hold.id)
	// Stage every new binding before transferring any: failure leaves targets intact.
	bindings, error := make(
		[]string,
		len(holds),
		a,
	); if error != nil {return {}, {code = .Allocation}}
	defer {for id in bindings {delete(id, targets.allocator)}; delete(bindings, a)}
	for h, k in holds {
		n, _ := interaction.find(targets, h.id)
		if n.activation_owner ==
		   "" {bindings[k], e = strings.clone("hold", targets.allocator); if e != nil {return {}, {code = .Allocation}}}
	}
	for h, k in holds {if bindings[k] != "" {n, _ := interaction.find(targets, h.id); n.activation_owner = bindings[k]; bindings[k] = ""}}
	complete = true
	return c, {}
}
@(private)
rebind_result :: proc(r: ^Result, id: string) {
	for i in 0 ..< r.count {r.signals[i].id = id}
	if r.dispatch.has_event {r.dispatch.event.id = id}
}
validate_candidate :: proc(p: ^base.Publication, c: ^Candidate) -> bool {return(
		base.validate(p, c.frame.stamp) ==
		.None \
	)}
commit :: proc(s: ^State, c: ^Candidate) {old := s.frame; s.frame = c.frame; c.frame = {}; delete(
		s.live.id,
		s.allocator,
	)
	s.live = s.frame.hold
	s.allocator = s.frame.allocator
	s.live.id = c.live_id
	c.live_id = ""
	s.last_result = s.frame.result
	rebind_result(&s.last_result, s.live.id)
	c^ = {}
	destroy_frame(&old)}
