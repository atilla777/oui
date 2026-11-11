package main

import fixture "../../../tests/ui_recipes/native_fixture"
import app "../app"
import model "../model"
import "core:fmt"
import "core:os"
import "core:time"
import sdl "vendor:sdl3"

main :: proc() {if !run() {os.exit(1)}}
run :: proc() -> bool {
	started := time.tick_now()
	args := make([dynamic]string); defer delete(args)
	for arg in os.args[1:] {if arg != "--instrument" {append(&args, arg)}}
	o, valid := app.parse_options(
		args[:],
	); if !valid || o.locale != .Russian || o.scale != 1 || (o.page != .Collections && o.page != .Catalogue) {return false}
	f: fixture.Fixture; defer fixture.close(&f); if !fixture.init(&f, false, "UI Showcase") {return false}
	context.allocator = fixture.owner_allocator(&f)
	data, e := os.read_entire_file(o.font, context.allocator); if e != nil {return false}
	fallback: []u8
	if o.fallback_font !=
	   "" {fallback, e = os.read_entire_file(o.fallback_font, context.allocator); if e != nil {delete(data); return false}}
	s := app.Shell {
		model = model.initial(),
		renderer = f.renderer,
		window = f.window,
		font_data = data,
		allocator = context.allocator,
		drawable = f.drawable,
		ledger = fixture.ledger(&f),
		sources = {fallback = fallback, assets = o.assets, alternate_assets = o.alternate_assets},
	}
	s.model.page =
		o.page; s.model.measurements_off = !f.instrument; s.input.window_id = f.input.window_id
	defer {t := time.tick_now(); assert(app.destroy_shell(&s)); delete(data); delete(fallback)
		ns := i64(time.tick_since(t))
		fmt.printf("Q owner_teardown scope=showcase on=%t ns=%d\n", f.instrument, ns)}
	if !app.enter(&s) {return false}
	fixture.require_owner_observations(&f)
	cold := fixture.Sample {
		index    = -11,
		total_ns = i64(time.tick_since(started)),
		after    = fixture.counters(&f),
	}
	fixture.describe(&f)
	fmt.printf("Q source-font-bytes primary=%d fallback=%d\n", len(data), len(fallback))
	fmt.printf(
		"Q sizes runtime=%d publication=%d interaction=%d reader=%d\n",
		size_of(app.Runtime),
		size_of(s.runtime.publication),
		size_of(s.runtime.interaction),
		size_of(app.Reader),
	)
	collection := o.page == .Collections; scope := "collection" if collection else "switches"
	fmt.printf(
		"Q ready workload=%s renderer=%s on=%t\n",
		scope,
		sdl.GetRendererName(f.renderer),
		f.instrument,
	)
	done := false
	for {
		event: sdl.Event
		for sdl.PollEvent(&event) {
			if fixture.quit(event) {return true}
			if event.type == .KEY_DOWN && event.key.key == sdl.K_F9 && !done {
				samples: [40]fixture.Sample
				for &sample, i in samples {sample.index = i - 10; sample.before = fixture.counters(&f); t := time.tick_now(); if !cycle(&s, &f, collection, &sample) {return false}; sample.total_ns = i64(time.tick_since(t)); sample.after = fixture.counters(&f)}
				fixture.emit(
					&f,
					"showcase-cold",
					[]fixture.Sample{cold},
				); fixture.emit(&f, scope, samples[:]); fmt.printf("Q outcome workload=%s page=%v effects=%d revision=%d collection_count=%d selected=%d locale=%v scale=%v\n", scope, s.model.page, s.model.effects, s.model.revision, s.collection.count, s.collection.selected, s.model.locale, s.model.scale); fmt.printf("Q complete workload=%s warmup=10 samples=30\n", scope); done = true
			}
		}
		if !app.present(&s.runtime) {return false}; sdl.Delay(10)
	}
}
