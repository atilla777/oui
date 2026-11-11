package ui_style

import "core:mem"
import "core:slice"
import "core:strings"

try_copy_frame :: proc(source: ^Frame, allocator: mem.Allocator) -> (Frame, bool) {
	f, e := new_frame(allocator, source.stamp)
	if e != .None {return {}, false}
	f.drawable, f.ui_scale = source.drawable, source.ui_scale
	complete := false; defer {if !complete {destroy_frame(&f)}}
	a := mem.rollback_stack_allocator(f.storage)
	ae: mem.Allocator_Error
	f.theme_revision, ae = strings.clone(source.theme_revision, a); if ae != nil {return {}, false}
	f.resource_revision, ae = strings.clone(
		source.resource_revision,
		a,
	); if ae != nil {return {}, false}
	f.presentation, ae = make(
		[]Presentation,
		len(source.presentation),
		a,
	); if ae != nil {return {}, false}
	for p, i in source.presentation {
		f.presentation[i] = p
		r := &f.presentation[i]
		r.id, ae = strings.clone(p.id, a); if ae != nil {return {}, false}
		r.computed, ae = clone_computed(p.computed, a); if ae != nil {return {}, false}
		r.visual.points, ae = slice.clone(p.visual.points, a); if ae != nil {return {}, false}
		r.patches, ae = slice.clone(p.patches, a); if ae != nil {return {}, false}
		if image, has := p.image.?;
		   has {image.id, ae = strings.clone(image.id, a); if ae != nil {return {}, false}; r.image = image}
	}
	f.diagnostics = make([dynamic]Diagnostic, 0, 0, a)
	for d in source.diagnostics {if !diagnose(&f, d.kind, d.id, d.reference) {return {}, false}}
	complete = true
	return f, true
}
