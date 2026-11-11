package main

import model "model"
Options :: struct {
	font:                        string,
	width, height:               i32,
	scale:                       f64,
	locale:                      model.Locale,
	window_check, test_controls: bool,
}
parse_options :: proc(args: []string) -> (Options, bool) {
	o := Options {
		width  = 800,
		height = 600,
		scale  = 1,
	}
	for i := 0; i < len(args); i += 1 {
		arg := args[i]
		if arg == "--window-check" {o.window_check = true; continue}
		if arg ==
		   "--test-controls" {when TEST {o.test_controls = true; continue} else {return {}, false}}
		if i + 1 >= len(args) {return {}, false}
		i += 1; value := args[i]
		switch arg {
		case "--font":
			o.font = value
		case "--locale":
			if value ==
			   "ru" {o.locale = .Russian} else if value == "en" {o.locale = .English} else {return {}, false}
		case "--scale":
			switch value {case "1":
				o.scale = 1; case "1.5":
				o.scale = 1.5; case "2":
				o.scale = 2; case:
				return {}, false}
		case "--size":
			if value ==
			   "800x600" {o.width, o.height = 800, 600} else if value == "480x320" {o.width, o.height = 480, 320} else {return {}, false}
		case:
			return {}, false
		}
	}
	return o, o.font != ""
}
