package ui_debug

import "core:mem"
import "core:strings"
import linux "core:sys/linux"
import "core:testing"

Handler_Probe :: struct {
	calls:   int,
	matched: bool,
}
probe_handler :: proc(user: rawptr, line: []u8, a: mem.Allocator) -> []u8 {
	p := cast(^Handler_Probe)user
	p.calls += 1
	p.matched = string(line) == `{"protocol":19,"request_id":"opaque","op":"list-sections"}`
	return transmute([]u8)strings.clone(`{"protocol":19,"request_id":"opaque","ok":true}`, a)
}

@(test)
selected_transport_handler_is_synchronous_opaque_and_not_legacy_validation :: proc(t: ^testing.T) {
	h := Host {
		allowed = true,
	}
	s, opened := open_server(&h); defer close_server(&s)
	when !(ODIN_DEBUG || #config(UI_DEMO_TEST, false)) {
		testing.expect(t, !opened && s.fd == -1); return
	}
	if !testing.expect(t, opened) {return}
	fd, e := linux.socket(.UNIX, .STREAM, {.NONBLOCK, .CLOEXEC}, nil)
	if !testing.expect(t, e == .NONE) {return}; defer linux.close(fd)
	address := linux.Sock_Addr_Un {
		sun_family = .UNIX,
	}
	copy(address.sun_path[:], transmute([]u8)s.path)
	if !testing.expect(t, linux.connect(fd, &address) == .NONE) {return}
	line := `{"protocol":19,"request_id":"opaque","op":"list-sections"}` + "\n"
	n, sent := linux.send(fd, transmute([]u8)line, {.NOSIGNAL})
	if !testing.expect(t, sent == .NONE && int(n) == len(line)) {return}
	p: Handler_Probe
	response: [256]u8; used := 0
	for _ in 0 ..< 8 {
		service_server_with_handler(&s, &p, probe_handler, 0)
		got, error := linux.recv(fd, response[used:], {})
		if error == .EAGAIN {continue}
		if error != .NONE || got == 0 {break}
		used += int(got)
		if response[used - 1] == '\n' {break}
	}
	testing.expect(
		t,
		p.calls == 1 &&
		p.matched &&
		string(response[:used]) == `{"protocol":19,"request_id":"opaque","ok":true}` + "\n",
	)
	// No callback/state is retained. Servicing again cannot replay a request.
	service_server_with_handler(&s, &p, probe_handler, 1)
	testing.expect(t, p.calls == 1)
}
