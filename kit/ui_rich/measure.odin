package ui_rich

import base "../ui_base"
import text "../ui_text"
import "core:mem"
import "core:strings"

rich_line_fits :: proc(
	line: Rich_Line,
	width, origin, scale: f64,
	horizontal: text.Text_Horizontal,
) -> bool {
	if line.width > width || !base.finite_nonnegative(scale) || scale == 0 {return false}
	x := origin
	if horizontal ==
	   .Center {x += max(0, (width - line.width) / 2)}; if horizontal == .Right {x += max(0, width - line.width)}
	edge := base.snap({origin, 0, width, 0}, scale).x + base.snap({origin, 0, width, 0}, scale).w
	for fragment in line.fragments {if base.snap({x, 0, 0, 0}, scale).x + fragment.metrics.width > edge {return false}; x += fragment.metrics.width}
	return true
}
rich_checked_metric :: proc(
	value: string,
	style: Rich_Style,
	m: Rich_Text_Metrics,
) -> (
	Rich_Run_Metrics,
	Rich_Error_Code,
) {
	if m.measure == nil {return {}, .Metrics_Failed}
	r, e := m.measure(value, style, m.user); if e != .None {return {}, e}
	if !base.finite_nonnegative(r.width) ||
	   !base.finite_nonnegative(r.height) ||
	   !base.finite_nonnegative(r.baseline) ||
	   !base.finite_nonnegative(r.ascent) ||
	   !base.finite_nonnegative(r.descent) ||
	   !base.finite_nonnegative(r.gap) ||
	   r.ascent + r.descent + r.gap <= 0 ||
	   !base.finite(r.ascent + r.descent + r.gap) ||
	   r.baseline > r.height {return {}, .Invalid_Geometry}
	return r, .None
}
rich_measure_range :: proc(
	b: ^Rich_Block,
	start, end: int,
	ellipsis: bool,
	m: Rich_Text_Metrics,
	a: mem.Allocator,
) -> (
	Rich_Line,
	Rich_Error,
) {
	line := Rich_Line {
		decoded_range = {start, end},
		fragments     = make([dynamic]Rich_Fragment, 0, 0, a),
	}
	complete := false; defer {if !complete {rich_free_line(line, a)}}
	base_metric, e := rich_checked_metric(
		"",
		b.base_style,
		m,
	); if e != .None {return {}, {code = e}}
	line.ascent, line.descent, line.gap = base_metric.ascent, base_metric.descent, base_metric.gap
	if b.options.overflow == .Ellipsis {
		prime, pe := rich_checked_metric(
			"…",
			b.base_style,
			m,
		); if pe != .None {return {}, {code = pe}}
		line.ascent = max(
			line.ascent,
			prime.ascent,
			prime.baseline,
		); line.descent = max(line.descent, prime.descent, prime.height - prime.baseline); line.gap = max(line.gap, prime.gap)
	}
	for run, index in b.document.runs {
		s, t :=
			max(start, run.decoded_range.start),
			min(end, run.decoded_range.end); if s >= t {continue}
		r: Rich_Run_Metrics
		if run.image_id != "" {
			if m.image == nil ||
			   !m.image(
					   run.image_id,
					   m.user,
				   ) {return {}, {code = .Resource_Missing, source_range = run.source_range, reason = "image"}}
			r = {
				width    = run.width,
				height   = run.height,
				baseline = run.height,
				ascent   = run.height,
				revision = "image",
			}
		} else {r, e = rich_checked_metric(b.document.decoded[s:t], run.style, m)
			if e != .None {return {}, {code = e, source_range = run.source_range}}}
		ae: mem.Allocator_Error
		r.revision, ae = strings.clone(
			r.revision,
			a,
		); if ae != nil {return {}, {code = .Allocation}}
		if _, fe := append(
			&line.fragments,
			Rich_Fragment{run_index = index, decoded_range = {s, t}, metrics = r},
		); fe != nil {delete(r.revision, a); return {}, {code = .Allocation}}
		line.width +=
			r.width; line.ascent = max(line.ascent, r.ascent, r.baseline); line.descent = max(line.descent, r.descent, r.height - r.baseline); line.gap = max(line.gap, r.gap)
	}
	if ellipsis {
		r, ellipsis_error := rich_checked_metric(
			"…",
			b.base_style,
			m,
		); if ellipsis_error != .None {return {}, {code = ellipsis_error}}
		ae: mem.Allocator_Error
		r.revision, ae = strings.clone(
			r.revision,
			a,
		); if ae != nil {return {}, {code = .Allocation}}
		if _, fe := append(&line.fragments, Rich_Fragment{synthetic = true, metrics = r});
		   fe != nil {delete(r.revision, a); return {}, {code = .Allocation}}
		line.width +=
			r.width; line.ascent = max(line.ascent, r.ascent, r.baseline); line.descent = max(line.descent, r.descent, r.height - r.baseline); line.gap = max(line.gap, r.gap)
	}
	if !base.finite_nonnegative(line.width) ||
	   !base.finite_nonnegative(
			   line.ascent + line.descent + line.gap,
		   ) {return {}, {code = .Invalid_Geometry}}
	complete = true
	return line, {}
}
