package ui_editor

import base "../ui_base"
import interaction "../ui_interaction"
import text "../ui_text"
import "core:mem"
import "core:strings"

@(private)
try_copy_proposal :: proc(p: Proposal, a: mem.Allocator) -> (Proposal, bool) {
	r := p; r.id, r.value, r.allocator = "", "", a
	e: mem.Allocator_Error
	r.id, e = strings.clone(p.id, a); if e != nil {return {}, false}
	r.value, e = strings.clone(p.value, a); if e != nil {destroy_proposal(&r); return {}, false}
	return r, true
}
@(private)
dispatch_editor :: proc(
	s: ^State,
	ctx: ^interaction.Context,
	action: Action,
	metrics: text.Text_Layout_Metrics,
) -> Result {
	if !interaction.ready(ctx) || s.frame.stamp != ctx.frame.stamp {return {code = .Not_Ready}}
	if code := interaction.guard_common(ctx, action.source);
	   code != .Applied {return {code = code}}
	e, found := find(&s.frame, action.id); if !found {return {code = .Not_Found}}
	if code := interaction.guard(ctx, e.node_id, action.source);
	   code != .Applied {return {code = code}}
	if e.availability != .Applied {return {code = e.availability}}
	if ctx.focus_id != e.node_id {return {code = .Invalid_Action}}
	if s.version == max(u64) {return {code = .Exhausted}}
	caret, anchor, scroll := e.caret, e.anchor, e.scroll
	if hint, supplied := action.pointer_scroll.?; supplied {
		if action.kind != .Select ||
		   action.source != .Mouse ||
		   !base.finite_nonnegative(hint) ||
		   hint >
			   max(
				   0,
				   e.extent - e.content.w,
			   ) {return {code = .Invalid_Action, rejection = .Invalid_Range}}
		scroll = hint
	}
	#partial switch action.kind {
	case .Submit, .Cancel:
		if base.advance_sequence(ctx.publication) != .None {return {code = .Exhausted}}
		s.version += 1
		intent := Intent.Submit; if action.kind == .Cancel {intent = .Cancel}
		return {
			code = .Applied,
			intent = intent,
			sequence = ctx.publication.sequence,
			frame_id = ctx.frame.stamp.attempt,
		}
	case .Move:
		if action.direction < .Left || action.direction > .End {return {code = .Invalid_Action}}
		index := 0
		for offset, j in e.boundaries {if offset == caret {index = j; break}}
		switch action.direction {
		case .Left:
			caret = e.boundaries[max(0, index - 1)]
		case .Right:
			caret = e.boundaries[min(len(e.boundaries) - 1, index + 1)]
		case .Home:
			caret = 0
		case .End:
			caret = len(e.value)
		}
		if !action.extend {
			if anchor != e.caret {
				if action.direction == .Left {caret = min(anchor, e.caret)}
				if action.direction == .Right {caret = max(anchor, e.caret)}
			}
			anchor = caret
		}
	case .Select:
		valid_caret, valid_anchor := false, false
		for offset in e.boundaries {valid_caret ||= offset == action.caret; valid_anchor ||= offset == action.anchor}
		if !valid_caret ||
		   !valid_anchor {return {code = .Invalid_Action, rejection = .Invalid_Range}}
		caret, anchor = action.caret, action.anchor
	case .Insert, .Backspace, .Delete:
		insertion := action.text
		if action.kind == .Insert &&
		   insertion == "" {return {code = .Applied, frame_id = ctx.frame.stamp.attempt}}
		if action.kind != .Insert {
			insertion = ""
			if anchor == caret {for offset, j in e.boundaries {
					if offset != caret {continue}
					if action.kind ==
					   .Backspace {anchor = e.boundaries[max(0, j - 1)]} else {anchor = e.boundaries[min(len(e.boundaries) - 1, j + 1)]}
					break
				}}
		}
		splice := editor_splice(e.value, anchor, caret, insertion, e.max_graphemes, s.allocator)
		defer destroy_editor_splice(&splice)
		if splice.rejection !=
		   .None {code := interaction.Code.Invalid_Action; if splice.rejection == .Allocation {code = .Allocation}; return {code = code, rejection = splice.rejection}}
		if metrics.validate_text ==
		   nil {return {code = .Invalid_Action, rejection = .Glyph_Missing}}
		ge, _ := metrics.validate_text(splice.value, e.font_id, e.font_size, metrics.user)
		if ge != .None {return {code = .Invalid_Action, rejection = .Glyph_Missing}}
		if splice.value != e.value {
			if ctx.publication.sequence == max(u64) {return {code = .Exhausted}}
			borrowed := Proposal {
				id            = e.id,
				value         = splice.value,
				base_revision = e.revision,
				sequence      = ctx.publication.sequence + 1,
				frame_id      = ctx.frame.stamp.attempt,
				caret         = splice.caret,
				anchor        = splice.caret,
				source        = action.source,
			}
			pending, ok := try_copy_proposal(
				borrowed,
				s.allocator,
			); if !ok {return {code = .Allocation}}
			result, copied := try_copy_proposal(
				borrowed,
				s.allocator,
			); if !copied {destroy_proposal(&pending); return {code = .Allocation}}
			if base.advance_sequence(ctx.publication) !=
			   .None {destroy_proposal(&pending); destroy_proposal(&result); return {code = .Exhausted}}
			if old, exists := s.pending.?; exists {destroy_proposal(&old)}
			s.pending = pending; s.version += 1
			return {
				code = .Applied,
				proposal = result,
				sequence = result.sequence,
				frame_id = result.frame_id,
			}
		}
		caret, anchor = splice.caret, splice.caret
	case:
		return {code = .Invalid_Action}
	}
	id, ae := strings.clone(e.id, s.allocator); if ae != nil {return {code = .Allocation}}
	delete(s.cursor.id, s.allocator); s.cursor = {id, caret, anchor, scroll}
	s.version += 1; base.invalidate(ctx.publication)
	return {code = .Applied, frame_id = ctx.frame.stamp.attempt}
}
