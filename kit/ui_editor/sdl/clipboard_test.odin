package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import "core:mem"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"

Clip_Test :: struct {
	value:  string,
	failed: bool,
	sets:   int,
}
@(test)
clipboard_shortcuts_are_atomic_and_do_not_duplicate_text :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := editor.create(); defer editor.destroy(&s)
	d := editor.Description {
		id           = "name",
		node_id      = "field",
		text_node_id = "value",
		value        = "aя",
		revision     = 1,
	}
	a := create(); input := backend.Input {
		window_id = 5,
	}
	clip := Clip_Test {
		value = "x",
	}
	a.clipboard = {
		get = proc(
			a: mem.Allocator,
			user: rawptr,
		) -> (
			string,
			bool,
		) {c := cast(^Clip_Test)user; v, e := strings.clone(c.value, a); return v, !c.failed && e == nil},
		set = proc(
			v: string,
			user: rawptr,
		) -> bool {c := cast(^Clip_Test)user; c.sets += 1; return !c.failed && v == "aя"},
		user = &clip,
	}
	for key in ([4]sdl.Keycode{sdl.K_A, sdl.K_C, sdl.K_X, sdl.K_V}) {
		if !publish(t, &p, &ctx, &s, d) {return}
		e: sdl.Event; e.key = {
			type     = .KEY_DOWN,
			windowID = 5,
			key      = key,
			mod      = sdl.KMOD_CTRL,
		}
		r := event(
			&a,
			&input,
			&ctx,
			&s,
			backend.normalize_event(&input, &ctx, e, {200, 100}),
			metrics(),
		)
		if !testing.expect(t, r.consumed) {return}
		if key == sdl.K_A {testing.expect(t, r.has_editor && !p.ready && p.sequence == 0)}
		if key == sdl.K_C {testing.expect(t, !r.has_editor && clip.sets == 1 && p.ready)}
		if key == sdl.K_X || key == sdl.K_V {
			if !testing.expect(t, r.has_editor && r.editor.proposal != nil) {return}
			expected := ""; if key == sdl.K_V {expected = "x"}
			testing.expect(t, r.editor.proposal.?.value == expected)
			d.resolution = {
				kind     = .Rejected,
				sequence = p.sequence,
			}
		}
		editor.destroy_result(&r.editor)
		e.key.type = .KEY_UP; backend.normalize_event(&input, &ctx, e, {200, 100})
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	clip.failed = true
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_V,
		mod      = sdl.KMOD_CTRL,
	}
	r := event(
		&a,
		&input,
		&ctx,
		&s,
		backend.normalize_event(&input, &ctx, e, {200, 100}),
		metrics(),
	)
	testing.expect(t, r.error == .Clipboard && p.ready && r.editor.proposal == nil)
}
