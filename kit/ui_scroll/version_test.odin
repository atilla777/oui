package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
technical_version_exhaustion_does_not_mutate_pending_or_readiness :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(context.allocator); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	ids := [3]string{"a", "b", "c"}; if !publish(t, &p, &ctx, &s, ids[:], "a") {return}
	s.version = max(u64)
	r := dispatch(&s, &ctx, {kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = 1})
	testing.expect(t, r.code == .Exhausted && p.ready && !s.has_pending && s.version == max(u64))
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(&s, &g, &i, ds[:], context.allocator); defer destroy_candidate(&c)
	testing.expect(t, e.code == .Exhausted && c.geometry.nodes == nil)
}
