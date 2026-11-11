package ui_debug

import "core:fmt"
import "core:mem"
import "core:os"
import linux "core:sys/linux"

Client :: struct {
	fd:               linux.Fd,
	active, writing:  bool,
	deadline:         u64,
	input:            [MESSAGE_LIMIT + 1]u8,
	output:           [MESSAGE_LIMIT]u8,
	used, size, sent: int,
}
Server :: struct {
	path, run: string,
	fd:        linux.Fd,
	clients:   []Client,
}
open_server :: proc(host: ^Host) -> (Server, bool) {
	if !(ODIN_DEBUG || #config(UI_DEMO_TEST, false)) || !host.allowed {return {fd = -1}, false}
	run, error := os.make_directory_temp("/tmp/opencode", "ui-debug-*", context.allocator)
	if error != nil {return {fd = -1}, false}
	s := Server {
		run = run,
		fd  = -1,
	}
	s.path = fmt.aprintf("%s/ui.sock", run)
	if os.chmod(run, {.Read_User, .Write_User, .Execute_User}) != nil ||
	   len(s.path) >= 108 {close_server(&s); return {fd = -1}, false}
	fd, errno := linux.socket(.UNIX, .STREAM, {.NONBLOCK, .CLOEXEC}, nil)
	if errno != .NONE {close_server(&s); return {fd = -1}, false}
	s.fd = fd
	addr := linux.Sock_Addr_Un {
		sun_family = .UNIX,
	}
	copy(addr.sun_path[:], transmute([]u8)s.path)
	if linux.bind(fd, &addr) != .NONE ||
	   os.chmod(s.path, {.Read_User, .Write_User}) != nil ||
	   linux.listen(fd, 8) != .NONE {close_server(&s); return {fd = -1}, false}
	s.clients = make([]Client, 8)
	return s, true
}
close_client :: proc(c: ^Client) {if c.active {linux.close(c.fd)}; c.active = false}
close_server :: proc(s: ^Server) {
	for &c in s.clients {close_client(&c)}
	if s.fd >= 0 && s.path != "" {linux.close(s.fd)}
	if s.path != "" {os.remove(s.path)}
	// Snapshot directories intentionally survive shutdown.
	if s.run != "" {os.remove(s.run)}
	delete(s.path); delete(s.run); delete(s.clients); s^ = {
		fd = -1,
	}
}
service_server :: proc(s: ^Server, host: ^Host, now: u64) {
	service_server_with_handler(s, host, legacy_server_handler, now)
}
// Synchronous transport-only seam. The statically selected handler owns its
// protocol authorization and grammar; its returned bytes use the given scratch
// allocator and are copied before the operation ends. No callback is retained.
Server_Handler :: #type proc(user: rawptr, line: []u8, a: mem.Allocator) -> []u8
legacy_server_handler :: proc(user: rawptr, line: []u8, a: mem.Allocator) -> []u8 {
	return handle_line(cast(^Host)user, line, a)
}
service_server_with_handler :: proc(s: ^Server, user: rawptr, handler: Server_Handler, now: u64) {
	if handler == nil {return}
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena); defer mem.dynamic_arena_destroy(&arena)
	old := context.temp_allocator
	context.temp_allocator = mem.dynamic_arena_allocator(&arena)
	defer {context.temp_allocator = old}
	for &c in s.clients {
		if c.active {continue}
		addr: linux.Sock_Addr_Un
		fd, error := linux.accept(s.fd, &addr, {.NONBLOCK, .CLOEXEC})
		if error != .NONE {break}
		c.fd, c.active, c.writing = fd, true, false
		c.deadline, c.used, c.size, c.sent = now + 2000, 0, 0, 0
	}
	for &c in s.clients {
		if !c.active {continue}
		if now >= c.deadline {close_client(&c); continue}
		if !c.writing {
			n, error := linux.recv(c.fd, c.input[c.used:], {})
			if error == .EAGAIN {continue}
			if error != .NONE || n == 0 {close_client(&c); continue}
			c.used += n
			line: []u8; ready := false
			for b, i in c.input[:c.used] {if b == '\n' {ready = true; if i == c.used - 1 && i < MESSAGE_LIMIT {line = c.input[:i]}; break}}
			if c.used >= len(c.input) {ready = true}
			if !ready {continue}
			data := handler(user, line, context.temp_allocator)
			if data == nil || len(data) + 1 > len(c.output) {close_client(&c); continue}
			copy(c.output[:], data); c.output[len(data)] = '\n'
			c.size, c.sent, c.writing = len(data) + 1, 0, true
		}
		if c.active && c.writing {
			n, error := linux.send(c.fd, c.output[c.sent:c.size], {.NOSIGNAL})
			if error == .EAGAIN {continue}
			if error != .NONE {close_client(&c); continue}
			c.sent += n
			if c.sent == c.size {close_client(&c)}
		}
	}
}
