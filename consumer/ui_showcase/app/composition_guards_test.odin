package app

import "core:testing"
import collections "ui:ui_collections"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import scroll "ui:ui_scroll"

@(test)
c03_actual_region_and_second_offset_owner_guards_are_atomic :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}
	r := &f.s.runtime; n, _ := active_collection(r)
	v := n.state.frame.collections[0]
	descriptions := []collections.Collection_Description{v.description}
	for region in ([]scroll.Description{{v.description.scroll_id, v.description.content_id}, {"10:collection10:item-00001", v.description.content_id}}) {
		e := collections.validate_regions(
			&r.live.geometry,
			descriptions,
			[]scroll.Description{region},
		)
		testing.expect(
			t,
			e.code == .Binding,
			"duplicate/nested ordinary+virtual regions cannot share this published geometry",
		)
	}
	c, e := collections.prepare(
		&n.state,
		reader_stamp(&r.live),
		v.description,
		v.viewport,
		v.offset,
		r.allocator,
	)
	defer collections.destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		collections.bind_candidate(&c, &r.live.geometry, &r.live.interaction).code == .None,
	)
	other := collections.create(r.allocator); defer collections.destroy(&other)
	testing.expect(t, !collections.validate_candidate(&r.publication, &other, &c))
	testing.expect(
		t,
		collections.validate_candidate(&r.publication, &n.state, &c) &&
		current(r) &&
		f.s.model.effects == 0,
	)
}

@(test)
c08_and_c06_actual_geometry_reject_conflicting_activation_and_invalid_layers :: proc(
	t: ^testing.T,
) {
	for page in ([]Runtime_Page{.Accessibility, .Custom}) {
		f: Page_Fixture
		if !start_page_fixture(t, &f, page) {stop_page_fixture(&f); return}
		r := &f.s.runtime
		target := r.live.interaction.targets[0].description
		for owner in ([]string{"slider", "hold", "gestures", "custom"}) {
			candidate, code := interaction.prepare(
				&r.live.geometry,
				[]interaction.Target{target},
				[]interaction.Capture_Claim{{target.id, "editor"}, {target.id, owner}},
				r.allocator,
			)
			testing.expect(t, code == .Conflict)
			interaction.destroy_candidate(&candidate)
		}
		candidate, e := layers.prepare(
			&r.layers,
			&r.interaction,
			&r.live.geometry,
			[]interaction.Target{target},
			nil,
			{
				base_root_id = "root",
				popups = []layers.Popup{{root_id = "root", owner_scope_id = "missing-scope"}},
			},
			r.allocator,
		)
		testing.expect(t, e.code != .None)
		layers.destroy_candidate(&candidate)
		testing.expect(t, current(r) && f.s.model.effects == 0)
		stop_page_fixture(&f)
	}
}
