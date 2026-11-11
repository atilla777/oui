package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import "base:runtime"
import "core:mem"
import "core:testing"

Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
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
				   .Resize_Non_Zeroed) {f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
common_guards_precede_gesture_allocations_and_action_values :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s); ds := descriptions([]string{"card"})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	fault := Fault {
		backing = context.allocator,
		refuse  = 1,
	}; s.allocator = {fault_allocator, &fault}
	defer {s.allocator = context.allocator}
	for refusal in ([4]interaction.Code{.Disabled, .Not_Visible, .Blocked_By_Modal, .Non_Interactive_Overlay}) {
		for &n in ctx.frame.targets {if n.description.id == "source" {n.availability = refusal}}
		fault.requests = 0
		r := dispatch(&s, &ctx, nil, {kind = .End, source = .Agent, cycle = 999})
		testing.expect(t, r.code == refusal && p.ready && p.sequence == 0 && fault.requests == 0)
	}
}
