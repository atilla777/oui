package main
import "core:mem"
import "core:strings"
import base "ui:ui_base"
import editor "ui:ui_editor"
import editor_sdl "ui:ui_editor/sdl"
import gestures "ui:ui_gestures"
import gesture_sdl "ui:ui_gestures/sdl"
import interaction "ui:ui_interaction"
import scroll "ui:ui_scroll"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import style "ui:ui_style"
import text "ui:ui_text"
import sdl "vendor:sdl3"

Reader :: struct {
	editor:   editor.Frame,
	gestures: gestures.Frame,
	text:     text.Frame,
	paint:    style.Frame,
	fonts:    ^fonts.Generation,
}
Runtime :: struct {
	publication:                       base.Publication,
	interaction:                       interaction.Context,
	editing:                           editor.State,
	gestures:                          gestures.State,
	scroll:                            scroll.State,
	input:                             backend.Input,
	editor_input:                      editor_sdl.Adapter,
	gesture_input:                     gesture_sdl.Adapter,
	reader:                            Reader,
	fonts:                             ^fonts.Generation, // Borrowed; caller font owner outlives runtime/readers.
	allocator:                         mem.Allocator,
	drawable:                          base.Extent,
	value:                             string,
	value_revision, revision, effects: u64,
	resolution:                        editor.Resolution,
	english, dropped, fail_next:       bool,
}
init :: proc(
	r: ^Runtime,
	g: ^fonts.Generation,
	drawable: base.Extent,
	a := context.allocator,
) -> bool {
	p, pe := base.create(a); if pe != .None {return false}
	r.publication, r.allocator, r.fonts, r.drawable = p, a, g, drawable
	r.interaction = interaction.create(
		a,
		&r.publication,
	); r.editing = editor.create(a); r.gestures = gestures.create(a); r.scroll = scroll.create(a); r.editor_input = editor_sdl.create(a)
	value, ae := strings.clone("Имя / Name", a); if ae != nil {destroy(r); return false}
	r.value, r.value_revision, r.revision = value, 1, 1
	return true
}
destroy_reader :: proc(r: ^Reader) {editor.destroy_frame(&r.editor); gestures.destroy_frame(
		&r.gestures,
	)
	text.destroy_frame(&r.text)
	style.destroy_frame(&r.paint)
	fonts.release_generation(&r.fonts)
	r^ = {}}
destroy :: proc(r: ^Runtime) {
	// The application closes the text-input lifecycle while its window is live.
	editor_sdl.cancel_capture(
		&r.editor_input,
	); gesture_sdl.close(&r.gesture_input); backend.close_input(&r.input)
	destroy_reader(
		&r.reader,
	); editor.destroy(&r.editing); gestures.destroy(&r.gestures); scroll.destroy(&r.scroll); interaction.destroy(&r.interaction); base.destroy(&r.publication); delete(r.value, r.allocator); r^ = {}
}
rebuild :: proc(r: ^Runtime) -> bool {
	ok := publish(r)
	if !ok {block_runtime(r)}
	return ok
}
block_runtime :: proc(r: ^Runtime) {
	base.invalidate(&r.publication); gestures.block(&r.gestures, &r.publication)
	r.gesture_input.clock.has_base =
		false; r.gesture_input.pending, r.gesture_input.pending_point = nil, nil
	editor_sdl.cancel_capture(&r.editor_input)
}
handle :: proc(r: ^Runtime, event: sdl.Event, window: base.Extent) -> bool {return handle_event(
		r,
		event,
		window,
	)}
