package sections

import profile "../../controls_demo/model"
import "core:fmt"
import "core:mem"
import controls "ui:ui_controls"

Profile_Recipes :: struct {
	dirty: bool,
	items: [9]controls.Composition,
	count: int,
}
destroy_profiles :: proc(p: ^Profile_Recipes) {
	for &item in p.items {controls.destroy_composition(&item)}; p^ = {}
}
// Owns all recipes until the publisher has finished preparing its candidates.
compose_profiles :: proc(
	s: ^profile.State,
	english, opened: bool,
	a: mem.Allocator,
) -> (
	Profile_Recipes,
	bool,
) {
	p: Profile_Recipes; complete := false; defer {if !complete {destroy_profiles(&p)}}
	p.dirty = profile.dirty(s)
	profiles := [3]controls.Item {
		{id = "aurora", label = "Aurora"},
		{id = "borealis", label = "Borealis"},
		{id = "cirrus", label = "Cirrus"},
	}
	modes := [3]controls.Item {
		{id = "calm", label = "Calm"},
		{id = "normal", label = "Normal"},
		{id = "vivid", label = "Vivid"},
	}
	tabs := [2]controls.Item {
		{id = "general", label = "General"},
		{id = "appearance", label = "Appearance"},
	}
	results := [3]controls.Item {
		{id = "apply-and-go", label = "Apply and go"},
		{id = "discard-and-go", label = "Discard and go"},
		{id = "stay", label = "Stay"},
	}
	help, enabled, intensity, mode, unavailable, reason, tip, confirm, body :=
		"Show help",
		"Enabled",
		"Intensity",
		"Mode",
		"Unavailable",
		"Not available in this fixture",
		"Intensity: 0..100",
		"Confirm",
		"Unsaved profile changes"
	if !english {
		tabs[0].label, tabs[1].label = "Общие", "Оформление"
		modes[0].label, modes[1].label, modes[2].label =
			"Спокойный", "Обычный", "Яркий"
		results[0].label, results[1].label, results[2].label =
			"Применить и перейти",
			"Отменить и перейти",
			"Остаться"
		help, enabled, intensity, mode, unavailable, reason, tip, confirm, body =
			"Подсказки",
			"Включено",
			"Интенсивность",
			"Режим",
			"Недоступно",
			"Недоступно в этом примере",
			"Интенсивность: 0..100",
			"Подтверждение",
			"Есть неприменённые изменения"
	}
	cancel, count := "stay", 3
	if s.dialog == .Reset {
		results[0] = {
			id    = "reset",
			label = "Reset",
		}; results[1] = {
			id    = "cancel",
			label = "Cancel",
		}
		body = "Reset draft to profile defaults?"; if !english {results[0].label, results[1].label, body = "Сбросить", "Отмена", "Сбросить черновик профиля?"}
		cancel, count = "cancel", 2
	}
	initial, ok := controls.item_node_id(
		"profiles/dialog",
		cancel,
		a,
	); if !ok {return {}, false}; defer delete(initial, a)
	mode_buffer: [128]u8; caption := ""; for item in modes {if item.id == s.draft.mode {caption = item.label}}
	profile_marks: [3][64]u8; tab_marks: [2][96]u8
	for &item, i in profiles {mark := "[ ]"; if item.id == s.selected_id {mark = "[*]"}; item.label = fmt.bprintf(profile_marks[i][:], "%s %s", mark, item.label)}
	for &item, i in tabs {mark := "[ ]"; if item.id == s.active_tab {mark = "[*]"}; item.label = fmt.bprintf(tab_marks[i][:], "%s %s", mark, item.label)}
	format := "Mode: %s"; if !english {format = "Режим: %s"}; mode = fmt.bprintf(mode_buffer[:], format, caption)
	ds := [9]controls.Description {
		{
			id = "profiles/list",
			node_id = "profiles/list",
			kind = .List,
			items = profiles[:],
			selected_id = s.selected_id,
		},
		{
			id = "profiles/tabs",
			node_id = "profiles/tabs",
			kind = .Tabs,
			items = tabs[:],
			selected_id = s.active_tab,
		},
		{
			id = "profiles/help",
			node_id = "profiles/help",
			kind = .Checkbox,
			label = help,
			checked = s.draft.show_help,
		},
		{
			id = "profiles/enabled",
			node_id = "profiles/enabled",
			kind = .Toggle,
			label = enabled,
			checked = s.draft.enabled,
			on_text = "ON",
			off_text = "OFF",
		},
		{
			id = "profiles/intensity",
			node_id = "profiles/intensity",
			kind = .Slider,
			label = intensity,
			value = s.draft.intensity,
			maximum = 100,
			step = 1,
		},
		{
			id = "profiles/mode",
			node_id = "profiles/mode",
			kind = .Select,
			label = mode,
			items = modes[:],
			selected_id = s.draft.mode,
			open = opened,
			owner_scope_id = "",
		},
		{
			id = "profiles/unavailable",
			node_id = "profiles/unavailable",
			kind = .Toggle,
			label = unavailable,
			disabled_reason = reason,
		},
		{
			id = "profiles/tooltip",
			kind = .Tooltip,
			body = tip,
			trigger_id = "profiles/intensity",
			owner_scope_id = "",
		},
		{
			id = "profiles/dialog",
			kind = .Dialog,
			label = confirm,
			body = body,
			open = s.dialog != .None,
			items = results[:count],
			cancel_id = cancel,
			initial_focus_id = initial,
		},
	}
	for d, i in ds {
		parent := "profiles/general"
		if i == 0 || i == 1 {parent = "profiles/body"}
		if i == 5 || i == 6 {parent = "profiles/appearance"}
		r, err := controls.compose_control(
			d,
			parent,
			"shell/root",
			a,
			enabled = i != 6,
			font = {"own"},
			font_size = 14,
		)
		if err.code != .None {return {}, false}; p.items[i] = r; p.count += 1
	}
	complete = true; return p, true
}
