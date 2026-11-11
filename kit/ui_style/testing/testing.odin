package ui_style_testing
import family ".."
import "core:testing"
expect_selected :: proc(t: ^testing.T, f: ^family.Frame, id: string, selected: bool) -> bool {
	for v in f.presentation {if v.id == id {return testing.expect(t, (.Selected in v.states) == selected, id)}}
	return testing.expect(t, false, id)
}
