package qualification_menu

import menu ".."
import fixture "../../../tests/ui_recipes/native_fixture"
import "core:fmt"
import "core:os"
import "core:time"
import sdl "vendor:sdl3"

main :: proc() {if !run() {os.exit(1)}}
run :: proc() -> bool {
	started := time.tick_now()
	f: fixture.Fixture; defer fixture.close(&f); if !fixture.init(&f, false) {return false}
	context.allocator = fixture.owner_allocator(&f)
	data, e := os.read_entire_file(f.font_path, context.allocator); if e != nil {return false}
	r: menu.Runtime
	defer {
		t := time.tick_now(); menu.destroy(&r); delete(data); ns := i64(time.tick_since(t))
		fmt.printf("Q owner_teardown scope=menu on=%t ns=%d\n", f.instrument, ns)
	}
	if !init_runtime(&r, &f, data) {return false}
	r.input.window_id =
		f.input.window_id; r.drawable = f.drawable; r.model.locale = .Russian if f.russian else .English
	if !menu.rebuild(&r) {return false}
	fixture.require_owner_observations(&f)
	cold := fixture.Sample {
		index    = -11,
		total_ns = i64(time.tick_since(started)),
		after    = fixture.counters(&f),
	}
	fixture.describe(&f)
	fmt.printf(
		"Q sizes runtime=%d publication=%d interaction=%d reader=%d\n",
		size_of(menu.Runtime),
		size_of(r.publication),
		size_of(r.interaction),
		size_of(menu.Reader),
	)
	fmt.printf(
		"Q ready workload=menu renderer=%s on=%t\n",
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
				for &sample, i in samples {
					sample.index =
						i - 10; sample.before = fixture.counters(&f); t := time.tick_now()
					if !cycle(&r, &f, &sample) {return false}
					sample.total_ns = i64(time.tick_since(t)); sample.after = fixture.counters(&f)
				}
				fixture.emit(
					&f,
					"menu-cold",
					[]fixture.Sample{cold},
				); fixture.emit(&f, "menu", samples[:]); fmt.printf("Q outcome workload=menu count=%d effects=%d revision=%d page=%v\n", r.model.count, r.model.effects, r.model.revision, r.model.page); fmt.println("Q complete workload=menu warmup=10 samples=30"); done = true
			}
		}
		if !menu.present(&r) {return false}; sdl.Delay(10)
	}
}
