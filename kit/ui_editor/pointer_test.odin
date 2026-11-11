package ui_editor
import "core:testing"
@(test)
pointer_ties_and_explicit_autoscroll_keep_source_boundaries :: proc(t: ^testing.T) {
	e := View {
		boundaries = []int{0, 3, 5},
		stops      = []f64{0, 10, 20},
		content    = {0, 0, 10, 10},
		extent     = 21,
	}
	testing.expect(t, editor_hit(e, 5) == 0 && editor_hit(e, 6) == 3)
	caret, scroll, ok := editor_drag(e, 20, 0.025)
	testing.expect(t, ok && scroll == 6 && caret == 5)
	_, _, ok = editor_drag(e, 20, -1)
	testing.expect(t, !ok)
}
