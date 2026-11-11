package app

import "core:testing"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import style "ui:ui_style"

@(test)
g15_composition_has_real_nested_route_controls :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Composition) {return}
	for id in ([]string{"composition/parent", "composition/decor", "composition/child", "composition/stop", "composition/presence"}) {
		_, found := layout.find(&f.s.runtime.live.geometry, id)
		testing.expect(t, found, id)
	}
	testing.expect(t, f.s.runtime.interaction.focus_id == "composition/child")
	_, registered := interaction.find_handler(&f.s.runtime.interaction, "composition/child")
	testing.expect(t, registered, "G15 child handler must use real interaction registration")
	decor_visible := false
	for p in f.s.runtime.live.paint.presentation {if p.id == "composition/decor" {decor_visible = p.computed[.Background].value.(style.Color)[3] > 0}}
	testing.expect(t, decor_visible, "the decorative part of the composite must actually paint")
}

@(test)
g15_model_effect_requires_actual_routed_intention :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Composition) {return}; s := &f.s
	child, _ := interaction.find_handler(&s.runtime.interaction, "composition/child")
	testing.expect(t, interaction.unsubscribe(&s.runtime.interaction, child.token) == .Applied)
	before := s.model
	dispatch(s, {.Activate, "composition/child", .Agent, false})
	testing.expect(
		t,
		s.model == before,
		"no callback intention means no child application outcome",
	)
}

@(test)
g15_route_stop_removal_readd_and_dispose :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Composition) {return}; s := &f.s
	child, _ := interaction.find_handler(&s.runtime.interaction, "composition/child")
	testing.expect(t, dispatch(s, {.Activate, "composition/child", .Agent, false}))
	testing.expect(
		t,
		s.model.composition.child_count == 1 && s.model.composition.parent_count == 0,
	)
	testing.expect(t, s.runtime.composition_route.child && !s.runtime.composition_route.parent)
	testing.expect(t, dispatch(s, {.Activate, "composition/stop", .Agent, false}))
	effects := s.model.effects
	testing.expect(t, dispatch(s, {.Activate, "composition/child", .Agent, false}))
	testing.expect(
		t,
		s.model.composition.child_count == 2 &&
		s.model.composition.parent_count == 1 &&
		s.model.effects == effects + 1,
	)
	testing.expect(t, s.runtime.composition_route.child && s.runtime.composition_route.parent)
	testing.expect(t, dispatch(s, {.Activate, "composition/presence", .Agent, false}))
	_, registered := interaction.find_handler(&s.runtime.interaction, "composition/child")
	testing.expect(t, !registered && s.runtime.composition_route.disposals == 1)
	effects = s.model.effects
	testing.expect(
		t,
		!dispatch(s, {.Activate, "composition/child", .Agent, false}) &&
		s.model.effects == effects,
	)
	testing.expect(t, dispatch(s, {.Activate, "composition/presence", .Agent, false}))
	next, found := interaction.find_handler(&s.runtime.interaction, "composition/child")
	testing.expect(t, found && next.token > child.token)
	testing.expect(t, present(&s.runtime))
}
