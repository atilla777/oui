package ui_transitions

import base "../ui_base"
import "core:mem"

Property :: enum {
	Foreground,
	Background,
	Border,
	Opacity,
	Offset,
	Scale,
	Progress,
}
Value :: union {
	f64,
	[2]f64,
	[4]f64,
}
Easing :: enum {
	Linear,
	Ease_In,
	Ease_Out,
	Ease_In_Out,
}
Timing :: struct {
	duration_ms, delay_ms: i64,
	easing:                Easing,
}
Endpoints :: struct {
	enter, exit: Value,
}
Track :: struct {
	property: Property,
	target:   Value,
	timing:   Timing,
	presence: Maybe(Endpoints),
}
Description :: struct {
	node_id: string,
	present: Maybe(bool),
	tracks:  []Track,
}
Presence_Phase :: enum {
	Hidden,
	Entering,
	Visible,
	Exiting,
}
Phase :: enum {
	Delayed,
	Active,
	Completed,
}
View :: struct {
	node_id:                string,
	property:               Property,
	start, current, target: Value,
	timing:                 Timing,
	elapsed_ms:             i64,
	phase:                  Phase,
	presence_track:         bool,
}
Presence :: struct {
	node_id: string,
	present: bool,
	phase:   Presence_Phase,
}
Step_Kind :: enum {
	Advance,
	Finish_All,
}
Step :: struct {
	kind:     Step_Kind,
	delta_ms: i64,
}
Stage :: enum {
	Descriptor,
	Sample,
	Prepare,
	Bind,
	Copy,
	Commit,
}
Error_Code :: enum {
	None,
	Descriptor,
	Time,
	Allocation,
	Stale,
	Exhausted,
	Geometry,
	Binding,
}
Error :: struct {
	code:     Error_Code,
	node_id:  string,
	property: Property,
	stage:    Stage,
}
Frame :: struct {
	bindings:              []string,
	tracks:                []View,
	presences:             []Presence,
	entries:               []base.Geometry_Entry,
	stamp:                 base.Frame_Stamp,
	drawable:              base.Extent,
	ui_scale:              f64,
	storage:               ^mem.Rollback_Stack,
	allocator:             mem.Allocator,
	bound, reduced_motion: bool,
}
State :: struct {
	frame:                Frame,
	identity:             ^base.Lifetime,
	version, clock_epoch: u64,
	allocator:            mem.Allocator,
}
Candidate :: struct {
	frame:    Frame,
	identity: ^base.Lifetime,
	version:  u64,
}
create :: proc(a := context.allocator) -> State {return {allocator = a}}
sample :: proc(start, target: f64, timing: Timing, elapsed_ms: i64) -> (f64, bool) {
	if !base.finite(start) ||
	   !base.finite(target) ||
	   elapsed_ms < 0 ||
	   !timing_valid(timing) {return 0, false}
	if elapsed_ms < timing.delay_ms {return start, true}
	if elapsed_ms <= timing.delay_ms && timing.duration_ms > 0 {return start, true}
	if timing.duration_ms == 0 ||
	   elapsed_ms >= timing.delay_ms + timing.duration_ms {return target, true}
	u := f64(elapsed_ms - timing.delay_ms) / f64(timing.duration_ms)
	switch timing.easing {
	case .Linear:
	case .Ease_In:
		u *= u
	case .Ease_Out:
		u = 1 - (1 - u) * (1 - u)
	case .Ease_In_Out:
		u = 3 * u * u - 2 * u * u * u
	}
	return start * (1 - u) + target * u, true
}
timing_valid :: proc(t: Timing) -> bool {return(
		t.duration_ms >= 0 &&
		t.delay_ms >= 0 &&
		t.duration_ms <= max(i64) - t.delay_ms &&
		t.easing >= .Linear &&
		t.easing <= .Ease_In_Out \
	)}
value_valid :: proc(property: Property, value: Value) -> bool {
	switch property {
	case .Foreground, .Background, .Border:
		v, ok := value.([4]f64); if !ok {return false}
		for x in v {if !base.finite(x) || x < 0 || x > 255 {return false}}
		return true
	case .Offset:
		v, ok := value.([2]f64); return ok && base.finite(v[0]) && base.finite(v[1])
	case .Scale:
		v, ok := value.(f64); return ok && base.finite_nonnegative(v)
	case .Opacity, .Progress:
		v, ok := value.(f64); return ok && base.finite(v) && v >= 0 && v <= 1
	}
	return false
}
sample_value :: proc(start, target: Value, timing: Timing, elapsed: i64) -> Value {
	switch s in start {
	case f64:
		v, _ := sample(s, target.(f64), timing, elapsed); return v
	case [2]f64:
		v: [2]f64; for x, i in s {v[i], _ = sample(x, target.([2]f64)[i], timing, elapsed)}
		return v
	case [4]f64:
		v: [4]f64; for x, i in s {v[i], _ = sample(x, target.([4]f64)[i], timing, elapsed)}
		return v
	}
	return nil
}
advance :: proc(v: ^View, delta: i64, finish: bool) {
	end := v.timing.delay_ms + v.timing.duration_ms
	v.elapsed_ms += min(delta, end - v.elapsed_ms)
	if finish {v.elapsed_ms = end}
	v.current = sample_value(v.start, v.target, v.timing, v.elapsed_ms)
	v.phase = .Active
	if v.elapsed_ms < v.timing.delay_ms {v.phase = .Delayed}
	if v.elapsed_ms == end {v.phase = .Completed}
}
