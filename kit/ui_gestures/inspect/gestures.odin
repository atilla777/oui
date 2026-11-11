package ui_gestures_inspect
import family ".."
import common "../../ui_inspect"
import interaction "../../ui_interaction"
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
	if f == nil ||
	   f.stamp != i.frame.stamp ||
	   f.model_revision != i.published_revision {return {}, .Metadata_Mismatch}
	r, ok := family.try_copy_frame(f, a); if !ok {return {}, .Allocation}; return r, .None
}
destroy :: family.destroy_frame
Gesture_View :: struct {
	description:  family.Description,
	availability: interaction.Code,
	actions:      bit_set[family.Action_Kind],
	offset:       Maybe(f64),
}
inspect_gesture :: proc(
	i: ^Inspection,
	ready: bool,
	id: string,
) -> (
	Gesture_View,
	common.Inspect_Error,
) {
	v, found := family.find(i, id); if !found {return {}, .Not_Found}
	r := Gesture_View {
		description  = v.description,
		availability = v.availability,
	}
	if v.scroll_id != "" {r.offset = v.scroll_offset}
	if !ready ||
	   i.stamp.lifetime == nil ||
	   !i.stamp.lifetime.alive {r.availability = .Not_Ready; return r, .None}
	if r.availability != .Applied {return r, .None}
	s := i.live
	if s.phase ==
	   .Idle {if v.kind != .Drop_Target && s.cycle != max(u64) {r.actions = {.Begin}}} else if s.owner.id == id {
		r.actions = {.End, .Cancel}
		if v.kind == .Repeat_Scroll {r.actions += {.Advance}}
		if v.kind == .Pan_Scroll ||
		   (v.kind == .Drag_Source && s.source == .Mouse) {r.actions += {.Move}}
	} else if v.kind == .Drop_Target &&
	   s.owner.kind == .Drag_Source &&
	   s.source != .Mouse &&
	   v.scope_id == s.owner.scope_id {r.actions = {.Aim}}
	return r, .None
}
inspect_gestures :: proc(
	i: ^Inspection,
	ready: bool,
	a: mem.Allocator,
) -> (
	[]Gesture_View,
	common.Inspect_Error,
) {
	r, e := make([]Gesture_View, len(i.gestures), a); if e != nil {return nil, .Allocation}
	for d, k in i.gestures {r[k], _ = inspect_gesture(i, ready, d.id)}; return r, .None
}
