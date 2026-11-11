package main
import "core:os"
import "core:testing"
import gestures "ui:ui_gestures"
import interaction "ui:ui_interaction"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
@(test)
selected_bundle_publishes_one_editor_gesture_scroll_reader :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		800,
		600,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, de := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, de == nil) {return}; defer delete(data)
	g, ge := fonts.create_generation(
		renderer,
		"font-v1",
		[]fonts.Font_Source{{"font", 16, data}},
		1,
		context.allocator,
	); if !testing.expect(t, ge.code == .None) {return}; defer fonts.release_generation(&g)
	r: Runtime; if !testing.expect(t, init(&r, g, {800, 600})) {return}; defer destroy(&r)
	testing.expect(
		t,
		rebuild(&r) &&
		r.publication.ready &&
		r.reader.editor.stamp == r.reader.gestures.stamp &&
		r.reader.text.stamp == r.reader.editor.stamp &&
		r.reader.fonts == g,
	)
	r.input.window_id = 5
	testing.expect(t, render_current(&r))
	before := r.reader.editor.stamp
	r.fail_next = true
	e: sdl.Event; e.text = {
		type     = .TEXT_INPUT,
		windowID = 5,
		text     = "я",
	}
	testing.expect(
		t,
		!handle(&r, e, {800, 600}) &&
		r.effects == 1 &&
		r.value == "Имя / Nameя" &&
		!r.publication.ready &&
		r.reader.editor.stamp == before,
	)
	handle(&r, e, {800, 600})
	testing.expect(t, r.effects == 1 && !r.publication.ready)
	testing.expect(
		t,
		rebuild(&r) &&
		r.publication.ready &&
		r.effects == 1 &&
		r.reader.editor.editors[0].value == r.value,
	)
	interaction.dispatch(&r.interaction, {kind = .Focus, id = "source", source = .Agent})
	if !testing.expect(t, rebuild(&r)) {return}
	e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_RETURN,
	}; handle(&r, e, {800, 600})
	e.key.type = .KEY_UP; handle(&r, e, {800, 600})
	e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_TAB,
	}; handle(&r, e, {800, 600})
	e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_RETURN,
	}; handle(&r, e, {800, 600})
	testing.expect(
		t,
		r.dropped && r.effects == 2 && r.publication.sequence == 2 && r.publication.ready,
	)
	e.key.type = .KEY_UP; handle(&r, e, {800, 600})
	interaction.dispatch(
		&r.interaction,
		{kind = .Focus, id = "language", source = .Agent},
	); rebuild(&r)
	e.key.type = .KEY_DOWN; handle(&r, e, {800, 600})
	testing.expect(
		t,
		r.english && r.effects == 3 && r.publication.sequence == 3 && r.publication.ready,
	)
	gestures.dispatch(
		&r.gestures,
		&r.interaction,
		&r.scroll,
		{kind = .Begin, id = "drag", source = .Agent},
	); rebuild(&r)
	font_revision := g.fonts[0].native_revision; g.fonts[0].native_revision += 1
	testing.expect(
		t,
		!render_current(&r) &&
		!r.publication.ready &&
		r.gestures.live.phase == .Idle &&
		!r.gesture_input.clock.has_base,
	)
	g.fonts[0].native_revision = font_revision
	testing.expect(t, rebuild(&r) && r.effects == 3 && r.publication.ready)
}
