package main
import "core:strings"
import base "ui:ui_base"
import editor "ui:ui_editor"
import editor_sdl "ui:ui_editor/sdl"
import gestures "ui:ui_gestures"
import gesture_sdl "ui:ui_gestures/sdl"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"

accept_editor :: proc(r: ^Runtime, result: ^editor.Result) -> bool {
	if p, has := result.proposal.?; has {
		if p.base_revision != r.value_revision ||
		   r.value_revision == max(u64) ||
		   r.effects == max(u64) ||
		   r.revision == max(u64) {return false}
		value, ae := strings.clone(p.value, r.allocator); if ae != nil {return false}
		delete(r.value, r.allocator); r.value = value
		r.value_revision += 1; r.revision += 1; r.effects += 1
		r.resolution = {
			kind     = .Accepted,
			sequence = p.sequence,
		}
	}
	return true
}
handle_event :: proc(r: ^Runtime, event: sdl.Event, window: base.Extent) -> bool {
	was_ready := r.publication.ready
	n := backend.normalize_event(&r.input, &r.interaction, event, window)
	consumed := false
	if r.gestures.live.phase != .Idle || n.loss {
		g := gesture_sdl.event(
			&r.gesture_input,
			&r.input,
			&r.interaction,
			&r.gestures,
			&r.scroll,
			n,
		)
		consumed = g.consumed
		if !accept_gesture(r, g.gesture) {base.invalidate(&r.publication); return false}
	}
	if !consumed || n.loss {
		e := editor_sdl.event(
			&r.editor_input,
			&r.input,
			&r.interaction,
			&r.editing,
			n,
			fonts.metrics(r.fonts),
		)
		defer editor.destroy_result(&e.editor)
		if !accept_editor(r, &e.editor) {base.invalidate(&r.publication); return false}
		consumed ||= e.consumed
	}
	if !consumed {
		g := gesture_sdl.event(
			&r.gesture_input,
			&r.input,
			&r.interaction,
			&r.gestures,
			&r.scroll,
			n,
		)
		consumed = g.consumed
		if !accept_gesture(r, g.gesture) {base.invalidate(&r.publication); return false}
	}
	if !consumed {
		b := backend.dispatch_input(&r.interaction, n)
		if b.dispatch.has_event {
			if r.effects == max(u64) || r.revision == max(u64) {return false}
			if b.dispatch.event.id == "language" {r.english = !r.english}
			r.effects += 1; r.revision += 1
		}
	}
	if !was_ready {return false} 	// Only independent recovery may repair a failed model publication.
	if !r.publication.ready && !rebuild(r) {return false}
	if r.editor_input.pending_click_id != "" {
		e := editor_sdl.take_pointer(
			&r.editor_input,
			&r.interaction,
			&r.editing,
			fonts.metrics(r.fonts),
		)
		defer editor.destroy_result(&e.editor)
		if !accept_editor(r, &e.editor) {return false}
		if !r.publication.ready && !rebuild(r) {return false}
	}
	return true
}
accept_gesture :: proc(r: ^Runtime, result: gestures.Result) -> bool {
	if result.has_proposal {
		if result.proposal.model_revision != r.revision {return true} 	// Explicit app rejection; UI proposal is not applied automatically.
		if r.revision == max(u64) || r.effects == max(u64) {return false}
		r.effects += 1; r.revision += 1; r.dropped = true
	}
	return true
}
