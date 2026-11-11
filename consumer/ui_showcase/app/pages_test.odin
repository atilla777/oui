package app

import model "../model"
import "core:testing"

@(test)
page_fixtures_and_namespaces :: proc(t: ^testing.T) {
	m := model.initial()
	m.scale = 1.5
	for page in model.Page {
		m.page = page; c: Page_Composition
		if !testing.expect(t, compose_page(&c, m, context.allocator)) {continue}
		defer destroy_composition(&c)
		for b in c.texts[:c.nt] {if b.id == "shell/scale-label" {testing.expect(t, b.text == "Масштаб 1.5")}}
		if page == .Catalogue {testing.expect(t, c.initial_focus == "shell/layout" && c.ni == 9)}
		if page == .Layout {
			testing.expect(t, c.initial_focus == "shell/controls")
			for id in ([]string{"layout/row", "layout/column", "layout/stack", "layout/grid", "layout/absolute", "layout/clip"}) {
				found := false; for n in c.nodes[:c.n] {if n.id == id {found = true}}
				testing.expect(t, found)
			}
		}
		if page ==
		   .Controls {testing.expect(t, c.initial_focus == "controls/checkbox" && c.recipes[2].control.value == 50)}
		for n, i in c.nodes[:c.n] {for prior in c.nodes[:i] {testing.expect(t, n.id != prior.id)}}
	}
}
