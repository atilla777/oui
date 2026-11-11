package app

import model "../model"
import sections "../sections"
import "core:fmt"
import base "ui:ui_base"
import controls "ui:ui_controls"
import editor "ui:ui_editor"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import fonts "ui:ui_sdl_text"

Lab_Menu_Runtime :: struct {
	confirmation_buffer:                     [128]u8,
	departure_press:                         string,
	departure_attempt:                       u64,
	editing:                                 Name_Page_Runtime,
	settings:                                bool,
	confirm:                                 bool,
	discard, leave_page:                     bool,
	destination:                             model.Page,
	pending_revision, token, consumed_token: u64,
}
lab_menu :: proc(page: model.Page) -> bool {return page == .Lab_Menu || page == .Lab_Settings}
lab_text :: proc(r: ^Runtime, id: Lab_String) -> string {
	return lab_word(r.model.locale, id)
}
lab_word :: proc(locale: model.Locale, id: Lab_String) -> string {
	word := LAB_WORDS[id]; return word.en if locale == .English else word.ru
}
compose_lab_catalogue :: proc(r: ^Runtime, c: ^Page_Composition) {
	// Keep the frozen gallery base fixture intact. The running consumer adds
	// the F4 group entry in the same composition/publication as its other routes.
	button(
		c,
		"catalogue/lab",
		"catalogue/lab-label",
		"catalogue/pages",
		lab_word(r.model.locale, .Gallery_Group if r.model.catalogue_lab else .Lab_Group),
	)
}
lab_button :: proc(c: ^Page_Composition, id, text_id, parent, value: string) {
	node(
		c,
		id,
		parent,
		.Stack,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}, padding = {4, 2, 4, 2}},
	)
	label(c, text_id, id, value, {x = {mode = .Fill}, y = {mode = .Fill}})
	c.targets[c.ni] = {id, "button", true, true}; c.ni += 1
}
compose_lab_menu :: proc(r: ^Runtime, c: ^Page_Composition) {
	v, _ := r.content.(^Lab_Menu_Runtime)
	if r.model.lab_submenu {
		lab_button(c, "lab/settings", "lab/settings-label", "root", lab_text(r, .Settings))
		lab_button(c, "lab/back", "lab/back-label", "root", lab_text(r, .Main_Menu))
		c.initial_focus = "lab/settings"
	} else {
		lab_button(c, "lab/submenu", "lab/submenu-label", "root", lab_text(r, .Submenu))
		c.initial_focus = "lab/submenu"
	}
	parent := "shell/root" if v.settings else "root"
	node(
		c,
		"lab/settings-modal",
		parent,
		.Column,
		{x = {mode = .Fill}, y = {mode = .Fill}, padding = {24, 24, 24, 24}, gap = 6},
	)
	c.nodes[c.n - 1].visible = v.settings
	sections.layer_panel(c, "lab/settings-modal")
	// Reuse the controlled single-line geometry, not its old host/application reducer.
	first := c.n
	m := r.model^; m.name = m.lab_name
	sections.compose_name(c, m)
	c.initial_focus = "lab/settings" if r.model.lab_submenu else "lab/submenu"
	for &n in c.nodes[first:c.n] {if n.parent == "root" {n.parent = "lab/settings-modal"}}
	ds := [2]controls.Description {
		{
			id = "lab/enabled",
			node_id = "lab/enabled",
			kind = .Checkbox,
			label = lab_text(r, .Enabled),
			checked = r.model.lab_enabled,
		},
		{
			id = "lab/amount",
			node_id = "lab/amount",
			kind = .Slider,
			label = lab_text(r, .Amount),
			value = r.model.lab_amount,
			minimum = 0,
			maximum = 100,
			step = 1,
			increment_id = "lab/amount/increment",
			decrement_id = "lab/amount/decrement",
		},
	}
	for d, index in ds {
		recipe, e := controls.compose_control(
			d,
			"lab/settings-modal",
			"lab/settings-modal",
			r.allocator,
			font = {"own"},
			font_size = 14,
		)
		if e.code != .None {block(r); return}; c.recipes[index] = recipe
		for n in recipe.nodes {c.nodes[c.n] = n; c.n += 1}
		for text in recipe.texts {c.texts[c.nt] = text; c.nt += 1}
		for target in recipe.targets {c.targets[c.ni] = target; c.ni += 1}
		for style in recipe.styles {c.styles[c.ns] = style; c.ns += 1}
	}
	lab_button(c, "lab/leave", "lab/leave-label", "lab/settings-modal", lab_text(r, .Catalogue))
	if v.settings {
		c.modals[c.nm] = {"lab/settings-modal", "name/field", true}; c.nm += 1
		if r.interaction.frame.stamp.attempt == 0 {c.initial_focus = "name/field"}
	}
	if v.confirm || v.discard {
		node(
			c,
			"lab/confirmation",
			"shell/root",
			.Column,
			{x = {mode = .Fill}, y = {mode = .Fill}, padding = {24, 24, 24, 24}, gap = 6},
		)
		sections.layer_panel(c, "lab/confirmation")
		label(
			c,
			"lab/confirmation-title",
			"lab/confirmation",
			lab_text(r, .Discard_Question) if v.discard else lab_text(r, .Apply_Question),
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}},
		)
		label(
			c,
			"lab/shown-name",
			"lab/confirmation",
			r.model.lab_name.draft,
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 30}},
		)
		label(
			c,
			"lab/shown-values",
			"lab/confirmation",
			fmt.bprintf(
				v.confirmation_buffer[:],
				lab_text(r, .Settings_Summary),
				r.model.lab_enabled,
				r.model.lab_amount,
			),
			{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
		)
		lab_button(
			c,
			"lab/stay" if v.discard else "lab/decline",
			"lab/decline-label",
			"lab/confirmation",
			lab_text(r, .Stay) if v.discard else lab_text(r, .Edit),
		)
		lab_button(
			c,
			"lab/discard" if v.discard else "lab/confirm",
			"lab/confirm-label",
			"lab/confirmation",
			lab_text(r, .Discard) if v.discard else lab_text(r, .Confirm),
		)
		c.modals[c.nm] = {
			"lab/confirmation",
			"lab/stay" if v.discard else "lab/decline",
			true,
		}; c.nm += 1
	}
}
lab_menu_action :: proc(r: ^Runtime, id: string) -> bool {
	v, _ := r.content.(^Lab_Menu_Runtime)
	if r.model.revision == max(u64) {return false}
	switch id {
	case "lab/submenu":
		r.model.lab_submenu = true
	case "lab/back":
		r.model.lab_submenu = false
	case "lab/settings":
		v.settings = true
	case "name/cancel":
		if v.confirm || v.discard {return false}
		v.leave_page = false
		if lab_dirty(r) {v.discard = true} else {v.settings = false}
	case "lab/leave":
		if v.confirm || v.discard {return false}
		v.leave_page, v.destination = true, .Catalogue
		if lab_dirty(r) {v.discard = true} else {r.model.page = v.destination}
	case "lab/stay":
		if !v.discard {return false}; v.discard, v.leave_page = false, false
	case "lab/discard":
		if !v.discard {return false}
		if model.restore_lab_settings(r.model, r.allocator) !=
		   .None {return lab_allocation_failure(r)}
		v.editing.resolution = {.External, 0, .None}
		v.discard, v.settings = false, false
		if v.leave_page {r.model.page = v.destination}; v.leave_page = false
	case "name/apply":
		if v.confirm || !v.settings || v.token == max(u64) {return false}
		value := r.model.lab_name.draft
		check := editor.editor_splice("", 0, 0, value, 64, r.allocator)
		defer editor.destroy_editor_splice(&check)
		v.editing.rejection, v.editing.empty = check.rejection, check.count == 0
		if check.rejection == .Allocation {return lab_allocation_failure(r)}
		if check.rejection != .None || check.count == 0 {return false}
		metrics := fonts.metrics(r.fonts)
		if e, _ := metrics.validate_text(value, "own", 14, metrics.user);
		   e != .None {v.editing.rejection = .Glyph_Missing; return false}
		v.token += 1; v.pending_revision = r.model.lab_name.value_revision; v.confirm = true
	case "lab/decline":
		if !v.confirm {return false}; v.confirm = false
	case "lab/confirm":
		m := &r.model.lab_name
		if !v.confirm ||
		   v.token <= v.consumed_token ||
		   v.pending_revision != m.value_revision ||
		   r.model.effects == max(u64) {return false}
		if model.apply_lab_settings(r.model, v.pending_revision, r.allocator) !=
		   .None {return lab_allocation_failure(r)}
		v.confirm = false; v.consumed_token = v.token
	case:
		return false
	}
	r.model.revision += 1; base.invalidate(&r.publication); return true
}
lab_menu_cancel :: proc(r: ^Runtime, action: interaction.Action) -> interaction.Code {
	result := layers.dispatch(&r.layers, &r.interaction, action)
	if event, ok := result.cancel.?; ok {
		if consume(r, reader_stamp(&r.live), event.sequence) {
			v, _ := r.content.(^Lab_Menu_Runtime)
			id := "lab/decline" if v.confirm else "name/cancel"
			if v.discard {id = "lab/stay"}
			lab_menu_action(r, id)
		}
	}
	return result.dispatch.code
}
lab_dirty :: proc(r: ^Runtime) -> bool {return(
		r.model.lab_name.draft != r.model.lab_name.applied ||
		r.model.lab_enabled != r.model.lab_applied_enabled ||
		r.model.lab_amount != r.model.lab_applied_amount \
	)}
lab_allocation_failure :: proc(r: ^Runtime) -> bool {
	// A refused owning transition is not ordinary input invalidation: only R
	// may retry publication, without replaying this intention.
	r.error = .Copy; block(r); return false
}
lab_control :: proc(r: ^Runtime, event: controls.Event) -> bool {
	v, _ := r.content.(^Lab_Menu_Runtime)
	if !v.settings ||
	   v.confirm ||
	   v.discard ||
	   r.model.revision == max(u64) ||
	   r.model.lab_name.value_revision == max(u64) {return false}
	switch event.control_id {
	case "lab/enabled":
		if event.kind != .Bool {return false}; r.model.lab_enabled = event.checked
	case "lab/amount":
		if event.kind != .Integer || event.value < 0 || event.value > 100 {return false}
		r.model.lab_amount = event.value
	case:
		return false
	}
	v.editing.resolution = {.External, 0, .None}
	r.model.lab_name.value_revision += 1; r.model.revision += 1; base.invalidate(&r.publication); return true
}
