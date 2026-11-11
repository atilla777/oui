package app

import "core:mem"
import inspect "ui:ui_inspect"

_ :: mem.Allocator
_ :: inspect.Inspection

when TOOLS {
	Tools_Slot :: ^Tools_Generation
	Tools_Runtime :: struct {
		enabled:   bool,
		epoch:     u64,
		normalize: Tool_Normalizer,
		trace:     ^Tool_Trace,
		sample_ms: i64,
	}
	Tool_Diagnostics :: struct {
		records: []inspect.Diagnostic_Record,
		owner:   rawptr,
		release: proc(_: rawptr, _: mem.Allocator),
	}
	Tool_Normalizer :: #type proc(_: ^Reader, _: mem.Allocator) -> (Tool_Diagnostics, bool)
	Tools_Shell :: struct {
		runtime: Tools_Runtime,
		history: Reader,
		epoch:   u64,
	}
	Tool_Value :: struct {
		id:    string,
		value: union {
			bool,
			i64,
			u64,
			f64,
			string,
		},
	}
	Tool_Observation :: struct {
		last_action:              Maybe(Tool_Record),
		selected_section, locale: string,
		scale:                    f64,
		pixel_perfect:            bool,
		effects:                  u64,
		values:                   []Tool_Value,
		unsupported:              []string,
	}
	Tool_Record :: struct {
		request_id, op, target, source:            string,
		sequence, screen_epoch:                    u64,
		dispatch_code, application_status, reason: string,
	}
	Tool_Trace :: struct {
		allocator:                        mem.Allocator,
		last, pending:                    Tool_Record,
		has_last, has_pending:            bool,
		before_revision, before_sequence: u64,
	}
	Tools_Generation :: struct {
		sample_ms:    i64,
		screen_epoch: u64,
		references:   u64,
		allocator:    mem.Allocator,
		inspection:   inspect.Inspection,
		observation:  Tool_Observation,
	}
} else {
	Tools_Slot :: struct {}
	Tools_Runtime :: struct {}
	Tools_Shell :: struct {}
}
