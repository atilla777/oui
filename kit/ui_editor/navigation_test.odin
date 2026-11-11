package ui_editor

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
unicode_navigation_keeps_boundary_selection_and_collapse :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	d := description()
	if !publish(t, &p, &ctx, &s, d) {return}
	for tc in ([]struct {
			direction:     Direction,
			extend:        bool,
			caret, anchor: int,
		}{{.Left, true, 3, 4}, {.Home, true, 0, 4}, {.End, true, 4, 4}, {.Left, true, 3, 4}, {.Left, false, 3, 3}, {.Home, false, 0, 0}, {.Left, false, 0, 0}, {.Right, false, 1, 1}, {.Right, false, 3, 3}, {.End, false, 4, 4}}) {
		r := dispatch(
			&s,
			&ctx,
			{id = "name", kind = .Move, direction = tc.direction, extend = tc.extend},
			metrics(),
		)
		if !testing.expect(t, r.code == .Applied && r.proposal == nil) {return}
		if !publish(t, &p, &ctx, &s, d) {return}
		e, _ := find(&s.frame, "name")
		testing.expect(t, e.caret == tc.caret && e.anchor == tc.anchor && p.sequence == 0)
	}
}
