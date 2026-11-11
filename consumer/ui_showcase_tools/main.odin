package main

import app "../ui_showcase/app"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import debug "ui:ui_debug"
import sdl "vendor:sdl3"

main :: proc() {if !app.run(os.args[1:], tools_loop) {os.exit(1)}}
tools_loop :: proc(session: app.Session) -> bool {
	if !session.options.ui_debug {return app.ordinary_loop(session)}
	when !(ODIN_DEBUG || #config(UI_DEMO_TEST, false)) {return false}
	s := session.shell
	if !enable_capture(s) {return false}
	if !app.rebuild(&s.runtime) {return false}
	permission := debug.Host {
		allowed = true,
	}
	server, opened := debug.open_server(&permission)
	if !opened {fmt.eprintln("showcase-v19: private endpoint unavailable"); return false}
	defer debug.close_server(&server)
	h := Host {
		shell     = s,
		allowed   = true,
		test_time = session.options.test_time,
		run       = server.run,
	}
	endpoint, error := json.marshal(struct {
		profile:  string,
		protocol: int,
		socket:   string,
	}{"showcase-v19", 19, server.path})
	if error != nil {return false}; defer delete(endpoint)
	fmt.println(string(endpoint))
	for {
		switch app.host_tick(session) {case .Success:
			return true; case .Failed:
			return false; case .Continue:}
		debug.service_server_with_handler(&server, &h, handle_line, sdl.GetTicks())
		sdl.Delay(10)
	}
}
enable_capture :: proc(s: ^app.Shell) -> bool {
	if s.tools.runtime.trace == nil {
		trace, e := new(
			app.Tool_Trace,
			s.allocator,
		); if e != nil {app.block(&s.runtime); return false}
		trace.allocator = s.allocator; s.tools.runtime.trace = trace
	}
	s.tools.runtime.enabled, s.tools.epoch = true, 1
	s.tools.runtime.normalize = normalize_tools_diagnostics
	s.runtime.tools_state = s.tools.runtime; s.runtime.tools_state.epoch = s.tools.epoch
	return true
}
