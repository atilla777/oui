package ui_editor
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
frozen_projection_is_owned_and_stamp_checked :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	if !publish(t, &p, &ctx, &s, description()) {return}
	f, ok := try_copy_frame(&s.frame); if !testing.expect(t, ok) {return}
	c := Candidate {
		frame   = f,
		owner   = &s,
		version = s.version,
	}; defer destroy_candidate(&c)
	entries := [1]base.Geometry_Entry {
		{
			id = "field",
			input_enabled = true,
			geometry = {
				scale = 2,
				offset = {10, 20},
				opacity = 0.5,
				bounds = {10, 20, 200, 40},
				content = {10, 20, 200, 40},
				clip = {10, 20, 200, 40},
				content_clip = {10, 20, 200, 40},
			},
		},
	}
	v := base.Geometry_View {
		stamp   = f.stamp,
		entries = entries[:],
	}
	testing.expect(t, sample_candidate(&c, v))
	entries[0].geometry.offset = {}
	e, _ := find(&c.frame, "name")
	testing.expect(t, e.geometry.offset == [2]f64{10, 20} && e.geometry.scale == 2)
	v.stamp.attempt += 1
	testing.expect(t, !sample_candidate(&c, v))
}
