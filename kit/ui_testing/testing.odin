package ui_testing

import base "../ui_base"
import inspect "../ui_inspect"
import ui "../ui_interaction"
import "core:fmt"
import "core:math"
import "core:testing"

State :: struct {
	focused, hovered, pressed: bool,
}
Outcome :: enum {
	None,
	Applied,
	Rejected,
}
Event_Result :: struct {
	dispatch: ui.Dispatch_Result,
	outcome:  Outcome,
}
Event_Expectation :: struct {
	target:   string,
	source:   ui.Source,
	sequence: u64,
	outcome:  Outcome,
}
message :: proc(i: ^inspect.Inspection, id, check: string) -> string {
	return fmt.tprintf(
		"%s id=%s frame=%d revision=%d published=%d ready=%v historical=%v",
		check,
		id,
		i.frame.id,
		i.model_revision,
		i.published_revision,
		i.ready,
		i.historical,
	)
}
expect_exists :: proc(t: ^testing.T, i: ^inspect.Inspection, id: string) -> bool {
	_, err := inspect.inspect(i, id)
	return testing.expect(t, err == .None, message(i, id, "expect_exists"))
}
expect_geometry :: proc(
	t: ^testing.T,
	i: ^inspect.Inspection,
	id: string,
	expected: base.Rect,
	tolerance: f64,
) -> bool {
	v, err := inspect.inspect(i, id)
	ok := err == .None && tolerance >= 0 && !math.is_nan(tolerance) && !math.is_inf(tolerance)
	if ok {
		a := v.resolved.bounds
		for delta in ([4]f64{a.x - expected.x, a.y - expected.y, a.w - expected.w, a.h - expected.h}) {
			ok = ok && !math.is_nan(delta) && !math.is_inf(delta) && math.abs(delta) <= tolerance
		}
	}
	return testing.expect(
		t,
		ok,
		message(
			i,
			id,
			fmt.tprintf(
				"expect_geometry expected=%v tolerance=%v actual=%v",
				expected,
				tolerance,
				v.resolved,
			),
		),
	)
}
expect_visible :: proc(t: ^testing.T, i: ^inspect.Inspection, id: string, expected: bool) -> bool {
	v, err := inspect.inspect(i, id)
	return testing.expect(
		t,
		err == .None && v.resolved.visible == expected,
		message(i, id, fmt.tprintf("expect_visible expected=%v", expected)),
	)
}
expect_available :: proc(
	t: ^testing.T,
	i: ^inspect.Inspection,
	id: string,
	action: inspect.Action,
	expected: inspect.Action_Status,
) -> bool {
	actual := inspect.action_status(i, id, action)
	return testing.expect(
		t,
		actual == expected,
		message(
			i,
			id,
			fmt.tprintf(
				"expect_available action=%v expected=%v actual=%v",
				action,
				expected,
				actual,
			),
		),
	)
}
expect_state :: proc(t: ^testing.T, i: ^inspect.Inspection, id: string, expected: State) -> bool {
	v, err := inspect.inspect(i, id)
	ok := err == .None
	if ok {
		n := v
		ok =
			n.focused == expected.focused &&
			n.hovered == expected.hovered &&
			n.pressed == expected.pressed
	}
	return testing.expect(t, ok, message(i, id, fmt.tprintf("expect_state expected=%v", expected)))
}
expect_no_errors :: proc(t: ^testing.T, i: ^inspect.Inspection) -> bool {
	r := inspect.strict_result(i)
	return testing.expect(
		t,
		r.ok,
		message(i, "", fmt.tprintf("expect_no_errors diagnostics=%v", r.offending_diagnostics)),
	)
}
expect_event :: proc(t: ^testing.T, result: Event_Result, expected: Event_Expectation) -> bool {
	d := result.dispatch
	ok :=
		d.code == .Applied &&
		d.has_event &&
		d.event.id == expected.target &&
		d.event.source == expected.source &&
		d.event.sequence == expected.sequence &&
		result.outcome == expected.outcome
	return testing.expect(
		t,
		ok,
		fmt.tprintf(
			"expect_event target=%s source=%v sequence=%d outcome=%v actual=%v",
			expected.target,
			expected.source,
			expected.sequence,
			expected.outcome,
			result,
		),
	)
}
