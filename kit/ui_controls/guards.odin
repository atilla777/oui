package ui_controls

import interaction "../ui_interaction"

@(private)
owner_guard :: proc(
	f: ^Frame,
	k: int,
	ctx: ^interaction.Context,
	source: interaction.Source,
) -> interaction.Code {
	if k >= len(f.gates) {return .Not_Ready}
	if f.gates[k] != .Applied {return f.gates[k]}
	id := f.controls[k].node_id
	code := interaction.guard(ctx, id, source)
	if code ==
	   .Invalid_Action {n, found := interaction.find(&ctx.frame, id); if found && n.description.role == "" {return .Applied}}
	return code
}
