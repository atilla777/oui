package main
import "core:fmt"
import adapter "ui:ui_editor/sdl"
main :: proc() {a := adapter.create(); assert(adapter.close(&a, nil)); fmt.printf(
		"editor adapter=%d native-init=0\n",
		size_of(adapter.Adapter),
	)}
