package ui_rich

import base "../ui_base"
import graphemes "../unicode_graphemes"
import "core:mem"

resolve_rich_display :: proc(
	b: ^Rich_Block,
	content: base.Rect,
	scale: f64,
	metrics: Rich_Text_Metrics,
	a: mem.Allocator,
) -> Rich_Error {
	if !base.finite(content.x) ||
	   !base.finite(content.y) ||
	   !base.finite_nonnegative(content.w) ||
	   !base.finite_nonnegative(content.h) ||
	   !base.finite(scale) ||
	   scale <= 0 {return {code = .Invalid_Geometry}}
	b.ellipsized, b.ellipsis_unavailable = false, false
	slots := 0; height := f64(0)
	if content.w > 0 && content.h > 0 {
		for line in b.lines {
			height += line.ascent + line.descent + line.gap
			box := base.snap({content.x, content.y, 0, height}, scale)
			if box.h > content.h {break}; slots += 1
		}
	}
	if limit, has := b.options.max_lines.?; has {slots = min(slots, limit)}
	b.visible_line_count = slots; b.hidden = slots < len(b.lines)
	last := -1
	for line, index in b.lines {if !rich_line_fits(line, content.w, content.x, scale, b.options.horizontal) {b.hidden = true; if index < slots && last < 0 {last = index}}}
	if b.options.overflow == .Ellipsis && slots > 0 {
		if last < 0 && slots < len(b.lines) {last = slots - 1}
		if last >= 0 {
			old := b.lines[last]
			boundary_result, ae := graphemes.try_boundaries(
				b.document.decoded[old.decoded_range.start:old.decoded_range.end],
				a,
			)
			if ae != nil {return {code = .Allocation}}
			bounds := boundary_result.([]int); defer delete(bounds, a)
			best := -1
			for offset in bounds {
				candidate, e := rich_measure_range(
					b,
					old.decoded_range.start,
					old.decoded_range.start + offset,
					true,
					metrics,
					a,
				); if e.code != .None {return e}
				fits := rich_line_fits(
					candidate,
					content.w,
					content.x,
					scale,
					b.options.horizontal,
				); rich_free_line(candidate, a)
				if fits {best = old.decoded_range.start + offset}
			}
			line: Rich_Line
			if best >= 0 {
				candidate, e := rich_measure_range(
					b,
					old.decoded_range.start,
					best,
					true,
					metrics,
					a,
				); if e.code != .None {return e}
				line = candidate; b.ellipsized = true
			} else {b.ellipsis_unavailable = true
				line.decoded_range = {old.decoded_range.start, old.decoded_range.start}}
			line.ascent, line.descent, line.gap, line.break_reason =
				old.ascent, old.descent, old.gap, old.break_reason
			rich_free_line(old, a); b.lines[last] = line; b.visible_line_count = last + 1
		}
	}
	height = 0
	for index in 0 ..< b.visible_line_count {line := b.lines[index]; height += line.ascent + line.descent + line.gap}
	y := content.y
	if b.options.vertical ==
	   .Center {y += max(0, (content.h - height) / 2)}; if b.options.vertical == .Bottom {y += max(0, content.h - height)}
	for &line, index in b.lines {
		line.displayed = index < b.visible_line_count
		line.baseline = base.snap({0, y + line.ascent, 0, 0}, scale).y
		x := content.x
		if b.options.horizontal ==
		   .Center {x += max(0, (content.w - line.width) / 2)}; if b.options.horizontal == .Right {x += max(0, content.w - line.width)}
		for &fragment in line.fragments {
			fragment.rect = {
				base.snap({x, 0, 0, 0}, scale).x,
				line.baseline - fragment.metrics.baseline,
				fragment.metrics.width,
				fragment.metrics.height,
			}
			x += fragment.metrics.width
			if !fragment.synthetic &&
			   b.document.runs[fragment.run_index].image_id !=
				   "" {fragment.rect = base.snap(fragment.rect, scale)}
			if !base.finite(fragment.rect.x) ||
			   !base.finite(fragment.rect.y) {return {code = .Invalid_Geometry}}
		}
		y += line.ascent + line.descent + line.gap
	}
	return {}
}
