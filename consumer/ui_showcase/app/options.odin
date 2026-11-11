package app

import model "../model"
TEST :: #config(UI_SHOWCASE_TEST, false)
TOOLS :: #config(UI_SHOWCASE_TOOLS, false)
Options :: struct {
	font:                                    string,
	fallback_font, assets, alternate_assets: string,
	page:                                    model.Page,
	locale:                                  model.Locale,
	width, height:                           i32,
	scale:                                   f64,
	pixel_perfect, test_controls:            bool,
	ui_debug, test_time:                     bool,
	ui_profile:                              string,
}
parse_options :: proc(args: []string) -> (Options, bool) {
	o := Options {
		width  = 800,
		height = 600,
		scale  = 1,
	}
	for i := 0; i < len(args); i += 1 {
		arg := args[i]
		for prior in args[:i] {if prior == arg {return {}, false}}
		if arg == "--pixel-perfect" {o.pixel_perfect = true; continue}
		if arg == "--ui-debug" {
			when TOOLS && (ODIN_DEBUG || #config(UI_DEMO_TEST, false)) {
				o.ui_debug = true; continue
			} else {return {}, false}
		}
		if arg == "--test-time" {
			when TOOLS && #config(UI_DEMO_TEST, false) {
				o.test_time = true; continue
			} else {return {}, false}
		}
		if arg ==
		   "--test-controls" {when TEST {o.test_controls = true; continue} else {return {}, false}}
		if i + 1 >= len(args) {return {}, false}; i += 1; value := args[i]
		switch arg {
		case "--ui-profile":
			when TOOLS && (ODIN_DEBUG || #config(UI_DEMO_TEST, false)) {
				if value != "showcase-v19" {return {}, false}; o.ui_profile = value
			} else {return {}, false}
		case "--font":
			if value == "" {return {}, false}; o.font = value
		case "--fallback-font":
			if value == "" {return {}, false}; o.fallback_font = value
		case "--assets":
			if value == "" {return {}, false}; o.assets = value
		case "--alternate-assets":
			if value == "" {return {}, false}; o.alternate_assets = value
		case "--locale":
			if value ==
			   "ru" {o.locale = .Russian} else if value == "en" {o.locale = .English} else {return {}, false}
		case "--section":
			page, ok := model.section_page(value)
			if !ok {return {}, false}; o.page = page
		case "--scale":
			switch value {case "1":
				o.scale = 1; case "1.5":
				o.scale = 1.5; case "2":
				o.scale = 2; case:
				return {}, false}
		case "--size":
			x := -1
			for c, j in value {if c == 'x' {if x >= 0 {return {}, false}; x = j}}
			if x <= 0 || x >= len(value) - 1 {return {}, false}
			w, wok := positive_i32(value[:x]); h, hok := positive_i32(value[x + 1:])
			if !wok || !hok {return {}, false}; o.width, o.height = w, h
		case:
			return {}, false
		}
	}
	return o,
		o.font != "" &&
		!(o.pixel_perfect && o.scale == 1.5) &&
		(o.ui_debug == (o.ui_profile == "showcase-v19")) &&
		(!o.test_time || o.ui_debug)
}
positive_i32 :: proc(value: string) -> (i32, bool) {
	n := i64(0)
	for c in value {if c < '0' || c > '9' {return 0, false}; n = n * 10 + i64(c - '0'); if n > i64(max(i32)) {return 0, false}}
	return i32(n), n > 0
}
