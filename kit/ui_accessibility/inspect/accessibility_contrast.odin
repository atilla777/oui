package ui_accessibility_inspect

import ui "../projection"
import "core:math"

// Data-based sRGB oracle, not glyph-pixel/antialiasing measurement.
@(private)
accessibility_luminance :: proc(c: ui.Color) -> f64 {
	l := [3]f64{}
	for channel in 0 ..< 3 {
		x := f64(c[channel]) / 255
		if x <=
		   0.04045 {l[channel] = x / 12.92} else {l[channel] = math.pow((x + 0.055) / 1.055, 2.4)}
	}
	return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]
}
@(private)
accessibility_ratio :: proc(a, b: ui.Color) -> f64 {
	x, y := accessibility_luminance(a), accessibility_luminance(b)
	return (max(x, y) + 0.05) / (min(x, y) + 0.05)
}
@(private)
accessibility_alpha :: proc(c: ui.Color, opacity: f64) -> ui.Color {
	r := c; r[3] = u8(clamp(math.floor(f64(c[3]) * opacity + 0.5), 0, 255)); return r
}
@(private)
accessibility_over :: proc(fg, bg: ui.Color) -> ui.Color {
	r := bg
	for k in 0 ..< 3 {r[k] = u8(clamp(math.floor((f64(fg[k]) * f64(fg[3]) + f64(bg[k]) * f64(255 - int(fg[3]))) / 255 + 0.5), 0, 255))}
	r[3] = 255; return r
}
@(private)
accessibility_color :: proc(
	f: ^ui.Frame,
	n: ui.Resolved_Node,
	property: ui.Paint_Property,
) -> ui.Color {
	c := n.style.foreground; if property == .Background {c = n.style.background}
	if p, has := ui.inspect_presentation(f, n.description.id);
	   has {if v, ok := p.computed[property].value.(ui.Color); ok {c = v}}
	for tr in f.transitions {if tr.node_id == n.description.id && ((property == .Foreground && tr.property == .Foreground) || (property == .Background && tr.property == .Background)) {if v, ok := tr.current.([4]f64); ok {if converted, valid := ui.transition_color(v); valid {c = converted}}}}
	v, ok := ui.visual_geometry(f, n.description.id); if ok {c = accessibility_alpha(c, v.opacity)}
	return c
}
@(private)
accessibility_contains :: proc(outer, inner: ui.Rect) -> bool {
	return(
		outer.x <= inner.x &&
		outer.y <= inner.y &&
		outer.x + outer.w >= inner.x + inner.w &&
		outer.y + outer.h >= inner.y + inner.h \
	)
}
@(private)
accessibility_overlap :: proc(a, b: ui.Rect) -> bool {
	r := accessibility_intersection(a, b); return r.w > 0 && r.h > 0
}
// Apply only a known uniform layer covering the whole text region. An opaque
// later layer may reestablish knowledge lost to an earlier unknown surface.
@(private)
accessibility_background_layer :: proc(
	bg: ^ui.Color,
	known: ^bool,
	c: ui.Color,
	painted, area: ui.Rect,
) {
	if c[3] == 0 || !accessibility_overlap(painted, area) {return}
	if !accessibility_contains(painted, area) {known^ = false; return}
	if c[3] == 255 {bg^, known^ = c, true} else if known^ {bg^ = accessibility_over(c, bg^)}
}
@(private)
accessibility_unknown_paint :: proc(f: ^ui.Frame, n: ui.Resolved_Node) -> bool {
	for c in f.custom {if c.node_id == n.description.id {return true}}
	if p, has := ui.inspect_presentation(f, n.description.id); has {
		_, image := p.image.?; _, fallback := p.fallback.?
		if image ||
		   fallback ||
		   (p.visual.kind != .Role &&
				   p.visual.kind != .Image &&
				   p.visual.kind != .Rectangle) {return true}
	}
	if _, has := ui.inspect_progress(f, n.description.id); has {return true}
	if f.hold.id == n.description.id && f.hold.phase != .Idle {return true}
	return false
}
@(private)
accessibility_focus_overlaps :: proc(f: ^ui.Frame, n: ui.Resolved_Node, area: ui.Rect) -> bool {
	if !n.focused {return false}
	v, ok := ui.visual_geometry(f, n.description.id); if !ok {return true}
	w := n.style.focus_width * v.scale
	if p, has := ui.inspect_presentation(f, n.description.id);
	   has {if !p.focus_indicator {return false}; w = p.focus_width * v.scale}
	if w <= 0 {return false}
	inner := v.bounds; inner.x += w; inner.y += w; inner.w -= 2 * w; inner.h -= 2 * w
	return accessibility_overlap(v.bounds, area) && !accessibility_contains(inner, area)
}
// Inspect the actual layer paint order; a nearest ancestor is not a backdrop
// oracle. No custom callback, GPU, renderer, input or clock is called here.
@(private)
accessibility_background :: proc(f: ^ui.Frame, id: string, area: ui.Rect) -> (ui.Color, bool) {
	bg: ui.Color; known, reached := false, false
	// Non-layered focus closes a subtree after its descendants, not at the
	// owner's Draw_Node. Conservatively refuse an intersecting focus outline.
	if len(f.layer_paint) ==
	   0 {for n in f.nodes {if accessibility_focus_overlaps(f, n, area) {return {}, false}}}
	count := len(f.nodes); layered := len(f.layer_paint) > 0
	if layered {count = len(f.layer_paint)}
	for step in 0 ..< count {
		index := step
		if layered {
			command := f.layer_paint[step]
			if command.kind ==
			   .Scrim {if reached {return {}, false}; accessibility_background_layer(&bg, &known, {0, 0, 0, 160}, area, area); continue}
			index = command.node_index
			if index < 0 || index >= len(f.nodes) {return {}, false}
			if command.kind ==
			   .Draw_Focus {if accessibility_focus_overlaps(f, f.nodes[index], area) {return {}, false}; continue}
		}
		n := f.nodes[index]; v, valid := ui.visual_geometry(f, n.description.id)
		if !layered && n.description.id == f.modal.root_id {
			if reached {return {}, false}
			accessibility_background_layer(&bg, &known, {0, 0, 0, 160}, area, area)
		}
		if !valid {return {}, false}
		if !n.visible || v.opacity <= 0 || v.scale <= 0 {continue}
		if p, has := ui.inspect_presentation(f, n.description.id); has && !p.drawable {continue}
		painted := accessibility_intersection(v.bounds, v.clip)
		if !accessibility_overlap(painted, area) {continue}
		c := accessibility_color(f, n, .Background)
		// Legacy labels without layout do not paint their style background.
		if _, styled := ui.inspect_presentation(f, n.description.id);
		   !styled {if _, layout := n.description.layout.?; !layout && n.description.role != .Button && n.description.id != f.modal.root_id {c[3] = 0}}
		unknown := accessibility_unknown_paint(f, n)
		rectangle := false
		if p, has := ui.inspect_presentation(f, n.description.id);
		   has {rectangle = p.visual.kind == .Rectangle}
		for custom in f.custom {if custom.node_id == n.description.id {rectangle = false}}
		if reached {
			if c[3] > 0 ||
			   (rectangle &&
					   accessibility_color(f, n, .Foreground)[3] > 0 &&
					   accessibility_overlap(v.content_clip, area)) ||
			   unknown ||
			   (n.description.text != "" && accessibility_overlap(v.content_clip, area)) ||
			   accessibility_focus_overlaps(f, n, area) {return {}, false}
			continue
		}
		accessibility_background_layer(&bg, &known, c, painted, area)
		if unknown {known = false}
		if rectangle {accessibility_background_layer(&bg, &known, accessibility_color(f, n, .Foreground), accessibility_intersection(v.content, v.content_clip), area)}
		// Border is not a uniform fill. Only interior text can use the fill.
		bw := n.style.border_width * v.scale
		if p, has := ui.inspect_presentation(f, n.description.id);
		   has {bw = p.border_width * v.scale}
		inner := v.bounds; inner.x += bw; inner.y += bw; inner.w -= 2 * bw; inner.h -= 2 * bw
		if bw > 0 && !accessibility_contains(inner, area) {known = false}
		if n.description.id ==
		   id {reached = true} else if n.description.text != "" && accessibility_overlap(v.content_clip, area) {known = false}
		if !layered && accessibility_focus_overlaps(f, n, area) {known = false}
	}
	return bg, known && reached
}
@(private)
accessibility_contrast_region :: proc(
	i: ^Accessibility_Inspection,
	n: ui.Resolved_Node,
	record: Accessibility_Record,
	region: ui.Rect,
	foreground: ui.Color,
) -> Accessibility_Record {
	r := record; f := i.source
	v, valid := ui.visual_geometry(f, n.description.id)
	valid = valid && accessibility_valid_visual(v)
	if !n.visible ||
	   !n.enabled ||
	   n.transition_blocked ||
	   (valid &&
			   (v.opacity <= 0 ||
					   v.scale <=
						   0)) {r.status, r.reason = .Not_Applicable, "unavailable_text"; return r}
	if !valid {r.status, r.reason, r.code = .Unassessed, "unknown_visual_geometry", "a11y.Unassessed"; return r}
	area := accessibility_intersection(ui.visual_rect(v, region), v.content_clip)
	if area.w <= 0 || area.h <= 0 {r.status, r.reason = .Not_Applicable, "clipped_text"; return r}
	bg, known := accessibility_background(f, n.description.id, area)
	if !known {r.status, r.reason, r.code = .Unassessed, "unknown_or_nonuniform_backdrop", "a11y.Unassessed"; return r}
	fg := accessibility_over(foreground, bg)
	ratio := accessibility_ratio(fg, bg); r.ratio = ratio
	r.status, r.reason = .Pass, "contrast_at_least_minimum"
	if ratio <
	   i.policy.minimum_contrast {r.status, r.reason, r.severity = .Warning, "contrast_below_minimum", .Warning}
	return r
}

@(private)
accessibility_merge_contrast :: proc(a, b: Accessibility_Record) -> Accessibility_Record {
	r := a
	if b.status == .Not_Applicable {return r}
	if value, has := b.ratio.?;
	   has {if old, known := r.ratio.?; !known || value < old {r.ratio = value}}
	unknown :=
		a.status == .Unassessed ||
		b.status == .Unassessed ||
		!a.coverage_complete ||
		!b.coverage_complete
	if b.status == .Warning ||
	   a.status == .Not_Applicable ||
	   (a.status == .Pass &&
			   b.status ==
				   .Unassessed) {r.status, r.reason, r.code, r.severity = b.status, b.reason, b.code, b.severity}
	r.coverage_complete = !unknown
	return r
}
@(private)
accessibility_contrast_record :: proc(
	i: ^Accessibility_Inspection,
	n: ui.Resolved_Node,
	record: Accessibility_Record,
) -> Accessibility_Record {
	f := i.source
	fg := accessibility_color(f, n, .Foreground)
	for b in f.text_blocks {if b.node_id == n.description.id {
			r := record; r.status, r.reason = .Not_Applicable, "no_displayed_text"
			for line in b.lines {if line.displayed && line.display_text != "" {r = accessibility_merge_contrast(r, accessibility_contrast_region(i, n, record, line.logical_rect, fg))}}
			return r
		}}
	return accessibility_contrast_region(i, n, record, n.content, fg)
}
@(private)
accessibility_rich_block :: proc(f: ^ui.Frame, id: string) -> (^ui.Rich_Block, bool) {
	for &b in f.rich_blocks {if b.node_id == id {return &b, true}}
	return nil, false
}
@(private)
accessibility_rich_record :: proc(
	i: ^Accessibility_Inspection,
	n: ui.Resolved_Node,
	b: ^ui.Rich_Block,
	index: int,
	record: Accessibility_Record,
) -> Accessibility_Record {
	r := record; r.status, r.reason = .Not_Applicable, "no_displayed_run"
	for line in b.lines {
		if !line.displayed {continue}
		for fragment in line.fragments {
			if (fragment.synthetic && index != len(b.document.runs)) ||
			   (!fragment.synthetic && fragment.run_index != index) {continue}
			color := b.base_style.color
			if !fragment.synthetic {
				run := b.document.runs[index]
				if run.image_id !=
				   "" {unknown := record; unknown.status, unknown.reason, unknown.code, unknown.coverage_complete = .Unassessed, "inline_image", "a11y.Unassessed", false; r = accessibility_merge_contrast(r, unknown); continue}
				color = run.style.color
			}
			if color ==
			   b.base_style.color {color = accessibility_color(i.source, n, .Foreground)} else if v, ok := ui.visual_geometry(i.source, n.description.id); ok {color = accessibility_alpha(color, v.opacity)}
			r = accessibility_merge_contrast(
				r,
				accessibility_contrast_region(i, n, record, fragment.rect, color),
			)
		}
	}
	return r
}

Accessibility_Contrast_Summary :: struct {
	id:                string,
	minimum_ratio:     Maybe(f64),
	coverage_complete: bool,
	run_count:         int,
}
// Borrowed ID and numeric values only; no capture, ticking or allocation.
accessibility_contrast_summary :: proc(
	i: ^Accessibility_Inspection,
	id: string,
) -> Accessibility_Contrast_Summary {
	r := Accessibility_Contrast_Summary {
		coverage_complete = true,
	}
	for record in i.records {if record.check == .Contrast && record.id == id {
			r.id = record.id; r.run_count += 1
			if record.status == .Unassessed ||
			   !record.coverage_complete {r.coverage_complete = false}
			if value, has := record.ratio.?;
			   has {if old, known := r.minimum_ratio.?; !known || value < old {r.minimum_ratio = value}}
		}}
	return r
}
