package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
cancel_refusal_stale_source_and_exhaustion_follow_the_common_gate :: proc(t: ^testing.T) {
	for allowed in ([]bool{false, true}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		ms := [2]Modal{{"a", "ab", true}, {"b", "bb", allowed}}; l := Layers {
			base_root_id = "base",
		}
		accept_scene(
			t,
			&p,
			&s,
			&ctx,
			l,
		); l.modals = ms[:1]; accept_scene(t, &p, &s, &ctx, l); l.modals = ms[:]; accept_scene(t, &p, &s, &ctx, l)
		for source in interaction.Source {
			r := dispatch(&s, &ctx, {kind = .Cancel, source = source})
			if allowed {testing.expect(t, r.cancel != nil && r.cancel.?.root_id == "b" && !p.ready); accept_scene(t, &p, &s, &ctx, l)
			} else {testing.expect(
					t,
					r.dispatch.code == .Invalid_Action &&
					r.cancel == nil &&
					p.ready &&
					p.sequence == 0,
				)}
		}
		r := dispatch(
			&s,
			&ctx,
			{kind = .Cancel, source = interaction.Source(99)},
		); testing.expect(t, r.dispatch.code == .Invalid_Action && p.ready)
		s.frame.stamp.attempt += 1; r = dispatch(&s, &ctx, {kind = .Cancel, source = .Agent}); testing.expect(t, r.dispatch.code == .Not_Ready && p.ready); s.frame.stamp = ctx.frame.stamp
		if allowed {
			p.sequence = max(
				u64,
			); ctx.frame.stamp.sequence = p.sequence; s.frame.stamp = ctx.frame.stamp; base.finish_commit(&p, ctx.frame.stamp)
			r = dispatch(
				&s,
				&ctx,
				{kind = .Cancel, source = .Agent},
			); testing.expect(t, r.dispatch.code == .Exhausted && r.cancel == nil && p.sequence == max(u64) && !p.ready, "common exhausted sequence blocks readiness without wrapping")
		}
		base.invalidate(
			&p,
		); r = dispatch(&s, &ctx, {kind = .Cancel, source = interaction.Source(99)}); testing.expect(t, r.dispatch.code == .Not_Ready)
		destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
popup_shield_hidden_disabled_and_tooltip_hit_are_independent_of_paint_only_overlays :: proc(
	t: ^testing.T,
) {
	for mode in 0 ..< 3 {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		ms := [1]Modal {
			{"a", "ab", true},
		}; ps := [1]Popup{{"pop", "a", "ax"}}; ts := [1]Tooltip{{"tip", "a"}}
		l := Layers {
			base_root_id = "base",
			modals       = ms[:],
			popups       = ps[:],
			tooltips     = ts[:],
		}
		disabled, hidden := "", ""; if mode == 1 {disabled = "pop"}; if mode == 2 {hidden = "pop"}
		f := scene(t, &p, l, disabled, hidden)
		c, e := prepare(&s, &ctx, &f.g, f.targets[:], nil, l, context.allocator)
		if testing.expect(t, e.code == .None) {
			n, code := hit_test(&c.frame, &f.g, &c.interaction, 20, 20)
			if mode == 0 {testing.expect(t, code == .Applied && n.description.id == "pb")}
			if mode ==
			   1 {testing.expect(t, n == nil && code == .Not_Found, "visible disabled popup still shields lower modal")}
			if mode ==
			   2 {testing.expect(t, code == .Applied && n.description.id == "ax", "hidden popup does not shield active main")}
			n, code = hit_test(
				&c.frame,
				&f.g,
				&c.interaction,
				60,
				60,
			); testing.expect(t, n == nil && code == .Not_Found)
			wrong :=
				f.g; wrong.stamp.attempt += 1; n, code = hit_test(&c.frame, &wrong, &c.interaction, 20, 20); testing.expect(t, n == nil && code == .Not_Ready)
		}
		destroy_candidate(
			&c,
		); destroy_scene(&f); destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
hidden_popup_close_returns_only_within_owner_scope_and_bad_return_falls_back_to_main :: proc(
	t: ^testing.T,
) {
	for return_id in ([]string{"ax", "open", "missing"}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		ms := [1]Modal{{"a", "ab", true}}; ps := [1]Popup{{"pop", "a", return_id}}
		l := Layers {
			base_root_id = "base",
			modals       = ms[:],
			popups       = ps[:],
		}; accept_scene(t, &p, &s, &ctx, l)
		dispatch(
			&s,
			&ctx,
			{kind = .Focus, id = "pb", source = .Agent},
		); accept_scene(t, &p, &s, &ctx, l)
		interaction.begin_pointer_press(&ctx, "pb"); accept_scene(t, &p, &s, &ctx, l)
		accept_scene(t, &p, &s, &ctx, l, "", "pop")
		want := "ab"; if return_id == "ax" {want = "ax"}
		testing.expect(t, ctx.focus_id == want && ctx.pressed_id == "" && p.sequence == 0)
		destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}
