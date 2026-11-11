package ui_inspect
import base "../ui_base"
import layout "../ui_layout"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"

Fault :: struct {
	backing:       mem.Allocator,
	calls, refuse: int,
}
fault_allocator :: proc(
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
	f := cast(^Fault)data
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode ==
				   .Resize_Non_Zeroed) {f.calls += 1; if f.calls == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
every_owning_allocation_refuses_without_partial_capture_or_leak :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	nodes := [1]layout.Node {
		{
			id = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); defer layout.destroy_frame(&g); testing.expect(t, e.code == .None)
	input := Inspection_Input {
		frame              = &g,
		ready              = false,
		model_revision     = 2,
		published_revision = 1,
		semantics          = []Semantic{{"root", "container", "Имя", "published:1"}},
		diagnostics        = []Diagnostic_Record {
			{
				code = "host.Resource_Generation_Failed",
				id = "assets",
				source_hint = "attempt:2",
				reference = "catalog-v2",
				detail = "generation refused",
				severity = .Error,
				phase = .update,
				attempt_revision = u64(2),
			},
		},
	}
	live: mem.Tracking_Allocator; mem.tracking_allocator_init(&live, context.allocator); defer mem.tracking_allocator_destroy(&live)
	a := mem.tracking_allocator(&live)
	completed := false
	for at in 1 ..< 256 {
		f := Fault {
			backing = a,
			refuse  = at,
		}
		i, error := capture(input, {fault_allocator, &f})
		if error == .None {
			testing.expect(
				t,
				i.historical &&
				!strict_result(&i).ok &&
				len(i.diagnostics) == 1 &&
				i.diagnostics[0].detail == "generation refused",
			)
			fmt.printf(
				"common inspector: bytes=%d peak=%d calls=%d sizeof(Inspection)=%d sizeof(Node_View)=%d\n",
				live.current_memory_allocated,
				live.peak_memory_allocated,
				f.calls,
				size_of(Inspection),
				size_of(Node_View),
			)
			destroy_inspection(&i); completed = true
		} else {testing.expect(t, error == .Allocation && i.frame.nodes == nil)
			destroy_inspection(&i)}
		testing.expect(
			t,
			live.current_memory_allocated == 0 &&
			len(live.allocation_map) == 0 &&
			len(live.bad_free_array) == 0,
		)
		if completed {break}
	}
	testing.expect(t, completed)
}
@(test)
failed_attempt_metadata_cannot_claim_ready_or_another_revision :: proc(t: ^testing.T) {
	for revision in ([]u64{0, 3}) {
		i, e := capture(
			{
				model_revision = 2,
				published_revision = 0,
				diagnostics = []Diagnostic_Record {
					{
						code = "host.Failed",
						severity = .Error,
						phase = .update,
						attempt_revision = revision,
					},
				},
			},
			context.allocator,
		)
		destroy_inspection(&i)
		// Revision zero is valid without a published frame; a future attempt is not.
		testing.expect(t, (e == .None) == (revision == 0))
	}
}
