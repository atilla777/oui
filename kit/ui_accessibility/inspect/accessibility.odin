package ui_accessibility_inspect

import common "../../ui_inspect"
import ui "../projection"
import "core:math"
import "core:mem"
import "core:strings"

Inspect_Error :: common.Inspect_Error
Severity :: common.Severity
Phase :: common.Phase
Strict_Result :: common.Strict_Result
Inspection :: common.Inspection
Action :: common.Action
Query :: common.Query
Diagnostic_Record :: common.Diagnostic_Record
inspect :: common.inspect
find :: common.find
strict_result :: common.strict_result
is_ready :: common.is_ready
error_name :: common.error_name
destroy_inspection :: common.destroy_inspection
Inspection_Input :: struct {
	frame:  ^ui.Frame,
	common: common.Inspection_Input,
}

Accessibility_Policy :: struct {
	minimum_contrast: f64,
	minimum_target:   ui.Extent,
}
default_accessibility_policy :: proc() -> Accessibility_Policy {return {4.5, {24, 24}}}
Accessibility_Check :: enum {
	Contrast,
	Target_Size,
	Reduced_Motion,
}
Assessment_Status :: enum {
	Pass,
	Warning,
	Unassessed,
	Not_Applicable,
}
Accessibility_Record :: struct {
	reduced_motion:                                                                    Maybe(bool),
	id, source_hint, reason, code:                                                     string,
	check:                                                                             Accessibility_Check,
	status:                                                                            Assessment_Status,
	global_scope:                                                                      bool,
	coverage_complete:                                                                 bool,
	run_index:                                                                         Maybe(int),
	ratio:                                                                             Maybe(f64),
	available:                                                                         Maybe(
		ui.Rect,
	),
	minimum_contrast:                                                                  f64,
	minimum_target:                                                                    ui.Extent,
	frame_id, model_revision, published_revision, transition_version, policy_revision: u64,
	property:                                                                          Maybe(
		ui.Transition_Property,
	),
	severity:                                                                          Severity,
	phase:                                                                             Phase,
}
Accessibility_Inspection :: struct {
	transition_version: u64,
	source:             ^ui.Frame,
	owned_strings:      []string,
	inspection:         Inspection,
	policy:             Accessibility_Policy,
	policy_revision:    u64,
	records:            []Accessibility_Record,
	record_storage:     []Accessibility_Record,
	allocator:          mem.Allocator,
}
Accessibility_Strict_Result :: struct {
	ok, coverage_complete:                                             bool,
	pass_count, warning_count, unassessed_count, not_applicable_count: int,
	legacy:                                                            Strict_Result,
	records:                                                           []Accessibility_Record,
}
capture_accessibility :: proc(
	input: Inspection_Input,
	policy: Accessibility_Policy,
	allocator: mem.Allocator,
	policy_revision: Maybe(u64) = nil,
	observation_policy_revision: Maybe(u64) = nil,
) -> (
	Accessibility_Inspection,
	Inspect_Error,
) {
	// The additive reader always uses checked copying, including legacy frames.
	if math.is_nan(policy.minimum_contrast) ||
	   math.is_inf(policy.minimum_contrast) ||
	   policy.minimum_contrast < 1 ||
	   policy.minimum_contrast > 21 ||
	   math.is_nan(policy.minimum_target.w) ||
	   math.is_inf(policy.minimum_target.w) ||
	   policy.minimum_target.w <= 0 ||
	   math.is_nan(policy.minimum_target.h) ||
	   math.is_inf(policy.minimum_target.h) ||
	   policy.minimum_target.h <= 0 {return {}, .Invalid_Policy}
	pr, has_pr := policy_revision.?; observed, has_observed := observation_policy_revision.?
	if !has_pr || !has_observed || pr != observed {return {}, .Metadata_Mismatch}
	// Keep the compatibility capture path unchanged.
	if input.frame == nil || len(input.frame.nodes) == 0 {return {}, .Metadata_Mismatch}
	if input.frame.modal.root_id != "" {
		if _, code := ui.find(input.frame, input.frame.modal.root_id);
		   code != .Applied {return {}, .Metadata_Mismatch}
		if _, code := ui.find(input.frame, input.frame.modal.initial_focus_id);
		   code != .Applied {return {}, .Metadata_Mismatch}
	}
	if !accessibility_finite(input.frame.ui_scale) ||
	   input.frame.ui_scale <= 0 ||
	   !accessibility_finite(input.frame.drawable.w) ||
	   !accessibility_finite(input.frame.drawable.h) ||
	   input.frame.drawable.w <= 0 ||
	   input.frame.drawable.h <= 0 {return {}, .Metadata_Mismatch}
	for n in input.frame.nodes {for rect in ([4]ui.Rect{n.bounds, n.content, n.clip, n.paint_clip}) {if !accessibility_valid_rect(rect) {return {}, .Metadata_Mismatch}}}
	if input.common.frame == nil ||
	   input.frame.drawable != input.common.frame.drawable ||
	   input.frame.ui_scale != input.common.frame.ui_scale ||
	   input.frame.stamp != input.common.frame.stamp ||
	   input.frame.id != input.common.frame.id ||
	   len(input.frame.nodes) != len(input.common.frame.nodes) {return {}, .Metadata_Mismatch}
	for n, k in input.frame.nodes {g := input.common.frame.nodes[k]; if n.description.id != g.description.id || n.bounds != g.bounds || n.clip != g.clip || n.content != g.content || n.paint_clip != g.paint_clip {return {}, .Metadata_Mismatch}}
	if len(input.frame.gestures) > 0 &&
	   input.frame.gesture_model_revision !=
		   input.common.published_revision {return {}, .Metadata_Mismatch}
	for s, n in input.common.semantics {
		if s.id == "" {return {}, .Metadata_Mismatch}
		if _, code := ui.find(input.frame, s.id); code != .Applied {return {}, .Metadata_Mismatch}
		for previous in input.common.semantics[:n] {if previous.id == s.id {return {}, .Metadata_Mismatch}}
	}
	r := Accessibility_Inspection {
		allocator = allocator,
		policy    = policy,
	}
	r.policy_revision, _ = policy_revision.?
	i, e := common.capture(input.common, allocator)
	if e != .None {return {}, e}
	r.inspection = i
	r.source = input.frame
	r.transition_version = input.frame.transition_version
	complete := false
	defer {if !complete {destroy_accessibility_inspection(&r)}}
	f := input.frame
	count := 1 + len(f.transitions) + len(f.presences) + 2 * len(f.nodes)
	for b in f.rich_blocks {count += len(b.document.runs) + 1}
	err: mem.Allocator_Error
	r.records, err = make([]Accessibility_Record, count, allocator)
	if err != nil {return {}, .Allocation}
	r.record_storage = r.records
	used := 0
	for n in f.nodes {
		if b, has := accessibility_rich_block(f, n.description.id); has {
			for _, index in b.document.runs {
				record := accessibility_base(
					&r,
					.Contrast,
					n.description.id,
				); record.run_index = index
				r.records[used] = accessibility_rich_record(&r, n, b, index, record); used += 1
			}
			synthetic := false
			for line in b.lines {for fragment in line.fragments {if line.displayed && fragment.synthetic {synthetic = true}}}
			if synthetic {
				index := len(
					b.document.runs,
				); record := accessibility_base(&r, .Contrast, n.description.id); record.run_index = index
				r.records[used] = accessibility_rich_record(&r, n, b, index, record); used += 1
			}
			continue
		}
		if n.description.text == "" {continue}
		record := accessibility_base(&r, .Contrast, n.description.id)
		record.run_index = 0
		r.records[used] = accessibility_contrast_record(&r, n, record); used += 1
	}
	for n in f.nodes {
		if !accessibility_target(f, n.description.id) {continue}
		record := accessibility_base(&r, .Target_Size, n.description.id)
		record = accessibility_target_record(&r, n, record)
		r.records[used] = record; used += 1
	}
	motion := accessibility_base(&r, .Reduced_Motion, "")
	motion.global_scope = true
	if f.transition_mode {motion.reduced_motion = f.reduced_motion}
	motion.status, motion.reason = .Pass, "reduced_motion_disabled"
	if !f.transition_mode {motion.status, motion.reason = .Not_Applicable, "no_transition_mode"} else if f.reduced_motion {motion.reason = "reduced_motion_enabled"}
	r.records[used] = motion; used += 1
	if f.transition_mode && f.reduced_motion {
		for tr in f.transitions {
			if tr.phase == .Completed && tr.current == tr.target {continue}
			record := accessibility_base(&r, .Reduced_Motion, tr.node_id)
			record.status, record.reason, record.severity =
				.Warning, "unfinished_transition", .Warning
			record.property = tr.property
			r.records[used] = record; used += 1
		}
		for presence in f.presences {
			if presence.phase != .Exiting {continue}
			record := accessibility_base(&r, .Reduced_Motion, presence.node_id)
			record.status, record.reason, record.severity = .Warning, "unfinished_exit", .Warning
			r.records[used] = record; used += 1
		}
	}
	r.records = r.records[:used]
	r.owned_strings, err = make(
		[]string,
		2 * used,
		allocator,
	); if err != nil {return {}, .Allocation}
	for &record, k in r.records {
		r.owned_strings[2 * k], err = strings.clone(
			record.id,
			allocator,
		); if err != nil {return {}, .Allocation}
		r.owned_strings[2 * k + 1], err = strings.clone(
			record.source_hint,
			allocator,
		); if err != nil {return {}, .Allocation}
		record.id, record.source_hint = r.owned_strings[2 * k], r.owned_strings[2 * k + 1]
	}
	for &record in r.records {if record.status == .Unassessed {record.coverage_complete = false}}
	r.source = nil
	complete = true
	return r, .None
}
destroy_accessibility_inspection :: proc(i: ^Accessibility_Inspection) {
	for s in i.owned_strings {delete(s, i.allocator)}; delete(i.owned_strings, i.allocator)
	delete(i.record_storage, i.allocator)
	destroy_inspection(&i.inspection)
	i^ = {}
}
accessibility_strict_result :: proc(i: ^Accessibility_Inspection) -> Accessibility_Strict_Result {
	r := Accessibility_Strict_Result {
		legacy            = strict_result(&i.inspection),
		coverage_complete = true,
		records           = i.records,
	}
	r.ok = r.legacy.ok
	for record in i.records {
		if !record.coverage_complete {r.coverage_complete = false}
		switch record.status {
		case .Pass:
			r.pass_count += 1
		case .Warning:
			r.warning_count += 1; r.ok = false
		case .Unassessed:
			r.unassessed_count += 1; r.coverage_complete = false
		case .Not_Applicable:
			r.not_applicable_count += 1
		}
	}
	return r
}

@(private)
accessibility_base :: proc(
	i: ^Accessibility_Inspection,
	check: Accessibility_Check,
	id: string,
) -> Accessibility_Record {
	f := i.source
	r := Accessibility_Record {
		coverage_complete  = true,
		id                 = id,
		check              = check,
		phase              = .published_frame,
		frame_id           = f.id,
		model_revision     = i.inspection.model_revision,
		published_revision = i.inspection.published_revision,
		transition_version = f.transition_version,
		policy_revision    = i.policy_revision,
		minimum_contrast   = i.policy.minimum_contrast,
		minimum_target     = i.policy.minimum_target,
	}
	switch check {case .Contrast:
		r.code = "a11y.Contrast"; case .Target_Size:
		r.code = "a11y.Target_Size"; case .Reduced_Motion:
		r.code = "a11y.Reduced_Motion"}
	for s in i.inspection.semantics {if s.id == id {r.source_hint = s.source_hint; break}}
	return r
}
@(private)
accessibility_target :: proc(f: ^ui.Frame, id: string) -> bool {
	n, code := ui.find(f, id); if code != .Applied {return false}
	if n.description.role == .Button {return true}
	for s in f.scroll {if s.id == id {return true}}
	for e in f.editors {if e.description.node_id == id {return true}}
	for g in f.gestures {if g.node_id == id {return true}}
	return false
}
@(private)
accessibility_intersection :: proc(a, b: ui.Rect) -> ui.Rect {
	x, y := max(a.x, b.x), max(a.y, b.y)
	return {x, y, max(0, min(a.x + a.w, b.x + b.w) - x), max(0, min(a.y + a.h, b.y + b.h) - y)}
}
@(private)
accessibility_finite :: proc(v: f64) -> bool {return !math.is_nan(v) && !math.is_inf(v)}
@(private)
accessibility_valid_rect :: proc(r: ui.Rect) -> bool {
	return(
		accessibility_finite(r.x) &&
		accessibility_finite(r.y) &&
		accessibility_finite(r.w) &&
		accessibility_finite(r.h) &&
		accessibility_finite(r.x + r.w) &&
		accessibility_finite(r.y + r.h) &&
		r.w >= 0 &&
		r.h >= 0 \
	)
}
@(private)
accessibility_target_record :: proc(
	i: ^Accessibility_Inspection,
	n: ui.Resolved_Node,
	r: Accessibility_Record,
) -> Accessibility_Record {
	r := r
	f := i.source
	v, valid := ui.visual_geometry(f, n.description.id)
	valid = valid && accessibility_valid_visual(v)
	if (n.availability != .Applied && n.availability != .Invalid_Action) ||
	   !n.visible ||
	   !n.enabled ||
	   n.transition_blocked ||
	   (valid &&
			   (v.opacity <= 0 ||
					   v.scale <=
						   0)) {r.status, r.reason = .Not_Applicable, "unavailable_target"; return r}
	if !valid {r.status, r.reason, r.code = .Unassessed, "unknown_visual_geometry", "a11y.Unassessed"; return r}
	for custom in f.custom {if custom.node_id == n.description.id {r.status, r.reason, r.code = .Unassessed, "custom_hit_shape", "a11y.Unassessed"; return r}}
	rect := accessibility_intersection(
		accessibility_intersection(v.bounds, v.clip),
		{0, 0, f.drawable.w / f.ui_scale, f.drawable.h / f.ui_scale},
	)
	for other in f.nodes {
		if other.description.id == n.description.id ||
		   (other.availability != .Applied && other.availability != .Invalid_Action) ||
		   !other.visible ||
		   !other.enabled ||
		   other.transition_blocked ||
		   !accessibility_target(f, other.description.id) {continue}
		ov, ok := ui.visual_geometry(
			f,
			other.description.id,
		); if !ok || ov.opacity <= 0 || ov.scale <= 0 {continue}
		overlap := accessibility_intersection(rect, accessibility_intersection(ov.bounds, ov.clip))
		if overlap.w > 0 &&
		   overlap.h >
			   0 {r.status, r.reason, r.code = .Unassessed, "overlapping_input_surface", "a11y.Unassessed"; return r}
	}
	r.available = rect
	r.status, r.reason = .Pass, "target_at_least_minimum"
	if rect.w < i.policy.minimum_target.w ||
	   rect.h <
		   i.policy.minimum_target.h {r.status, r.reason, r.severity = .Warning, "target_below_minimum", .Warning}
	return r
}

@(private)
accessibility_valid_visual :: proc(v: ui.Visual_Geometry) -> bool {
	return(
		accessibility_finite(v.scale) &&
		accessibility_finite(v.opacity) &&
		accessibility_valid_rect(v.bounds) &&
		accessibility_valid_rect(v.content) &&
		accessibility_valid_rect(v.clip) &&
		accessibility_valid_rect(v.content_clip) \
	)
}
