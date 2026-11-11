package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"
@(test)
editing_keys_and_composition_refusal_do_not_fall_through_to_base :: proc(t: ^testing.T) {
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
	for tc in ([]struct {
			key:       sdl.Keycode,
			kind:      editor.Action_Kind,
			direction: editor.Direction,
		}{{sdl.K_LEFT, .Move, .Left}, {sdl.K_RIGHT, .Move, .Right}, {sdl.K_HOME, .Move, .Home}, {sdl.K_END, .Move, .End}, {sdl.K_BACKSPACE, .Backspace, .Left}, {sdl.K_DELETE, .Delete, .Left}, {sdl.K_RETURN, .Submit, .Left}, {sdl.K_ESCAPE, .Cancel, .Left}}) {
		if !publish(t, &p, &ctx, &s, d) {return}
		e: sdl.Event; e.key = {
			type     = .KEY_DOWN,
			windowID = 5,
			key      = tc.key,
		}
		n := backend.normalize_event(&input, &ctx, e, {200, 100})
		r := event(&a, &input, &ctx, &s, n, metrics())
		if !testing.expect(
			t,
			r.consumed && r.has_editor && r.editor.code == .Applied,
		) {editor.destroy_result(&r.editor); return}
		if proposal, ok := r.editor.proposal.?; ok {d.resolution = {
				kind     = .Rejected,
				sequence = proposal.sequence,
			}}
		editor.destroy_result(&r.editor)
		e.key.type = .KEY_UP; backend.normalize_event(&input, &ctx, e, {200, 100})
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	e: sdl.Event; e.edit = {
		type     = .TEXT_EDITING,
		windowID = 5,
		text     = "composition",
	}
	r := event(
		&a,
		&input,
		&ctx,
		&s,
		backend.normalize_event(&input, &ctx, e, {200, 100}),
		metrics(),
	)
	testing.expect(t, r.consumed && r.error == .Unsupported_Composition && p.ready)
}
