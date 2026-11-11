package ui_interaction

// One pointer-down transaction, before the caller's mandatory rebuild.
begin_pointer_press :: proc(ctx: ^Context, id: string) -> Code {
	code := begin_press(ctx, id)
	if code == .Applied {ctx.focus_id = ctx.pressed_id}
	return code
}
