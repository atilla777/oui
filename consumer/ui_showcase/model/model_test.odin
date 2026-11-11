package showcase_model

import "core:testing"

@(test)
controlled_values_and_process_state :: proc(t: ^testing.T) {
	m := initial()
	testing.expect(t, m.page == .Catalogue && !m.checkbox && !m.toggle && m.slider == 50)
	testing.expect(t, apply(&m, {kind = .Controls}))
	testing.expect(t, apply(&m, {kind = .Checkbox, boolean = true}))
	testing.expect(t, apply(&m, {kind = .Toggle, boolean = true}))
	testing.expect(t, apply(&m, {kind = .Slider, integer = 100}))
	testing.expect(t, apply(&m, {kind = .Language}))
	testing.expect(t, apply(&m, {kind = .Scale}))
	testing.expect(t, apply(&m, {kind = .Layout}))
	testing.expect(t, apply(&m, {kind = .Catalogue}))
	testing.expect(t, apply(&m, {kind = .Controls}))
	testing.expect(
		t,
		m.checkbox && m.toggle && m.slider == 100 && m.locale == .English && m.scale == 1.5,
	)
	testing.expect(t, m.effects == 9 && m.revision == 9)
	before := m
	testing.expect(t, !apply(&m, {kind = .Slider, integer = 101}) && m == before)
	testing.expect(t, !apply(&m, {kind = .Slider, integer = -1}) && m == before)
	testing.expect(t, !apply(&m, {kind = .Mode}) && m == before)
}

@(test)
mode_refusal_and_overflow_are_atomic :: proc(t: ^testing.T) {
	m := initial()
	testing.expect(t, apply(&m, {kind = .Mode}))
	before := m
	testing.expect(t, !apply(&m, {kind = .Scale}) && m == before)
	m.revision = max(u64); before = m
	testing.expect(t, !apply(&m, {kind = .Language}) && m == before)
}

@(test)
composition_counter_refusals_never_apply_half_a_routed_outcome :: proc(t: ^testing.T) {
	for failing_parent in ([2]bool{false, true}) {
		m := initial(); m.page = .Composition; m.composition.stop = false
		if failing_parent {m.composition.parent_count = max(u64)} else {m.composition.child_count = max(u64)}
		before := m
		testing.expect(t, !apply(&m, {kind = .Gallery, id = "composition/child"}) && m == before)
	}
	m := initial(); m.page = .Composition; m.composition.child_present = false
	before := m
	testing.expect(t, !apply(&m, {kind = .Gallery, id = "composition/child"}) && m == before)
}

@(test)
hud_clamp_and_styling_disabled_or_exhausted_counters_are_atomic :: proc(t: ^testing.T) {
	m := initial(); m.page = .Hud
	for _ in 0 ..< 12 {testing.expect(t, apply(&m, {kind = .Gallery, id = "hud/minus"}))}
	testing.expect(t, m.hud_hp == 0)
	for _ in 0 ..< 12 {testing.expect(t, apply(&m, {kind = .Gallery, id = "hud/plus"}))}
	testing.expect(t, m.hud_hp == 100)
	m.hud_count = max(u64); before := m
	testing.expect(t, !apply(&m, {kind = .Gallery, id = "hud/restore"}) && m == before)
	m = initial(); m.page = .Styling
	testing.expect(t, apply(&m, {kind = .Gallery, id = "styling/count"}) && m.styling.count == 1)
	for id in ([3]string{"styling/theme", "styling/fallback", "styling/selected"}) {
		testing.expect(t, apply(&m, {kind = .Gallery, id = id}) && m.styling.count == 1)
	}
	testing.expect(t, apply(&m, {kind = .Gallery, id = "styling/disabled"}))
	before = m
	testing.expect(t, !apply(&m, {kind = .Gallery, id = "styling/count"}) && m == before)
	m.styling.disabled = false; m.styling.count = max(u64); before = m
	testing.expect(t, !apply(&m, {kind = .Gallery, id = "styling/count"}) && m == before)
}
