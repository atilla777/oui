package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:strings"
import "core:testing"

@(test)
partition_errors_are_exact_and_cannot_replace_published_state :: proc(t: ^testing.T) {
	for variant in 0 ..< 10 {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		l := Layers {
			base_root_id = "base",
		}; accept_scene(t, &p, &s, &ctx, l)
		ps := [1]Popup{{"pop", "", "open"}}; l.popups = ps[:]
		f := scene(t, &p, l)
		expected := "pop"
		switch variant {
		case 0:
			ps[0].owner_scope_id = "missing"
		case 1:
			ps[0].owner_scope_id = "pop"
		case 2:
			ps[0].root_id = "base"; expected = "base"
		case 3:
			ps[0].root_id = "pb"; expected = "pb"
		case 4:
			l.popups = nil
		case 5:
			l.base_root_id = "root"; expected = "root"
		case 6:
			f.g.nodes[0].description.role = .Column; expected = "root"
		case 7:
			ps[0].root_id = "absent"; expected = "absent"
		case 8:
			ps[0].owner_scope_id = "base"
		case 9:
			node, _ := layout.find(&f.g, "pop"); delete(node.description.parent, f.g.allocator)
			node.description.parent = strings.clone("base", f.g.allocator)
		}
		c, e := prepare(
			&s,
			&ctx,
			&f.g,
			f.targets[:],
			nil,
			l,
			context.allocator,
		); destroy_candidate(&c)
		testing.expect(
			t,
			e.code == .Invalid_Layers &&
			e.id == expected &&
			ctx.focus_id == "open" &&
			s.frame.layers.popups == nil &&
			!p.ready,
		)
		destroy_scene(&f); destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
initial_focus_cannot_be_a_popup_or_other_scope_and_disabled_modal_is_invalid :: proc(
	t: ^testing.T,
) {
	for initial in ([]string{"pb", "open", "missing", "a"}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		ms := [1]Modal{{"a", initial, true}}; ps := [1]Popup{{"pop", "a", "ax"}}
		l := Layers {
			base_root_id = "base",
			modals       = ms[:],
			popups       = ps[:],
		}; f := scene(t, &p, l)
		c, e := prepare(
			&s,
			&ctx,
			&f.g,
			f.targets[:],
			nil,
			l,
			context.allocator,
		); destroy_candidate(&c)
		testing.expect(t, e.code == .Invalid_Layers && e.id == initial)
		destroy_scene(&f); destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
	for hidden in ([]bool{false, true}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		ms := [1]Modal{{"a", "ab", true}}; l := Layers {
			base_root_id = "base",
			modals       = ms[:],
		}
		disabled, hide := "a", ""; if hidden {disabled, hide = "", "a"}
		f := scene(t, &p, l, disabled, hide)
		c, e := prepare(
			&s,
			&ctx,
			&f.g,
			f.targets[:],
			nil,
			l,
			context.allocator,
		); destroy_candidate(&c)
		testing.expect(t, e.code == .Invalid_Layers && e.id == "a")
		destroy_scene(&f); destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
diagnostics_keep_layer_and_underlying_interaction_code_and_own_borrowed_id :: proc(t: ^testing.T) {
	id := strings.clone("bad-layer")
	e, ok := base.try_copy_error(
		describe_error({.Interaction, id, .Conflict}),
		context.allocator,
	); delete(id); defer base.destroy_error(&e)
	testing.expect(
		t,
		ok &&
		e.family == .Layers &&
		e.stage == .Prepare &&
		e.code == u32(Error_Code.Interaction) &&
		e.existing_code == u32(interaction.Code.Conflict) &&
		e.id == "bad-layer",
	)
}
