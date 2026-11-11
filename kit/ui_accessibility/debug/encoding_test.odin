package ui_accessibility_debug
import "base:runtime"
import "core:mem"
import "core:strings"
import "core:testing"
refuse :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode == .Resize_Non_Zeroed) {return nil, .Out_Of_Memory}
	a := cast(^mem.Allocator)data; return a.procedure(a.data, mode, size, alignment, old, old_size, loc)
}
@(test)
owning_accessibility_encoder_preserves_integer_tokens_and_refuses_oom :: proc(t: ^testing.T) {
	document := Accessibility_Reply {
		protocol = 17,
		frame_id = max(u64),
	}
	observation := transmute([]u8)string(`{"cycle":9007199254740993}`)
	r := encode_accessibility_document(document, observation, context.allocator); defer delete(r)
	testing.expect(
		t,
		strings.contains(string(r), `"frame_id":18446744073709551615`) &&
		strings.contains(string(r), `"cycle":9007199254740993`) &&
		strings.contains(string(r), `"accessibility":`) &&
		strings.contains(string(r), `"transitions":`),
		string(r),
	)
	backing := context.allocator
	failed := encode_accessibility_document(
		document,
		observation,
		{refuse, &backing},
	); testing.expect(t, failed == nil)
	malformed := encode_accessibility_document(
		document,
		transmute([]u8)string("{"),
		context.allocator,
	); testing.expect(t, malformed == nil)
}
