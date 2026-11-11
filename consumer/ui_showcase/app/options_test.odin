package app

import "core:testing"

// G01–G21 / AC-001: the frozen catalogue has nineteen section IDs.
// Future page execution is deliberately not asserted by this metadata/CLI test.
@(test)
frozen_gallery_direct_start_ids :: proc(t: ^testing.T) {
	for id in ([]string{"layout", "controls", "profiles", "styling", "atlas", "text", "rich-text", "text-input", "scroll-table", "collections", "layers", "hud", "gestures", "composition", "custom", "transitions", "accessibility", "world", "diagnostics-performance"}) {
		_, ok := parse_options([]string{"--font", "own.ttf", "--section", id})
		testing.expect(t, ok, id)
	}
}

@(test)
cli_contract :: proc(t: ^testing.T) {
	o, ok := parse_options([]string{"--font", "own.ttf"})
	testing.expect(
		t,
		ok && o.width == 800 && o.height == 600 && o.scale == 1 && o.page == .Catalogue,
	)
	o, ok = parse_options(
		[]string {
			"--section",
			"controls",
			"--locale",
			"en",
			"--size",
			"960x720",
			"--scale",
			"2",
			"--pixel-perfect",
			"--font",
			"own.ttf",
		},
	)
	testing.expect(
		t,
		ok &&
		o.page == .Controls &&
		o.locale == .English &&
		o.width == 960 &&
		o.height == 720 &&
		o.scale == 2 &&
		o.pixel_perfect,
	)
	for args in ([][]string{{}, {"--font"}, {"--font", ""}, {"--font", "a", "--font", "b"}, {"--font", "a", "--section", "unknown"}, {"--font", "a", "--bad", "x"}, {"--font", "a", "--size", "0x600"}, {"--font", "a", "--size", "2147483648x600"}, {"--font", "a", "--size", "800x600x1"}, {"--font", "a", "--size", "+800x600"}, {"--font", "a", "--scale", "1.5", "--pixel-perfect"}, {"--font", "a", "--locale", "fr"}, {"--font", "a", "--scale", "nan"}, {"--font", "a", "--pixel-perfect", "--pixel-perfect"}}) {_, valid := parse_options(args); testing.expect(t, !valid)}
}
