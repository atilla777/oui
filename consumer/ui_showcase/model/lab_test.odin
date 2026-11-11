package showcase_model

import "core:testing"

@(test)
lab_pure_settings_transaction_and_stale_revision :: proc(t: ^testing.T) {
	m := initial(); m.lab_name.draft = "Shown draft"
	m.lab_name.value_revision += 1; m.lab_enabled, m.lab_amount = true, 61
	testing.expect(t, apply_lab_settings(&m, 1, context.allocator) == .Stale)
	testing.expect(
		t,
		m.lab_name.applied == "Алексей" &&
		!m.lab_applied_enabled &&
		m.lab_applied_amount == 50,
	)
	testing.expect(t, apply_lab_settings(&m, 2, context.allocator) == .None)
	defer delete(m.lab_name.applied)
	testing.expect(
		t,
		m.lab_name.applied == "Shown draft" &&
		m.lab_applied_enabled &&
		m.lab_applied_amount == 61 &&
		m.effects == 1,
	)
	m.lab_name.draft = "Unapplied"; m.lab_enabled, m.lab_amount = false, 0
	testing.expect(t, restore_lab_settings(&m, context.allocator) == .None)
	defer delete(m.lab_name.draft)
	testing.expect(
		t,
		m.lab_name.draft == "Shown draft" && m.lab_enabled && m.lab_amount == 61 && m.effects == 1,
	)
}

@(test)
lab_pure_hp_bounds_and_completion :: proc(t: ^testing.T) {
	for initial in ([4]int{0, 5, 95, 100}) {
		a, ok := reduce_lab_hud({initial, 7}, -10, false)
		testing.expect(t, ok && a.hp == max(0, initial - 10) && a.count == 7)
		b, valid := reduce_lab_hud({initial, 7}, 10, false)
		testing.expect(t, valid && b.hp == min(100, initial + 10) && b.count == 7)
		c, done := reduce_lab_hud({initial, 7}, 0, true)
		testing.expect(t, done && c.hp == 100 && c.count == 8)
	}
	_, accepted := reduce_lab_hud({60, max(u64)}, 0, true)
	testing.expect(t, !accepted)
}
