package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import scroll "../ui_scroll"
import "core:strings"

@(private)
gate :: proc(
	f: ^Frame,
	ctx: ^interaction.Context,
	id: string,
	source: interaction.Source,
) -> (
	^View,
	interaction.Code,
) {
	v, found := find(f, id); if !found {return nil, .Not_Found}
	if v.availability != .Applied {return nil, v.availability}
	code := interaction.guard(ctx, v.node_id, source)
	if code ==
	   .Invalid_Action {n, ok := interaction.find(&ctx.frame, v.node_id); if ok && n.description.role == "" {code = .Applied}}
	if code != .Applied {return nil, code}; return v, .Applied
}
@(private)
accepts :: proc(f: ^Frame, owner: Description, target: ^View) -> bool {
	if target.kind != .Drop_Target || owner.scope_id != target.scope_id {return false}
	v, found := find(f, owner.id); if !found {return false}
	if v.node_id == target.node_id {return false}
	for id in v.ancestors {if id == target.node_id {return false}}
	for kind in target.accept_types {if kind == owner.payload_type {return true}}; return false
}
@(private)
emit :: proc(r: ^Result, l: Live, kind: Signal_Kind) {
	r.signals[r.count] = {
		kind,
		l.owner.id,
		l.target_id,
		l.source,
		l.phase,
		l.cycle,
		l.elapsed_ms,
		l.reason,
	}; r.count += 1
}
@(private)
dispatch_gesture :: proc(
	s: ^State,
	ctx: ^interaction.Context,
	ss: ^scroll.State,
	a: Action,
) -> Result {
	if code := interaction.guard_common(ctx, a.source); code != .Applied {return {code = code}}
	if s.frame.stamp != ctx.frame.stamp {return {code = .Not_Ready}}
	guard_id := s.live.owner.id
	if a.kind == .Begin {guard_id = a.id}
	if guard_id !=
	   "" {if _, code := gate(&s.frame, ctx, guard_id, a.source); code != .Applied {return {code = code}}}
	if a.kind ==
	   .Aim {if _, code := gate(&s.frame, ctx, a.id, a.source); code != .Applied {return {code = code}}}
	if a.kind < .Begin || a.kind > .Cancel {return {code = .Invalid_Action}}
	if s.version == max(u64) {return {code = .Exhausted}}
	l, ok := copy_live(s.live, s.allocator); if !ok {return {code = .Allocation}}
	defer destroy_live(&l, s.allocator)
	r := Result {
		code = .Applied,
	}
	previous_phase := l.phase
	scroll_delta: Maybe(f64)
	#partial switch a.kind {
	case .Cancel:
		if l.phase == .Idle ||
		   l.cycle != a.cycle ||
		   l.source != a.source ||
		   a.reason <= .None ||
		   a.reason > .Update_Failed {return {code = .Invalid_Action}}
		l.phase, l.reason = .Idle, a.reason
	case .Begin:
		if l.phase != .Idle {return {code = .Conflict}}
		d, code := gate(&s.frame, ctx, a.id, a.source); if code != .Applied {return {code = code}}
		if d.kind == .Drop_Target || l.cycle == max(u64) {return {code = .Invalid_Action}}
		if d.kind == .Repeat_Scroll {
			if ss == nil || ss.frame.stamp != s.frame.stamp {return {code = .Not_Ready}}
			scroll_delta = d.step
		}
		phase := Phase.Active
		if a.source == .Mouse || d.kind == .Pan_Scroll {
			if !base.finite(a.point[0]) ||
			   !base.finite(a.point[1]) ||
			   !base.contains(d.geometry.bounds, a.point[0], a.point[1]) ||
			   !base.contains(
					   d.geometry.clip,
					   a.point[0],
					   a.point[1],
				   ) {return {code = .Invalid_Action}}
			if d.kind != .Repeat_Scroll {phase = .Armed}
		}
		owned, copied := copy_description(
			d.description,
			s.allocator,
		); if !copied {return {code = .Allocation}}
		cycle := l.cycle + 1
		destroy_live(&l, s.allocator)
		l = {
			owner          = owned,
			source         = a.source,
			cycle          = cycle,
			phase          = phase,
			start          = a.point,
			current        = a.point,
			start_offset   = d.scroll_offset,
			model_revision = s.frame.model_revision,
			allocator      = s.allocator,
		}
	case .Advance:
		if l.phase != .Active ||
		   l.owner.kind != .Repeat_Scroll ||
		   l.cycle != a.cycle ||
		   l.source != a.source ||
		   a.duration_ms < 0 ||
		   a.duration_ms > max(i64) - l.elapsed_ms {return {code = .Invalid_Action}}
		if _, code := gate(&s.frame, ctx, l.owner.id, a.source);
		   code != .Applied {return {code = code}}
		next := l.elapsed_ms + a.duration_ms
		ticks :=
			repeat_ticks(next, l.owner.delay_ms, l.owner.interval_ms) -
			repeat_ticks(l.elapsed_ms, l.owner.delay_ms, l.owner.interval_ms)
		delta := f64(ticks) * l.owner.step
		if !base.finite(delta) {return {code = .Invalid_Action}}
		if ticks != 0 {scroll_delta = delta}
		l.elapsed_ms = next
	case .Move:
		if l.phase == .Idle ||
		   l.cycle != a.cycle ||
		   l.source != a.source ||
		   (l.owner.kind != .Pan_Scroll && (l.owner.kind != .Drag_Source || l.source != .Mouse)) ||
		   !base.finite(a.point[0]) ||
		   !base.finite(a.point[1]) {return {code = .Invalid_Action}}
		if _, code := gate(&s.frame, ctx, l.owner.id, a.source);
		   code != .Applied {return {code = code}}
		dx, dy := a.point[0] - l.start[0], a.point[1] - l.start[1]
		if !base.finite(dx) || !base.finite(dy) {return {code = .Invalid_Action}}
		l.current = a.point
		if l.phase == .Active ||
		   abs(dx) >= 6 ||
		   abs(dy) >= 6 ||
		   dx * dx + dy * dy >= 36 {l.phase = .Active}
		if l.phase == .Active && l.owner.kind == .Pan_Scroll {
			if ss == nil || ss.frame.stamp != s.frame.stamp {return {code = .Not_Ready}}
			r, found := scroll.find(
				&ss.frame,
				l.owner.scroll_id,
			); if !found {return {code = .Not_Found}}
			v, _ := find(&s.frame, l.owner.id)
			start, ms := base.inverse_point(
				v.geometry,
				l.start,
			); current, mc := base.inverse_point(v.geometry, a.point)
			if !ms || !mc {return {code = .Invalid_Action}}
			offset :=
				l.start_offset -
				(current[1] - start[1]); if !base.finite(offset) {return {code = .Invalid_Action}}
			scroll_delta = clamp(offset, 0, r.max_offset) - r.offset
		}
		if l.phase == .Active && l.owner.kind == .Drag_Source {
			target := ""
			for index := len(s.frame.gestures) - 1; index >= 0; index -= 1 {
				d := &s.frame.gestures[index]
				if d.kind == .Drop_Target &&
				   d.scope_id == l.owner.scope_id &&
				   d.availability == .Applied &&
				   base.contains(d.geometry.bounds, a.point[0], a.point[1]) &&
				   base.contains(d.geometry.clip, a.point[0], a.point[1]) {target = d.id; break}
			}
			id, ae := strings.clone(
				target,
				s.allocator,
			); if ae != nil {return {code = .Allocation}}
			delete(l.target_id, s.allocator); l.target_id, l.target_accepted = id, false
			if d, found := find(&s.frame, target);
			   found {l.target_accepted = accepts(&s.frame, l.owner, d)}
		}
	case .Aim:
		if l.phase != .Active ||
		   l.source == .Mouse ||
		   l.cycle != a.cycle ||
		   l.source != a.source ||
		   l.owner.kind != .Drag_Source {return {code = .Invalid_Action}}
		if _, code := gate(&s.frame, ctx, l.owner.id, a.source);
		   code != .Applied {return {code = code}}
		d, code := gate(&s.frame, ctx, a.id, a.source)
		if code != .Applied {return {code = code}}
		if d.kind != .Drop_Target ||
		   d.scope_id != l.owner.scope_id {return {code = .Invalid_Action}}
		id, ae := strings.clone(d.id, s.allocator)
		if ae != nil {return {code = .Allocation}}
		delete(l.target_id, s.allocator)
		l.target_id, l.target_accepted = id, accepts(&s.frame, l.owner, d)
	case .End:
		if l.phase == .Idle ||
		   l.cycle != a.cycle ||
		   l.source != a.source {return {code = .Invalid_Action}}
		if _, code := gate(&s.frame, ctx, l.owner.id, a.source);
		   code != .Applied {return {code = code}}
		if l.owner.kind == .Drag_Source {
			if l.phase ==
			   .Armed {l.reason = .Below_Threshold} else if l.target_id == "" {l.reason = .No_Target} else {
				d, code := gate(&s.frame, ctx, l.target_id, a.source)
				if code != .Applied ||
				   !accepts(&s.frame, l.owner, d) {l.reason = .Rejected_Target} else {
					if ctx.publication.sequence == max(u64) {return {code = .Exhausted}}
					r.has_proposal = true
					r.proposal = {
						l.owner.id,
						l.target_id,
						l.owner.payload_id,
						l.owner.payload_type,
						l.cycle,
						ctx.publication.sequence + 1,
						s.frame.stamp.attempt,
						l.model_revision,
					}
				}
			}
		}
		l.phase = .Idle
	case:
		return {code = .Invalid_Action}
	}
	if delta, pending := scroll_delta.?; pending {
		if ss == nil || ss.frame.stamp != s.frame.stamp {return {code = .Not_Ready}}
		sr := scroll.dispatch(
			ss,
			ctx,
			{kind = .Scroll_By, id = l.owner.scroll_id, source = a.source, delta_y = delta},
		)
		if sr.code != .Applied {return {code = sr.code}}
	}
	if r.has_proposal {if base.advance_sequence(ctx.publication) != .None {return {code = .Exhausted}}}
	r.cycle, r.phase, r.reason = l.cycle, l.phase, l.reason
	kind := Signal_Kind.Moved
	if a.kind == .Cancel {kind = .Cancelled}
	if a.kind == .Advance {kind = .Advanced}
	if a.kind == .Move && previous_phase == .Armed && l.phase == .Active {emit(&r, l, .Activated)}
	if a.kind ==
	   .Begin {kind = .Began}; if a.kind == .End {kind = .Ended; if l.reason != .None {kind = .Cancelled}}
	emit(&r, l, kind)
	old := s.live; s.live = l; l = {}; destroy_live(&old, s.allocator)
	rebind(&r, s.live); s.result = r; s.version += 1; base.invalidate(ctx.publication)
	return r
}

@(private)
repeat_ticks :: proc(elapsed, delay, interval: i64) -> i128 {
	if elapsed < delay {return 0}
	return 1 + (i128(elapsed) - i128(delay)) / i128(interval)
}
