package ui_transitions

import base "../ui_base"
import "core:mem"
import "core:strings"

destroy_frame :: proc(f: ^Frame) {
	base.release(f.stamp)
	if f.storage != nil {mem.rollback_stack_destroy(f.storage); free(f.storage, f.allocator)}
	f^ = {}
}
destroy :: proc(s: ^State) {destroy_frame(&s.frame); if s.identity != nil {s.identity.alive = false
		base.release({lifetime = s.identity})}
	s^ = {}}
destroy_candidate :: proc(c: ^Candidate) {destroy_frame(&c.frame); base.release(
		{lifetime = c.identity},
	)
	c^ = {}}
new_frame :: proc(stamp: base.Frame_Stamp, a: mem.Allocator) -> (Frame, Error_Code) {
	storage, ae := new(mem.Rollback_Stack, a); if ae != nil {return {}, .Allocation}
	if mem.rollback_stack_init_dynamic(storage, 4096, a) !=
	   nil {free(storage, a); return {}, .Allocation}
	if !base.retain(
		stamp,
	) {mem.rollback_stack_destroy(storage); free(storage, a); return {}, .Stale}
	return {stamp = stamp, allocator = a, storage = storage}, .None
}
prepare :: proc(
	s: ^State,
	stamp: base.Frame_Stamp,
	descriptions: []Description,
	step: Step,
	reduced_motion: bool,
	a := context.allocator,
) -> (
	Candidate,
	Error,
) {
	if step.delta_ms < 0 ||
	   step.kind < .Advance ||
	   step.kind > .Finish_All ||
	   (step.kind == .Finish_All &&
			   step.delta_ms != 0) {return {}, {code = .Time, stage = .Sample}}
	if s.version == max(u64) {return {}, {code = .Exhausted, stage = .Prepare}}
	if stamp.lifetime == nil ||
	   !stamp.lifetime.alive ||
	   stamp.attempt == 0 ||
	   (s.frame.stamp.lifetime != nil &&
			   s.frame.stamp.lifetime !=
				   stamp.lifetime) {return {}, {code = .Stale, stage = .Prepare}}
	count, presence_count := 0, 0
	for d, index in descriptions {
		if d.node_id == "" {return {}, {code = .Descriptor, stage = .Descriptor}}
		for prior in descriptions[:index] {if prior.node_id == d.node_id {return {}, {.Descriptor, d.node_id, .Foreground, .Descriptor}}}
		if len(d.tracks) > max(int) - count {return {}, {code = .Allocation, stage = .Prepare}}
		count += len(d.tracks); if d.present != nil {presence_count += 1}
		for tr, j in d.tracks {
			e := Error {
				code     = .Descriptor,
				node_id  = d.node_id,
				property = tr.property,
				stage    = .Descriptor,
			}
			if !timing_valid(tr.timing) || !value_valid(tr.property, tr.target) {return {}, e}
			for prior in d.tracks[:j] {if prior.property == tr.property {return {}, e}}
			if endpoints, has := tr.presence.?;
			   has {if d.present == nil || !value_valid(tr.property, endpoints.enter) || !value_valid(tr.property, endpoints.exit) {return {}, e}}
		}
	}
	f, fe := new_frame(stamp, a); if fe != .None {return {}, {code = fe, stage = .Prepare}}
	complete := false; defer {if !complete {destroy_frame(&f)}}
	ca := mem.rollback_stack_allocator(f.storage)
	ae: mem.Allocator_Error
	f.tracks, ae = make(
		[]View,
		count,
		ca,
	); if ae != nil {return {}, {code = .Allocation, stage = .Prepare}}
	f.presences, ae = make(
		[]Presence,
		presence_count,
		ca,
	); if ae != nil {return {}, {code = .Allocation, stage = .Prepare}}
	k, pk := 0, 0
	f.bindings, ae = make(
		[]string,
		len(descriptions),
		ca,
	); if ae != nil {return {}, {code = .Allocation, stage = .Prepare}}
	for d, index in descriptions {
		f.bindings[index], ae = strings.clone(
			d.node_id,
			ca,
		); if ae != nil {return {}, {code = .Allocation, stage = .Prepare}}
		present, has_presence := d.present.?
		old_presence := Presence {
			present = present,
			phase   = .Hidden,
		}
		had_presence := false
		for old in s.frame.presences {if old.node_id == d.node_id {old_presence = old; had_presence = true; break}}
		presence_changed := has_presence && had_presence && old_presence.present != present
		all_done := true
		for track in d.tracks {
			v := View {
				property = track.property,
				start    = track.target,
				current  = track.target,
				target   = track.target,
				timing   = track.timing,
			}
			if endpoints, yes := track.presence.?;
			   yes {v.presence_track = true; v.start = endpoints.enter; if !present {v.target, v.start = endpoints.exit, endpoints.exit}}
			if track.presence == nil ||
			   (has_presence &&
					   !present &&
					   !had_presence) {v.elapsed_ms = track.timing.delay_ms + track.timing.duration_ms}
			target := v.target
			for old in s.frame.tracks {
				if old.node_id != d.node_id || old.property != track.property {continue}
				v = old; advance(&v, step.delta_ms, reduced_motion || step.kind == .Finish_All)
				if v.target != target ||
				   v.timing != track.timing ||
				   (track.presence != nil && presence_changed) ||
				   v.presence_track !=
					   (track.presence !=
							   nil) {v.start, v.target, v.timing, v.elapsed_ms = v.current, target, track.timing, 0}
				if endpoints, yes := track.presence.?;
				   yes &&
				   present &&
				   old_presence.phase == .Hidden {v.start, v.elapsed_ms = endpoints.enter, 0}
				break
			}
			v.presence_track = track.presence != nil
			advance(&v, 0, reduced_motion || step.kind == .Finish_All)
			if v.presence_track && v.phase != .Completed {all_done = false}
			v.node_id, ae = strings.clone(
				d.node_id,
				ca,
			); if ae != nil {return {}, {code = .Allocation, property = track.property, stage = .Prepare}}
			f.tracks[k] = v; k += 1
		}
		if has_presence {
			phase := Presence_Phase.Visible
			if !present {phase = .Hidden; if !all_done {phase = .Exiting}} else if !all_done {phase = .Entering}
			f.presences[pk] = {
				present = present,
				phase   = phase,
			}
			f.presences[pk].node_id, ae = strings.clone(
				d.node_id,
				ca,
			); if ae != nil {return {}, {code = .Allocation, stage = .Prepare}}; pk += 1
		}
	}
	if s.identity == nil {
		identity, ie := new(
			base.Lifetime,
			s.allocator,
		); if ie != nil {return {}, {code = .Allocation, stage = .Prepare}}
		identity^ = {
			references = 1,
			alive      = true,
			allocator  = s.allocator,
		}; s.identity = identity
	}
	if !base.retain({lifetime = s.identity}) {return {}, {code = .Allocation, stage = .Prepare}}
	f.reduced_motion = reduced_motion
	complete = true
	return {frame = f, identity = s.identity, version = s.version}, {}
}
validate_candidate :: proc(p: ^base.Publication, s: ^State, c: ^Candidate) -> bool {
	return(
		s.identity != nil &&
		s.identity.alive &&
		c.identity == s.identity &&
		c.version == s.version &&
		c.frame.bound &&
		base.validate(p, c.frame.stamp) == .None \
	)
}
commit :: proc(s: ^State, c: ^Candidate) {old := s.frame; s.frame = c.frame; c.frame = {}
	s.version += 1
	destroy_frame(&old)
	destroy_candidate(c)}
block :: proc(s: ^State, p: ^base.Publication) -> bool {base.invalidate(p); if s.clock_epoch ==
	   max(u64) {return false}
	s.clock_epoch += 1
	return true}
