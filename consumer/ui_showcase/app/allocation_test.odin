package app

import model "../model"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Allocation_Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}

// IV131-R1: refuse allocations at the composed consumer, not just in a
// library factory or copy_reader. All owners are created with the same fault
// allocator; disabling it during baseline setup must not bypass stored owners.
Content_Allocation_Boundary :: enum {
	Init,
	First_Rebuild,
	Rebuild,
	Scale,
	Atlas_Set,
	Atlas_Reload,
}
exercise_content_boundary :: proc(
	t: ^testing.T,
	renderer: ^sdl.Renderer,
	primary, fallback: []u8,
	page: model.Page,
	boundary: Content_Allocation_Boundary,
	refuse: int,
) -> int {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking); f := Allocation_Fault {
		backing = a,
	}; ledger: backend.Resource_Ledger
	s := Shell {
		model     = model.initial(),
		font_data = primary,
		renderer  = renderer,
		allocator = {refuse_allocation, &f},
		drawable  = {1280, 960},
		ledger    = &ledger,
		sources   = {
			fallback,
			"resources/atlas/a/manifest.json",
			"resources/atlas/b/manifest.json",
		},
	}
	s.model.page = page
	retained: Reader
	defer {
		destroy_shell(&s); destroy_reader(&retained)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			ledger.live == 0 &&
			ledger.created == ledger.destroyed,
			"composed content boundary must release all tracked allocations/native ledger resources",
		)
	}
	if boundary != .Init {
		if !testing.expect(
			t,
			init(&s.runtime, renderer, primary, &s.model, s.allocator, &ledger, s.sources),
		) {return 0}
		s.runtime.drawable = s.drawable
		if boundary != .First_Rebuild {
			if !testing.expect(t, rebuild(&s.runtime)) {return 0}
			copied: bool; retained, copied = copy_reader(&s.runtime.live, a); if !testing.expect(t, copied) {return 0}
		}
	}
	before := tracking.current_memory_allocated; native_before := ledger.live
	old_stamp := reader_stamp(
		&s.runtime.live,
	); old_images, old_fonts := s.runtime.images, s.runtime.fonts
	action := "shell/scale"
	if boundary == .Rebuild {#partial switch page {case .Styling:
			action = "styling/theme"; case .Atlas:
			action = "atlas/count"; case .Text:
			action = "text/key"; case .Rich_Text:
			action = "rich/limit"; case:}}
	if boundary ==
	   .Atlas_Set {action = "atlas/assets"}; if boundary == .Atlas_Reload {action = "atlas/reload"}
	initial := s.model
	f.requests, f.refuse = 0, refuse
	ok := false
	switch boundary {
	case .Init:
		ok = init(&s.runtime, renderer, primary, &s.model, s.allocator, &ledger, s.sources)
	case .First_Rebuild:
		ok = rebuild(&s.runtime)
	case .Rebuild, .Scale, .Atlas_Set, .Atlas_Reload:
		ok = dispatch(&s, {.Activate, action, .Agent, false})
	}
	requests := f.requests
	testing.expect(
		t,
		ok == (refuse == 0),
		"each observed allocation must be a checked consumer refusal",
	)
	accepted := s.model
	if boundary == .Init ||
	   boundary ==
		   .First_Rebuild {testing.expect(t, accepted == initial)} else {testing.expect(t, accepted.effects == initial.effects + 1 && accepted.revision == initial.revision + 1)}
	if !ok {
		testing.expect(t, !s.runtime.publication.ready && !current(&s.runtime))
		if boundary == .Init {
			testing.expect(
				t,
				s.runtime.publication.lifetime == nil &&
				tracking.current_memory_allocated == 0 &&
				ledger.live == 0,
			)
		} else {
			testing.expect(
				t,
				reader_stamp(&s.runtime.live) == old_stamp &&
				s.runtime.images == old_images &&
				s.runtime.fonts == old_fonts,
				"failed candidate must not replace historical live owners",
			)
			testing.expect(
				t,
				tracking.current_memory_allocated == before + i64(len(s.runtime.diagnostic.id)) &&
				ledger.live == native_before,
				"failed candidate must leave only its copied error ID, not candidate resources",
			)
			if boundary !=
			   .First_Rebuild {testing.expect(t, draw_reader(&retained), "retained historical reader remains drawable after failed rebuild/scale/replacement")}
		}
		testing.expect(
			t,
			!dispatch(&s, {.Activate, action, .Agent, false}) && s.model == accepted,
			"Not_Ready must reject replay without changing the model",
		)
		f.refuse = 0
		testing.expect(
			t,
			recover(&s) && s.model == accepted && current(&s.runtime) && present(&s.runtime),
			"R rebuilds accepted desired state without replay",
		)
	}
	destroy_shell(&s)
	if old_stamp.lifetime !=
	   nil {testing.expect(t, !old_stamp.lifetime.alive && draw_reader(&retained), "historical reader owns resources after source destruction")}
	return requests
}

@(test)
g05_g08_consumer_init_prepare_scale_and_atlas_replacement_allocation_refusals :: proc(
	t: ^testing.T,
) {
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
	for page in ([4]model.Page{.Styling, .Atlas, .Text, .Rich_Text}) {
		for boundary in Content_Allocation_Boundary {
			if page != .Atlas && (boundary == .Atlas_Set || boundary == .Atlas_Reload) {continue}
			count := exercise_content_boundary(t, renderer, primary, fallback, page, boundary, 0)
			if !testing.expect(t, count > 0) {return}
			fmt.printf(
				"content allocation boundary page=%v operation=%v observed=%d\n",
				page,
				boundary,
				count,
			)
			for refusal in 1 ..= count {exercise_content_boundary(t, renderer, primary, fallback, page, boundary, refusal)}
		}
	}
}
refuse_allocation :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := (^Allocation_Fault)(data)
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode == .Resize_Non_Zeroed) {
		f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}
	}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
exercise_refusal :: proc(
	t: ^testing.T,
	renderer: ^sdl.Renderer,
	data: []u8,
	page: model.Page,
	operation, refuse: int,
) -> int {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking); f := Allocation_Fault {
		backing = a,
		refuse  = refuse,
	}; fa := mem.Allocator{refuse_allocation, &f}
	m := model.initial(); m.page = page
	r: Runtime; ledger: backend.Resource_Ledger
	defer {destroy(&r)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			ledger.live == 0,
		)}
	ok := false
	if operation == 0 {ok = init(&r, renderer, data, &m, fa, &ledger)} else {
		if !testing.expect(t, init(&r, renderer, data, &m, a, &ledger)) {return 0}
		r.drawable = {800, 600}; if !testing.expect(t, rebuild(&r)) {return 0}
		before := tracking.current_memory_allocated; stamp := r.live.text.stamp
		if operation == 2 {
			reader, copied := copy_reader(&r.live, fa); ok = copied; destroy_reader(&reader)
		} else {
			r.allocator = fa; if operation == 3 {m.scale = 1.5}
			ok = rebuild(&r)
			if !ok {testing.expect(t, !r.publication.ready && r.live.text.stamp == stamp && m.effects == 0)}
		}
		// A saved error ID is the one intentionally retained diagnostic, not a candidate/reader leak.
		if !ok {testing.expect(t, tracking.current_memory_allocated == before + i64(len(r.diagnostic.id)))}
	}
	testing.expect(t, ok == (refuse == 0))
	return f.requests
}
@(test)
first_publication_allocation_failure_recovers_without_replay :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		800,
		600,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	ledger: backend.Resource_Ledger
	f := Allocation_Fault {
		backing = mem.tracking_allocator(&tracking),
	}
	for page in ([4]model.Page{.Catalogue, .Layout, .Controls, .Profiles}) {
		m := model.initial()
		m.page, m.locale, m.scale = page, .English, 1.5
		m.checkbox, m.toggle, m.slider = true, true, 73
		s := Shell {
			model     = m,
			font_data = data,
			renderer  = renderer,
			allocator = {refuse_allocation, &f},
			drawable  = {800, 600},
			ledger    = &ledger,
		}
		f.requests, f.refuse = 0, 1
		testing.expect(
			t,
			!enter(&s) && !s.runtime.publication.ready && s.runtime.publication.lifetime == nil,
		)
		testing.expect(
			t,
			s.model == m && tracking.current_memory_allocated == 0 && ledger.live == 0,
		)
		f.refuse = 0
		testing.expect(
			t,
			recover(&s),
			"R must reinitialize after the actual first base.create allocation refusal",
		)
		testing.expect(t, s.model == m && current(&s.runtime) && present(&s.runtime))
		destroy_shell(&s)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			ledger.live == 0 &&
			len(tracking.bad_free_array) == 0,
		)
	}
	s := Shell {
		model     = model.initial(),
		font_data = data,
		renderer  = renderer,
		allocator = {refuse_allocation, &f},
		drawable  = {800, 600},
		ledger    = &ledger,
	}
	if !testing.expect(t, enter(&s)) {return}; defer destroy_shell(&s)
	s.input.mouse_down, s.input.south_down = true, true
	f.requests, f.refuse = 0, 1
	testing.expect(
		t,
		!dispatch(&s, {.Activate, "shell/controls", .Agent, false}) && s.model.page == .Controls,
	)
	accepted := s.model
	testing.expect(
		t,
		accepted.effects == 1 &&
		!s.runtime.publication.ready &&
		tracking.current_memory_allocated == 0 &&
		ledger.live == 0,
	)
	f.refuse = 0
	testing.expect(
		t,
		recover(&s) &&
		s.model == accepted &&
		s.runtime.interaction.focus_id == "controls/checkbox",
	)
	testing.expect(
		t,
		s.input.mouse_down && s.input.south_down && current(&s.runtime) && present(&s.runtime),
	)
	destroy_shell(&s)
	testing.expect(
		t,
		tracking.current_memory_allocated == 0 &&
		ledger.live == 0 &&
		len(tracking.bad_free_array) == 0,
	)
}

@(test)
every_observed_owning_allocation_refusal :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		800,
		600,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	for page in ([4]model.Page{.Catalogue, .Layout, .Controls, .Profiles}) {for op in 0 ..< 4 {
			count := exercise_refusal(t, renderer, data, page, op, 0)
			for refuse in 1 ..= count {exercise_refusal(t, renderer, data, page, op, refuse)}
		}}
}
