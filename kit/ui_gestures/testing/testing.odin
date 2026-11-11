package ui_gestures_testing
import family ".."
import interaction "../../ui_interaction"
import scroll "../../ui_scroll"
gesture :: proc(
	s: ^family.State,
	ctx: ^interaction.Context,
	ss: ^scroll.State,
	action: family.Action,
) -> family.Result {
	a := action; a.source = .Agent; return family.dispatch(s, ctx, ss, a)
}
