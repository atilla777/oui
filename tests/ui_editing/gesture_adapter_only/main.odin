package main
import "core:fmt"
import adapter "ui:ui_gestures/sdl"
main :: proc() {a: adapter.Adapter; adapter.close(&a); fmt.printf(
		"gesture adapter=%d native-init=0\n",
		size_of(adapter.Adapter),
	)}
