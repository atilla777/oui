package selected_tools
import "core:testing"
import accessibility "ui:ui_accessibility/debug"
import collections "ui:ui_collections/debug"
import custom "ui:ui_custom/debug"
import debug "ui:ui_debug"
import performance "ui:ui_debug/performance"
import editor "ui:ui_editor/debug"
import gestures "ui:ui_gestures/debug"
import rich "ui:ui_rich/debug"
import transitions "ui:ui_transitions/debug"

check :: proc(
	t: ^testing.T,
	parse: proc(_: []u8) -> (debug.Request, bool),
	version: int,
	good, bad: []string,
) {
	for text in good {r, ok := parse(transmute([]u8)text); testing.expect(t, ok && r.protocol == version, text); _, legacy := debug.parse_request(transmute([]u8)text); testing.expect(t, !legacy, text)}
	for text in bad {_, ok := parse(transmute([]u8)text); testing.expect(t, !ok, text)}
}
@(test)
selected_grammars_retain_original_positive_and_refusal_oracles :: proc(t: ^testing.T) {
	check(
		t,
		editor.parse_editor_request,
		11,
		[]string {
			`{"protocol":11,"request_id":"r","op":"text_insert","id":"name","text":""}`,
			`{"protocol":11,"request_id":"r","op":"text_select","id":"name","anchor":0,"caret":3}`,
			`{"protocol":11,"request_id":"r","op":"text_move","id":"name","direction":"left","extend":true}`,
			`{"protocol":11,"request_id":"r","op":"text_delete","id":"name","direction":"backward"}`,
			`{"protocol":11,"request_id":"r","op":"text_submit","id":"name"}`,
			`{"protocol":11,"request_id":"r","op":"text_cancel","id":"name"}`,
			`{"protocol":11,"request_id":"r","op":"tree"}`,
		},
		[]string {
			`{"protocol":11,"request_id":"r","op":"text_insert","id":"name"}`,
			`{"protocol":11,"request_id":"r","op":"text_insert","id":"name","text":null}`,
			`{"protocol":11,"request_id":"r","op":"text_insert","id":"name","text":"x","te\u0078t":"y"}`,
			`{"protocol":11,"request_id":"r","op":"text_select","id":"name","anchor":-1,"caret":0}`,
			`{"protocol":11,"request_id":"r","op":"text_select","id":"name","anchor":1.0,"caret":0}`,
			`{"protocol":11,"request_id":"r","op":"text_move","id":"name","direction":"word","extend":false}`,
			`{"protocol":11,"request_id":"r","op":"text_submit","id":"name","value":"x"}`,
			`{"protocol":11,"request_id":"r","op":"tree"} {}`,
		},
	)
	check(
		t,
		collections.parse_collections_request,
		13,
		[]string {
			`{"protocol":13,"request_id":"r","op":"scroll_to_item","id":"4:list3:far"}`,
			`{"protocol":13,"request_id":"r","op":"tree"}`,
			`{"protocol":13,"request_id":"r","op":"find","name":"Same"}`,
		},
		[]string {
			`{"protocol":13,"protocol":13,"request_id":"r","op":"tree"}`,
			`{"protocol":13,"request_id":"r","op":"scroll_to_item","id":"04:list3:far"}`,
			`{"protocol":13,"request_id":"r","op":"scroll_to_item","id":"4:list0:"}`,
			`{"protocol":13,"request_id":"r","op":"scroll_to_item","id":"4:list3:far!"}`,
			`{"protocol":13,"request_id":"r","op":"tree","unknown":1}`,
		},
	)
	check(
		t,
		gestures.parse_gestures_request,
		14,
		[]string {
			`{"protocol":14,"request_id":"a","op":"gesture_begin","id":"drag"}`,
			`{"protocol":14,"request_id":"a","op":"gesture_aim","id":"drop","cycle":18446744073709551615}`,
			`{"protocol":14,"request_id":"a","op":"gesture_move","cycle":1,"x":12.5,"y":-4}`,
			`{"protocol":14,"request_id":"a","op":"gesture_advance","cycle":9007199254740993,"duration_ms":400}`,
			`{"protocol":14,"request_id":"a","op":"gesture_end","cycle":1}`,
			`{"protocol":14,"request_id":"a","op":"gesture_cancel","cycle":1}`,
			`{"protocol":14,"request_id":"a","op":"tree"}`,
		},
		[]string {
			`{"protocol":14,"request_id":"a","op":"gesture_end","cycle":1.0}`,
			`{"protocol":14,"request_id":"a","op":"gesture_end","cycle":18446744073709551616}`,
			`{"protocol":14,"request_id":"a","op":"gesture_end","cycle":0}`,
			`{"protocol":14,"request_id":"a","op":"gesture_end","cycle":1,"cycle":2}`,
			`{"protocol":14,"request_id":"a","op":"gesture_begin","id":"drag","cycle":1}`,
			`{"protocol":14,"request_id":"a","op":"gesture_move","cycle":1,"x":2}`,
			`{"protocol":14,"request_id":"a","op":"gesture_advance","cycle":1,"duration_ms":-1}`,
		},
	)
	for entry in ([]struct {
			parse:     proc(_: []u8) -> (debug.Request, bool),
			version:   int,
			good, bad: string,
		}{{rich.parse_rich_request, 12, `{"protocol":12,"request_id":"r","op":"tree"}`, `{"protocol":12,"request_id":"r","op":"text_insert","id":"x","text":"a"}`}, {custom.parse_custom_request, 15, `{"protocol":15,"request_id":"r","op":"tree"}`, `{"protocol":15,"request_id":"r","op":"gesture_end","cycle":1}`}, {transitions.parse_transition_request, 16, `{"protocol":16,"request_id":"r","op":"finish-transitions"}`, `{"protocol":16,"request_id":"r","op":"advance","duration_ms":1.0}`}, {accessibility.parse_accessibility_request, 17, `{"protocol":17,"request_id":"r","op":"finish-transitions"}`, `{"protocol":17,"request_id":"r","op":"tree","unexpected":true}`}, {performance.parse_performance_request, 18, `{"protocol":18,"request_id":"p","op":"text_insert","id":"name","text":"18"}`, `{"protocol":18,"request_id":"p","op":"scroll_to_item","id":"item-10000"}`}}) {check(t, entry.parse, entry.version, []string{entry.good}, []string{entry.bad})}
}
@(test)
typed_requests_keep_exact_payloads_across_parser_return :: proc(t: ^testing.T) {
	r, ok := editor.parse_editor_request(
		transmute([]u8)string(
			`{"protocol":11,"request_id":"r","op":"text_select","id":"name","anchor":0,"caret":3}`,
		),
	)
	a, valid := editor.action(
		r,
	); testing.expect(t, ok && valid && a.kind == .Select && a.anchor == 0 && a.caret == 3)
	g, gok := gestures.parse_gestures_request(
		transmute([]u8)string(
			`{"protocol":14,"request_id":"a","op":"gesture_advance","cycle":9007199254740993,"duration_ms":400}`,
		),
	)
	p, has := g.extension.(gestures.Gesture_Request); testing.expect(t, gok && has && p.action.cycle == 9007199254740993 && p.action.duration_ms == 400)
	gr, mapped := gestures.reply(
		{code = .Conflict},
		{kind = .Begin},
		.Active,
	); testing.expect(t, mapped && gr.code == .Gesture_Busy)
	_, wrong := gestures.reply(
		{code = .Conflict},
		{kind = .Aim},
		.Active,
	); testing.expect(t, !wrong)
	step, error := transitions.step(
		{op = "finish-transitions"},
		true,
	); testing.expect(t, error == "" && step.kind == .Finish_All)
	_, denied := transitions.step(
		{op = "advance", duration_ms = 1},
		false,
	); testing.expect(t, denied == "Interactive_Clock")
}
