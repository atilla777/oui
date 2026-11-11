package ui_debug

import "core:testing"

@(test)
grammar_v10 :: proc(t: ^testing.T) {
	for line in ([]string{`{"protocol":10,"request_id":"a","op":"capabilities"}`, `{"protocol":10,"request_id":"a","op":"find","role":"button"}`, `{"protocol":10,"request_id":"a","op":"find","name":"Открыть"}`, `{"protocol":10,"request_id":"a","op":"navigate","direction":"backward"}`, `{"protocol":10,"request_id":"a","op":"advance","duration_ms":9223372036854775807}`, `{"protocol":10,"request_id":"a","op":"snapshot","overlays":["bounds","content","hit"]}`, `{"protocol":10,"request_id":"a","op":"set_value"}`}) {
		r, ok := parse_request(transmute([]u8)line)
		testing.expect(t, ok && r.protocol == 10 && r.request_id == "a", line)
	}
	for line in ([]string{`{"protocol":9,"request_id":"a","op":"tree"}`, `{"protocol":10,"request_id":"a","op":"tree","id":"x"}`, `{"protocol":10,"request_id":"a","op":"find","id":"x","role":"button"}`, `{"protocol":10,"request_id":"a","op":"find","name":""}`, `{"protocol":10,"request_id":"a","op":"navigate","direction":"left"}`, `{"protocol":10,"request_id":"a","op":"advance","duration_ms":9223372036854775808}`, `{"protocol":10,"request_id":"a","op":"advance","duration_ms":1.0}`, `{"protocol":10,"request_id":"a","op":"snapshot","overlays":["hit","hit"]}`, `{"protocol":10,"request_id":"a","op":"snapshot","overlays":["crop"]}`, `{"protocol":10,"request_id":"a","op":"tree","op":"tree"}`, `{"protocol":10,"request_id":"a","op":"tree"} {}`, `{"protocol":10,"request_id":"a","op":"tree",}`, `{"protocol":10,"request_id":"a","op":"other"}`}) {
		_, ok := parse_request(transmute([]u8)line)
		testing.expect(t, !ok, line)
	}
}
