// Independent app-owned strings/font binding; no reference-app import.
package outside_app

import "core:fmt"
import "core:os"
import base "ui:ui_base"
import layout "ui:ui_layout"
import fonts "ui:ui_sdl_text"
import text "ui:ui_text"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Model :: struct {
	count:    int,
	captions: [2]string,
}

main :: proc() {
	assert(len(os.args) == 2, "explicit application font path required")
	model := Model{7, {"Outside application", "Внешнее приложение"}}
	bytes, e := os.read_entire_file(os.args[1], context.allocator); assert(e == nil)
	defer delete(bytes)
	assert(sdl.Init({.VIDEO})); defer sdl.Quit()
	assert(ttf.Init()); defer ttf.Quit()
	window := sdl.CreateWindow("External font binding", 640, 480, {})
	assert(window != nil); defer sdl.DestroyWindow(window)
	renderer := sdl.CreateRenderer(window, nil)
	assert(renderer != nil); defer sdl.DestroyRenderer(renderer)
	generation, ge := fonts.create_generation(
		renderer,
		"outside-font-revision",
		[]fonts.Font_Source{{"outside-font", 16, bytes}},
		1,
		context.allocator,
	)
	assert(ge.code == .None); defer fonts.release_generation(&generation)
	publication, pe := base.create(context.allocator); assert(pe == .None)
	defer base.destroy(&publication)
	for caption, i in model.captions {
		stamp, se := base.begin_attempt(&publication, u64(i + 1)); assert(se == .None)
		nodes := [1]layout.Node {
			{
				id = "outside-title",
				role = .Content,
				layout = {x = {mode = .Fixed, value = 400}, y = {mode = .Content}},
				enabled = true,
				visible = true,
			},
		}
		description := [1]text.Text_Node{{"outside-title", caption, {"outside-font"}, 16, {}}}
		candidate, error := text.prepare(
			description[:],
			nodes[:],
			{drawable = {640, 480}, ui_scale = 1},
			fonts.metrics(generation),
			context.allocator,
			stamp,
		)
		assert(error.code == .None)
		assert(candidate.text.text_blocks[0].lines[0].display_text == caption)
		assert(candidate.text.text_blocks[0].font_id == "outside-font")
		text.destroy_candidate(&candidate)
	}
	fmt.printf("external-consumer count=%d own-captions=2 font=outside-font\n", model.count)
}
