package main

import "core:testing"
import interaction "ui:ui_interaction"

@(test)
publisher_binds_all_selected_owners_and_owning_reader :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r)
	if !testing.expect(t, publish(&r)) {return}
	n, found := interaction.find(&r.reader.input_frame, "check")
	testing.expect(
		t,
		found && n.availability == .Applied && r.reader.input_frame.stamp == r.ctx.frame.stamp,
		"reader retains full immutable input projection as well as wheel hit projection",
	)
	testing.expect(
		t,
		r.p.ready &&
		r.ctx.frame.stamp == r.layers.frame.stamp &&
		r.ctx.frame.stamp == r.scroll.frame.stamp &&
		r.ctx.frame.stamp == r.hold.frame.stamp &&
		r.ctx.frame.stamp == r.controls.frame.stamp,
	)
	testing.expect(
		t,
		len(r.reader.scroll.regions) == 1 &&
		len(r.reader.controls.controls) == 4 &&
		len(r.reader.hold.holds) == 1 &&
		len(r.reader.layers.groups) == 3,
	)
}
