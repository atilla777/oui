package ui_editor
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
submit_cancel_are_single_intents_not_application_outcomes :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	for kind in ([2]Action_Kind{.Submit, .Cancel}) {
		if !publish(t, &p, &ctx, &s, description()) {return}
		before := p.sequence
		r := dispatch(&s, &ctx, {id = "name", kind = kind}, metrics())
		expected := Intent.Submit; if kind == .Cancel {expected = .Cancel}
		testing.expect(
			t,
			r.code == .Applied &&
			r.intent == expected &&
			r.proposal == nil &&
			p.sequence == before + 1 &&
			!p.ready,
		)
		testing.expect(
			t,
			dispatch(&s, &ctx, {id = "name", kind = kind}, metrics()).code == .Not_Ready,
		)
	}
}
