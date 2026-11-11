package main

import "core:testing"

@(test)
explicit_font_and_supported_options :: proc(t: ^testing.T) {
	args := []string {
		"--font",
		"own font.ttf",
		"--size",
		"480x320",
		"--scale",
		"1.5",
		"--locale",
		"ru",
		"--window-check",
	}
	o, ok := parse_options(args)
	testing.expect(
		t,
		ok &&
		o.font == "own font.ttf" &&
		o.width == 480 &&
		o.height == 320 &&
		o.scale == 1.5 &&
		o.locale == .Russian &&
		o.window_check,
	)
	_, ok = parse_options([]string{"--font", "font.ttf"}); testing.expect(t, ok)
	for invalid in ([][]string{nil, {"--font"}, {"--font", "x", "--scale", "0"}, {"--font", "x", "--locale", "xx"}, {"--font", "x", "--size", "1x1"}, {"--font", "x", "--ui-debug"}}) {
		_, valid := parse_options(invalid); testing.expect(t, !valid)
	}
}
