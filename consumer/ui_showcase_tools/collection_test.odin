package main

import app "../ui_showcase/app"
import "core:testing"
import interaction "ui:ui_interaction"

_ :: app.Shell
_ :: interaction.Code

@(test)
v19_hidden_materialized_item_reports_same_stable_refusal_as_execution :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Collections) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		checked := false
		for target in s.runtime.live.interaction.targets {
			if target.availability != .Not_Visible {continue}
			n, found := node_projection(&s.runtime.live, true, target.description.id)
			if !testing.expect(t, found) {return}
			for status in n.actions {if status.action == "activate" {testing.expect(t, !status.allowed && status.reason == "Hidden")}}
			x := app.execute_tool_action(s, {op = "activate", id = n.id})
			testing.expect(t, x.code == "Hidden"); checked = true; break
		}
		testing.expect(t, checked, "fixture must have a hidden overscan target")
	}
}

@(test)
v19_materialized_collection_item_reports_activation_owner_permission :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Collections) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		n, found := node_projection(&s.runtime.live, true, "10:collection10:item-00001")
		if !testing.expect(t, found) {return}
		allowed :=
			false; for status in n.actions {if status.action == "activate" {allowed = status.suitable && status.allowed}}
		testing.expect(t, allowed)
		x := app.execute_tool_action(s, {op = "activate", id = n.id})
		testing.expect(
			t,
			x.code == "Applied" && x.application == "applied" && s.collection.selected == 1,
		)
	}
}

@(test)
v19_collection_region_reports_actual_scroll_permission :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Collections) {return}
		s := &f.s; if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		n, found := node_projection(&s.runtime.live, true, "collections/viewport")
		if !testing.expect(t, found) {return}
		allowed :=
			false; for a in n.actions {if a.action == "scroll" {allowed = a.suitable && a.allowed && a.reason == "Applied"}}
		testing.expect(
			t,
			allowed,
			"materialized collection region must report the same permission as its real owner",
		)
		before := s.model.effects
		x := app.execute_tool_action(s, {op = "scroll", id = n.id, delta_y = 1200})
		testing.expect(
			t,
			x.code == "Applied" && x.application == "none" && s.model.effects == before,
		)
		v := s.runtime.live.content.(app.Collection_Page_Reader)
		testing.expect(t, v.frame.collections[0].offset > 0 && len(v.frame.nodes) < 10000)
	}
}
