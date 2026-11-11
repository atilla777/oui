package ui_debug
import "core:os"
import "core:strings"
import linux "core:sys/linux"
import "core:testing"
@(test)
private_socket_keeps_modes_build_gate_and_single_line_single_execution :: proc(t: ^testing.T) {
	u := Fixture {
		revision  = 3,
		published = 3,
	}; u.caps.actions[.Activate] = true
	h := Host {
		allowed      = true,
		user         = &u,
		capture      = fixture_capture,
		execute      = fixture_execute,
		capabilities = u.caps,
	}
	s, opened := open_server(&h); defer close_server(&s)
	when !(ODIN_DEBUG ||
		#config(
			UI_DEMO_TEST,
			false,
		)) {testing.expect(t, !opened && s.fd == -1 && s.path == "" && u.calls == 0); return}
	if !testing.expect(t, opened) {return}
	directory, de := os.stat(
		s.run,
		context.allocator,
	); defer os.file_info_delete(directory, context.allocator)
	info: linux.Statx
	se := linux.statx(
		linux.AT_FDCWD,
		strings.clone_to_cstring(s.path, context.temp_allocator),
		{},
		{.MODE},
		&info,
	)
	testing.expect(
		t,
		de == nil &&
		directory.mode == {.Read_User, .Write_User, .Execute_User} &&
		se == .NONE &&
		(transmute(u32)info.mode) & 0o777 == 0o600,
	)
	client, ce := linux.socket(
		.UNIX,
		.STREAM,
		{.NONBLOCK, .CLOEXEC},
		nil,
	); if !testing.expect(t, ce == .NONE) {return}; defer linux.close(client)
	address := linux.Sock_Addr_Un {
		sun_family = .UNIX,
	}; copy(address.sun_path[:], transmute([]u8)s.path)
	if !testing.expect(t, linux.connect(client, &address) == .NONE) {return}
	request := `{"protocol":10,"request_id":"socket","op":"activate","id":"button"}` + "\n"
	n, sent := linux.send(
		client,
		transmute([]u8)request,
		{.NOSIGNAL},
	); if !testing.expect(t, sent == .NONE && int(n) == len(request)) {return}
	response: [65536]u8; used := 0
	for _ in 0 ..< 8 {
		service_server(&s, &h, 0)
		received, e := linux.recv(
			client,
			response[used:],
			{},
		); if e == .EAGAIN {continue}; if e != .NONE || received == 0 {break}; used += int(received); if response[used - 1] == '\n' {break}
	}
	testing.expect(
		t,
		u.calls == 1 &&
		strings.count(string(response[:used]), "\n") == 1 &&
		strings.contains(string(response[:used]), `"historical":true`),
		string(response[:used]),
	)
}
