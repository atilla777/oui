package app

import model "../model"
import "core:fmt"
import "core:strings"
import "core:testing"
import assessment "ui:ui_accessibility/inspect"
import projection "ui:ui_accessibility/projection"
import base "ui:ui_base"
import controls "ui:ui_controls"
import hold "ui:ui_hold"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import style "ui:ui_style"
import transitions "ui:ui_transitions"
import wire "ui:ui_wire"

@(test)
g18_supported_resize_round_trip_keeps_current :: proc(t: ^testing.T) {
	for locale in model.Locale {
		for size in ([][2]i32{{1200, 900}, {1280, 960}}) {
			f: Page_Fixture
			if !start_page_fixture(
				t,
				&f,
				.Accessibility,
				size = size,
				locale = locale,
			) {stop_page_fixture(&f); return}
			testing.expect(t, current(&f.s.runtime) && present(&f.s.runtime))
			stop_page_fixture(&f)
		}
		f: Page_Fixture
		if !start_page_fixture(
			t,
			&f,
			.Accessibility,
			locale = locale,
		) {stop_page_fixture(&f); return}
		before := f.s.model
		f.s.runtime.drawable = {800, 600}
		testing.expect(
			t,
			!rebuild(&f.s.runtime) && !current(&f.s.runtime),
			"tight G18 must retain the real overflow refusal, not shrink text or waive diagnostics",
		)
		testing.expect(t, f.s.model == before)
		stop_page_fixture(&f)
	}
}

@(test)
g18_native_resize_uses_a_meaningful_supported_viewport_not_the_tight_negative :: proc(
	t: ^testing.T,
) {
	w, h := test_resize_extent(.Accessibility, 1280)
	testing.expect(t, w == 1200 && h == 900)
	w, h = test_resize_extent(.Accessibility, 1200)
	testing.expect(t, w == 1280 && h == 960)
	w, h = test_resize_extent(.Controls, 960)
	testing.expect(t, w == 800 && h == 600, "F2 original native matrix must not change")
	w, h = test_resize_extent(.World, 1280)
	testing.expect(
		t,
		w == 1200 && h == 900,
		"G19 fixed-size world samples use the supported positive resize",
	)
	w, h = test_resize_extent(.Diagnostics_Performance, 1280)
	testing.expect(
		t,
		w == 1200 && h == 900,
		"G21 independent editor/collection retains readable positive geometry",
	)
}

@(test)
g18_selected_normal_and_opt_in_strict_are_visible_without_disabling_actions :: proc(
	t: ^testing.T,
) {
	for locale in model.Locale {
		f: Page_Fixture
		if !start_page_fixture(
			t,
			&f,
			.Accessibility,
			locale = locale,
		) {stop_page_fixture(&f); return}
		s := &f.s
		for strict in ([]bool{false, true, false}) {
			if s.model.accessibility.strict !=
			   strict {testing.expect(t, dispatch(s, {.Activate, "accessibility/strict", .Agent, false}))}
			testing.expect(t, rebuild(&s.runtime) && present(&s.runtime))
			v, _ := s.runtime.live.content.(Accessibility_Page_Reader)
			result := assessment.accessibility_strict_result(&v.assessment.value)
			testing.expect(t, result.warning_count > 0 && !result.ok && !result.coverage_complete)
			status, mode := "", ""
			for b in s.runtime.live.text.text_blocks {
				if b.node_id == "accessibility/status" {status = b.original_text}
				if b.node_id == "accessibility/strict-label" {mode = b.original_text}
			}
			expected := "Normal"; if strict {expected = "Strict"}
			if locale ==
			   .Russian {expected = "Обычный"; if strict {expected = "Строгий"}}
			testing.expect(t, mode == expected, "selected assessment mode must be visible")
			selected_ok := result.ok if strict else result.legacy.ok
			testing.expect(
				t,
				strings.contains(
					status,
					"selected-ok=true" if selected_ok else "selected-ok=false",
				),
				"use the existing selected result; genuine common diagnostics still fail normal",
			)
			testing.expect(
				t,
				strings.contains(status, "coverage=false"),
				"Unassessed never becomes a conformance claim",
			)
			if s.model.accessibility.mode !=
			   .Dialog {testing.expect(t, dispatch(s, {.Activate, "accessibility/mode", .Agent, false}))}
			before := s.model.effects
			testing.expect(t, dispatch(s, {.Activate, "accessibility/action", .Agent, false}))
			testing.expect(
				t,
				dispatch(s, {.Activate, "20:accessibility/dialog7:confirm", .Agent, false}),
			)
			testing.expect(
				t,
				s.model.effects == before + 1,
				"Warning and strict failure do not disable ordinary confirmation",
			)
		}
		stop_page_fixture(&f)
	}
}

@(test)
g18_warning_only_capture_passes_normal_selected_check_not_accessibility_strict :: proc(
	t: ^testing.T,
) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	g, e := layout.prepare(
		[]layout.Node {
			{
				id = "warning",
				role = .Box,
				enabled = true,
				visible = true,
				layout = {x = {mode = .Fixed, value = 40}, y = {mode = .Fixed, value = 40}},
			},
		},
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	)
	defer layout.destroy_frame(&g)
	if !testing.expect(t, e.code == .None && len(g.diagnostics) == 0) {return}
	i, code := interaction.prepare(
		&g,
		[]interaction.Target{{"warning", "button", true, true}},
		nil,
		context.allocator,
	)
	defer interaction.destroy_candidate(&i)
	if !testing.expect(t, code == .Applied) {return}
	n := g.nodes[0]
	nodes := [1]wire.Resolved_Node {
		{
			description = {
				id = "warning",
				text = "Warning",
				role = .Button,
				enabled = true,
				visible = true,
				layout = n.description.layout,
			},
			bounds = n.bounds,
			content = n.content,
			clip = n.clip,
			paint_clip = n.paint_clip,
			enabled = true,
			visible = true,
			availability = .Applied,
			style = {
				foreground = {255, 255, 255, 255},
				background = {255, 255, 255, 255},
				font_size = 16,
			},
		},
	}
	view := projection.Frame {
		nodes    = nodes[:],
		id       = g.id,
		stamp    = g.stamp,
		drawable = g.drawable,
		ui_scale = g.ui_scale,
	}
	value, ae := assessment.capture_accessibility(
		{
			frame = &view,
			common = {
				frame = &g,
				interaction = &i,
				ready = true,
				model_revision = 1,
				published_revision = 1,
			},
		},
		assessment.default_accessibility_policy(),
		context.allocator,
		u64(1),
		u64(1),
	)
	defer assessment.destroy_accessibility_inspection(&value)
	if !testing.expect(t, ae == .None) {return}
	result := assessment.accessibility_strict_result(&value)
	testing.expect(t, result.legacy.ok && result.warning_count > 0 && !result.ok)
	generation := Assessment_Generation {
		value = value,
	}
	a: Accessibility_Page_Runtime
	m: model.Model
	r := Runtime {
		model = &m,
		content = &a,
		live = Reader{content = Accessibility_Page_Reader{assessment = &generation}},
	}
	for strict in ([]bool{false, true}) {
		m.accessibility.strict = strict
		c: Page_Composition; c.nt = 1; c.texts[0].id = "accessibility/status"
		compose_accessibility_status(&r, &c)
		testing.expect(
			t,
			strings.contains(
				c.texts[0].text,
				"selected-ok=false" if strict else "selected-ok=true",
			),
			"real contrast Warning fails only opt-in accessibility strict, not normal",
		)
	}
}

@(test)
g18_dialog_has_readable_opaque_panel_away_from_shell_text :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Accessibility) {return}
	testing.expect(
		t,
		dispatch(&f.s, {.Activate, "accessibility/mode", .Agent, false}) &&
		dispatch(&f.s, {.Activate, "accessibility/action", .Agent, false}),
	)
	id := f.s.runtime.controls.frame.controls[0].node_id
	n, found := layout.find(&f.s.runtime.live.geometry, id)
	testing.expect(
		t,
		found && n.bounds.w >= 320 && n.bounds.y >= 300 && n.bounds.h >= 100,
		"G18 confirmation must be a readable panel, not tiny text over the shell heading",
	)
	opaque := false
	for p in f.s.runtime.live.paint.presentation {if p.id == id {opaque = p.computed[.Background].value.(style.Color)[3] == 255}}
	testing.expect(t, opaque && present(&f.s.runtime))
}

@(test)
c08_selected_projection_has_real_rich_editor_scroll_gesture_fixtures :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Accessibility) {return}
	for id in ([]string{"accessibility/c08-rich", "accessibility/c08-editor", "accessibility/c08-scroll", "accessibility/c08-gesture"}) {
		_, found := layout.find(&f.s.runtime.live.geometry, id)
		testing.expect(t, found, "C08 must project actual selected family fixtures")
	}
	v, selected := f.s.runtime.live.content.(Accessibility_Page_Reader)
	testing.expect(
		t,
		selected &&
		v.c08 != nil &&
		len(v.c08.rich.rich_blocks) == 1 &&
		len(v.c08.editor.editors) == 1 &&
		len(v.c08.gestures.gestures) == 1 &&
		len(f.s.runtime.live.scroll.regions) == 1,
	)
	runs := 0
	for record in v.assessment.value.records {if record.id == "accessibility/c08-rich" && record.check == .Contrast {runs += 1}}
	testing.expect(t, runs >= 2, "rich assessment must consume the actual styled runs")
	testing.expect(t, present(&f.s.runtime))
}

@(test)
g18_clipped_target_assesses_visible_twenty_not_layout_forty :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Accessibility) {return}
	n, found := layout.find(&f.s.runtime.live.geometry, "accessibility/clipped-target")
	if !testing.expect(t, found, "G18 must retain the original clipped target fixture") {return}
	testing.expect(t, n.bounds.w == 40 && n.paint_clip.w == 20)
	v, _ := f.s.runtime.live.content.(Accessibility_Page_Reader)
	assessed := false
	for record in v.assessment.value.records {if record.id == "accessibility/clipped-target" && record.check == .Target_Size {assessed = record.status == .Warning}}
	testing.expect(t, assessed && present(&f.s.runtime))
}

@(test)
g18_assessment_is_a_real_page_with_confirm_alternative :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(
		t,
		&f,
		.Accessibility,
	) {fmt.eprintf("accessibility entry fault=%v diagnostic=%v\n", f.s.runtime.error, f.s.runtime.diagnostic); return}; s := &f.s
	_, good := layout.find(&s.runtime.live.geometry, "accessibility/good")
	_, bad := layout.find(&s.runtime.live.geometry, "accessibility/bad")
	if !testing.expect(t, good && bad, "G18 requires real assessed good/bad samples") {return}
	testing.expect(t, dispatch(s, {.Activate, "accessibility/mode", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "accessibility/action", .Agent, false}))
	initial, ok := controls.item_node_id(
		"accessibility/dialog",
		"cancel",
		context.allocator,
	); defer delete(initial)
	testing.expect(t, ok && s.runtime.interaction.focus_id == initial)
	testing.expect(t, present(&s.runtime))
}

@(test)
g18_bad_and_unassessed_have_readable_separate_labels :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Accessibility) {return}
	_, bad := layout.find(&f.s.runtime.live.geometry, "accessibility/bad-description")
	_, unknown := layout.find(&f.s.runtime.live.geometry, "accessibility/unknown-description")
	testing.expect(
		t,
		bad && unknown,
		"invisible bad text and unknown custom background need separate readable explanations",
	)
}

@(test)
g18_departure_cancels_pending_token_without_completion :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Accessibility) {return}; s := &f.s
	n, _ := layout.find(&s.runtime.live.geometry, "accessibility/action")
	page_pointer(s, .MOUSE_BUTTON_DOWN, n.bounds.x + n.bounds.w / 2, n.bounds.y + n.bounds.h / 2)
	testing.expect(t, s.model.accessibility.pending_token != 0)
	testing.expect(t, dispatch(s, {.Activate, "shell/catalogue", .Agent, false}))
	testing.expect(
		t,
		s.model.accessibility.pending_token == 0 && s.model.accessibility.counter == 0,
		"leaving must cancel, never preserve or confirm the token",
	)
}

@(test)
g18_assessment_tokens_hold_dialog_and_cold_cancel :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Accessibility) {return}; s := &f.s; r := &s.runtime
	v, _ := r.live.content.(Accessibility_Page_Reader)
	good, bad, unknown := false, false, false
	for record in v.assessment.value.records {if record.check == .Contrast {
			if record.id ==
			   "accessibility/good" {good = record.status == .Pass && record.ratio.? == 21}
			if record.id == "accessibility/bad" {bad = record.status == .Warning}
			if record.id == "accessibility/unknown" {unknown = record.status == .Unassessed}
		}}
	if !testing.expect(
		t,
		good && bad && unknown,
	) {for record in v.assessment.value.records {fmt.eprintf("assessment %s %v %v ratio=%v reason=%s\n", record.id, record.check, record.status, record.ratio, record.reason)}}
	testing.expect(t, !assessment.accessibility_strict_result(&v.assessment.value).ok)
	n, _ := layout.find(&r.live.geometry, "accessibility/action")
	page_pointer(s, .MOUSE_BUTTON_DOWN, n.bounds.x + n.bounds.w / 2, n.bounds.y + n.bounds.h / 2)
	h, _ := active_hold(r)
	testing.expect(t, h.state.live.phase == .Holding && s.model.accessibility.pending_token == 1)
	x := hold.dispatch(
		&h.state,
		&r.interaction,
		{kind = .Advance, source = .Mouse, duration_ms = 999},
	); accept_hold(r, reader_stamp(&r.live), x)
	testing.expect(t, rebuild(r) && s.model.accessibility.counter == 0)
	x = hold.dispatch(
		&h.state,
		&r.interaction,
		{kind = .Advance, source = .Mouse, duration_ms = 1},
	); accept_hold(r, reader_stamp(&r.live), x)
	testing.expect(t, rebuild(r) && s.model.accessibility.counter == 1 && s.model.effects == 1)
	page_pointer(s, .MOUSE_BUTTON_UP, n.bounds.x + n.bounds.w / 2, n.bounds.y + n.bounds.h / 2)
	testing.expect(t, dispatch(s, {.Activate, "accessibility/mode", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "accessibility/action", .Agent, false}))
	id, _ := controls.item_node_id(
		"accessibility/dialog",
		"confirm",
		context.allocator,
	); defer delete(id)
	testing.expect(t, dispatch(s, {.Activate, id, .Agent, false}))
	testing.expect(
		t,
		s.model.accessibility.counter == 2 &&
		s.model.accessibility.requests == 2 &&
		s.model.effects == 2,
	)
	testing.expect(t, dispatch(s, {.Activate, "accessibility/reduced", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "accessibility/target", .Agent, false}))
	v, _ = r.live.content.(Accessibility_Page_Reader)
	g, found := transitions.geometry(&v.visual, "transitions/card")
	testing.expect(t, found && g.scale == .8 && g.opacity == .6)
	old, copied := copy_reader(
		&r.live,
		r.allocator,
	); if !testing.expect(t, copied) {return}; defer destroy_reader(&old)
	testing.expect(t, dispatch(s, {.Activate, "shell/catalogue", .Agent, false}))
	testing.expect(t, draw_reader(&old))
}

@(test)
g18_reduced_motion_is_not_only_a_label :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Accessibility) {return}; s := &f.s
	_, found := layout.find(&s.runtime.live.geometry, "transitions/card")
	testing.expect(t, found, "G18 reduced motion must control an actual visual transition")
}
