package ui_transitions_inspect
import family ".."
import base "../../ui_base"
import common "../../ui_inspect"
import "core:mem"
Inspection :: family.Frame
capture :: proc(
	i: ^common.Inspection,
	f: ^family.Frame,
	a: mem.Allocator,
) -> (
	Inspection,
	common.Inspect_Error,
) {
	if f == nil || !f.bound || f.stamp != i.frame.stamp {return {}, .Metadata_Mismatch}
	r, ok := family.try_copy_frame(f, a); if !ok {return {}, .Allocation}; return r, .None
}
destroy :: family.destroy_frame
Transition_Inspection :: struct {
	transition_mode, reduced_motion: bool,
	frame_id, transition_version:    u64,
	transitions:                     []family.View,
	presences:                       []family.Presence,
}
inspect_transitions :: proc(i: ^Inspection, version: u64) -> Transition_Inspection {return {
		true,
		i.reduced_motion,
		i.stamp.attempt,
		version,
		i.tracks,
		i.presences,
	}}
Visual_View :: struct {
	node_id:         string,
	geometry:        base.Frozen_Geometry,
	input_available: bool,
}
inspect_visual :: proc(i: ^Inspection, id: string) -> (Visual_View, common.Inspect_Error) {
	for e in i.entries {if e.id == id {return {id, e.geometry, e.input_enabled}, .None}}
	return {}, .Not_Found
}
