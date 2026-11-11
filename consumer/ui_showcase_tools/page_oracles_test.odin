package main

import app "../ui_showcase/app"
import model "../ui_showcase/model"
import "core:os"
import "core:strings"
import "core:testing"
import inspect "ui:ui_inspect"

_ :: app.Shell
_ :: model.Page
_ :: os.exists
_ :: strings.contains
_ :: inspect.Query

@(test)
v19_every_page_owning_nodes_exact_queries_and_geometry_match_source :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		fallback, e := os.read_entire_file(
			"resources/fallback.ttf",
			context.allocator,
		)
		if !testing.expect(t, e == nil) {return}; defer delete(fallback)
		for page in model.Page {
			f: app.Page_Fixture
			if !app.start_page_fixture(
				t,
				&f,
				page,
				fallback = fallback,
				assets = "resources/atlas/a/manifest.json",
				alternate_assets = "resources/atlas/b/manifest.json",
			) {app.stop_page_fixture(&f); return}
			s := &f.s
			if !testing.expect(
				t,
				enable_capture(s) && app.rebuild(&s.runtime),
			) {app.stop_page_fixture(&f); return}
			reader := &s.runtime.live
			for node in reader.geometry.nodes {
				n, found := node_projection(reader, true, node.description.id)
				if !testing.expect(t, found, node.description.id) {continue}
				testing.expect(
					t,
					n.bounds == node.bounds &&
					n.content == node.content &&
					n.clip == node.clip &&
					n.paint_clip == node.paint_clip &&
					n.visible == node.visible &&
					n.enabled == node.enabled &&
					n.parent_id == node.description.parent,
					node.description.id,
				)
				for child in n.children {child_node, exists := node_projection(reader, true, child); testing.expect(t, exists && child_node.parent_id == n.id)}
				i := &reader.tools.inspection
				ids, ie := inspect.find(i, {.ID, n.id}, context.temp_allocator)
				testing.expect(
					t,
					ie == .None && len(ids) == 1 && i.frame.nodes[ids[0]].description.id == n.id,
				)
				if n.role !=
				   "" {matches, me := inspect.find(i, {.Role, n.role}, context.temp_allocator); expected := 0; for semantics in i.semantics {if semantics.role == n.role || (semantics.role == "" && n.role == "container") {expected += 1}}; testing.expect(t, me == .None && len(matches) == expected)}
				if n.name !=
				   "" {matches, me := inspect.find(i, {.Name, n.name}, context.temp_allocator); expected := 0; for semantics in i.semantics {if semantics.name == n.name {expected += 1}}; testing.expect(t, me == .None && len(matches) == expected)}
				testing.expect(t, len(n.unsupported) > 0)
			}
			retained, ok := app.copy_reader(reader, context.allocator)
			if testing.expect(t, ok) {
				app.destroy_shell(s)
				testing.expect(t, !app.reader_stamp(&retained).lifetime.alive)
				for node in retained.geometry.nodes {n, found := node_projection(&retained, false, node.description.id); testing.expect(t, found); for status in n.actions {testing.expect(t, !status.allowed && status.reason == "Not_Ready")}}
				app.destroy_reader(&retained)
			}
			app.stop_page_fixture(&f)
		}
	}
}

@(test)
v19_locale_changes_names_not_ids_and_misses_are_exact :: proc(t: ^testing.T) {
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		f: app.Page_Fixture; defer app.stop_page_fixture(&f)
		if !app.start_page_fixture(t, &f, .Controls) {return}; s := &f.s
		if !testing.expect(t, enable_capture(s) && app.rebuild(&s.runtime)) {return}
		ru, found := node_projection(&s.runtime.live, true, "controls/checkbox")
		if !testing.expect(t, found) {return}
		name := strings.clone(ru.name); defer delete(name)
		testing.expect(t, app.dispatch(s, {.Activate, "shell/language", .Agent, false}))
		en, exists := node_projection(&s.runtime.live, true, "controls/checkbox")
		testing.expect(t, exists && ru.id == en.id && name != en.name)
		i := &s.runtime.live.tools.inspection
		for query in ([]inspect.Query{{.ID, "controls/CHECKBOX"}, {.Name, " checkbox "}, {.Role, "BUTTON"}}) {
			matches, error := inspect.find(
				i,
				query,
				context.temp_allocator,
			); testing.expect(t, error == .None && len(matches) == 0)
		}
	}
}
