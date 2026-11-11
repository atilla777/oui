package ui_base

import "core:mem"
import "core:testing"

@(test)
publication_attempts_lifetime_and_reentry :: proc(t: ^testing.T) {
	p, e := create(context.allocator)
	if !testing.expect(t, e == .None) {return}
	defer destroy(&p)
	s, se := begin_attempt(&p, 7)
	if !testing.expect(t, se == .None, "a live owner must begin preparation") {return}
	q, qe := create(context.allocator); defer destroy(&q)
	testing.expect(t, qe == .None && validate(&q, s) == .Stale)
	testing.expect(t, enter_commit(&p, s) == .None)
	testing.expect(t, enter_commit(&p, s) == .Reentry)
	finish_commit(&p, s)
	testing.expect(t, is_current(&p, s))
	testing.expect(t, enter_commit(&p, s) == .Stale, "an attempt cannot be published twice")
	next, ne := begin_attempt(&p, 8)
	testing.expect(t, ne == .None && !p.ready && validate(&p, s) == .Stale)
	testing.expect(t, retain(next))
	destroy(&p)
	testing.expect(t, !next.lifetime.alive)
	release(next)
}

@(test)
saved_error_is_independent :: proc(t: ^testing.T) {
	bytes := [4]u8{'n', 'o', 'd', 'e'}
	e := Error {
		family      = .Text,
		stage       = .Prepare,
		code        = 2,
		id          = string(bytes[:]),
		byte_offset = 3,
	}
	r, ok := try_copy_error(e, context.allocator)
	if !testing.expect(t, ok, "saved error must own node ID") {return}
	defer destroy_error(&r)
	mem.zero_slice(bytes[:])
	testing.expect(
		t,
		r.id == "node" && r.byte_offset == 3 && r.family == .Text && r.stage == .Prepare,
	)
}

@(test)
checked_counters_and_sequence_barrier :: proc(t: ^testing.T) {
	p, e := create(context.allocator); defer destroy(&p)
	testing.expect(t, e == .None)
	p.attempt = max(u64)
	_, ae := begin_attempt(&p, 0)
	testing.expect(t, ae == .Exhausted && !p.ready)
	p.attempt = 0
	s, _ := begin_attempt(&p, 0)
	testing.expect(t, enter_commit(&p, s) == .None)
	finish_commit(&p, s)
	testing.expect(t, advance_sequence(&p) == .None && !is_current(&p, s))
	testing.expect(t, validate(&p, s) == .Stale)
	p.sequence = max(u64)
	testing.expect(t, advance_sequence(&p) == .Exhausted && !p.ready)
}
