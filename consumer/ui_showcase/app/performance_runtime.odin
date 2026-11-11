package app

import "core:fmt"
import "core:time"
import text "ui:ui_text"

// Consumer-only qualification build. No kit API, transport or release observer.
QUALIFICATION :: TEST && #config(UI_QUALIFICATION, false)
when QUALIFICATION {
	Qualification_Samples :: struct {
		phases: [Performance_Phase]Phase_Sample,
	}
} else {
	Qualification_Samples :: struct {}
}

Performance_Phase :: enum {
	Prepare,
	Copy,
	Commit,
	Draw,
	Readback,
	Present,
}
Phase_Sample :: struct {
	ns:        i64,
	available: bool,
}
destroy_sample_end :: proc(start: time.Tick, enabled: bool) -> Phase_Sample {
	if !enabled {return {}}
	return {i64(time.tick_since(start)), true}
}
Performance_Page_Runtime :: struct {
	diagnostic:   Diagnostic_Observation,
	samples:      [Performance_Phase]Phase_Sample,
	sample_count: u64,
	operations:   [Performance_Phase]u64,
	callbacks:    [3]u64, // font metrics, line measurement, glyph validation
	metrics:      text.Text_Layout_Metrics,
	buffer:       [512]u8,
	editing:      Name_Page_Runtime,
	collection:   Collection_Page_Runtime,
}
performance_metrics :: proc(
	r: ^Runtime,
	source: text.Text_Layout_Metrics,
) -> text.Text_Layout_Metrics {
	p, selected := r.content.(^Performance_Page_Runtime)
	if !selected || r.model.measurements_off {return source}
	p.metrics = source
	return {performance_font_metrics, performance_measure_line, performance_validate_text, p}
}
performance_font_metrics :: proc(
	id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Font_Metrics,
	text.Text_Metric_Error,
) {
	p := cast(^Performance_Page_Runtime)user
	if p.callbacks[0] < max(u64) {p.callbacks[0] += 1}
	return p.metrics.font_metrics(id, size, p.metrics.user)
}
performance_measure_line :: proc(
	value, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Line_Metrics,
	text.Text_Metric_Error,
) {
	p := cast(^Performance_Page_Runtime)user
	if p.callbacks[1] < max(u64) {p.callbacks[1] += 1}
	return p.metrics.measure_line(value, id, size, p.metrics.user)
}
performance_validate_text :: proc(
	value, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Metric_Error,
	int,
) {
	p := cast(^Performance_Page_Runtime)user
	if p.callbacks[2] < max(u64) {p.callbacks[2] += 1}
	return p.metrics.validate_text(value, id, size, p.metrics.user)
}
sample_begin :: proc(r: ^Runtime) -> time.Tick {
	when QUALIFICATION {
		if r.model == nil || r.model.measurements_off {return {}}
		return time.tick_now()
	}
	if p, selected := r.content.(^Performance_Page_Runtime);
	   selected && r.model.measurements_off {p.samples = {}; return {}}
	if _, selected := r.content.(^Performance_Page_Runtime);
	   selected && !r.model.measurements_off {return time.tick_now()}
	return {}
}
sample_end :: proc(r: ^Runtime, phase: Performance_Phase, start: time.Tick) {
	when QUALIFICATION {
		if r.model == nil || r.model.measurements_off {
			r.qualification.phases[phase] = {}
		} else {
			r.qualification.phases[phase] = {i64(time.tick_since(start)), true}
		}
	}
	if p, selected := r.content.(^Performance_Page_Runtime); selected {
		if r.model.measurements_off {p.samples[phase] = {}; return}
		p.samples[phase] = {i64(time.tick_since(start)), true}
		if p.operations[phase] < max(u64) {p.operations[phase] += 1}
		if p.sample_count < max(u64) {p.sample_count += 1}
	}
}
compose_performance_status :: proc(r: ^Runtime, c: ^Page_Composition) {
	if p, selected := r.content.(^Performance_Page_Runtime); selected {
		message := fmt.bprintf(
			p.buffer[:],
			"CPU ns p/c/k/d/r/p=%d/%d/%d/%d/%d/%d; callbacks=%v operations=%d; GPU/SDL heap unavailable",
			p.samples[.Prepare].ns,
			p.samples[.Copy].ns,
			p.samples[.Commit].ns,
			p.samples[.Draw].ns,
			p.samples[.Readback].ns,
			p.samples[.Present].ns,
			p.callbacks,
			p.sample_count,
		)
		if !p.samples[.Present].available {message = "CPU phase samples unavailable until first complete frame; GPU time and SDL heap unavailable" if r.model.locale == .English else "Фазы CPU недоступны до первого полного кадра; время GPU и память SDL недоступны"}
		if r.model.measurements_off {message = "Instrumentation off: all phase/callback metrics unavailable" if r.model.locale == .English else "Измерения выключены: фазы и счётчики недоступны"}
		if p.diagnostic.has {message = diagnostic_message(r, p)}
		for &t in c.texts[:c.nt] {if t.id == "performance/status" {t.text = message; t.options = {
					wrap              = .WordWrap,
					overflow          = .Clip,
					overflow_expected = true,
				}}}
		c.initial_focus = "name/field"
	}
}
Performance_Page_Reader :: struct {
	editing:    Name_Page_Reader,
	collection: Collection_Page_Reader,
}
active_collection :: proc(r: ^Runtime) -> (^Collection_Page_Runtime, bool) {
	if c, selected := r.content.(^Collection_Page_Runtime); selected {return c, true}
	if p, selected := r.content.(^Performance_Page_Runtime); selected {return &p.collection, true}
	return nil, false
}
