package showcase_profile

import "core:fmt"
import "core:strings"
import "core:testing"

@(test)
v19_exact_grammar_is_separate_from_legacy :: proc(t: ^testing.T) {
	for body in ([]string{`"op":"list-sections"`, `"op":"select-section","section":"lab-hud"`, `"op":"geometry","id":"hud/restore"`, `"op":"find","name":"Восстановить"`, `"op":"find","role":"button"`, `"op":"find","id":"stable"`, `"op":"tree"`, `"op":"inspect","id":"stable"`, `"op":"diagnostics"`, `"op":"assert-no-errors"`, `"op":"capabilities"`, `"op":"focus","id":"stable"`, `"op":"activate","id":"stable"`, `"op":"navigate","direction":"backward"`, `"op":"scroll","id":"table/viewport","delta_y":-2.5`, `"op":"begin-hold","id":"hud/restore"`, `"op":"advance-hold","duration_ms":9223372036854775807`, `"op":"release-hold"`, `"op":"cancel-hold"`, `"op":"cancel"`, `"op":"snapshot"`, `"op":"set_value"`, `"op":"drag"`, `"op":"overlays"`, `"op":"crop"`, `"op":"finish-transitions"`}) {
		line := fmt.tprintf("%s%s%s", `{"protocol":19,"request_id":"тест",`, body, "}")
		r, ok := parse_request(transmute([]u8)line)
		testing.expect(t, ok && r.protocol == 19 && r.request_id == "тест", line)
	}
}

@(test)
v19_rejects_unknown_duplicate_trailing_and_out_of_range_before_execution :: proc(t: ^testing.T) {
	for body in ([]string{`"op":"other"`, `"op":"tree","section":"hud"`, `"op":"snapshot","overlays":[]`, `"op":"find"`, `"op":"find","id":"x","role":"button"`, `"op":"find","name":""`, `"op":"begin"`, `"op":"release"`, `"op":"assert_no_errors"`, `"op":"select-section"`, `"op":"select-section","section":""`, `"op":"activate","id":"x","id":"y"`, `"op":"tree","\u006fp":"tree"`, `"op":"advance-hold","duration_ms":-1`, `"op":"advance-hold","duration_ms":1.0`, `"op":"advance-hold","duration_ms":9223372036854775808`, `"op":"scroll","id":"x","delta_y":1e999`, `"op":"scroll","id":"x","delta_y":"1"`, `"op":"navigate","direction":"sideways"`, `"op":"inspect","id":null`, `"op":"tree","unknown":true`, `"op":"tree","id":"x\u0000y"`}) {
		line := fmt.tprintf("%s%s%s", `{"protocol":19,"request_id":"test",`, body, "}")
		_, ok := parse_request(transmute([]u8)line); testing.expect(t, !ok, line)
	}
	for line in ([]string{`{"protocol":10,"request_id":"test","op":"tree"}`, `{"protocol":19.0,"request_id":"test","op":"tree"}`, `{"protocol":19,"request_id":"","op":"tree"}`, `{"protocol":19,"request_id":"test","op":"tree"} {}`, `{"protocol":19,"request_id":"test","op":"tree",}`, "{\"protocol\":19,\"request_id\":\"test\",\"op\":\"tree\",\"id\":\"\xff\"}"}) {_, ok := parse_request(transmute([]u8)line); testing.expect(t, !ok, line)}
	oversize := strings.repeat(" ", MESSAGE_LIMIT, context.temp_allocator)
	_, ok := parse_request(transmute([]u8)oversize); testing.expect(t, !ok)
}
