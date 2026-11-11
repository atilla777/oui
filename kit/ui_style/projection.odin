package ui_style

import base "../ui_base"
import layout "../ui_layout"
import "core:mem"
import "core:slice"
import "core:strings"

Description :: struct {
	id:         string,
	role:       Role,
	appearance: Appearance,
	visual:     Visual,
	states:     State_Mask,
}
Presentation :: struct {
	id:                                      string,
	computed:                                Computed_Appearance,
	states:                                  State_Mask,
	visual:                                  Visual,
	image:                                   Maybe(Image_Metadata),
	focus_indicator:                         bool,
	focus_color:                             Color,
	focus_width, radius, border_width:       f64,
	area, content, paint_clip, content_clip: Rect,
	drawable:                                bool,
	fallback:                                Maybe(Rect),
	patches:                                 []Image_Patch,
}
Diagnostic_Kind :: enum {
	Missing_Style,
	Missing_Token,
	Missing_Image,
	Invalid_Metadata,
	Below_Slice_Minimum,
	Patch_Limit,
}
Diagnostic :: struct {
	kind:          Diagnostic_Kind,
	id, reference: string,
}
Frame :: struct {
	drawable:                          base.Extent,
	ui_scale:                          f64,
	storage:                           ^mem.Rollback_Stack,
	presentation:                      []Presentation,
	diagnostics:                       [dynamic]Diagnostic,
	theme_revision, resource_revision: string,
	stamp:                             base.Frame_Stamp,
	allocator:                         mem.Allocator,
}
Error_Code :: enum {
	None,
	Allocation,
	Invalid_Appearance,
	Not_Found,
}
Error :: struct {
	code: Error_Code,
	id:   string,
}
prepare :: proc(
	geometry: ^layout.Frame,
	descriptions: []Description,
	theme: Theme,
	resources: Resource_Catalog,
	a: mem.Allocator,
	scale_mode := Scale_Mode.Normal,
) -> (
	Frame,
	Error,
) {
	for token, i in theme.tokens {
		if token.id == "" {return {}, {.Invalid_Appearance, ""}}
		for prior in theme.tokens[:i] {if prior.id == token.id {return {}, {.Invalid_Appearance, token.id}}}
		switch v in token.value {
		case Color:
		case Font_ID:
			if v.id == "" {return {}, {.Invalid_Appearance, token.id}}
		case Image_ID:
			if v.id == "" {return {}, {.Invalid_Appearance, token.id}}
		case f64, Token_Ref, Image_Off:
			return {}, {.Invalid_Appearance, token.id}
		case:
			return {}, {.Invalid_Appearance, token.id}
		}
	}
	for image, i in resources.images {
		if image.id == "" {return {}, {.Invalid_Appearance, ""}}
		for prior in resources.images[:i] {if prior.id == image.id {return {}, {.Invalid_Appearance, image.id}}}
	}
	f, fe := new_frame(a, geometry.stamp)
	if fe != .None {return {}, {fe, ""}}
	f.drawable, f.ui_scale = geometry.drawable, geometry.ui_scale
	complete := false; defer {if !complete {destroy_frame(&f)}}
	ca := mem.rollback_stack_allocator(f.storage)
	e: mem.Allocator_Error
	f.theme_revision, e = strings.clone(
		theme.revision,
		ca,
	); if e != nil {return {}, {.Allocation, ""}}
	f.resource_revision, e = strings.clone(
		resources.revision,
		ca,
	); if e != nil {return {}, {.Allocation, ""}}
	f.presentation, e = make(
		[]Presentation,
		len(descriptions),
		ca,
	); if e != nil {return {}, {.Allocation, ""}}
	f.diagnostics = make([dynamic]Diagnostic, 0, 0, ca)
	for s in theme.roles {if !valid_state_style(s.style, theme) {return {}, {.Invalid_Appearance, ""}}}
	for s in theme.styles {if !valid_state_style(s.style, theme) {return {}, {.Invalid_Appearance, ""}}}
	for d, i in descriptions {
		for prior in descriptions[:i] {if prior.id == d.id {return {}, {.Invalid_Appearance, d.id}}}
		n, ok := layout.find(geometry, d.id)
		if !ok {return {}, {.Not_Found, d.id}}
		if !valid_state_style(d.appearance.local, theme) ||
		   !valid_visual(d.visual, n.description.role) {return {}, {.Invalid_Appearance, d.id}}
		states := d.states
		if !n.enabled {states += {.Disabled}}
		paint := resolve_appearance(d.role, d.appearance, theme, states)
		p := &f.presentation[i]
		p.id, e = strings.clone(d.id, ca); if e != nil {return {}, {.Allocation, d.id}}
		p.computed, e = clone_computed(paint, ca); if e != nil {return {}, {.Allocation, d.id}}
		p.states = states
		p.area, p.content, p.paint_clip, p.content_clip = n.bounds, n.content, n.paint_clip, n.clip
		limit := min(n.bounds.w, n.bounds.h) / 2
		p.radius, p.border_width =
			min(limit, paint[.Radius].value.(f64)), min(limit, paint[.Border_Width].value.(f64))
		if d.visual.kind != .Role &&
		   d.visual.kind !=
			   .Image {p.radius = min(min(n.content.w, n.content.h) / 2, paint[.Radius].value.(f64))}
		p.drawable = n.visible && n.paint_clip.w > 0 && n.paint_clip.h > 0
		p.focus_indicator = .Focused in states && .Disabled not_in states && n.enabled && n.visible
		if p.focus_indicator {
			p.focus_width = max(
				1,
				paint[.Focus_Width].value.(f64),
			); p.focus_color = paint[.Focus_Color].value.(Color)
			if p.focus_color[3] == 0 {p.focus_color = {255, 255, 255, 255}}
		}
		p.visual = d.visual
		p.visual.points, e = slice.clone(
			d.visual.points,
			ca,
		); if e != nil {return {}, {.Allocation, d.id}}
		if !diagnose_appearance(
			&f,
			d.id,
			d.appearance,
			d.role,
			theme,
			states,
		) {return {}, {.Allocation, d.id}}
		if image, has_image := paint[.Image].value.(Image_ID); has_image {
			found := false
			area := n.content
			for metadata in resources.images {if metadata.id == image.id {
					found = true
					if _, nine := metadata.nine_slice.?; nine {area = n.bounds}
					if !valid_image_metadata(metadata) {
						if !diagnose(
							&f,
							.Invalid_Metadata,
							d.id,
							image.id,
						) {return {}, {.Allocation, d.id}}
						break
					}
					if _, nine := metadata.nine_slice.?; nine {
						patches, result := nine_slice_patches(
							metadata,
							n.bounds,
							geometry.ui_scale,
							scale_mode,
							ca,
						)
						if result == .Allocation {return {}, {.Allocation, d.id}}
						if result == .Invalid_Scale {return {}, {.Invalid_Appearance, d.id}}
						if result != .Ok {
							kind := Diagnostic_Kind.Invalid_Metadata
							if result == .Below_Minimum {kind = .Below_Slice_Minimum}
							if result == .Patch_Limit {kind = .Patch_Limit}
							if !diagnose(&f, kind, d.id, image.id) {return {}, {.Allocation, d.id}}
							break
						}
						p.patches = patches
					} else if n.content.w > 0 && n.content.h > 0 {
						p.patches, e = make(
							[]Image_Patch,
							1,
							ca,
						); if e != nil {return {}, {.Allocation, d.id}}
						p.patches[0] = {{0, 0, metadata.source.w, metadata.source.h}, n.content}
					}
					owned :=
						metadata; owned.id, e = strings.clone(metadata.id, ca); if e != nil {return {}, {.Allocation, d.id}}
					p.image = owned
					break
				}}
			if !found {if !diagnose(&f, .Missing_Image, d.id, image.id) {return {}, {.Allocation, d.id}}}
			if _, has := p.image.?;
			   !has {p.fallback = area; p.computed[.Image].provenance.fallback = true}
		}
	}
	complete = true
	return f, {}
}

new_frame :: proc(a: mem.Allocator, stamp: base.Frame_Stamp) -> (Frame, Error_Code) {
	storage, e := new(mem.Rollback_Stack, a)
	if e != nil {return {}, .Allocation}
	storage.block_allocator = a
	if mem.rollback_stack_init_dynamic(storage, 4096, a) !=
	   nil {free(storage, a); return {}, .Allocation}
	f := Frame {
		storage   = storage,
		allocator = a,
	}
	if !base.retain(
		stamp,
	) {mem.rollback_stack_destroy(storage); free(storage, a); return {}, .Allocation}
	f.stamp = stamp
	return f, .None
}
destroy_frame :: proc(f: ^Frame) {
	base.release(f.stamp)
	if f.storage != nil {mem.rollback_stack_destroy(f.storage); free(f.storage, f.allocator)}
	f^ = {}
}
destroy_candidate :: destroy_frame
clone_value :: proc(v: Paint_Value, a: mem.Allocator) -> (Paint_Value, mem.Allocator_Error) {
	switch n in v {
	case Font_ID:
		id, e := strings.clone(n.id, a); return Font_ID{id}, e
	case Image_ID:
		id, e := strings.clone(n.id, a); return Image_ID{id}, e
	case Token_Ref:
		id, e := strings.clone(n.id, a); return Token_Ref{id}, e
	case Color, f64, Image_Off:
		return v, nil
	}
	return v, nil
}
clone_computed :: proc(
	paint: Computed_Appearance,
	a: mem.Allocator,
) -> (
	r: Computed_Appearance,
	e: mem.Allocator_Error,
) {
	r = paint
	for &p in r {
		p.value = clone_value(p.value, a) or_return
		p.provenance.style_id = strings.clone(p.provenance.style_id, a) or_return
		p.provenance.token_id = strings.clone(p.provenance.token_id, a) or_return
	}
	return r, nil
}
diagnose :: proc(f: ^Frame, kind: Diagnostic_Kind, id, reference: string) -> bool {
	a := mem.rollback_stack_allocator(f.storage)
	i, ie := strings.clone(id, a); if ie != nil {return false}
	r, re := strings.clone(reference, a); if re != nil {return false}
	_, e := append(&f.diagnostics, Diagnostic{kind, i, r})
	return e == nil
}
diagnose_state_style :: proc(
	f: ^Frame,
	id: string,
	style: State_Style,
	theme: Theme,
	states: State_Mask,
) -> bool {
	for state in Visual_State {
		if state != .Normal && state not_in states {continue}
		for d in style.states[state] {if ref, ok := d.value.(Token_Ref); ok {
				found := false
				for token in theme.tokens {if token.id == ref.id {found = true; break}}
				if !found {if !diagnose(f, .Missing_Token, id, ref.id) {return false}}
			}}
	}
	return true
}
diagnose_appearance :: proc(
	f: ^Frame,
	id: string,
	appearance: Appearance,
	role: Role,
	theme: Theme,
	states: State_Mask,
) -> bool {
	for e in theme.roles {if e.role == role {if !diagnose_state_style(f, id, e.style, theme, states) {return false}}}
	if appearance.style_id != "" {
		found := false
		for e in theme.styles {if e.id == appearance.style_id {found = true; if !diagnose_state_style(f, id, e.style, theme, states) {return false}; break}}
		if !found {if !diagnose(f, .Missing_Style, id, appearance.style_id) {return false}}
	}
	return diagnose_state_style(f, id, appearance.local, theme, states)
}
point_cross :: proc(a, b, c: [2]f64) -> f64 {return(
		(b[0] - a[0]) * (c[1] - a[1]) -
		(b[1] - a[1]) * (c[0] - a[0]) \
	)}
point_on_segment :: proc(a, b, p: [2]f64) -> bool {return(
		point_cross(a, b, p) == 0 &&
		p[0] >= min(a[0], b[0]) &&
		p[0] <= max(a[0], b[0]) &&
		p[1] >= min(a[1], b[1]) &&
		p[1] <= max(a[1], b[1]) \
	)}
segments_intersect :: proc(a, b, c, d: [2]f64) -> bool {
	x, y, z, w :=
		point_cross(a, b, c), point_cross(a, b, d), point_cross(c, d, a), point_cross(c, d, b)
	return(
		((x > 0 && y < 0 || x < 0 && y > 0) && (z > 0 && w < 0 || z < 0 && w > 0)) ||
		point_on_segment(a, b, c) ||
		point_on_segment(a, b, d) ||
		point_on_segment(c, d, a) ||
		point_on_segment(c, d, b) \
	)
}
valid_visual :: proc(v: Visual, kind: layout.Kind) -> bool {
	if v.kind < .Role || v.kind > .Image {return false}
	extent, has := v.intrinsic.?
	if has &&
	   (!finite_nonnegative(extent.w) ||
			   !finite_nonnegative(extent.h) ||
			   kind != .Box) {return false}
	if v.kind != .Role && (kind != .Box || !has) {return false}
	if v.kind != .Polygon && v.kind != .Triangle {return len(v.points) == 0}
	if len(v.points) < 3 || (v.kind == .Triangle && len(v.points) != 3) {return false}
	area: f64
	for p, i in v.points {
		if !finite_nonnegative(p[0]) ||
		   !finite_nonnegative(p[1]) ||
		   p[0] > 1 ||
		   p[1] > 1 {return false}
		for prior in v.points[:i] {if prior == p {return false}}
		next := v.points[(i + 1) % len(v.points)]; area += p[0] * next[1] - p[1] * next[0]
		for j in i + 1 ..< len(v.points) {
			if j == i + 1 || (i == 0 && j == len(v.points) - 1) {continue}
			if segments_intersect(
				p,
				next,
				v.points[j],
				v.points[(j + 1) % len(v.points)],
			) {return false}
		}
	}
	return area != 0
}
