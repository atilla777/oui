package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
candidate_cannot_restore_hover_after_pointer_loss_or_validate_against_foreign_origin :: proc(
	t: ^testing.T,
) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g := fixture(t, &p, false); accept(t, &p, &s, &ctx, &g, false); layout.destroy_frame(&g)
	interaction.observe_pointer(&ctx, 10, 10)
	g = fixture(t, &p, false); defer layout.destroy_frame(&g)
	ts := [1]interaction.Target{{"open", "button", true, true}}
	c, e := prepare(
		&s,
		&ctx,
		&g,
		ts[:],
		nil,
		{base_root_id = "base"},
		context.allocator,
	); defer destroy_candidate(&c)
	if !testing.expect(
		t,
		e.code == .None && c.hover_id == "open" && validate_candidate(&p, &c),
	) {return}
	interaction.cancel_pointer(&ctx)
	testing.expect(
		t,
		!validate_candidate(&p, &c),
		"loss during prepare cannot resurrect frozen hover",
	)
	other, _ := base.create(context.allocator); defer base.destroy(&other)
	other_ctx := interaction.create(
		context.allocator,
		&other,
	); defer interaction.destroy(&other_ctx)
	bad, be := prepare(
		&s,
		&other_ctx,
		&g,
		ts[:],
		nil,
		{base_root_id = "base"},
		context.allocator,
	); defer destroy_candidate(&bad)
	testing.expect(
		t,
		be.code != .None || !validate_candidate(&p, &bad),
		"candidate origin must belong to selected publication",
	)
}

@(test)
selected_layer_roots_must_remain_structural_not_buttons :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g := fixture(t, &p, true); defer layout.destroy_frame(&g)
	ms := [1]Modal{{"modal", "confirm", true}}
	for root in ([]string{"root", "base", "modal"}) {
		ts := [3]interaction.Target {
			{"open", "button", true, true},
			{"confirm", "button", true, true},
			{root, "button", true, true},
		}
		c, e := prepare(
			&s,
			&ctx,
			&g,
			ts[:],
			nil,
			{base_root_id = "base", modals = ms[:]},
			context.allocator,
		); destroy_candidate(&c)
		testing.expect(
			t,
			e.code == .Invalid_Layers && e.id == root,
			"layer root cannot acquire a focus or activation interface",
		)
	}
}
