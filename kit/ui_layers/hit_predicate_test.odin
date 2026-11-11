package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
Shape_Probe :: struct {
	calls: int,
}
decline_popup_shape :: proc(id: string, point: [2]f64, user: rawptr) -> bool {
	p := cast(^Shape_Probe)user; p.calls += 1
	return id != "pb"
}
@(test)
custom_shape_does_not_bypass_popup_shield_or_touch_lower_target :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ms := [1]Modal{{"a", "ab", true}}; ps := [1]Popup{{"pop", "a", "ax"}}
	l := Layers {
		base_root_id = "base",
		modals       = ms[:],
		popups       = ps[:],
	}
	f := scene(t, &p, l, "", ""); defer destroy_scene(&f)
	c, e := prepare(
		&s,
		&ctx,
		&f.g,
		f.targets[:],
		nil,
		l,
		context.allocator,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	probe: Shape_Probe
	n, code := hit_test(&c.frame, &f.g, &c.interaction, 20, 20, decline_popup_shape, &probe)
	testing.expect(t, n == nil && code == .Not_Found && probe.calls == 1)
}
