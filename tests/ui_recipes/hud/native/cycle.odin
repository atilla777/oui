package main

import fixture "../../native_fixture"

workload_cycle :: proc(f: ^fixture.Fixture, s: ^State, sample: ^fixture.Sample) -> bool {
	t := fixture.begin(f); before := s.effects
	s.hp += 10; s.revision += 1; publish(s)
	s.hp -= 10; s.revision += 1; publish(s)
	verify(f, s, true, sample)
	s.hp = 60; s.revision += 1; publish(s)
	sample.action_ns = fixture.elapsed(f, t)
	return s.effects == before + 1 && s.hs.live.phase == .Idle && s.p.ready
}
