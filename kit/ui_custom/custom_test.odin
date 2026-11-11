package ui_custom

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

validate_disk :: proc(payload: []u8) -> bool {return len(payload) == 1 && payload[0] == 3}
measure_disk :: proc(payload: []u8, constraints: Constraints) -> (base.Extent, bool) {return {
			20,
			20,
		},
		true}
hit_disk :: proc(payload: []u8, p: [2]f64, size: base.Extent) -> bool {
	x, y := (p[0] - size.w / 2) / (size.w / 2), (p[1] - size.h / 2) / (size.h / 2)
	return x * x + y * y < 1
}
@(test)
custom_owns_payload_and_exact_local_hit :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := [1]layout.Resolved_Node {
		{
			description = {id = "disk", role = .Content},
			bounds = {10, 20, 20, 20},
			content = {10, 20, 20, 20},
			paint_clip = {10, 20, 20, 20},
			clip = {10, 20, 20, 20},
		},
	}
	g := layout.Frame {
		nodes = nodes[:],
		stamp = stamp,
	}
	targets := [1]interaction.Target_View {
		{description = {id = "disk"}, availability = .Applied, activation_owner = "custom"},
	}
	i := interaction.Frame {
		targets = targets[:],
		stamp   = stamp,
	}
	payload := [1]u8{3}
	f, e := prepare(
		&g,
		&i,
		[]Description {
			{
				node_id = "disk",
				type_id = "circle",
				revision = "1",
				payload = payload[:],
				validate = validate_disk,
				measure = measure_disk,
				hit = hit_disk,
			},
		},
	)
	defer destroy_frame(&f)
	if !testing.expect(t, e.code == .None) {return}
	payload[0] = 99
	testing.expect(t, f.views[0].payload[0] == 3)
	testing.expect(t, hit(&f, "disk", {20, 30}))
	testing.expect(t, !hit(&f, "disk", {10, 20}))
	entries := [1]base.Geometry_Entry {
		{
			id = "disk",
			input_enabled = true,
			geometry = {
				scale = 2,
				offset = {5, 7},
				opacity = 1,
				bounds = {25, 47, 40, 40},
				content = {25, 47, 40, 40},
				clip = {25, 47, 40, 40},
				content_clip = {25, 47, 40, 40},
			},
		},
	}
	if !testing.expect(t, sample_candidate(&f, {stamp, entries[:]})) {return}
	testing.expect(t, hit(&f, "disk", {45, 67}) && !hit(&f, "disk", {25, 47}))
	r, copied := try_copy_frame(&f)
	destroy_frame(&f)
	defer destroy_frame(&r)
	if !testing.expect(t, copied) {return}
	base.destroy(&p)
	testing.expect(t, hit(&r, "disk", {45, 67}))
}

@(test)
measurement_is_node_addressed_and_checked :: proc(t: ^testing.T) {
	d := []Description {
		{
			node_id = "disk",
			type_id = "circle",
			revision = "1",
			payload = []u8{3},
			validate = validate_disk,
			measure = measure_disk,
			hit = hit_disk,
		},
	}
	m := Metrics {
		descriptions = d,
	}
	size, ok := measure("disk", &m)
	testing.expect(t, ok && size == (base.Extent{20, 20}))
	_, ok = measure("absent", &m); testing.expect(t, !ok)
	d[0].payload = nil
	_, ok = measure("disk", &m); testing.expect(t, !ok)
}
