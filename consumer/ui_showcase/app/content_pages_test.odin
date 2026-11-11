package app

import model "../model"
import "core:mem"
import "core:os"
import "core:testing"
import layout "ui:ui_layout"
import style "ui:ui_style"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
g05_through_g08_page_descriptions :: proc(t: ^testing.T) {
	for page, i in ([4]model.Page{.Styling, .Atlas, .Text, .Rich_Text}) {
		m := model.initial(); m.page = page
		c: Page_Composition; defer destroy_composition(&c)
		testing.expect(t, compose_page(&c, m, context.allocator))
		ids := [4]string{"styling/palette", "atlas/panel", "text/paragraph", "rich/card"}
		found := false; for n in c.nodes[:c.n] {if n.id == ids[i] {found = true}}
		testing.expect(t, found, ids[i])
	}
}

@(test)
g05_g08_native_software_baseline_resources_and_values :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		1280,
		960,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	primary, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(primary)
	fallback, fe := os.read_entire_file(
		"resources/fallback.ttf",
		context.allocator,
	); if !testing.expect(t, fe == nil) {return}; defer delete(fallback)
	for page in ([5]model.Page{.Styling, .Atlas, .Text, .Rich_Text, .Layout}) {for locale in model.Locale {
			s := Shell {
				model = model.initial(),
				font_data = primary,
				renderer = renderer,
				allocator = context.allocator,
				drawable = {1280, 960},
				sources = {
					fallback = fallback,
					assets = "resources/atlas/a/manifest.json",
					alternate_assets = "resources/atlas/b/manifest.json",
				},
			}
			s.model.page, s.model.locale = page, locale
			defer destroy_shell(&s)
			if !testing.expect(t, enter(&s)) {continue}
			testing.expect(t, current(&s.runtime) && present(&s.runtime))
			ids := [5]string {
				"styling/theme",
				"atlas/assets",
				"text/key",
				"rich/limit",
				"layout/more",
			}
			index := 0; #partial switch page {case .Atlas:
				index = 1; case .Text:
				index = 2; case .Rich_Text:
				index = 3; case .Layout:
				index = 4; case .Styling:}
			testing.expect(t, dispatch(&s, {.Activate, ids[index], .Agent, false}))
			testing.expect(t, s.model.effects == 1 && current(&s.runtime) && present(&s.runtime))
			if page == .Layout {
				fixed, fixed_ok := layout.find(
					&s.runtime.live.geometry,
					"layout/fixed",
				); percent, percent_ok := layout.find(&s.runtime.live.geometry, "layout/percent"); sizes, sizes_ok := layout.find(&s.runtime.live.geometry, "layout/sizes")
				if testing.expect(
					t,
					fixed_ok && percent_ok && sizes_ok,
				) {testing.expect(t, fixed.bounds.w >= 80 && fixed.bounds.w <= 160 && percent.bounds.w == 200 && fixed.bounds.x >= sizes.content.x)}
				start, _ := layout.find(
					&s.runtime.live.geometry,
					"layout/align-start",
				); center, _ := layout.find(&s.runtime.live.geometry, "layout/align-center"); end, _ := layout.find(&s.runtime.live.geometry, "layout/align-end")
				testing.expect(
					t,
					start.bounds.y < center.bounds.y && center.bounds.y < end.bounds.y,
				)
				testing.expect(t, dispatch(&s, {.Activate, "layout/safe-area", .Agent, false}))
				root, root_ok := layout.find(
					&s.runtime.live.geometry,
					"root",
				); if testing.expect(t, root_ok) {testing.expect(t, root.bounds.x == 12 && root.bounds.y == 18 && root.bounds.w == 1256 && root.bounds.h == 924)}
			}
			if page == .Styling {
				testing.expect(t, dispatch(&s, {.Activate, "styling/fallback", .Agent, false}))
				found :=
					false; for p in s.runtime.live.paint.presentation {if p.id == "styling/image" {found = p.fallback != nil}}
				testing.expect(t, found)
			}
			if page == .Atlas {
				for p in s.runtime.live.paint.presentation {if p.id == "atlas/metadata" || p.id == "atlas/status" {testing.expect(t, p.computed[.Background].value.(style.Color) == (style.Color{235, 240, 245, 255}), "light-theme metadata must have its contrasting light background")}}
				testing.expect(t, dispatch(&s, {.Activate, "atlas/theme", .Agent, false}))
				found :=
					false; for p in s.runtime.live.paint.presentation {if p.id == "atlas/body" {found = p.computed[.Background].value.(style.Color) == (style.Color{20, 25, 38, 255})}}
				testing.expect(t, found)
			}
			if page == .Text {
				for fixture in 0 ..< 4 {
					c: Page_Composition; testing.expect(t, compose_page(&c, s.model, context.allocator)); testing.expect(t, c.content.consumer_violated == (fixture % 2 == 1)); testing.expect(t, c.content.consumer_count == (14 if locale == .Russian else 16)); destroy_composition(&c)
					overflow :=
						false; for d in s.runtime.live.text.text_diagnostics {if d.node_id == "text/probe" && d.kind == .Pixel_Overflow {overflow = true}}
					testing.expect(t, overflow == (fixture >= 2))
					for block in s.runtime.live.text.text_blocks {for line in block.lines {for range in line.source_byte_ranges {testing.expect(t, range.start >= 0 && range.start <= range.end && range.end <= len(block.original_text))}}}
					testing.expect(
						t,
						dispatch(&s, {.Activate, "text/limit", .Agent, false}) &&
						current(&s.runtime) &&
						present(&s.runtime),
					)
				}
			}
			if page == .Rich_Text {
				content, selected := s.runtime.live.content.(Rich_Page_Reader); testing.expect(t, selected)
				fallback_used, ellipsis := false, false
				for block in content.frame.rich_blocks {for c in block.coverage {if c.resource == "greek" {fallback_used = true}; testing.expect(t, c.source_range.start <= c.source_range.end && c.source_range.end <= len(block.document.source))}; if block.node_id == "rich/card" {ellipsis = block.ellipsized}}
				testing.expect(t, fallback_used && ellipsis)
			}
			reader, copied := copy_reader(&s.runtime.live, context.allocator)
			if testing.expect(
				t,
				copied,
			) {stamp := reader_stamp(&reader); destroy_shell(&s); testing.expect(t, !stamp.lifetime.alive && draw_reader(&reader)); destroy_reader(&reader)}
		}}
}

@(test)
g05_g08_every_reader_allocation_refusal_preserves_current_source :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		1280,
		960,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	primary, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(primary)
	fallback, fe := os.read_entire_file(
		"resources/fallback.ttf",
		context.allocator,
	); if !testing.expect(t, fe == nil) {return}; defer delete(fallback)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking); f := Allocation_Fault {
		backing = a,
	}
	for page in ([4]model.Page{.Styling, .Atlas, .Text, .Rich_Text}) {
		m := model.initial(); m.page = page; r: Runtime
		if !testing.expect(
			t,
			init(
				&r,
				renderer,
				primary,
				&m,
				a,
				nil,
				{
					fallback,
					"resources/atlas/a/manifest.json",
					"resources/atlas/b/manifest.json",
				},
			),
		) {return}
		r.drawable = {1280, 960}; if !testing.expect(t, rebuild(&r)) {destroy(&r); return}
		before := tracking.current_memory_allocated; requests := 0
		for refusal := 0; refusal <= requests; refusal += 1 {
			f.requests, f.refuse = 0, refusal
			reader, ok := copy_reader(&r.live, {refuse_allocation, &f})
			if refusal ==
			   0 {requests = f.requests; testing.expect(t, ok)} else {testing.expect(t, !ok)}
			destroy_reader(&reader)
			testing.expect(
				t,
				current(&r) &&
				tracking.current_memory_allocated == before &&
				len(tracking.bad_free_array) == 0,
			)
		}
		destroy(
			&r,
		); testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
	}
}
