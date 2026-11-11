package ui_transitions

import base "../ui_base"
import "core:testing"

// Unit sampler state acceptance, deliberately not a complete typed publication.
accept_sample :: proc(s: ^State, c: ^Candidate) {old := s.frame; s.frame = c.frame; c.frame = {}
	destroy_frame(&old)
	destroy_candidate(c)}
@(test)
retarget_is_continuous_and_equal_exit_preserves_timing :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(); defer destroy(&s)
	d := []Description {
		{
			node_id = "card",
			present = true,
			tracks = []Track {
				{
					property = .Opacity,
					target = f64(1),
					timing = {delay_ms = 200, duration_ms = 100},
					presence = Endpoints{enter = f64(1), exit = f64(1)},
				},
			},
		},
	}
	elapsed := [6]i64{0, 0, 199, 200, 299, 300}
	for delta, index in ([]i64{0, 0, 199, 1, 99, 1}) {
		if index == 1 {d[0].present = false}
		stamp, _ := base.begin_attempt(&p, 1)
		c, e := prepare(&s, stamp, d, {delta_ms = delta}, false)
		if !testing.expect(t, e.code == .None) {destroy_candidate(&c); return}
		phase :=
			Presence_Phase.Exiting; if index == 0 {phase = .Entering}; if index == 5 {phase = .Hidden}
		testing.expect(
			t,
			c.frame.tracks[0].elapsed_ms == elapsed[index] &&
			c.frame.presences[0].phase == phase &&
			c.frame.tracks[0].current.(f64) == 1,
		)
		accept_sample(&s, &c)
	}
	stamp, _ := base.begin_attempt(&p, 1)
	d[0].present = true; d[0].tracks[0].presence = Endpoints {
		enter = f64(0),
		exit  = f64(0),
	}
	c, e := prepare(&s, stamp, d, {}, false)
	if !testing.expect(t, e.code == .None) {destroy_candidate(&c); return}
	accept_sample(&s, &c)
	stamp, _ = base.begin_attempt(&p, 1)
	c, e = prepare(&s, stamp, d, {delta_ms = 250}, false)
	if !testing.expect(
		t,
		e.code == .None && c.frame.tracks[0].current.(f64) == .5,
	) {destroy_candidate(&c); return}
	accept_sample(&s, &c)
	d[0].tracks[0].target = f64(0)
	stamp, _ = base.begin_attempt(&p, 1)
	c, e = prepare(&s, stamp, d, {}, false); defer destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .None &&
		c.frame.tracks[0].start.(f64) == .5 &&
		c.frame.tracks[0].current.(f64) == .5 &&
		c.frame.tracks[0].elapsed_ms == 0,
	)
}
