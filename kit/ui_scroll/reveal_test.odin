package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
focus_reveals_at_commit_while_reveal_only_does_not_take_focus :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ids := [3]string{"a", "b", "c"}; if !publish(t, &p, &ctx, &s, ids[:], "a") {return}
	r := dispatch(&s, &ctx, {kind = .Reveal_Item, id = "c", source = .Agent})
	testing.expect(t, r.code == .Applied && ctx.focus_id == "a" && !p.ready)
	if !publish(t, &p, &ctx, &s, ids[:]) {return}
	testing.expect(t, ctx.focus_id == "a" && s.frame.regions[0].offset == 50)
	r = dispatch(&s, &ctx, {kind = .Focus, id = "b", source = .Agent})
	testing.expect(t, r.code == .Applied && ctx.focus_id == "a")
	if !publish(t, &p, &ctx, &s, ids[:]) {return}
	testing.expect(t, ctx.focus_id == "b" && s.frame.regions[0].offset == 30)
	// A missing requested focus does not invent a replacement/reveal; retain
	// the previously available b using OLD order, as the old regression did.
	dispatch(&s, &ctx, {kind = .Focus, id = "a", source = .Agent})
	remaining := [2]string{"b", "c"}; publish(t, &p, &ctx, &s, remaining[:])
	testing.expect(t, ctx.focus_id == "b" && !s.has_pending)
}
