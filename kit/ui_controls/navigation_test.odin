package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
focus_navigation_and_slider_auxiliary_use_common_dispatch_once :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	views := [3]interaction.Target_View {
		{
			description = {id = "slider", role = "button", enabled = true, visible = true},
			availability = .Applied,
		},
		{
			description = {id = "plus", role = "button", enabled = true, visible = true},
			parent = "slider",
			availability = .Applied,
		},
		{
			description = {id = "plain", role = "button", enabled = true, visible = true},
			availability = .Applied,
		},
	}
	f := interaction.Frame {
		targets = views[:],
		stamp   = stamp,
	}
	ds := [1]Description {
		{
			id = "level",
			node_id = "slider",
			increment_id = "plus",
			kind = .Slider,
			minimum = 0,
			maximum = 100,
			step = 10,
			value = 50,
		},
	}
	c, e := prepare(
		&f,
		{},
		ds[:],
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}
	s := create(); commit(&s, &c); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	i, ok := interaction.try_copy_frame(&f, context.allocator); testing.expect(t, ok)
	base.enter_commit(&p, stamp); interaction.commit(&ctx, &i); base.finish_commit(&p, stamp)
	r := dispatch(&s, &ctx, {kind = .Focus, id = "slider", source = .Agent})
	testing.expect(t, r.dispatch.code == .Applied && ctx.focus_id == "slider" && p.sequence == 0)
	base.finish_commit(&p, stamp)
	r = dispatch(&s, &ctx, {kind = .Navigate, source = .Agent})
	testing.expect(t, r.dispatch.code == .Applied && ctx.focus_id == "plus" && p.sequence == 0)
	base.finish_commit(&p, stamp)
	n, _ := interaction.find(&ctx.frame, "slider"); n.availability = .Disabled
	r = dispatch(&s, &ctx, {kind = .Activate, id = "plus", source = .Agent})
	testing.expect(
		t,
		r.dispatch.code == .Disabled && r.event == nil && p.sequence == 0 && p.ready,
		"aux cannot bypass owner guard",
	)
	n.availability = .Applied
	r = dispatch(&s, &ctx, {kind = .Activate, id = "plus", source = .Agent})
	testing.expect(
		t,
		r.event != nil &&
		r.event.?.value == 60 &&
		r.dispatch.event.id == "plus" &&
		p.sequence == 1,
	)
}
