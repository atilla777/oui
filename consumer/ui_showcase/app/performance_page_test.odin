package app

import model "../model"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:testing"
import "core:time"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"

@(test)
g21_callback_counters_count_only_actual_delegated_calls :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}
	r := &f.s.runtime; p, _ := r.content.(^Performance_Page_Runtime)
	source := fonts.metrics(r.fonts); observed := performance_metrics(r, source)
	before := p.callbacks
	fm, fe := observed.font_metrics("own", 14, observed.user)
	line, le := observed.measure_line("Name", "own", 14, observed.user)
	ve, offset := observed.validate_text("Имя", "own", 14, observed.user)
	expected_fm, expected_fe := source.font_metrics("own", 14, source.user)
	expected_line, expected_le := source.measure_line("Name", "own", 14, source.user)
	expected_ve, expected_offset := source.validate_text("Имя", "own", 14, source.user)
	testing.expect(
		t,
		fm == expected_fm &&
		fe == expected_fe &&
		line == expected_line &&
		le == expected_le &&
		ve == expected_ve &&
		offset == expected_offset,
	)
	for count, i in p.callbacks {testing.expect(t, count == before[i] + 1)}
	f.s.model.measurements_off = true; before = p.callbacks
	observed = performance_metrics(r, source)
	observed.font_metrics(
		"own",
		14,
		observed.user,
	); observed.measure_line("Name", "own", 14, observed.user); observed.validate_text("Имя", "own", 14, observed.user)
	testing.expect(
		t,
		p.callbacks == before,
		"off uses the same real callbacks but adds no observer counts",
	)
}

@(test)
c03_native_tab_from_editor_can_reach_shell_not_an_empty_focus_loop :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}
	reached := false
	for _ in 0 ..< 80 {
		if f.s.runtime.interaction.focus_id == "shell/catalogue" {reached = true; break}
		page_key(&f.s, sdl.K_TAB)
	}
	testing.expect(
		t,
		reached,
		"C03 editor and virtual logical Tab stop must return to shell navigation",
	)
}

@(test)
g21_runtime_destroy_sample_is_actual_and_off_is_unavailable :: proc(t: ^testing.T) {
	for off in ([]bool{false, true}) {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Diagnostics_Performance, measurements_off = off) {return}
		measured: Phase_Sample
		destroy(&f.s.runtime, &measured)
		testing.expect(
			t,
			measured.available == !off && (off || measured.ns > 0),
			"runtime destroy must be sampled around its actual teardown, not inferred from a screenshot or whole fixture",
		)
	}
}

@(test)
g21_callback_and_operation_counters_are_observed_not_guessed :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}
	testing.expect(t, present(&f.s.runtime) && rebuild(&f.s.runtime))
	found := false
	for b in f.s.runtime.live.text.text_blocks {if b.node_id == "performance/status" {found = strings.contains(b.original_text, "callbacks=") && strings.contains(b.original_text, "operations=")}}
	testing.expect(t, found, "G21 must report actual callback and phase operation counts")
}

@(test)
g21_c03_editor_and_collection_are_visible_independent_owners :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}; s := &f.s
	_, name := layout.find(&s.runtime.live.geometry, "name/field")
	_, collection := layout.find(&s.runtime.live.geometry, "collections/viewport")
	if !testing.expect(
		t,
		name && collection,
		"G21/C03 requires the real combined editor + 10000 collection",
	) {return}
	testing.expect(t, dispatch(s, {.Activate, "collections/middle", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "collections/end", .Agent, false}))
	testing.expect(t, s.model.name.draft == "Алексей" && present(&s.runtime))
}

@(test)
g21_original_small_viewport_is_a_ready_real_drawable :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance, size = {800, 600}) {return}
	testing.expect(t, current(&f.s.runtime) && present(&f.s.runtime))
}

@(test)
g21_name_panel_does_not_overlap_shell_or_collection :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}
	n, _ := layout.find(&f.s.runtime.live.geometry, "name/field")
	c, _ := layout.find(&f.s.runtime.live.geometry, "collections/viewport")
	for id in ([]string{"collections/data-actions", "collections/reveal-actions"}) {
		row, _ := layout.find(&f.s.runtime.live.geometry, id)
		testing.expect(
			t,
			row.bounds.x + row.bounds.w < n.bounds.x,
			"collection actions must not be obscured by the editor panel",
		)
	}
	testing.expect(
		t,
		n.bounds.x >= 650 && n.bounds.y >= 248 && c.bounds.x + c.bounds.w < n.bounds.x,
		"baseline needs two readable non-overlapping panels",
	)
}

@(test)
g21_section_model_does_not_overwrite_g09_name :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}; s := &f.s
	testing.expect(t, dispatch(s, {.Focus, "name/field", .Agent, false}))
	page_key(s, sdl.K_A, {.LCTRL}); page_text(s, "Имя"); page_key(s, sdl.K_RETURN)
	testing.expect(
		t,
		s.model.name.applied == "Алексей",
		"G21 must own its section model; it must not overwrite G09",
	)
}

@(test)
g21_reproducible_on_off_costs_failure_recovery_and_cleanup :: proc(t: ^testing.T) {
	for locale in model.Locale {for off in ([]bool{false, true}) {for repetition in 0 ..< 3 {
				tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator)
				previous :=
					context.allocator; context.allocator = mem.tracking_allocator(&tracking)
				ledger: backend.Resource_Ledger
				f: Page_Fixture
				started := time.tick_now()
				ok := start_page_fixture(
					t,
					&f,
					.Diagnostics_Performance,
					&ledger,
					locale = locale,
					measurements_off = off,
				)
				cold_ns := i64(time.tick_since(started))
				if ok {
					s := &f.s
					testing.expect(t, rebuild(&s.runtime) && present(&s.runtime))
					g21_log_sample(s, "idle", repetition)
					testing.expect(t, dispatch(s, {.Focus, "name/field", .Agent, false}))
					page_key(s, sdl.K_A, {.LCTRL}); page_text(s, "Имя")
					g21_log_sample(s, "insert", repetition)
					page_key(s, sdl.K_RETURN)
					g21_log_sample(s, "submit", repetition)
					testing.expect(
						t,
						s.model.performance_name.applied == "Имя" &&
						s.performance_collection.selected == 0,
					)
					testing.expect(
						t,
						dispatch(s, {.Activate, "collections/middle", .Agent, false}),
					)
					g21_log_sample(s, "reveal-05000", repetition)
					testing.expect(t, dispatch(s, {.Activate, "collections/end", .Agent, false}))
					g21_log_sample(s, "reveal-10000", repetition)
					testing.expect(
						t,
						dispatch(s, {.Activate, "10:collection10:item-10000", .Agent, false}),
					)
					g21_log_sample(s, "activate-10000", repetition)
					for size in ([]layout.Extent{{960, 720}, {800, 600}, {960, 720}, {1280, 960}}) {
						s.drawable, s.runtime.drawable = size, size
						// Fixed software output cannot resize: real validators must refuse
						// mismatched candidate/output. Positive native resize is ISD-only.
						built := rebuild(&s.runtime)
						if size.w ==
						   1280 {testing.expect(t, built && current(&s.runtime))} else {testing.expect(t, !built && !current(&s.runtime) && s.runtime.error == .Publish)}
						g21_log_sample(s, "fixed-software-output-size-guard", repetition)
					}
					testing.expect(
						t,
						s.performance_collection.selected == 10000 &&
						s.model.performance_name.applied == "Имя",
					)
					before := s.model.effects
					s.runtime.fault = .Copy; started = time.tick_now()
					testing.expect(t, !rebuild(&s.runtime))
					failure_ns := i64(time.tick_since(started)); started = time.tick_now()
					testing.expect(
						t,
						recover(s) && present(&s.runtime) && s.model.effects == before,
					)
					recovery_ns := i64(time.tick_since(started))
					p, _ := s.runtime.content.(^Performance_Page_Runtime)
					for phase in Performance_Phase {testing.expect(t, p.samples[phase].available == !off)}
					for count in p.callbacks {testing.expect(t, (count > 0) == !off)}
					for count in p.operations {testing.expect(t, (count > 0) == !off)}
					g21_log_sample(s, "recovery", repetition)
					low, high := max(i64), i64(0)
					for equivalent in 0 ..< 8 {
						testing.expect(t, rebuild(&s.runtime) && present(&s.runtime))
						live := tracking.current_memory_allocated
						low, high = min(low, live), max(high, live)
						fmt.printf(
							"G21 retained equivalent=%d off=%t live=%d\n",
							equivalent,
							off,
							live,
						)
					}
					// Decimal timing/counter strings vary in width; the fixed bounded
					// observation is not retained frame history (off has fixed labels).
					testing.expect(t, high - low < 256)
					fmt.printf(
						"G21 locale=%v off=%t repetition=%d size=1280x960 scale=1 mode=Normal revision=%d effects=%d selected=%d failure_ns=%d recovery_ns=%d phases=%v\n",
						locale,
						off,
						repetition,
						s.model.revision,
						s.model.effects,
						s.performance_collection.selected,
						failure_ns,
						recovery_ns,
						p.samples,
					)
				}
				started = time.tick_now()
				stop_page_fixture(&f)
				destroy_ns := i64(time.tick_since(started))
				fmt.printf(
					"G21 observer destroy_ns=%d off=%t (whole fixture; includes software renderer/TTF shutdown)\n",
					destroy_ns,
					off,
				)
				context.allocator = previous
				fmt.printf(
					"G21 locale=%v off=%t repetition=%d cold_ns=%d allocations=%d bytes=%d live=%d peak=%d native_created=%d native_destroyed=%d native_live=%d bad_frees=%d\n",
					locale,
					off,
					repetition,
					cold_ns,
					tracking.total_allocation_count,
					tracking.total_memory_allocated,
					tracking.current_memory_allocated,
					tracking.peak_memory_allocated,
					ledger.created,
					ledger.destroyed,
					ledger.live,
					len(tracking.bad_free_array),
				)
				testing.expect(
					t,
					tracking.current_memory_allocated == 0 &&
					len(tracking.bad_free_array) == 0 &&
					ledger.live == 0 &&
					ledger.created == ledger.destroyed,
				)
				mem.tracking_allocator_destroy(&tracking)
			}}}
}

g21_log_sample :: proc(s: ^Shell, action: string, repetition: int) {
	if s.drawable == (layout.Extent{1280, 960}) {present(&s.runtime)}
	p, selected := s.runtime.content.(^Performance_Page_Runtime); if !selected {return}
	fmt.printf(
		"G21 sample fixture=software action=%s repetition=%d locale=%v off=%t drawable=%v scale=%v mode=Normal revision=%d effects=%d phases=%v callbacks=%v operations=%v\n",
		action,
		repetition,
		s.model.locale,
		s.model.measurements_off,
		s.drawable,
		s.model.scale,
		s.model.revision,
		s.model.effects,
		p.samples,
		p.callbacks,
		p.operations,
	)
}

@(test)
g21_instrumentation_toggle_is_an_app_owned_setting :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}; s := &f.s
	before := s.model.effects
	testing.expect(t, dispatch(s, {.Activate, "performance/instrumentation", .Agent, false}))
	testing.expect(
		t,
		s.model.effects == before + 1,
		"instrumentation off must be a real controlled setting, not a decorative button",
	)
}
