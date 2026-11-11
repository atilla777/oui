package ui_transitions

import base "../ui_base"
import interaction "../ui_interaction"
import style "../ui_style"
import "core:testing"

@(test)
one_projection_moves_hit_paint_patch_and_does_not_change_modal_gate :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	entries := []base.Geometry_Entry {
		{
			id = "card",
			input_enabled = true,
			geometry = {
				scale = .5,
				offset = {80, 0},
				opacity = .5,
				bounds = {90, 10, 50, 20},
				content = {92, 12, 46, 16},
				clip = {90, 10, 50, 20},
				content_clip = {92, 12, 46, 16},
			},
		},
	}
	f := Frame {
		stamp    = stamp,
		entries  = entries,
		bound    = true,
		drawable = {300, 200},
		ui_scale = 1,
	}
	targets := []interaction.Target_View {
		{
			description = {id = "card"},
			availability = .Blocked_By_Modal,
			bounds = {20, 20, 100, 40},
		},
	}
	i := interaction.Frame {
		stamp   = stamp,
		targets = targets,
	}
	if !testing.expect(t, sample_interaction(&f, &i)) {return}
	testing.expect(
		t,
		i.targets[0].bounds == entries[0].geometry.bounds &&
		i.targets[0].availability == .Blocked_By_Modal,
	)
	presentations := []style.Presentation {
		{
			id = "card",
			area = {20, 20, 100, 40},
			content = {24, 24, 92, 32},
			drawable = true,
			radius = 4,
			border_width = 2,
			patches = []style.Image_Patch {
				{source = {1, 2, 3, 4}, destination = {20, 20, 100, 40}},
			},
		},
	}
	s := style.Frame {
		stamp        = stamp,
		presentation = presentations,
		drawable     = {300, 200},
		ui_scale     = 1,
	}
	if !testing.expect(t, sample_style(&f, &s)) {return}
	testing.expect(
		t,
		s.presentation[0].area == entries[0].geometry.bounds &&
		s.presentation[0].radius == 2 &&
		s.presentation[0].border_width == 1,
	)
	testing.expect(
		t,
		s.presentation[0].patches[0].source == (base.Rect{1, 2, 3, 4}) &&
		s.presentation[0].patches[0].destination == (base.Rect{90, 10, 50, 20}),
	)
}
