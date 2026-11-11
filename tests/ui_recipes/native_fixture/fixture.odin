// Verification-only SDL plumbing shared by the three thin native recipes.
// Not exported as a library capability or a build/run framework.
package native_fixture

import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import style "ui:ui_style"
import text "ui:ui_text"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Fixture :: struct {
	window:                                         ^sdl.Window,
	renderer:                                       ^sdl.Renderer,
	input:                                          backend.Input,
	fonts:                                          ^fonts.Generation,
	images:                                         ^backend.Generation,
	ledger:                                         backend.Resource_Ledger,
	tracking:                                       mem.Tracking_Allocator,
	observer:                                       mem.Tracking_Allocator,
	previous:                                       mem.Allocator,
	font_path:                                      string,
	drawable:                                       layout.Extent,
	instrument:                                     bool,
	active_sample:                                  ^Sample,
	overlay:                                        proc(_: ^sdl.Renderer, _: rawptr) -> bool,
	overlay_user:                                   rawptr,
	russian:                                        bool,
	initialized, ttf_initialized, allocator_active: bool,
}

init :: proc(f: ^Fixture, own_fonts := true, title: cstring = "Standalone Menu") -> bool {
	font_path := ""
	f.drawable = {800, 600}
	for i := 1; i < len(os.args); i += 1 {
		if os.args[i] == "--test-controls" {continue}
		if os.args[i] == "--instrument" {f.instrument = true; continue}
		if i + 1 >= len(os.args) {return false}
		switch os.args[i] {
		case "--font":
			font_path = os.args[i + 1]
		case "--locale":
			f.russian = os.args[i + 1] == "ru"
		case "--size":
			if os.args[i + 1] ==
			   "1280x960" {f.drawable = {1280, 960}} else if os.args[i + 1] != "800x600" {return false}
		case "--scale":
			if os.args[i + 1] != "1" {return false}
		case "--section", "--fallback-font", "--assets", "--alternate-assets": // Validated by the showcase fixture's existing parser.
		case:
			return false
		}
		i += 1
	}
	if font_path == "" {return false}
	f.font_path = font_path
	f.initialized = sdl.Init({.VIDEO, .GAMEPAD}); if !f.initialized {return false}
	f.ttf_initialized = ttf.Init(); if !f.ttf_initialized {return false}
	// Existing ISD standalone-menu launch contract, with explicit consumer_root.
	// The manifest's consumer path identifies the recipe, not this window title.
	f.window = sdl.CreateWindow(title, i32(f.drawable.w), i32(f.drawable.h), {})
	if f.window == nil {return false}
	f.renderer = sdl.CreateRenderer(f.window, nil); if f.renderer == nil {return false}
	f.input.window_id = sdl.GetWindowID(f.window)
	f.previous = context.allocator
	if f.instrument {
		mem.tracking_allocator_init(&f.observer, f.previous)
		mem.tracking_allocator_init(&f.tracking, f.previous, mem.tracking_allocator(&f.observer))
		f.allocator_active = true
	}
	context.allocator = owner_allocator(f)
	if !own_fonts {return true}
	data, e := os.read_entire_file(font_path, context.allocator)
	if e != nil {return false}; defer delete(data)
	font, fe := fonts.create_generation(
		f.renderer,
		"native-recipe-font",
		[]fonts.Font_Source{{"fixture", 10, data}},
		1,
		context.allocator,
		ledger(f),
	)
	if fe.code != .None {return false}; f.fonts = font
	images, ie := backend.create_generation(
		f.renderer,
		"native-recipe-images",
		nil,
		context.allocator,
		ledger(f),
	)
	if ie.code != .None {return false}; f.images = images
	return true
}
describe :: proc(f: ^Fixture) {
	vsync: i32; known := sdl.GetRenderVSync(f.renderer, &vsync)
	fmt.printf(
		"Q environment video=%s renderer=%s vsync_known=%t vsync=%d drawable=%.0fx%.0f locale=%s scale=1 fixture_bytes=%d sample_bytes=%d\n",
		sdl.GetCurrentVideoDriver(),
		sdl.GetRendererName(f.renderer),
		known,
		vsync,
		f.drawable.w,
		f.drawable.h,
		"ru" if f.russian else "en",
		size_of(Fixture),
		size_of(Sample),
	)
}
check_invalid_font :: proc(f: ^Fixture) {
	// Real invalid-resource refusal, distinguished from test-injected faults.
	bad, be := fonts.create_generation(
		f.renderer,
		"invalid",
		[]fonts.Font_Source{{"fixture", 10, []u8{0, 1, 2}}},
		1,
		context.allocator,
		ledger(f),
	)
	assert(bad == nil && be.code != .None)
	fmt.println("native-real-invalid-font=refused")
}

close :: proc(f: ^Fixture) {
	started := time.tick_now()
	context.allocator = f.previous if f.allocator_active else context.allocator
	backend.close_input(&f.input)
	fonts.release_generation(&f.fonts); backend.release_generation(&f.images)
	final := counters(f)
	if f.allocator_active {
		assert(
			f.tracking.current_memory_allocated == 0 &&
			len(f.tracking.bad_free_array) == 0 &&
			f.ledger.live == 0 &&
			f.ledger.created == f.ledger.destroyed,
		)
		context.allocator = f.previous; mem.tracking_allocator_destroy(&f.tracking)
		assert(f.observer.current_memory_allocated == 0 && len(f.observer.bad_free_array) == 0)
		mem.tracking_allocator_destroy(&f.observer)
	}
	if f.renderer != nil {sdl.DestroyRenderer(f.renderer)}
	if f.window != nil {sdl.DestroyWindow(f.window)}
	if f.ttf_initialized {ttf.Quit()}
	if f.initialized {sdl.Quit()}
	elapsed_ns := i64(time.tick_since(started))
	if f.instrument {fmt.printf("native-cleanup ui-live=%d bad-frees=0 retained-handles=%d acquired=%d released=%d observer-live=0 ui-allocs=%d ui-bytes=%d ui-peak=%d observer-allocs=%d observer-bytes=%d observer-peak=%d\n", final.live, final.native_live, final.native_created, final.native_destroyed, final.allocs, final.bytes, final.peak, final.observer_allocs, final.observer_bytes, final.observer_peak)} else {fmt.println("native-cleanup ui-memory/retained-ledger=unavailable (observers off)")}
	fmt.printf(
		"Q teardown on=%t ns=%d (helper native teardown; owner teardown reported separately)\n",
		f.instrument,
		elapsed_ns,
	)
	fmt.println(
		"native-cleanup window=0 renderer=0 input-gamepad=0; SDL/TTF/driver heaps unavailable",
	)
}

paint :: proc(f: ^Fixture, g: ^layout.Frame, tf: ^text.Frame) -> bool {
	ds := make([]style.Description, len(g.nodes)); defer delete(ds)
	plain := []style.Declaration {
		{.Font, style.Font_ID{"fixture"}},
		{.Font_Size, f64(10)},
		{.Foreground, style.Color{240, 240, 240, 255}},
		{.Background, style.Color{35, 66, 96, 255}},
	}
	for n, i in g.nodes {ds[i] = {
			id   = n.description.id,
			role = "native-fixture",
		}; ds[i].appearance.local.states[.Normal] = plain}
	frame, e := style.prepare(
		g,
		ds,
		{revision = "native-recipe-theme"},
		{revision = f.images.revision},
		context.allocator,
	)
	if e.code !=
	   .None {fmt.eprintf("native style: %v\n", e); return false}; defer style.destroy_frame(&frame)
	phase_start := begin(f)
	if !backend.render(
		f.images,
		&frame,
	) {fmt.eprintf("native primitives: %s\n", sdl.GetError()); return false}
	if f.overlay != nil && !f.overlay(f.renderer, f.overlay_user) {return false}
	if !fonts.render(
		f.fonts,
		tf,
		&frame,
	) {fmt.eprintf("native text: %s matches=%t\n", sdl.GetError(), fonts.matches(f.fonts, tf, &frame)); return false}
	if f.active_sample != nil {f.active_sample.draw_ns += elapsed(f, phase_start)}
	phase_start = begin(f)
	pixels, ok := backend.readback(f.renderer, g.drawable)
	if !ok {return false}; sdl.DestroySurface(pixels)
	if f.active_sample != nil {f.active_sample.readback_ns += elapsed(f, phase_start)}
	phase_start = begin(f)
	ok = sdl.RenderPresent(f.renderer)
	if f.active_sample != nil {f.active_sample.present_ns += elapsed(f, phase_start)}
	return ok
}

// Add only fixed-position root text siblings; assert the extra labels cannot change
// any published interaction geometry. The original typed owner remains sole input owner.
paint_labels :: proc(f: ^Fixture, g: ^layout.Frame, ids, labels: []string) -> bool {
	nodes := make([dynamic]layout.Node); defer delete(nodes)
	for n in g.nodes {append(&nodes, n.description)}
	assert(nodes[0].role == .Stack)
	nodes[0].role = .Absolute // Drawing-only overlay; verify every original bound below.
	ts := make([]text.Text_Node, len(ids)); defer delete(ts)
	label_ids := make(
		[]string,
		len(ids),
	); defer {for id in label_ids {delete(id)}; delete(label_ids)}
	for id, i in ids {
		label_id := fmt.aprintf("native-label-%d", i); label_ids[i] = label_id
		n, found := layout.find(g, id); if !found {return false}
		append(
			&nodes,
			layout.Node {
				id = label_id,
				parent = g.nodes[0].description.id,
				role = .Content,
				enabled = true,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = n.bounds.w},
					y = {mode = .Fixed, value = max(n.bounds.h, 16)},
					offset = {
						n.bounds.x - g.nodes[0].content.x,
						n.bounds.y - g.nodes[0].content.y,
					},
				},
			},
		)
		ts[i] = {
			id        = label_id,
			text      = labels[i],
			font      = {"fixture"},
			font_size = 10,
		}
	}
	c, e := text.prepare(
		ts,
		nodes[:],
		{drawable = g.drawable, ui_scale = 1},
		fonts.metrics(f.fonts),
		context.allocator,
		g.stamp,
	)
	if e.code !=
	   .None {fmt.eprintf("native labels: %v\n", e); return false}; defer text.destroy_candidate(&c)
	for n in g.nodes {copy, found := layout.find(&c.geometry, n.description.id); assert(found && copy.bounds == n.bounds && copy.clip == n.clip)}
	return paint(f, &c.geometry, &c.text)
}

normalized :: proc(
	f: ^Fixture,
	ctx: ^interaction.Context,
	e: sdl.Event,
) -> backend.Normalized_Input {
	return backend.normalize_event(&f.input, ctx, e, f.drawable)
}

ledger :: proc(f: ^Fixture) -> ^backend.Resource_Ledger {return &f.ledger if f.instrument else nil}
owner_allocator :: proc(f: ^Fixture) -> mem.Allocator {return(
		mem.tracking_allocator(&f.tracking) if f.instrument else f.previous \
	)}
require_owner_observations :: proc(f: ^Fixture) {if f.instrument {c := counters(f); assert(
			c.allocs > 0 && c.live > 0 && c.observer_allocs > 0 && c.observer_live > 0,
		)}}
Counters :: struct {
	allocs, bytes, live, peak, observer_allocs, observer_bytes, observer_live, observer_peak: i64,
	native_live, native_created, native_destroyed, native_peak:                               u64,
}
counters :: proc(f: ^Fixture) -> Counters {
	if !f.instrument {return {}}
	return {
		f.tracking.total_allocation_count,
		f.tracking.total_memory_allocated,
		f.tracking.current_memory_allocated,
		f.tracking.peak_memory_allocated,
		f.observer.total_allocation_count,
		f.observer.total_memory_allocated,
		f.observer.current_memory_allocated,
		f.observer.peak_memory_allocated,
		f.ledger.live,
		f.ledger.created,
		f.ledger.destroyed,
		f.ledger.peak,
	}
}
Sample :: struct {
	rebuild_phases_available:                                                      bool,
	prepare_ns, phase_copy_ns, commit_ns:                                          i64,
	index:                                                                         int,
	total_ns:                                                                      i64,
	action_ns, copy_ns, draw_ns, readback_ns, present_ns, failure_ns, recovery_ns: i64,
	before, after:                                                                 Counters,
}
emit :: proc(f: ^Fixture, scope: string, samples: []Sample) {
	for s in samples {
		fmt.printf(
			"Q scope=%s i=%d on=%t total_ns=%d internal_available=%t action_ns=%d copy_ns=%d draw_ns=%d readback_ns=%d present_ns=%d failure_ns=%d recovery_ns=%d allocs=%d bytes=%d live=%d peak=%d observer_allocs=%d observer_bytes=%d observer_live=%d observer_peak=%d native_live=%d native_created=%d native_destroyed=%d native_peak=%d rebuild_phases_available=%t prepare_ns=%d phase_copy_ns=%d commit_ns=%d\n",
			scope,
			s.index,
			f.instrument,
			s.total_ns,
			f.instrument,
			s.action_ns,
			s.copy_ns,
			s.draw_ns,
			s.readback_ns,
			s.present_ns,
			s.failure_ns,
			s.recovery_ns,
			s.after.allocs - s.before.allocs,
			s.after.bytes - s.before.bytes,
			s.after.live,
			s.after.peak,
			s.after.observer_allocs - s.before.observer_allocs,
			s.after.observer_bytes - s.before.observer_bytes,
			s.after.observer_live,
			s.after.observer_peak,
			s.after.native_live,
			s.after.native_created,
			s.after.native_destroyed,
			s.after.native_peak,
			s.rebuild_phases_available,
			s.prepare_ns,
			s.phase_copy_ns,
			s.commit_ns,
		)
	}
}
begin :: proc(f: ^Fixture) -> time.Tick {if f.instrument {return time.tick_now()}; return {}}
elapsed :: proc(f: ^Fixture, t: time.Tick) -> i64 {if f.instrument {return i64(time.tick_since(t))}
	return 0}

import interaction "ui:ui_interaction"
// F11 requests a bounded verification scenario; F12 requests graceful cleanup.
quit :: proc(e: sdl.Event) -> bool {return(
		e.type == .QUIT ||
		e.type == .WINDOW_CLOSE_REQUESTED ||
		(e.type == .KEY_DOWN && e.key.key == sdl.K_F12) \
	)}
check :: proc(e: sdl.Event) -> bool {return(
		e.type == .KEY_DOWN &&
		!e.key.repeat &&
		e.key.key == sdl.K_F11 \
	)}
