package app

import "core:fmt"

// Existing bounded stdout evidence, not a command endpoint or a proposal history.
log_lab :: proc(s: ^Shell) {
	settings, confirm, discard, pending := false, false, false, false
	token := u64(0)
	if v, ok := s.runtime.content.(^Lab_Menu_Runtime);
	   ok {settings, confirm, discard, token = v.settings, v.confirm, v.discard, v.token}
	if v, ok := s.runtime.content.(^Lab_Inventory_Runtime);
	   ok {pending, token = v.has_pending, v.pending_token}
	fmt.printf(
		"lab settings=%t confirm=%t discard=%t draft_revision=%d draft_bytes=%d applied_bytes=%d enabled=%t applied_enabled=%t amount=%d applied_amount=%d hp=%d hold_count=%d inventory_revision=%d left=%d right=%d selected=%s pending=%t token=%d\n",
		settings,
		confirm,
		discard,
		s.model.lab_name.value_revision,
		len(s.model.lab_name.draft),
		len(s.model.lab_name.applied),
		s.model.lab_enabled,
		s.model.lab_applied_enabled,
		s.model.lab_amount,
		s.model.lab_applied_amount,
		s.model.lab_hp,
		s.model.lab_hold_count,
		s.inventory.revision,
		s.inventory.panels[0].count,
		s.inventory.panels[1].count,
		s.model.lab_selected,
		pending,
		token,
	)
}
