package architecture

import "core:strings"
import "core:testing"

@(test)
common_inspector_has_no_umbrella_dependency :: proc(t: ^testing.T) {
	source :: #load("../../../kit/ui_inspect/inspect.odin", string)
	testing.expect(
		t,
		!strings.contains(source, `"../ui"`),
		"common inspector must not import the removed monolithic runtime",
	)
}
