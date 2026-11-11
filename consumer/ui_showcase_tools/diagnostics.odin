package main

import app "../ui_showcase/app"
import "core:mem"
import common "ui:ui_inspect"
import rich "ui:ui_rich/inspect"
import style "ui:ui_style/inspect"
import text "ui:ui_text/inspect"

Diagnostics_Owner :: struct {
	text, style, rich, combined: []common.Diagnostic_Record,
}
release_diagnostics :: proc(owner: rawptr, a: mem.Allocator) {
	o := cast(^Diagnostics_Owner)owner
	text.destroy_diagnostics(
		o.text,
		a,
	); style.destroy_diagnostics(o.style, a); rich.destroy_diagnostics(o.rich, a)
	delete(o.combined, a); free(o, a)
}
normalize_tools_diagnostics :: proc(
	reader: ^app.Reader,
	a: mem.Allocator,
) -> (
	app.Tool_Diagnostics,
	bool,
) {
	o, ae := new(Diagnostics_Owner, a); if ae != nil {return {}, false}
	complete := false; defer {if !complete {release_diagnostics(o, a)}}
	ok: bool
	o.text, ok = text.diagnostics(&reader.text, a); if !ok {return {}, false}
	o.style, ok = style.diagnostics(&reader.paint, a); if !ok {return {}, false}
	if v, selected := reader.content.(app.Rich_Page_Reader);
	   selected {o.rich, ok = rich.diagnostics(&v.frame, a); if !ok {return {}, false}}
	o.combined, ae = make([]common.Diagnostic_Record, len(o.text) + len(o.style) + len(o.rich), a)
	if ae != nil {return {}, false}
	n := copy(o.combined, o.text); n += copy(o.combined[n:], o.style); copy(o.combined[n:], o.rich)
	complete = true; return {o.combined, o, release_diagnostics}, true
}
