package ui_transitions

import "core:testing"

@(test)
exact_delay_easing_endpoints_and_invalid_time :: proc(t: ^testing.T) {
	for easing, index in ([]Easing{.Linear, .Ease_In, .Ease_Out, .Ease_In_Out}) {
		halves := [4]f64{.5, .25, .75, .5}
		for elapsed, j in ([]i64{199, 200, 700, 1200, max(i64)}) {
			want := f64(0)
			if j == 2 {want = halves[index]}
			if j >= 3 {want = 1}
			value, valid := sample(
				0,
				1,
				{duration_ms = 1000, delay_ms = 200, easing = easing},
				elapsed,
			)
			testing.expect(t, valid && value == want)
		}
	}
	_, valid := sample(0, 1, {duration_ms = max(i64), delay_ms = 1}, 1)
	testing.expect(t, !valid)
	value, valid_zero := sample(3, 8, {delay_ms = 2}, 2)
	testing.expect(t, valid_zero && value == 8)
}
