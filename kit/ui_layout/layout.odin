package ui_layout

import base "../ui_base"
import "core:math"
import "core:mem"
import "core:slice"
import "core:strings"

Extent :: base.Extent
Rect :: base.Rect
Frame_Stamp :: base.Frame_Stamp
snap :: base.snap
intersection :: base.intersection
finite_nonnegative :: base.finite_nonnegative
Kind :: enum {
	Column,
	Row,
	Stack,
	Grid,
	Absolute,
	Box,
	Content,
}
Node :: struct {
	id, parent:       string,
	role:             Kind,
	layout:           Maybe(Layout),
	enabled, visible: bool,
}
Error_Code :: enum {
	None,
	Invalid_ID,
	Duplicate_ID,
	Missing_Parent,
	Cycle,
	Invalid_Tree,
	Invalid_Size,
	Invalid_Scale,
	Metrics_Failed,
	Invalid_Layout,
	Invalid_Grid,
	Invalid_Safe_Area,
	Unsupported_Scale_Mode,
	Allocation,
}
// Error ID borrows input on refusal. Clone it explicitly before releasing input.
Update_Error :: struct {
	code: Error_Code,
	id:   string,
}
Diagnostic_Kind :: enum {
	Content_Overflow,
	Container_Overflow,
	Relative_In_Content,
}
Diagnostic :: struct {
	kind:                Diagnostic_Kind,
	id:                  string,
	frame_id:            u64,
	required, available: Extent,
}
Resolved_Node :: struct {
	description:                       Node,
	bounds, content, clip, paint_clip: Rect,
	measured:                          Extent,
	rows, columns:                     []f64,
	enabled, visible:                  bool,
}
Frame :: struct {
	nodes:             []Resolved_Node,
	diagnostics:       [dynamic]Diagnostic,
	id:                u64,
	stamp:             Frame_Stamp,
	drawable:          Extent,
	ui_scale:          f64,
	allocator:         mem.Allocator,
	allocation_failed: bool,
}
Layout_Candidate :: Frame
node_index :: proc(nodes: []Node, id: string) -> int {for n, i in nodes {if n.id == id {return i}}
	return -1}
find :: proc(f: ^Frame, id: string) -> (^Resolved_Node, bool) {for &n in f.nodes {if n.description.id ==
		   id {return &n, true}}
	return nil, false}
destroy_frame :: proc(f: ^Frame) {
	for n in f.nodes {
		delete(n.description.id, f.allocator); delete(n.description.parent, f.allocator)
		if l, ok := n.description.layout.?;
		   ok {delete(l.rows, f.allocator); delete(l.columns, f.allocator); delete(l.metric_id, f.allocator)}
		delete(n.rows, f.allocator); delete(n.columns, f.allocator)
	}
	delete(f.nodes, f.allocator); delete(f.diagnostics)
	base.release(f.stamp)
	f^ = {}
}
destroy_candidate :: destroy_frame
try_clone_description :: proc(n: Node, a: mem.Allocator) -> (r: Node, e: mem.Allocator_Error) {
	r = n; r.id, r.parent = "", ""; r.layout = nil
	complete := false
	defer {if !complete {delete(r.id, a); delete(r.parent, a); if l, ok := r.layout.?; ok {delete(l.rows, a); delete(l.columns, a); delete(l.metric_id, a)}}}
	r.id = strings.clone(n.id, a) or_return
	r.parent = strings.clone(n.parent, a) or_return
	if l, ok := n.layout.?; ok {
		v := l; v.rows, v.columns, v.metric_id = nil, nil, ""; r.layout = v
		v.rows, e = slice.clone(l.rows, a); r.layout = v; if e != nil {return r, e}
		v.columns, e = slice.clone(l.columns, a); r.layout = v; if e != nil {return r, e}
		v.metric_id, e = strings.clone(l.metric_id, a); r.layout = v; if e != nil {return r, e}
	}
	complete = true
	return r, nil
}

Size_Mode :: enum {
	Content,
	Fixed,
	Fill,
	Percent,
}
Axis_Size :: struct {
	mode:       Size_Mode,
	value, min: f64,
	max:        Maybe(f64),
}
Insets :: struct {
	left, top, right, bottom: f64,
}
Align :: enum {
	Start,
	Center,
	End,
	Stretch,
}
Justify :: enum {
	Start,
	Center,
	End,
	SpaceBetween,
}
Overflow :: enum {
	Clip,
	Visible,
}
Track_Mode :: enum {
	Fixed,
	Content,
	Fill,
}
Track :: struct {
	mode:       Track_Mode,
	value, min: f64,
	max:        Maybe(f64),
}
Layout :: struct {
	x, y:                  Axis_Size,
	padding, margin:       Insets,
	gap:                   f64,
	align:                 Align,
	align_self:            Maybe(Align),
	justify:               Justify,
	grow, shrink:          f64,
	overflow:              Overflow,
	anchor, pivot, offset: [2]f64,
	rows, columns:         []Track,
	row, column:           int,
	metric_id:             string,
}
Scale_Mode :: enum {
	Normal,
	Pixel_Perfect,
}
Layout_Options :: struct {
	drawable:   Extent,
	ui_scale:   f64,
	scale_mode: Scale_Mode,
	safe_area:  Maybe(Rect),
}
Intrinsic_Metrics :: proc(id: string, user: rawptr) -> (Extent, bool)
Layout_Metrics :: struct {
	intrinsic: Intrinsic_Metrics,
	user:      rawptr,
}

prepare :: proc(
	nodes: []Node,
	options: Layout_Options,
	metrics: Layout_Metrics,
	allocator: mem.Allocator,
	stamp: Frame_Stamp,
) -> (
	result: Layout_Candidate,
	result_error: Update_Error,
) {
	// The solver does not publish or construct interaction state.
	root, validation := validate_layout(nodes, options)
	if validation.code != .None {return {}, validation}
	sizes, ae := make([]Extent, len(nodes), allocator)
	if ae != nil {return {}, {.Allocation, ""}}
	defer delete(sizes, allocator)
	children, ce := make([][dynamic]int, len(nodes), allocator)
	if ce != nil {return {}, {.Allocation, ""}}
	defer {for list in children {delete(list)}; delete(children, allocator)}
	for &list in children {list = make([dynamic]int, 0, 0, allocator)}
	for node, i in nodes {if node.parent != "" {if _, e := append(&children[node_index(nodes, node.parent)], i); e != nil {return {}, {.Allocation, ""}}}}
	err := layout_measure(nodes, children, root, sizes, metrics, allocator)
	if err.code != .None {return {}, err}
	if !base.retain(stamp) {return {}, {.Allocation, ""}}
	frame := Frame {
		id          = stamp.attempt,
		stamp       = stamp,
		drawable    = options.drawable,
		ui_scale    = options.ui_scale,
		nodes       = make([]Resolved_Node, len(nodes), allocator),
		allocator   = allocator,
		diagnostics = make([dynamic]Diagnostic, 0, 0, allocator),
	}
	if len(frame.nodes) != len(nodes) {destroy_frame(&frame); return {}, {.Allocation, ""}}
	cursor := 0
	slot := Rect {
		0,
		0,
		options.drawable.w / options.ui_scale,
		options.drawable.h / options.ui_scale,
	}
	if safe, ok := options.safe_area.?;
	   ok {slot = {safe.x / options.ui_scale, safe.y / options.ui_scale, safe.w / options.ui_scale, safe.h / options.ui_scale}}
	inherited := slot
	l, _ := nodes[root].layout.?
	slot.w = axis_resolve(l.x, sizes[root].w, slot.w)
	slot.h = axis_resolve(l.y, sizes[root].h, slot.h)
	if l.x.mode ==
	   .Fill {slot.w = axis_limit(l.x, max(0, inherited.w - l.margin.left - l.margin.right))}
	if l.y.mode ==
	   .Fill {slot.h = axis_limit(l.y, max(0, inherited.h - l.margin.top - l.margin.bottom))}
	slot.x += l.margin.left; slot.y += l.margin.top
	layout_arrange(
		&frame,
		nodes,
		children,
		root,
		sizes,
		slot,
		snap(inherited, options.ui_scale),
		true,
		true,
		&cursor,
	)
	if frame.allocation_failed {destroy_frame(&frame); return {}, {.Allocation, ""}}
	if nodes[root].visible &&
	   (slot.w + l.margin.left + l.margin.right > inherited.w ||
			   slot.h + l.margin.top + l.margin.bottom >
				   inherited.h) {layout_diagnostic(&frame, .Container_Overflow, nodes[root].id, {slot.w + l.margin.left + l.margin.right, slot.h + l.margin.top + l.margin.bottom}, {inherited.w, inherited.h})}
	for node in frame.nodes {
		for tracks in ([][]f64{node.rows, node.columns}) {for value in tracks {if !finite_nonnegative(value) {destroy_frame(&frame); return {}, {.Invalid_Size, nodes[root].id}}}}
		for rect in ([4]Rect{node.bounds, node.content, node.clip, node.paint_clip}) {
			if !finite(rect.x) ||
			   !finite(rect.y) ||
			   !finite_nonnegative(rect.w) ||
			   !finite_nonnegative(
					   rect.h,
				   ) {destroy_frame(&frame); return {}, {.Invalid_Size, nodes[root].id}}
		}
	}
	if frame.allocation_failed {destroy_frame(&frame); return {}, {.Allocation, ""}}
	for &d in frame.diagnostics {owner, _ := find(&frame, d.id); d.id = owner.description.id}
	return frame, {}
}

finite :: proc(value: f64) -> bool {return !math.is_nan(value) && !math.is_inf(value)}
valid_axis :: proc(a: Axis_Size) -> bool {
	if !finite_nonnegative(a.value) || !finite_nonnegative(a.min) {return false}
	if upper, ok := a.max.?; ok {if !finite_nonnegative(upper) || upper < a.min {return false}}
	return a.mode >= .Content && a.mode <= .Percent && (a.mode != .Percent || a.value <= 1)
}
layout_role :: proc(nodes: []Node, index: int) -> Kind {return nodes[index].role}
container_role :: proc(role: Kind) -> bool {return(
		role == .Column ||
		role == .Row ||
		role == .Stack ||
		role == .Grid ||
		role == .Absolute \
	)}
validate_layout :: proc(nodes: []Node, options: Layout_Options) -> (int, Update_Error) {
	if !finite_nonnegative(options.ui_scale) ||
	   options.ui_scale == 0 {return -1, {.Invalid_Scale, ""}}
	if options.scale_mode != .Normal &&
	   options.scale_mode != .Pixel_Perfect {return -1, {.Unsupported_Scale_Mode, ""}}
	if options.scale_mode == .Pixel_Perfect &&
	   (options.ui_scale < 1 ||
			   math.floor(options.ui_scale) !=
				   options.ui_scale) {return -1, {.Unsupported_Scale_Mode, ""}}
	if !finite_nonnegative(options.drawable.w) ||
	   !finite_nonnegative(options.drawable.h) ||
	   !finite_nonnegative(options.drawable.w / options.ui_scale) ||
	   !finite_nonnegative(options.drawable.h / options.ui_scale) {return -1, {.Invalid_Size, ""}}
	if r, ok := options.safe_area.?; ok {
		if !finite_nonnegative(r.x) ||
		   !finite_nonnegative(r.y) ||
		   !finite_nonnegative(r.w) ||
		   !finite_nonnegative(r.h) ||
		   !finite(r.x + r.w) ||
		   !finite(r.y + r.h) ||
		   r.x + r.w > options.drawable.w ||
		   r.y + r.h > options.drawable.h {return -1, {.Invalid_Safe_Area, ""}}
	}
	root := -1
	for node, i in nodes {
		if node.id == "" {return -1, {.Invalid_ID, node.id}}
		role := layout_role(nodes, i)
		for previous in nodes[:i] {if previous.id == node.id {return -1, {.Duplicate_ID, node.id}}}
		l, ok := node.layout.?
		if !ok ||
		   node.role < .Column ||
		   node.role > .Content {return -1, {.Invalid_Layout, node.id}}
		if !valid_axis(l.x) || !valid_axis(l.y) {return -1, {.Invalid_Layout, node.id}}
		if l.align < .Start ||
		   l.align > .Stretch ||
		   l.justify < .Start ||
		   l.justify > .SpaceBetween ||
		   l.overflow < .Clip ||
		   l.overflow > .Visible {return -1, {.Invalid_Layout, node.id}}
		if a, has_align := l.align_self.?;
		   has_align {if a < .Start || a > .Stretch {return -1, {.Invalid_Layout, node.id}}}
		if (role == .Stack || role == .Absolute || !container_role(role)) &&
		   (l.gap != 0 || l.justify != .Start) {return -1, {.Invalid_Layout, node.id}}
		if node.role == .Grid && l.justify != .Start {return -1, {.Invalid_Layout, node.id}}
		if node.parent == "" &&
		   (l.grow != 0 || l.shrink != 0) {return -1, {.Invalid_Layout, node.id}}
		if node.role == .Grid {
			if len(l.rows) == 0 || len(l.columns) == 0 {return -1, {.Invalid_Grid, node.id}}
			for tracks in ([][]Track{l.rows, l.columns}) {for track in tracks {
					if track.mode < .Fixed ||
					   track.mode > .Fill ||
					   !valid_axis({value = track.value, min = track.min, max = track.max}) ||
					   (track.mode == .Fill &&
							   track.value <= 0) {return -1, {.Invalid_Grid, node.id}}
				}}
		} else if len(l.rows) != 0 || len(l.columns) != 0 {return -1, {.Invalid_Layout, node.id}}
		for v in ([11]f64{l.padding.left, l.padding.top, l.padding.right, l.padding.bottom, l.margin.left, l.margin.top, l.margin.right, l.margin.bottom, l.gap, l.grow, l.shrink}) {if !finite_nonnegative(v) {return -1, {.Invalid_Layout, node.id}}}
		for a in 0 ..< 2 {if !finite_nonnegative(l.anchor[a]) || l.anchor[a] > 1 || !finite_nonnegative(l.pivot[a]) || l.pivot[a] > 1 || !finite(l.offset[a]) {return -1, {.Invalid_Layout, node.id}}}
		if node.parent == "" {if root >= 0 {return -1, {.Invalid_Tree, node.id}}; root = i}
	}
	if root < 0 {return -1, {.Invalid_Tree, ""}}
	for node, i in nodes {
		if node.parent == "" {continue}
		parent := node_index(nodes, node.parent)
		if parent < 0 {return -1, {.Missing_Parent, node.id}}
		if !container_role(layout_role(nodes, parent)) {return -1, {.Invalid_Tree, node.id}}
		l, _ := node.layout.?
		if nodes[parent].role == .Grid {
			p, _ := nodes[parent].layout.?
			if l.row < 0 ||
			   l.column < 0 ||
			   l.row >= len(p.rows) ||
			   l.column >= len(p.columns) {return -1, {.Invalid_Grid, node.id}}
		} else if l.row != 0 || l.column != 0 {return -1, {.Invalid_Layout, node.id}}
		if layout_role(nodes, parent) != .Row &&
		   layout_role(nodes, parent) != .Column &&
		   (l.grow != 0 || l.shrink != 0) {return -1, {.Invalid_Layout, node.id}}
		ancestor := i
		for step in 0 ..= len(nodes) {
			if step == len(nodes) {return -1, {.Cycle, node.id}}
			if nodes[ancestor].parent == "" {break}
			ancestor = node_index(nodes, nodes[ancestor].parent)
			if ancestor < 0 {return -1, {.Missing_Parent, node.id}}
		}
	}
	return root, {}
}

axis_limit :: proc(a: Axis_Size, value: f64) -> f64 {
	result := max(a.min, value)
	if upper, ok := a.max.?; ok {result = min(result, upper)}
	return result
}
axis_resolve :: proc(a: Axis_Size, natural, available: f64, measuring := false) -> f64 {
	value := natural
	switch a.mode {
	case .Content:
	case .Fixed:
		value = a.value
	case .Fill:
		value = available
	case .Percent:
		value = available * a.value
	}
	if measuring && (a.mode == .Fill || a.mode == .Percent) {value = a.min}
	return axis_limit(a, value)
}
layout_measure :: proc(
	nodes: []Node,
	children: [][dynamic]int,
	index: int,
	sizes: []Extent,
	metrics: Layout_Metrics,
	allocator: mem.Allocator,
) -> Update_Error {
	node := nodes[index]; l, _ := node.layout.?
	role := layout_role(nodes, index)
	size: Extent
	if role == .Content || (role == .Box && l.metric_id != "") {
		if metrics.intrinsic == nil {return {.Metrics_Failed, node.id}}
		size_value, ok := metrics.intrinsic(node.id, metrics.user)
		size = size_value
		if !ok ||
		   !finite_nonnegative(size.w) ||
		   !finite_nonnegative(size.h) {return {.Metrics_Failed, node.id}}
	}
	count := 0
	for i in children[index] {
		child := nodes[i]
		err := layout_measure(nodes, children, i, sizes, metrics, allocator)
		if err.code != .None {return err}
		if !child.visible {continue}
		c, _ := child.layout.?
		w := axis_resolve(c.x, sizes[i].w, 0, true) + c.margin.left + c.margin.right
		h := axis_resolve(c.y, sizes[i].h, 0, true) + c.margin.top + c.margin.bottom
		if role == .Row {if count > 0 {size.w += l.gap}; size.w += w; size.h = max(size.h, h)}
		if role == .Stack {size.w = max(size.w, w); size.h = max(size.h, h)}
		if role == .Column {if count > 0 {size.h += l.gap}; size.h += h; size.w = max(size.w, w)}
		count += 1
	}
	if node.role == .Grid {
		columns, co := try_grid_tracks(
			nodes,
			children,
			index,
			sizes,
			l.columns,
			true,
			0,
			false,
			allocator,
		)
		defer delete(columns, allocator)
		if !co {return {.Allocation, node.id}}
		rows, ro := try_grid_tracks(
			nodes,
			children,
			index,
			sizes,
			l.rows,
			false,
			0,
			false,
			allocator,
		)
		defer delete(rows, allocator)
		if !ro {return {.Allocation, node.id}}
		for value in columns {size.w += value}
		for value in rows {size.h += value}
		size.w +=
			l.gap * f64(max(0, len(columns) - 1)); size.h += l.gap * f64(max(0, len(rows) - 1))
	}
	sizes[index] = {
		size.w + l.padding.left + l.padding.right,
		size.h + l.padding.top + l.padding.bottom,
	}
	if !finite_nonnegative(sizes[index].w) ||
	   !finite_nonnegative(sizes[index].h) {return {.Invalid_Size, node.id}}
	return {}
}
layout_arrange :: proc(
	frame: ^Frame,
	nodes: []Node,
	children: [][dynamic]int,
	index: int,
	sizes: []Extent,
	bounds, inherited: Rect,
	enabled, visible: bool,
	cursor: ^int,
) {
	if frame.allocation_failed {return}
	node := nodes[index]; l, _ := node.layout.?
	role := layout_role(nodes, index)
	b := bounds
	content := Rect {
		b.x + l.padding.left,
		b.y + l.padding.top,
		max(0, b.w - l.padding.left - l.padding.right),
		max(0, b.h - l.padding.top - l.padding.bottom),
	}
	r := Resolved_Node {
		description = {},
		bounds      = snap(b, frame.ui_scale),
		content     = snap(content, frame.ui_scale),
		paint_clip  = intersection(inherited, snap(b, frame.ui_scale)),
		clip        = intersection(inherited, snap(content, frame.ui_scale)),
		measured    = {
			max(0, sizes[index].w - l.padding.left - l.padding.right),
			max(0, sizes[index].h - l.padding.top - l.padding.bottom),
		},
		enabled     = enabled && node.enabled,
		visible     = visible && node.visible,
	}
	description, de := try_clone_description(node, frame.allocator)
	if de != nil {frame.allocation_failed = true; return}
	r.description = description
	// Install ownership before any later fallible arrangement work.
	frame.nodes[cursor^] = r
	owner := &frame.nodes[cursor^]
	if r.visible {
		if l.padding.left + l.padding.right > b.w ||
		   l.padding.top + l.padding.bottom >
			   b.h {layout_diagnostic(frame, .Container_Overflow, r.description.id, {l.padding.left + l.padding.right, l.padding.top + l.padding.bottom}, {b.w, b.h})}
		if role == .Content &&
		   (r.measured.w > content.w ||
				   r.measured.h >
					   content.h) {layout_diagnostic(frame, .Content_Overflow, r.description.id, r.measured, {content.w, content.h})}
	}
	if node.role == .Grid {
		ok: bool
		r.columns, ok = try_grid_tracks(
			nodes,
			children,
			index,
			sizes,
			l.columns,
			true,
			content.w,
			true,
			frame.allocator,
		)
		owner.columns = r.columns
		if !ok {frame.allocation_failed = true; return}
		r.rows, ok = try_grid_tracks(
			nodes,
			children,
			index,
			sizes,
			l.rows,
			false,
			content.h,
			true,
			frame.allocator,
		)
		owner.rows = r.rows
		if !ok {frame.allocation_failed = true; return}
		// Tracks and their gaps occupy space even when no child occupies a cell.
		// Preserve the resolved sizes: Grid never auto-shrinks a track deficit.
		required := Extent{l.gap * f64(len(r.columns) - 1), l.gap * f64(len(r.rows) - 1)}
		for value in r.columns {required.w += value}
		for value in r.rows {required.h += value}
		if r.visible && (required.w > content.w + 1e-9 || required.h > content.h + 1e-9) {
			layout_diagnostic(
				frame,
				.Container_Overflow,
				r.description.id,
				required,
				{content.w, content.h},
			)
		}
	}
	frame.nodes[cursor^] = r
	cursor^ += 1
	x, y := content.x, content.y
	main, me := make([]f64, len(nodes), frame.allocator)
	defer delete(main, frame.allocator)
	if me != nil {frame.allocation_failed = true; return}
	weights, we := make([]f64, len(nodes), frame.allocator)
	defer delete(weights, frame.allocator)
	if we != nil {frame.allocation_failed = true; return}
	limits, le := make([]Axis_Size, len(nodes), frame.allocator)
	defer delete(limits, frame.allocator)
	if le != nil {frame.allocation_failed = true; return}
	flow := role == .Row || role == .Column
	remaining := content.w
	if role == .Column {remaining = content.h}
	count := 0
	if flow {
		for i in children[index] {
			child := nodes[i]
			if !child.visible {continue}
			c, _ := child.layout.?
			a, natural, margins, available :=
				c.x, sizes[i].w, c.margin.left + c.margin.right, content.w
			if role ==
			   .Column {a, natural, margins, available = c.y, sizes[i].h, c.margin.top + c.margin.bottom, content.h}
			base := axis_resolve(a, natural, available)
			if a.mode == .Fill {base = axis_limit(a, 0)}
			main[i], limits[i] = base, a
			remaining -= base + margins
			if count > 0 {remaining -= l.gap}
			count += 1
		}
		for i in children[index] {
			child := nodes[i]
			if !child.visible {continue}
			c, _ := child.layout.?
			if remaining >=
			   0 {weights[i] = c.grow; if limits[i].mode == .Fill && weights[i] == 0 {weights[i] = 1}} else {weights[i] = c.shrink * main[i]}
		}
		remaining = distribute(main, weights, limits, remaining)
		if remaining > 0 {
			offset: f64
			if l.justify == .Center {offset = remaining / 2}
			if l.justify == .End {offset = remaining}
			if role == .Row {x += offset} else {y += offset}
		}
	}
	gap := l.gap
	if flow &&
	   l.justify == .SpaceBetween &&
	   count > 1 &&
	   remaining > 0 {gap += remaining / f64(count - 1)}
	child_clip := inherited
	if l.overflow == .Clip {child_clip = r.clip}
	for i in children[index] {
		child := nodes[i]
		c, _ := child.layout.?
		slot := content
		if node.role == .Grid {
			for value, j in r.columns {if j < c.column {slot.x += value + l.gap}}
			for value, j in r.rows {if j < c.row {slot.y += value + l.gap}}
			slot.w, slot.h = r.columns[c.column], r.rows[c.row]
		}
		w := axis_resolve(c.x, sizes[i].w, slot.w)
		h := axis_resolve(c.y, sizes[i].h, slot.h)
		if c.x.mode == .Fill {w = axis_limit(c.x, max(0, slot.w - c.margin.left - c.margin.right))}
		if c.y.mode == .Fill {h = axis_limit(c.y, max(0, slot.h - c.margin.top - c.margin.bottom))}
		cx, cy := x + c.margin.left, y + c.margin.top
		if node.role == .Grid {cx, cy = slot.x + c.margin.left, slot.y + c.margin.top}
		if flow && child.visible {if role == .Row {w = main[i]} else {h = main[i]}}
		align := l.align
		if a, ok := c.align_self.?; ok {align = a}
		if node.role == .Grid {
			cx += align_offset(align, slot.w - w - c.margin.left - c.margin.right)
			cy += align_offset(align, slot.h - h - c.margin.top - c.margin.bottom)
		}
		if role == .Stack ||
		   role ==
			   .Column {cx += align_offset(align, content.w - w - c.margin.left - c.margin.right)}
		if role == .Stack ||
		   role == .Row {cy += align_offset(align, content.h - h - c.margin.top - c.margin.bottom)}
		if node.role == .Absolute {
			cx =
				content.x +
				c.anchor[0] * content.w +
				c.offset[0] -
				c.pivot[0] * (w + c.margin.left + c.margin.right) +
				c.margin.left
			cy =
				content.y +
				c.anchor[1] * content.h +
				c.offset[1] -
				c.pivot[1] * (h + c.margin.top + c.margin.bottom) +
				c.margin.top
		}
		if r.visible && child.visible {
			if (l.x.mode == .Content && (c.x.mode == .Fill || c.x.mode == .Percent)) ||
			   (l.y.mode == .Content &&
					   (c.y.mode == .Fill ||
							   c.y.mode ==
								   .Percent)) {layout_diagnostic(frame, .Relative_In_Content, child.id, {w, h}, {slot.w, slot.h})}
			horizontal_overflow :=
				cx - c.margin.left < content.x ||
				cx + w + c.margin.right > content.x + content.w + 1e-9
			vertical_overflow :=
				cy - c.margin.top < content.y ||
				cy + h + c.margin.bottom > content.y + content.h + 1e-9
			if horizontal_overflow || vertical_overflow {
				layout_diagnostic(
					frame,
					.Container_Overflow,
					child.id,
					{w + c.margin.left + c.margin.right, h + c.margin.top + c.margin.bottom},
					{content.w, content.h},
				)
			}
		}
		layout_arrange(
			frame,
			nodes,
			children,
			i,
			sizes,
			{cx, cy, w, h},
			child_clip,
			r.enabled,
			r.visible,
			cursor,
		)
		if child.visible {if role == .Row {x += w + c.margin.left + c.margin.right + gap}; if role == .Column {y += h + c.margin.top + c.margin.bottom + gap}}
	}
}

layout_diagnostic :: proc(
	frame: ^Frame,
	kind: Diagnostic_Kind,
	id: string,
	required, available: Extent,
) {
	// Resolve IDs after arrangement to bind diagnostics to owned descriptions.
	if _, e := append(&frame.diagnostics, Diagnostic{kind, id, frame.id, required, available});
	   e != nil {frame.allocation_failed = true}
}

try_grid_tracks :: proc(
	nodes: []Node,
	children: [][dynamic]int,
	index: int,
	sizes: []Extent,
	tracks: []Track,
	horizontal: bool,
	available: f64,
	arrange: bool,
	allocator: mem.Allocator,
) -> (
	[]f64,
	bool,
) {
	values, ve := make([]f64, len(tracks), allocator)
	if ve != nil {return nil, false}
	complete := false
	defer {if !complete {delete(values, allocator)}}
	weights, we := make([]f64, len(tracks), allocator); defer delete(weights, allocator)
	if we != nil {return nil, false}
	limits, le := make([]Axis_Size, len(tracks), allocator); defer delete(limits, allocator)
	if le != nil {return nil, false}
	l, _ := nodes[index].layout.?
	remaining := available - l.gap * f64(max(0, len(tracks) - 1))
	for track, j in tracks {
		a := Axis_Size {
			min = track.min,
			max = track.max,
		}
		value := track.min
		if track.mode == .Fixed {value = track.value}
		if track.mode == .Content {
			for i in children[index] {
				child := nodes[i]
				if !child.visible {continue}
				c, _ := child.layout.?
				cell :=
					c.row; axis := c.y; natural := sizes[i].h; margins := c.margin.top + c.margin.bottom
				if horizontal {cell, axis, natural, margins = c.column, c.x, sizes[i].w, c.margin.left + c.margin.right}
				if cell == j {value = max(value, axis_resolve(axis, natural, 0, true) + margins)}
			}
		}
		values[j] = axis_limit(a, value); limits[j] = a; remaining -= values[j]
		if track.mode == .Fill {weights[j] = track.value}
	}
	if arrange && remaining > 0 {distribute(values, weights, limits, remaining)}
	complete = true
	return values, true
}

align_offset :: proc(align: Align, surplus: f64) -> f64 {
	if surplus <= 0 {return 0}
	if align == .Center {return surplus / 2}
	if align == .End {return surplus}
	return 0
}

// Freeze at a limit and redistribute only among remaining original weights.
// Each nonfinal iteration freezes at least one participant: <= n+1 passes.
distribute :: proc(values, weights: []f64, limits: []Axis_Size, initial_remaining: f64) -> f64 {
	remaining := initial_remaining
	for _ in 0 ..= len(values) {
		total: f64
		for weight in weights {total += weight}
		if !finite(total) || !finite(remaining) {
			for &value in values {value = math.QNAN_F64}
			return math.QNAN_F64
		}
		if total <= 0 || remaining == 0 {break}
		frozen := false
		for value, i in values {
			if weights[i] <= 0 {continue}
			proposed := value + remaining * (weights[i] / total)
			if axis_limit(limits[i], proposed) != proposed {frozen = true}
		}
		if !frozen {
			for &value, i in values {if weights[i] > 0 {value += remaining * (weights[i] / total)}}
			return 0
		}
		old_remaining := remaining
		for &value, i in values {
			if weights[i] <= 0 {continue}
			proposed := value + old_remaining * (weights[i] / total)
			limited := axis_limit(limits[i], proposed)
			if limited != proposed {remaining -= limited - value; value = limited; weights[i] = 0}
		}
	}
	return remaining
}
