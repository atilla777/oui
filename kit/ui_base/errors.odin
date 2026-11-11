package ui_base

import "core:mem"
import "core:strings"

Family :: enum {
	Publication,
	Layout,
	Interaction,
	Style,
	Text,
	Scroll,
	Controls,
	Hold,
	Layers,
}
Stage :: enum {
	Prepare,
	Copy,
	Validate,
	Commit,
	Dispatch,
}
// Borrowed error view; try_copy_error materializes any ID needed beyond input lifetime.
Error :: struct {
	family:        Family,
	stage:         Stage,
	code:          u32,
	existing_code: u32,
	id:            string,
	byte_offset:   int,
	allocator:     mem.Allocator,
}
try_copy_error :: proc(e: Error, a: mem.Allocator) -> (Error, bool) {
	id, error := strings.clone(e.id, a)
	if error != nil {return {}, false}
	r := e; r.id, r.allocator = id, a
	return r, true
}
destroy_error :: proc(e: ^Error) {if e.allocator.procedure != nil {delete(e.id, e.allocator)}; e^ =
		{}}
