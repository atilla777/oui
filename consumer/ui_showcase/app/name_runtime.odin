package app

import model "../model"
import "core:fmt"
import "core:mem"
import "core:strings"
import base "ui:ui_base"
import editor "ui:ui_editor"
import editor_sdl "ui:ui_editor/sdl"
import fonts "ui:ui_sdl_text"

Name_Page_Runtime :: struct {
	diagnostic:               [256]u8,
	state:                    editor.State,
	input:                    editor_sdl.Adapter,
	resolution:               editor.Resolution,
	rejection:                editor.Rejection,
	native_error:             editor_sdl.Error,
	failed, empty, has_clock: bool,
	last_ms:                  i64,
}
compose_name_status :: proc(r: ^Runtime, c: ^Page_Composition) {
	n, ok := active_name(r); if !ok {return}
	message :=
		"Ready; 1-64 EGC, draft may be empty" if r.model.locale == .English else "Готово; 1-64 EGC, черновик может быть пустым"
	if n.rejection !=
	   .None {message = "Insertion refused" if r.model.locale == .English else "Вставка отклонена"}
	if n.empty {message = "Empty name cannot be applied" if r.model.locale == .English else "Пустое имя нельзя применить"}
	if n.native_error ==
	   .Clipboard {message = "Clipboard refused" if r.model.locale == .English else "Буфер обмена: отказ"}
	if n.native_error ==
	   .Unsupported_Composition {message = "IME/preedit is unsupported" if r.model.locale == .English else "IME/preedit не поддерживается"}
	value := fmt.bprintf(n.diagnostic[:], "%s [%v / %v]", message, n.native_error, n.rejection)
	parent := "root"; if r.page == .Diagnostics_Performance {parent = "performance/name-panel"}
	if lab_menu(r.page) {parent = "lab/settings-modal"}
	label(c, "name/status", parent, value, {x = {mode = .Fill}, y = {mode = .Content}})
	c.texts[c.nt - 1].options.wrap = .WordWrap
}
Name_Page_Reader :: struct {
	frame:   editor.Frame,
	focused: bool,
}
active_name :: proc(r: ^Runtime) -> (^Name_Page_Runtime, bool) {
	if v, ok := r.content.(^Lab_Menu_Runtime); ok {return &v.editing, true}
	if n, ok := r.content.(^Name_Page_Runtime); ok {return n, true}
	if g, ok := r.content.(^Gesture_Page_Runtime); ok {return &g.editing, true}
	if p, selected := r.content.(^Performance_Page_Runtime); selected {return &p.editing, true}
	return nil, false
}
name_values :: proc(r: ^Runtime) -> ^model.Name_State {
	if lab_menu(r.page) {return &r.model.lab_name}
	if r.page == .Diagnostics_Performance {return &r.model.performance_name}
	if r.page == .Gestures {return &r.model.gesture_name}
	return &r.model.name
}
destroy_name_values :: proc(m: ^model.Name_State, a: mem.Allocator) {
	if m.owned_draft {delete(m.draft, a)}; if m.owned_applied {delete(m.applied, a)}
	m^ = {
		draft          = "Алексей",
		applied        = "Алексей",
		value_revision = 1,
	}
}
// Controlled-name oracle: empty draft is legal, Submit requires 1..64 EGC,
// Cancel restores applied. Copy borrowed proposals before destroying sources.
accept_name :: proc(r: ^Runtime, stamp: base.Frame_Stamp, result: ^editor.Result) -> bool {
	n, selected := active_name(r); if !selected {return false}; m := name_values(r)
	if p, has := result.proposal.?; has {
		if p.id != "name" ||
		   p.base_revision != m.value_revision ||
		   m.value_revision == max(u64) ||
		   r.model.revision == max(u64) ||
		   r.model.effects == max(u64) ||
		   !consume(r, stamp, p.sequence) {return false}
		value, ae := strings.clone(p.value, r.allocator)
		if ae !=
		   nil {n.resolution = {.Rejected, p.sequence, .Allocation}; n.rejection = .Allocation; block(r); return false}
		if m.owned_draft {delete(m.draft, r.allocator)}
		m.draft, m.owned_draft = value, true; m.value_revision += 1
		r.model.revision += 1; r.model.effects += 1
		n.resolution = {.Accepted, p.sequence, .None}; n.rejection = .None; n.empty = false
		return true
	}
	n.rejection = result.rejection
	if result.intent != .None {
		if !consume(r, stamp, result.sequence) {return false}
		accepted := name_intent(r, result.intent); return accepted || !n.failed
	}
	return true
}
name_intent :: proc(r: ^Runtime, intent: editor.Intent) -> bool {
	if lab_menu(r.page) {
		id := "name/apply" if intent == .Submit else "name/cancel"
		return lab_menu_action(r, id)
	}
	n, ok := active_name(r); if !ok {return false}; m := name_values(r)
	n.failed, n.empty = false, false
	if r.model.revision == max(u64) ||
	   r.model.effects == max(u64) ||
	   m.value_revision == max(u64) {return false}
	value := m.applied
	if intent == .Submit {
		v := editor.editor_splice(
			"",
			0,
			0,
			m.draft,
			64,
			r.allocator,
		); defer editor.destroy_editor_splice(&v)
		n.rejection, n.empty = v.rejection, v.count == 0
		if v.rejection != .None || n.empty {return false}
		metrics := fonts.metrics(r.fonts)
		if e, _ := metrics.validate_text(m.draft, "own", 14, metrics.user);
		   e != .None {n.rejection = .Glyph_Missing; return false}
		value = m.draft
	}
	copy, ae := strings.clone(value, r.allocator)
	if ae != nil {n.failed = true; n.rejection = .Allocation; block(r); return false}
	if intent == .Submit {
		if m.owned_applied {delete(m.applied, r.allocator)}; m.applied, m.owned_applied = copy, true
	} else {
		if m.owned_draft {delete(m.draft, r.allocator)}; m.draft, m.owned_draft = copy, true
		m.value_revision += 1; n.resolution = {.External, 0, .None}
	}
	n.rejection = .None; r.model.revision += 1; r.model.effects += 1
	base.invalidate(&r.publication); return true
}
request_exit :: proc(s: ^Shell) -> bool {s.exit_pending = true; return close_page_input(s)}
close_page_input :: proc(s: ^Shell) -> bool {
	if n, ok := active_name(&s.runtime); ok {
		block(&s.runtime)
		if !editor_sdl.close(
			&n.input,
			s.window,
		) {n.native_error = .Text_Lifecycle; s.runtime.error = .Text_Lifecycle; s.cleanup_pending = true; return false}
	}
	s.cleanup_pending = false
	return true
}
sync_name :: proc(s: ^Shell) -> bool {
	if s.cleanup_pending {return false}
	if n, ok := active_name(&s.runtime); ok {
		// Software consumers have no native window; explicit callbacks still
		// permit tests of the native boundary without synthesizing SDL success.
		if s.window == nil && n.input.lifecycle.start == nil {return true}
		wanted :=
			s.runtime.publication.ready &&
			!s.input.suspended &&
			s.runtime.interaction.focus_id == "name/field"
		if !editor_sdl.sync(&n.input, &s.input, &s.runtime.interaction, &n.state, s.window) {
			n.native_error = .Text_Lifecycle; s.runtime.error = .Text_Lifecycle
			if !wanted && n.input.text_active {s.cleanup_pending = true}
			block(&s.runtime); return false
		}
	}
	return true
}
