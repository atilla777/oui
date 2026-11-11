package main

import recipe ".."
import fixture "../../native_fixture"
import "core:fmt"
import "core:os"
import "core:time"
import base "ui:ui_base"
import hold "ui:ui_hold"
import adapter "ui:ui_hold/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

State :: struct {
	p:                  base.Publication,
	ctx:                interaction.Context,
	ls:                 layers.State,
	hs:                 hold.State,
	a:                  adapter.Adapter,
	reader:             recipe.Reader,
	hp:                 f64,
	effects, conflicts: int,
	revision:           u64,
}
publish :: proc(s: ^State) {recipe.destroy_reader(&s.reader); s.reader = recipe.publish(
		&s.p,
		&s.ctx,
		&s.ls,
		&s.hs,
		s.hp,
		s.revision,
		&s.conflicts,
		{800, 600},
	)}
input :: proc(f: ^fixture.Fixture, s: ^State, e: sdl.Event) {
	n := fixture.normalized(f, &s.ctx, e)
	r := adapter.handle(&s.a, &s.hs, &s.ctx, n)
	if !r.consumed {backend.dispatch_input(&s.ctx, n)}
	publish(s)
}
verify :: proc(f: ^fixture.Fixture, s: ^State, quiet := false, sample: ^fixture.Sample = nil) {
	before := s.effects
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = f.input.window_id,
		key      = sdl.K_SPACE,
	}
	input(f, s, e); assert(s.hs.live.phase == .Holding)
	assert(
		!hold.dispatch(&s.hs, &s.ctx, {kind = .Advance, duration_ms = 999}).dispatch.has_event,
	); publish(s)
	x := hold.dispatch(
		&s.hs,
		&s.ctx,
		{kind = .Advance, duration_ms = 1},
	); assert(x.dispatch.has_event)
	s.hp = 100; s.effects += 1; s.revision += 1; publish(s)
	e.key.type = .KEY_UP; input(f, s, e)
	e.key.type = .KEY_DOWN; input(f, s, e)
	loss: sdl.Event; loss.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = f.input.window_id,
	}; input(f, s, loss)
	assert(s.hs.live.phase != .Holding)
	t := fixture.begin(f)
	base.invalidate(
		&s.p,
	); assert(hold.dispatch(&s.hs, &s.ctx, {kind = .Advance, duration_ms = 1000}).code == .Not_Ready)
	if sample != nil {sample.failure_ns = fixture.elapsed(f, t)}
	t = fixture.begin(f); publish(s); assert(s.effects == before + 1)
	if sample != nil {sample.recovery_ns = fixture.elapsed(f, t)}
	e.key.type = .KEY_UP; input(f, s, e)
	loss.window.type = .WINDOW_FOCUS_GAINED; input(f, s, loss)
	if !quiet {fmt.println("native-hud=ok threshold=999+1 loss=cancel failure=not-ready recovery=no-replay input=native-synthetic")}
}
draw :: proc(f: ^fixture.Fixture, s: ^State) -> bool {
	f.overlay = progress_overlay; f.overlay_user = s
	label := "Восстановить" if f.russian else "Restore"
	value := fmt.aprintf("HP %.0f/100", s.hp); defer delete(value)
	return fixture.paint_labels(
		f,
		&s.reader.geometry,
		[]string{"restore", "progress"},
		[]string{label, value},
	)
}
progress_overlay :: proc(renderer: ^sdl.Renderer, user: rawptr) -> bool {
	s := cast(^State)user
	assert(base.is_current(&s.p, s.reader.hold.stamp))
	saved, valid := backend.save_renderer_state(renderer); if !valid {return false}
	defer {assert(backend.restore_renderer_state(renderer, saved))}
	if !sdl.SetRenderClipRect(renderer, nil) ||
	   !sdl.SetRenderDrawColor(renderer, 60, 180, 120, 255) {return false}
	for p in s.reader.hold.progress {rect := sdl.FRect{f32(p.fill.x), f32(p.fill.y), f32(p.fill.w), f32(p.fill.h)}; if !sdl.RenderFillRect(renderer, &rect) {return false}}
	return true
}
main :: proc() {if !run() {os.exit(1)}}
run :: proc() -> bool {
	started := time.tick_now()
	f: fixture.Fixture; defer fixture.close(&f); if !fixture.init(&f) {return false}
	context.allocator = fixture.owner_allocator(&f)
	s: State; s.hp = 60; s.revision = 1
	p, e := base.create(context.allocator); if e != .None {return false}; s.p = p
	s.ctx = interaction.create(
		context.allocator,
		&s.p,
	); s.ls = layers.create(context.allocator); s.hs = hold.create(context.allocator)
	defer {t := time.tick_now(); recipe.destroy_reader(&s.reader); hold.destroy(&s.hs)
		layers.destroy(&s.ls)
		interaction.destroy(&s.ctx)
		base.destroy(&s.p)
		ns := i64(time.tick_since(t))
		fmt.printf("Q owner_teardown scope=hud on=%t ns=%d\n", f.instrument, ns)}
	publish(&s)
	fixture.require_owner_observations(&f)
	cold := fixture.Sample {
		index    = -11,
		total_ns = i64(time.tick_since(started)),
		after    = fixture.counters(&f),
	}
	fixture.describe(&f)
	fmt.printf(
		"Q sizes state=%d publication=%d interaction=%d reader=%d\n",
		size_of(State),
		size_of(s.p),
		size_of(s.ctx),
		size_of(recipe.Reader),
	)
	done := false
	for {
		event: sdl.Event
		for sdl.PollEvent(&event) {
			if fixture.quit(event) {return true}
			if event.type == .KEY_DOWN && event.key.key == sdl.K_F9 && !done {
				samples: [40]fixture.Sample
				for &sample, i in samples {sample.index = i - 10; sample.before = fixture.counters(&f); t := time.tick_now(); if !workload_cycle(&f, &s, &sample) {return false}; f.active_sample = &sample; ok := draw(&f, &s); f.active_sample = nil; if !ok {return false}; sample.total_ns = i64(time.tick_since(t)); sample.after = fixture.counters(&f)}
				fixture.emit(
					&f,
					"hud-cold",
					[]fixture.Sample{cold},
				); fixture.emit(&f, "hud", samples[:]); fmt.printf("Q outcome workload=hud hp=%.0f effects=%d revision=%d hold=%v\n", s.hp, s.effects, s.revision, s.hs.live.phase); fmt.println("Q complete workload=hud warmup=10 samples=30"); done = true; continue
			}
			if fixture.check(
				event,
			) {fixture.check_invalid_font(&f); verify(&f, &s)} else {input(&f, &s, event)}
		}
		if !draw(&f, &s) {return false}; sdl.Delay(10)
	}
}
