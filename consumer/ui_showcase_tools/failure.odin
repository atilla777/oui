package main

import app "../ui_showcase/app"
import "core:fmt"
import common "ui:ui_inspect"

remember_failure :: proc(h: ^Host, code: string) {
	if h.shell == nil {return}
	r := &h.shell.runtime
	h.last_failure = {code, r.tools_state.epoch, r.publication.attempt, h.shell.model.revision}
}
current_diagnostics :: proc(
	h: ^Host,
	reader: ^app.Reader,
	ready: bool,
) -> (
	[]common.Diagnostic_Record,
	bool,
) {
	n := 0; strict := false
	if reader !=
	   nil {n = len(reader.tools.inspection.diagnostics); i := reader.tools.inspection; i.ready, i.historical = ready, !ready; strict = common.strict_result(&i).ok}
	failed := h.shell != nil && h.shell.runtime.error != .None
	has_old := h.last_failure.code != ""
	count := n; if failed {count += 1}; if has_old {count += 1}
	data := make([]common.Diagnostic_Record, count, context.temp_allocator)
	if reader != nil {copy(data, reader.tools.inspection.diagnostics)}
	if failed {
		data[n] = {
			code             = fmt.tprintf("%v", h.shell.runtime.error),
			severity         = .Error,
			phase            = .update,
			attempt_revision = h.shell.model.revision,
		}; n += 1; strict = false
	}
	if has_old {
		v := h.last_failure
		active :=
			!ready &&
			h.shell.runtime.tools_state.epoch == v.epoch &&
			h.shell.runtime.publication.attempt == v.attempt
		data[n] = {
			code             = v.code,
			severity         = .Error if active else .Info,
			phase            = .update,
			attempt_revision = v.revision,
			detail           = "snapshot/capture failure" if active else "historical failure; explicit recovery published a different attempt",
		}
		if active {strict = false}
	}
	return data, strict
}
