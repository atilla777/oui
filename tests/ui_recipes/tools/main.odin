package recipe

import debug "ui:ui_debug"
import inspect "ui:ui_inspect"
import assertions "ui:ui_testing"

// Testing stays in this test fixture; neither production entrypoint imports it.
// Constructing a Host is not permission to open/service any endpoint.
main :: proc() {
	i: inspect.Inspection
	h: debug.Host
	assert(size_of(i) > 0 && size_of(h) > 0)
	assert(assertions.expect_exists != nil && debug.destroy_capture != nil)
}
