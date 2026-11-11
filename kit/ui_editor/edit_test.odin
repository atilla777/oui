package ui_editor

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
insert_and_forward_delete_resegment_unicode_without_replay :: proc(t: ^testing.T) {
	for tc in ([]struct {
			value:               string,
			caret:               int,
			kind:                Action_Kind,
			insertion, expected: string,
		}{{"a", 1, .Insert, "\u0301", "a\u0301"}, {"👩\u200d👩x", 0, .Delete, "", "x"}, {"🇺🇸🇨", 0, .Delete, "", "🇨"}, {"a", 1, .Delete, "", "a"}}) {
		p, _ := base.create(context.allocator); defer base.destroy(&p)
		ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
		s := create(); defer destroy(&s)
		d := description(tc.value)
		if !publish(t, &p, &ctx, &s, d) {return}
		dispatch(
			&s,
			&ctx,
			{id = "name", kind = .Select, anchor = tc.caret, caret = tc.caret},
			metrics(),
		)
		if !publish(t, &p, &ctx, &s, d) {return}
		r := dispatch(&s, &ctx, {id = "name", kind = tc.kind, text = tc.insertion}, metrics())
		defer destroy_result(&r)
		if !testing.expect(t, r.code == .Applied) {return}
		if tc.expected !=
		   tc.value {testing.expect(t, r.proposal != nil && r.proposal.?.value == tc.expected && p.sequence == 1)} else {testing.expect(t, r.proposal == nil && p.sequence == 0)}
	}
}
