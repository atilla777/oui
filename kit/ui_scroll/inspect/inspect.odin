package ui_scroll_inspect
import family ".."
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
	if f == nil || f.stamp != i.frame.stamp {return {}, .Metadata_Mismatch}
	r, ok := family.try_copy_frame(f, a); if !ok {return {}, .Allocation}; return r, .None
}
destroy :: family.destroy_frame
