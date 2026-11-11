package ui_interaction

import base "../ui_base"
import "core:strings"
import "core:testing"

@(test)
family_guard_preserves_frozen_refusals_without_mutation :: proc(t: ^testing.T) {
	p, e := base.create(context.allocator); testing.expect(t, e == .None); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	// A selected family publishes these gates into the ordinary interaction
	// projection. This small fixture isolates common guards from layer policy.
	s, _ := base.begin_attempt(&p, 0)
	ctx.frame.stamp = s; testing.expect(t, base.retain(s))
	ctx.frame.targets = make([]Target_View, 1, context.allocator)
	ctx.frame.allocator = context.allocator
	id, ae := strings.clone("target", context.allocator)
	ctx.frame.targets[0].description.id = id
	testing.expect(t, ae == nil)
	base.finish_commit(&p, s)
	for refusal in ([4]Code{.Blocked_By_Modal, .Non_Interactive_Overlay, .Disabled, .Not_Visible}) {
		ctx.frame.targets[0].availability = refusal
		for source in Source {
			testing.expect(t, guard(&ctx, "target", source) == refusal)
			for kind in ([2]Action_Kind{.Focus, .Activate}) {
				r := dispatch(&ctx, {kind = kind, id = "target", source = source})
				testing.expect(t, r.code == refusal && !r.has_event)
			}
		}
		testing.expect(t, p.ready && p.sequence == 0 && ctx.focus_id == "")
	}
	testing.expect(t, guard(&ctx, "missing", .Agent) == .Not_Found)
	testing.expect(t, guard(&ctx, "target", Source(99)) == .Invalid_Action)
	base.invalidate(&p)
	testing.expect(t, guard(&ctx, "missing", Source(99)) == .Not_Ready)
}
