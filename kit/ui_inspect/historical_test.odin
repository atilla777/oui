package ui_inspect
import base "../ui_base"
import layout "../ui_layout"
import "core:testing"
@(test)
dead_publication_is_readable_but_never_current :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); s, _ := base.begin_attempt(&p, 1)
	nodes := [1]layout.Node {
		{
			id = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 20},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); defer layout.destroy_frame(&g); testing.expect(t, ge.code == .None)
	caps: [Action]bool; caps[.Activate] = true
	i, ie := capture(
		{
			frame = &g,
			ready = true,
			model_revision = 1,
			published_revision = 1,
			capabilities = caps,
		},
		context.allocator,
	); defer destroy_inspection(&i); testing.expect(t, ie == .None)
	base.destroy(&p)
	_, readable := inspect(&i, "root"); testing.expect(t, readable == .None)
	testing.expect(
		t,
		action_status(&i, "root", .Activate).code == .Not_Ready && !strict_result(&i).ok,
	)
	bad, be := capture(
		{frame = &g, ready = true, model_revision = 1, published_revision = 1},
		context.allocator,
	); defer destroy_inspection(&bad)
	testing.expect(t, be == .Metadata_Mismatch)
	historical, he := capture(
		{frame = &g, ready = false, model_revision = 1, published_revision = 1},
		context.allocator,
	); defer destroy_inspection(&historical)
	testing.expect(t, he == .None && historical.historical)
}
