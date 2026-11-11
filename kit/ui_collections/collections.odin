package ui_collections

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:math"
import "core:mem"
import "core:strings"

Rect :: base.Rect
Extent :: base.Extent
finite :: base.finite
finite_nonnegative :: base.finite_nonnegative
intersection :: base.intersection
Code :: interaction.Code
Error_Code :: enum {
	None,
	Invalid_ID,
	Duplicate_ID,
	Invalid_Size,
	Allocation,
	Stale,
	Exhausted,
	Binding,
}
Update_Error :: struct {
	code: Error_Code,
	id:   string,
}
Frame :: struct {
	bound:          bool,
	owner_gate:     Code,
	target_removed: bool,
	collections:    []Collection_State,
	nodes:          []Materialized,
	stamp:          base.Frame_Stamp,
	allocator:      mem.Allocator,
}
Materialized :: struct {
	geometry:                          base.Frozen_Geometry,
	description:                       layout.Node,
	item:                              Collection_Item,
	bounds, content, clip, paint_clip: Rect,
	visible, enabled:                  bool,
	availability:                      Code,
}
find :: proc(f: ^Frame, id: string) -> (^Materialized, Code) {
	for &n in f.nodes {if n.description.id == id {return &n, .Applied}}
	return nil, .Not_Found
}
destroy_frame :: proc(f: ^Frame) {
	for n in f.nodes {destroy_description(n.description, f.allocator)}
	delete(f.nodes, f.allocator)
	destroy_collections(f)
	base.release(f.stamp)
	f^ = {}
}

Collection_Mode :: enum {
	List,
	Grid,
}
Collection_Item :: struct {
	item_id, semantic_name: string,
	visible, enabled:       bool,
	disabled_reason:        string,
}
Collection_Description :: struct {
	id, scroll_id, content_id:  string,
	mode:                       Collection_Mode,
	items:                      []Collection_Item,
	selected_id:                string,
	data_revision, reset_epoch: u64,
	height, card_width, gap:    f64,
	overscan_rows:              int,
}
Collection_State :: struct {
	focus_id, focus_node_id, anchor_id:                               string,
	intra_offset:                                                     f64,
	data:                                                             ^Collection_Data, // Immutable, retained across scroll-only candidates and copies.
	description:                                                      Collection_Description,
	viewport:                                                         Rect,
	columns, rows, visible_count:                                     int,
	extent, offset:                                                   f64,
	visible_start, visible_end, materialized_start, materialized_end: int,
	materialized_count, text_count:                                   int,
	metadata_items_copied, metrics_calls:                             int,
}

Collection_Item_View :: struct {
	item:                                Collection_Item,
	logical_ordinal, visible_ordinal:    int,
	selected, materialized, in_viewport: bool,
	node_index:                          Maybe(int),
	bounds:                              Maybe(Rect),
}

inspect_collection :: proc(frame: ^Frame, collection_id: string) -> (^Collection_State, bool) {
	for &s in frame.collections {if s.description.id == collection_id {return &s, true}}
	return nil, false
}

lookup_collection_item :: proc(
	frame: ^Frame,
	collection_id, item_id: string,
) -> (
	Collection_Item_View,
	Code,
) {
	s, ok := inspect_collection(frame, collection_id)
	if !ok {return {}, .Not_Found}
	i, known := s.data.index[item_id]
	if !known {return {}, .Not_Found}
	v := Collection_Item_View {
		item            = s.data.items[i],
		logical_ordinal = i,
		visible_ordinal = s.data.ordinals[i],
		selected        = s.description.selected_id == item_id,
	}
	if v.visible_ordinal >= s.materialized_start && v.visible_ordinal < s.materialized_end {
		index := v.visible_ordinal - s.materialized_start
		if index < 0 || index >= len(frame.nodes) {return v, .Applied}
		n := &frame.nodes[index]
		v.materialized = true
		v.in_viewport = n.clip.w > 0 && n.clip.h > 0
		v.bounds, v.node_index = n.bounds, index
	}
	return v, .Applied
}

@(private)
Collection_Data :: struct {
	allocator:                 mem.Allocator,
	references:                int,
	revision:                  u64,
	id, scroll_id, content_id: string,
	items:                     []Collection_Item,
	index:                     map[string]int,
	visible:                   []int,
	ordinals:                  []int,
}

@(private)
release_collection_data :: proc(data: ^Collection_Data) {
	if data == nil {return}
	data.references -= 1
	if data.references != 0 {return}
	a := data.allocator
	for item in data.items {
		delete(item.item_id, a); delete(item.semantic_name, a); delete(item.disabled_reason, a)
	}
	delete(data.items, a); delete(data.visible, a); delete(data.ordinals, a); delete(data.index)
	delete(data.id, a); delete(data.scroll_id, a); delete(data.content_id, a)
	free(data, a)
}

destroy_collections :: proc(frame: ^Frame) {
	for s in frame.collections {
		delete(s.focus_node_id, frame.allocator)
		delete(s.description.selected_id, frame.allocator)
		release_collection_data(s.data)
	}
	delete(frame.collections, frame.allocator)
}

try_copy_frame :: proc(source: ^Frame, allocator := context.allocator) -> (Frame, bool) {
	f := Frame {
		allocator      = allocator,
		bound          = source.bound,
		owner_gate     = source.owner_gate,
		target_removed = source.target_removed,
	}
	complete := false; defer {if !complete {destroy_frame(&f)}}
	if source.stamp.lifetime !=
	   nil {if !base.retain(source.stamp) {return {}, false}; f.stamp = source.stamp}
	ae: mem.Allocator_Error
	f.collections, ae = make(
		[]Collection_State,
		len(source.collections),
		allocator,
	); if ae != nil {return {}, false}
	for s, index in source.collections {
		if s.data == nil || s.data.references == max(int) {return {}, false}
		r := &f.collections[index]; r^ = s
		r.focus_node_id, r.description.selected_id = "", ""
		s.data.references += 1
		r.focus_node_id, ae = strings.clone(
			s.focus_node_id,
			allocator,
		); if ae != nil {return {}, false}
		r.description.selected_id, ae = strings.clone(
			s.description.selected_id,
			allocator,
		); if ae != nil {return {}, false}
	}
	f.nodes, ae = make(
		[]Materialized,
		len(source.nodes),
		allocator,
	); if ae != nil {return {}, false}
	for n, index in source.nodes {
		f.nodes[index] = n
		f.nodes[index].description = {}
		description, de := layout.try_clone_description(
			n.description,
			allocator,
		); if de != nil {return {}, false}
		f.nodes[index].description = description
	}
	complete = true
	return f, true
}

// Candidate-only geometry/materialization seam. Does not publish a Context.
prepare_collection :: proc(
	d: Collection_Description,
	viewport: Rect,
	offset: f64,
	allocator := context.allocator,
	previous: ^Frame = nil,
) -> (
	Frame,
	Update_Error,
) {
	f, e := prepare_internal(d, viewport, offset, allocator, previous)
	if e.code != .None {destroy_frame(&f); return {}, e}
	return f, e
}
@(private)
prepare_internal :: proc(
	d: Collection_Description,
	viewport: Rect,
	offset: f64,
	allocator := context.allocator,
	previous: ^Frame = nil,
) -> (
	Frame,
	Update_Error,
) {
	f := Frame {
		allocator = allocator,
	}
	if d.id == "" || d.scroll_id == "" || d.content_id == "" {return f, {.Invalid_ID, d.id}}
	if d.mode < .List ||
	   d.mode > .Grid ||
	   !finite(d.height) ||
	   d.height <= 0 ||
	   !finite(d.card_width) ||
	   d.card_width < 0 ||
	   (d.mode == .Grid && d.card_width == 0) ||
	   !finite(d.gap) ||
	   d.gap < 0 ||
	   d.overscan_rows < 0 ||
	   d.overscan_rows > 8 ||
	   !finite(viewport.x) ||
	   !finite(viewport.y) ||
	   !finite_nonnegative(viewport.w) ||
	   !finite_nonnegative(viewport.h) ||
	   !finite(viewport.x + viewport.w) ||
	   !finite(viewport.y + viewport.h) ||
	   !finite(offset) ||
	   !finite(d.height + d.gap) ||
	   !finite(d.card_width + d.gap) ||
	   !finite(viewport.w + d.gap) {return f, {.Invalid_Size, d.id}}
	data: ^Collection_Data
	if previous != nil {
		if old, ok := inspect_collection(previous, d.id);
		   ok &&
		   old.data.revision == d.data_revision &&
		   old.data.scroll_id == d.scroll_id &&
		   old.data.content_id == d.content_id {
			data = old.data
			if data.references == max(int) {return f, {.Allocation, d.id}}
			data.references += 1
		}
	}
	copied := 0
	ae: mem.Allocator_Error
	fresh := data == nil
	if data == nil {
		data, ae = new(Collection_Data, allocator); if ae != nil {return f, {.Allocation, d.id}}
		data.allocator, data.references, data.revision = allocator, 1, d.data_revision
		copied = len(d.items)
	}
	// Any failure after partial metadata acquisition releases it. No Context is touched.
	keep_data := false
	defer {if !keep_data {release_collection_data(data)}}
	if fresh {
		data.id, ae = strings.clone(d.id, allocator); if ae != nil {return f, {.Allocation, d.id}}
		data.scroll_id, ae = strings.clone(
			d.scroll_id,
			allocator,
		); if ae != nil {return f, {.Allocation, d.id}}
		data.content_id, ae = strings.clone(
			d.content_id,
			allocator,
		); if ae != nil {return f, {.Allocation, d.id}}
		data.items, ae = make(
			[]Collection_Item,
			len(d.items),
			allocator,
		); if ae != nil {return f, {.Allocation, d.id}}
		data.index, ae = make(
			map[string]int,
			len(d.items),
			allocator,
		); if ae != nil {return f, {.Allocation, d.id}}
		data.ordinals, ae = make(
			[]int,
			len(d.items),
			allocator,
		); if ae != nil {return f, {.Allocation, d.id}}
		n := 0
		for item in d.items {if item.visible {n += 1}}
		data.visible, ae = make([]int, n, allocator); if ae != nil {return f, {.Allocation, d.id}}
		cursor := 0
		for item, i in d.items {
			if item.item_id == "" {return f, {.Invalid_ID, d.id}}
			if _, exists := data.index[item.item_id]; exists {return f, {.Duplicate_ID, d.id}}
			data.items[i].visible, data.items[i].enabled = item.visible, item.enabled
			data.items[i].item_id, ae = strings.clone(
				item.item_id,
				allocator,
			); if ae != nil {return f, {.Allocation, d.id}}
			data.items[i].semantic_name, ae = strings.clone(
				item.semantic_name,
				allocator,
			); if ae != nil {return f, {.Allocation, d.id}}
			data.items[i].disabled_reason, ae = strings.clone(
				item.disabled_reason,
				allocator,
			); if ae != nil {return f, {.Allocation, d.id}}
			data.index[data.items[i].item_id] = i
			data.ordinals[i] = -1
			if item.visible {data.ordinals[i] = cursor; data.visible[cursor] = i; cursor += 1}
		}
	}
	n := len(data.visible)
	if d.selected_id !=
	   "" {if _, exists := data.index[d.selected_id]; !exists {return f, {.Invalid_ID, d.id}}}
	s := Collection_State {
		data                  = data,
		description           = d,
		viewport              = viewport,
		visible_count         = n,
		columns               = 1,
		metadata_items_copied = copied,
	}
	s.description.id, s.description.scroll_id, s.description.content_id =
		data.id, data.scroll_id, data.content_id
	s.description.items = data.items
	stride := d.height + d.gap
	if d.mode == .Grid {
		columns := math.floor((viewport.w + d.gap) / (d.card_width + d.gap))
		if !finite(columns) || columns >= f64(max(int)) {return f, {.Invalid_Size, d.id}}
		s.columns = max(1, int(columns))
	}
	s.rows = n / s.columns
	if n % s.columns != 0 {s.rows += 1}
	if s.rows > 0 {s.extent = f64(s.rows) * d.height + f64(s.rows - 1) * d.gap}
	if !finite(s.extent) || f64(n) > 9007199254740991 {return f, {.Invalid_Size, d.id}}
	s.offset = clamp(offset, 0, max(0, s.extent - viewport.h))
	if !finite(s.offset + viewport.h) {return f, {.Invalid_Size, d.id}}
	if viewport.h > 0 && viewport.w > 0 && n > 0 {
		first := int(min(f64(s.rows), math.floor(s.offset / stride)))
		if first < s.rows && f64(first) * stride + d.height <= s.offset {first += 1}
		end := int(min(f64(s.rows), math.ceil((s.offset + viewport.h) / stride)))
		s.visible_start, s.visible_end =
			collection_row_ordinal(first, s.columns, n), collection_row_ordinal(end, s.columns, n)
		if first < end {
			s.materialized_start = max(0, first - d.overscan_rows) * s.columns
			s.materialized_end = collection_row_ordinal(
				end + min(d.overscan_rows, s.rows - end),
				s.columns,
				n,
			)
		}
	}
	s.materialized_count = s.materialized_end - s.materialized_start
	s.text_count = s.materialized_count
	f.collections, ae = make(
		[]Collection_State,
		1,
		allocator,
	); if ae != nil {return f, {.Allocation, d.id}}
	s.description.selected_id = ""
	f.collections[0] = s
	keep_data = true
	f.collections[0].description.selected_id, ae = strings.clone(
		d.selected_id,
		allocator,
	); if ae != nil {return f, {.Allocation, d.id}}
	f.nodes, ae = make(
		[]Materialized,
		s.materialized_count,
		allocator,
	); if ae != nil {return f, {.Allocation, d.id}}
	for ordinal := s.materialized_start; ordinal < s.materialized_end; ordinal += 1 {
		item := data.items[data.visible[ordinal]]
		width := viewport.w
		if d.mode == .Grid {width = d.card_width}
		bounds := Rect {
			viewport.x,
			viewport.y + f64(ordinal / s.columns) * stride - s.offset,
			width,
			d.height,
		}
		if d.mode == .Grid {bounds.x += f64(ordinal % s.columns) * (d.card_width + d.gap)}
		if !finite(bounds.x) ||
		   !finite(bounds.y) ||
		   !finite(bounds.x + bounds.w) ||
		   !finite(bounds.y + bounds.h) {
			destroy_frame(&f)
			return Frame{allocator = allocator}, {.Invalid_Size, d.id}
		}
		node := &f.nodes[ordinal - s.materialized_start]
		node.description = layout.Node {
			role    = .Content,
			visible = true,
			enabled = item.enabled,
		}
		node.description.id, ae = item_node_id(
			d.id,
			item.item_id,
			allocator,
		); if ae != nil {return f, {.Allocation, d.id}}
		node.description.parent, ae = strings.clone(
			d.content_id,
			allocator,
		); if ae != nil {return f, {.Allocation, d.id}}
		node.item = item
		node.bounds, node.content = bounds, bounds
		node.clip, node.paint_clip = intersection(viewport, bounds), intersection(viewport, bounds)
		node.visible, node.enabled = true, item.enabled
		node.availability = .Applied
		if node.clip.w <= 0 || node.clip.h <= 0 {node.availability = .Not_Visible
		} else if !item.enabled {node.availability = .Disabled}
	}
	return f, {}
}

@(private)
collection_row_ordinal :: proc(row, columns, count: int) -> int {
	// Avoid overflowing the multiplication for the final partial row.
	if row > count / columns {return count}
	return min(count, row * columns)
}
