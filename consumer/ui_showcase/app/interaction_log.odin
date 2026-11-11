package app

import "core:fmt"

// Ordinary bounded state observations on stdout, not a command endpoint. The
// display harness records these separately from non-atomic external PNGs.
log_interaction :: proc(s: ^Shell) {
	if p, selected := s.runtime.content.(^Performance_Page_Runtime); selected {
		fmt.printf(
			"performance locale=%v off=%t drawable=%v scale=%v revision=%d effects=%d draft=%q applied=%q selected=%d samples=%v callbacks=%v operations=%v counters_available=%t scope=consumer-CPU-submission GPU-time=unavailable SDL-heap=unavailable\n",
			s.model.locale,
			s.model.measurements_off,
			s.drawable,
			s.model.scale,
			s.model.revision,
			s.model.effects,
			s.model.performance_name.draft,
			s.model.performance_name.applied,
			s.performance_collection.selected,
			p.samples,
			p.callbacks,
			p.operations,
			!s.model.measurements_off,
		)
	}
	fmt.printf(
		"names draft=%q applied=%q gesture_draft=%q gesture_applied=%q\n",
		s.model.name.draft,
		s.model.name.applied,
		s.model.gesture_name.draft,
		s.model.gesture_name.applied,
	)
	fmt.printf(
		"interaction table_set=%d table_fixture=%d table_selected=%d collection_count=%d collection_selected=%d collection_mode=%v hp=%d restore_count=%d layers=%d,%d,%d cards=%d,%d\n",
		s.model.table_dataset,
		s.model.table_fixture,
		s.model.table_selected,
		s.collection.count,
		s.collection.selected,
		s.collection.mode,
		s.model.hud_hp,
		s.model.hud_count,
		s.model.layer_counts[0],
		s.model.layer_counts[1],
		s.model.layer_counts[2],
		s.gesture.panels[0].count,
		s.gesture.panels[1].count,
	)
	if n, ok := active_name(&s.runtime);
	   ok {fmt.printf("editor error=%v rejection=%v active=%t capture=%q\n", n.native_error, n.rejection, n.input.text_active, n.input.capture_id)}
	if h, ok := s.runtime.content.(^Hold_Page_Runtime);
	   ok {fmt.printf("hold phase=%v elapsed=%d depth=%d popup=%t tooltip=%t cancel=%t\n", h.state.live.phase, h.state.live.elapsed_ms, h.depth, h.popup, h.tooltip, h.cancel_allowed)}
	if g, ok := s.runtime.content.(^Gesture_Page_Runtime);
	   ok {fmt.printf("gesture phase=%v target=%q accepted=%t outcome=%v\n", g.state.live.phase, g.state.live.target_id, g.state.live.target_accepted, g.outcome.reason)}
}
