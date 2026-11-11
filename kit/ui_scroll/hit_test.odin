package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
hit_matches_half_open_viewport_and_selected_frozen_projection :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	s := create(context.allocator); defer destroy(&s)
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(
		&s,
		&g,
		&i,
		ds[:],
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer destroy_candidate(&c)
	r, ok := hit_test(&c.frame, &c.geometry, &i, 10, 39)
	testing.expect(t, ok && r.id == "scroll")
	_, ok = hit_test(&c.frame, &c.geometry, &i, 10, 40); testing.expect(t, !ok)
	entries := [1]base.Geometry_Entry {
		{
			id = "scroll",
			input_enabled = true,
			geometry = {scale = 1, opacity = 1, content_clip = {20, 10, 50, 20}},
		},
	}
	view := base.Geometry_View {
		stamp   = c.frame.stamp,
		entries = entries[:],
	}
	_, ok = hit_test(&c.frame, &c.geometry, &i, 25, 15, view); testing.expect(t, ok)
	_, ok = hit_test(
		&c.frame,
		&c.geometry,
		&i,
		5,
		5,
		view,
	); testing.expect(t, !ok, "selected visual clip replaces identity clip")
	entries[0].input_enabled =
		false; _, ok = hit_test(&c.frame, &c.geometry, &i, 25, 15, view); testing.expect(t, !ok)
	entries[0].input_enabled = true
	entries[0].geometry.opacity = 0
	_, ok = hit_test(
		&c.frame,
		&c.geometry,
		&i,
		25,
		15,
		view,
	); testing.expect(t, !ok, "invisible geometry cannot take wheel input")
	entries[0].geometry.opacity = 1; entries[0].geometry.scale = 0
	_, ok = hit_test(
		&c.frame,
		&c.geometry,
		&i,
		25,
		15,
		view,
	); testing.expect(t, !ok, "non-invertible geometry cannot take wheel input")
	view.stamp.attempt += 1; _, ok = hit_test(&c.frame, &c.geometry, &i, 25, 15, view); testing.expect(t, !ok)
}
