package ui_layers

import base "../ui_base"
import "core:mem"
import "core:strings"

try_copy_frame :: proc(source: ^Frame, a: mem.Allocator) -> (Frame, bool) {
	f, ok := clone_layers(source.layers, a); if !ok {return {}, false}
	complete := false; defer {if !complete {destroy_frame(&f)}}
	if !base.retain(source.stamp) {return {}, false}; f.stamp = source.stamp
	e: mem.Allocator_Error
	f.returns, e = make([]string, len(source.returns), a); if e != nil {return {}, false}
	for id, i in source.returns {f.returns[i], e = strings.clone(id, a); if e != nil {return {}, false}}
	f.paint = make([dynamic]Paint, 0, 0, a); f.groups = make([dynamic]Group, 0, 0, a)
	if _, pe := append(&f.paint, ..source.paint[:]); pe != nil {return {}, false}
	if _, ge := append(&f.groups, ..source.groups[:]); ge != nil {return {}, false}
	complete = true; return f, true
}
