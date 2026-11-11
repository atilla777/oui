package model

import "core:testing"

@(test)
one_intention_one_effect :: proc(t: ^testing.T) {
	m: Model
	testing.expect(t, apply(&m, .Action))
	testing.expect(t, m.count == 1 && m.effects == 1 && m.revision == 1)
}

@(test)
pages_language_and_overflow :: proc(t: ^testing.T) {
	m: Model
	testing.expect(t, apply(&m, .Open) && m.page == .Submenu)
	testing.expect(t, !apply(&m, .Action) && m.count == 0)
	testing.expect(t, apply(&m, .Language) && m.locale == .Russian)
	testing.expect(t, apply(&m, .Back) && m.page == .Main)
	testing.expect(t, m.effects == 3 && m.revision == 3)
	m.count = max(u64)
	before := m
	testing.expect(t, !apply(&m, .Action) && m == before)
	m = {
		effects = max(u64),
	}; before = m
	testing.expect(t, !apply(&m, .Open) && m == before)
	m = {
		revision = max(u64),
	}; before = m
	testing.expect(t, !apply(&m, .Action) && m == before)
}
