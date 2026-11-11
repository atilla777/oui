package main

import "core:fmt"
import "core:mem"
import "core:os"
import base "ui:ui_base"
import custom "ui:ui_custom"
import painter "ui:ui_custom/sdl"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import rich "ui:ui_rich"
import fonts "ui:ui_rich/sdl"
import backend "ui:ui_sdl"
import style "ui:ui_style"
import transitions "ui:ui_transitions"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

TEST :: #config(STANDALONE_MENU_TEST, false)
Options :: struct {
	font:                     string,
	width, height:            i32,
	scale:                    f64,
	english, check, controls: bool,
}
options :: proc(args: []string) -> (Options, bool) {
	o := Options {
		width  = 800,
		height = 600,
		scale  = 1,
	}
	for j := 0; j < len(args); j += 1 {
		key := args[j]
		if key == "--window-check" {o.check = true; continue}
		if key ==
		   "--test-controls" {when TEST {o.controls = true; continue} else {return {}, false}}
		if j + 1 >= len(args) {return {}, false}; j += 1; value := args[j]
		switch key {
		case "--font":
			o.font = value
		case "--locale":
			if value == "en" {o.english = true} else if value != "ru" {return {}, false}
		case "--size":
			if value ==
			   "480x320" {o.width, o.height = 480, 320} else if value != "800x600" {return {}, false}
		case "--scale":
			switch value {case "1":
				o.scale = 1; case "1.5":
				o.scale = 1.5; case "2":
				o.scale = 2; case:
				return {}, false}
		case:
			return {}, false
		}
	}
	return o, o.font != ""
}
valid :: proc(p: []u8) -> bool {return len(p) == 1 && p[0] == 1}
measure :: proc(_: []u8, _: custom.Constraints) -> (base.Extent, bool) {return {50, 50}, true}
hit :: proc(_: []u8, point: [2]f64, size: base.Extent) -> bool {x, y :=
		(point[0] - size.w / 2) / (size.w / 2), (point[1] - size.h / 2) / (size.h / 2)
	return x * x + y * y < 1}
disk :: proc(c: painter.Canvas, _: []u8, view: painter.Custom_View) -> bool {
	r := view.presentation.area
	return painter.canvas_fill_circle(
		c,
		{r.x + r.w / 2, r.y + r.h / 2},
		r.w / 2,
		{35, 66, 96, 255},
	)
}
Runtime :: struct {
	painters: ^painter.Generation, // Borrowed from run; outlives Runtime.
	p:        base.Publication,
	ctx:      interaction.Context,
	cs:       custom.State,
	ts:       transitions.State,
	rc:       rich.Candidate,
	paint:    style.Frame,
	input:    backend.Input,
	effects:  u64,
	failed:   bool,
}
destroy :: proc(r: ^Runtime) {
	rich.destroy_candidate(&r.rc); style.destroy_frame(&r.paint)
	custom.destroy(
		&r.cs,
	); transitions.destroy(&r.ts); interaction.destroy(&r.ctx); base.destroy(&r.p)
}
rebuild :: proc(
	r: ^Runtime,
	font: ^fonts.Generation,
	size: base.Extent,
	o: Options,
	a: mem.Allocator,
) -> bool {
	stamp, se := base.begin_attempt(&r.p, r.effects + 1); if se != .None {return false}
	if r.failed {r.failed = false; return false}
	tc, te := transitions.prepare(
		&r.ts,
		stamp,
		[]transitions.Description {
			{
				node_id = "disk",
				tracks = []transitions.Track{{property = .Offset, target = [2]f64{30, 0}}},
			},
		},
		{},
		false,
		a,
	)
	defer transitions.destroy_candidate(&tc); if te.code != .None {return false}
	message := "[b]Проверка библиотеки[/b]\nКруглая кнопка: точная форма. [i]Русский текст[/i]"; if o.english {message = "[b]Library check[/b]\nCircle button: exact shape. [i]English text[/i]"}
	nodes := []layout.Node {
		{
			id = "root",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fill},
				y = {mode = .Fill},
				padding = {10, 10, 10, 10},
				gap = 10,
			},
		},
		{
			id = "text",
			parent = "root",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Content}},
		},
		{
			id = "disk",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 50},
				y = {mode = .Fixed, value = 50},
			},
		},
	}
	rc, re := rich.prepare(
		nodes,
		{drawable = size, ui_scale = o.scale},
		[]rich.Description {
			{
				id = "text",
				source = message,
				base_style = {font_id = "body", size = 16, color = {240, 240, 240, 255}},
				options = {wrap = .WordWrap, overflow = .Ellipsis, max_lines = 3},
			},
		},
		fonts.rich_metrics(font),
		a,
		stamp,
	)
	defer rich.destroy_candidate(&rc); if re.code != .None {fmt.eprintln("rich", re); return false}
	i, ie := interaction.prepare(
		&rc.geometry,
		[]interaction.Target{{"disk", "button", true, true}},
		[]interaction.Capture_Claim{{"disk", "custom"}},
		a,
	)
	defer interaction.destroy_frame(
		&i,
	); if ie != .Applied || interaction.bind_activation_owner(&i, "disk", "custom") != .Applied {return false}
	cc, ce := custom.prepare(
		&rc.geometry,
		&i,
		[]custom.Description {
			{
				node_id = "disk",
				type_id = "circle",
				revision = "1",
				payload = []u8{1},
				validate = valid,
				measure = measure,
				hit = hit,
			},
		},
		a,
	)
	defer custom.destroy_candidate(&cc); if ce.code != .None {return false}
	if transitions.bind_geometry(&tc, &rc.geometry, &i).code != .None ||
	   !transitions.sample_interaction(&tc.frame, &i) ||
	   !custom.sample_candidate(&cc, transitions.geometry_view(&tc.frame)) {return false}
	paint, pe := style.prepare(
		&rc.geometry,
		[]style.Description{{id = "text", role = "label"}, {id = "disk", role = "button"}},
		{},
		{revision = "content-v1"},
		a,
	)
	defer style.destroy_frame(&paint)
	if pe.code != .None ||
	   !transitions.sample_style(&tc.frame, &paint) ||
	   painter.preflight(r.painters, &cc, &paint).code != .None {return false}
	if !custom.validate_candidate(&r.p, &cc) ||
	   !transitions.validate_candidate(&r.p, &r.ts, &tc) ||
	   !rich.validate_candidate(&r.p, &rc) {return false}
	if base.enter_commit(&r.p, stamp) != .None {return false}
	interaction.commit(&r.ctx, &i); custom.commit(&r.cs, &cc); transitions.commit(&r.ts, &tc)
	old_rich, old_paint := r.rc, r.paint; r.rc, rc = rc, {}; r.paint, paint = paint, {}
	base.finish_commit(
		&r.p,
		stamp,
	); rich.destroy_candidate(&old_rich); style.destroy_frame(&old_paint)
	fmt.printf(
		"ready effects=%d sequence=%d attempt=%d locale-en=%v size=%v scale=%v\n",
		r.effects,
		r.p.sequence,
		stamp.attempt,
		o.english,
		size,
		o.scale,
	)
	return true
}
main :: proc() {if !run() {os.exit(1)}}
run :: proc() -> (ok: bool) {
	o, valid_options := options(
		os.args[1:],
	); if !valid_options {fmt.eprintln("content consumer: --font FILE --locale ru|en --size 800x600|480x320 --scale 1|1.5|2"); return false}
	if !sdl.Init({.VIDEO}) {return false}; defer sdl.Quit()
	if !ttf.Init() {return false}; defer ttf.Quit()
	w := sdl.CreateWindow(
		"Standalone Menu",
		o.width,
		o.height,
		{.HIDDEN, .RESIZABLE, .HIGH_PIXEL_DENSITY},
	); if w == nil {return false}; defer sdl.DestroyWindow(w)
	renderer := sdl.CreateRenderer(
		w,
		nil,
	); if renderer == nil {return false}; defer sdl.DestroyRenderer(renderer)
	data, de := os.read_entire_file(
		o.font,
		context.allocator,
	); if de != nil {return false}; defer delete(data)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	fg, fe := fonts.create_generation(
		renderer,
		"content-v1",
		nil,
		[]fonts.Rich_Font_Source{{"body", data}},
		[]fonts.Rich_Font_Chain{{"body", nil}},
		[]fonts.Rich_Font_Request {
			{"body", 16, false, false, false},
			{"body", 16, true, false, false},
			{"body", 16, false, true, false},
		},
		o.scale,
		a,
	)
	if fe.code != .None {fmt.eprintln(fe); return false}; defer fonts.release_generation(&fg)
	pg, pe := painter.create_generation(
		renderer,
		"content-v1",
		[]painter.Painter{{"circle", "1", disk}},
		a,
	); if pe.code != .None {return false}; defer painter.release_generation(&pg)
	r := Runtime {
		painters = pg,
	}; r.p, _ = base.create(
		a,
	); r.ctx = interaction.create(a, &r.p); r.cs = custom.create(); r.ts = transitions.create(a); r.input.window_id = sdl.GetWindowID(w)
	defer {
		destroy(&r); fonts.release_generation(&fg); painter.release_generation(&pg)
		fmt.printf(
			"destroy live=%d peak=%d allocations=%d bytes=%d bad-frees=%d\n",
			tracking.current_memory_allocated,
			tracking.peak_memory_allocated,
			tracking.total_allocation_count,
			tracking.total_memory_allocated,
			len(tracking.bad_free_array),
		)
		if tracking.current_memory_allocated != 0 || len(tracking.bad_free_array) != 0 {ok = false}
	}
	width, height: i32
	if !sdl.GetRenderOutputSize(renderer, &width, &height) ||
	   !rebuild(&r, fg, {f64(width), f64(height)}, o, a) ||
	   !sdl.ShowWindow(w) {return false}
	frames := 0
	for {
		e: sdl.Event
		for sdl.PollEvent(&e) {
			if e.type == .QUIT || e.type == .WINDOW_CLOSE_REQUESTED {return true}
			if e.type == .KEY_DOWN && !e.key.repeat {
				if e.key.key ==
				   sdl.K_R {rebuild(&r, fg, {f64(width), f64(height)}, o, a); continue}
				when TEST {if o.controls {
						if e.key.key == sdl.K_F12 {return true}
						if e.key.key == sdl.K_F2 {r.failed = true; continue}
						if e.key.key ==
						   sdl.K_F10 {nw, nh := i32(480), i32(320); if o.width == 480 {nw, nh = 800, 600}; o.width, o.height = nw, nh; sdl.SetWindowSize(w, nw, nh); continue}
					}}
			}
			if e.type == .WINDOW_PIXEL_SIZE_CHANGED || e.type == .WINDOW_RESIZED {
				if !sdl.GetRenderOutputSize(renderer, &width, &height) {return false}
				rebuild(&r, fg, {f64(width), f64(height)}, o, a); continue
			}
			ww, wh: i32; if !sdl.GetWindowSize(w, &ww, &wh) {return false}
			n := backend.normalize_event(&r.input, &r.ctx, e, {f64(ww), f64(wh)})
			cr := painter.handle(&r.cs, &r.ctx, n)
			if cr.dispatch.has_event {r.effects += 1}
			if !r.p.ready && !n.loss {rebuild(&r, fg, {f64(width), f64(height)}, o, a)}
		}
		if !sdl.SetRenderDrawColor(renderer, 16, 22, 31, 255) ||
		   !sdl.RenderClear(renderer) {return false}
		if r.p.ready {
			if !fonts.render_node(fg, &r.rc.frame, &r.paint, "text") ||
			   painter.render_node(pg, &r.cs.frame, &r.paint, "disk").code !=
				   .None {base.invalidate(&r.p); return false}
		}
		if o.check && frames == 2 {
			surface, read := backend.readback(
				renderer,
				{f64(width), f64(height)},
			); if !read {return false}; sdl.DestroySurface(surface)
			fmt.println("render/readback/present ok")
		}
		if !sdl.RenderPresent(renderer) {return false}
		frames += 1; if o.check && frames >= 3 {return true}; sdl.Delay(16)
	}
}
