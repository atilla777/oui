package app

import model "../model"
import "core:fmt"
import "core:strings"
import inspect "ui:ui_inspect"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"

_ :: strings.clone
_ :: fmt.tprintf
_ :: model.Page
_ :: inspect.Inspection
_ :: interaction.Code
_ :: layers.within

when TOOLS {
	TOOL_UNSUPPORTED_PROJECTIONS :: []string {
		"editor-assessment",
		"gesture-assessment",
		"accessibility-assessment",
		"logical-item-lookup",
	}
	section_id :: proc(page: model.Page) -> string {
		if page == .Catalogue {return "catalogue"}
		for s in model.SECTIONS {if s.page == page {return s.id}}
		for s in model.LAB_SECTIONS {if s.page == page {return s.id}}
		return ""
	}
	release_tools_generation :: proc(slot: ^Tools_Slot) {
		g := slot^; slot^ = nil
		if g == nil {return}; g.references -= 1; if g.references != 0 {return}
		inspect.destroy_inspection(&g.inspection)
		for v in g.observation.values {
			delete(v.id, g.allocator)
			if s, is_string := v.value.(string); is_string {delete(s, g.allocator)}
		}
		delete(g.observation.values, g.allocator)
		delete(g.observation.unsupported, g.allocator)
		if record, exists := g.observation.last_action.?;
		   exists {destroy_tool_record(&record, g.allocator)}
		free(g, g.allocator)
	}
	prepare_tools_generation :: proc(
		r: ^Runtime,
		source: ^Reader,
		c: ^Page_Composition,
		focus: string,
	) -> (
		Tools_Slot,
		bool,
	) {
		g, ae := new(Tools_Generation, r.allocator); if ae != nil {return nil, false}
		g.references, g.allocator = 1, r.allocator
		g.screen_epoch = r.tools_state.epoch
		g.sample_ms = r.tools_state.sample_ms
		complete := false; defer {if !complete {release_tools_generation(&g)}}
		semantics, se := make([]inspect.Semantic, len(source.geometry.nodes), r.allocator)
		if se != nil {return nil, false}
		defer delete(semantics, r.allocator)
		for node, i in source.geometry.nodes {
			id := node.description.id; role, name := "", ""
			if target, found := interaction.find(&source.interaction, id);
			   found {role = target.description.role}
			for text in c.texts[:c.nt] {
				if text.id == id {name = text.text; if role == "" {role = "label"}; break}
				if role != "" &&
				   layers.within(&source.geometry, text.id, id) {name = text.text; break}
			}
			semantics[i] = {
				id   = id,
				role = role,
				name = name,
			}
		}
		caps: [inspect.Action]bool; for &cap in caps {cap = true}
		e: inspect.Inspect_Error
		normalized: Tool_Diagnostics
		if r.tools_state.normalize != nil {
			ok: bool; normalized, ok = r.tools_state.normalize(source, r.allocator)
			if !ok {return nil, false}
		}
		defer {if normalized.release != nil {normalized.release(normalized.owner, r.allocator)}}
		g.inspection, e = inspect.capture(
			{
				frame = &source.geometry,
				interaction = &source.interaction,
				focus_id = focus,
				hover_id = r.interaction.hover_id,
				pressed_id = r.interaction.pressed_id,
				ready = true,
				model_revision = r.model.revision,
				published_revision = r.model.revision,
				semantics = semantics,
				diagnostics = normalized.records,
				capabilities = caps,
			},
			r.allocator,
		)
		if e != .None {return nil, false}
		bad := 0
		for &d in g.inspection.diagnostics {
			// This exact fixture is already explicitly admitted by the native
			// publisher. Other overflows remain unexpected.
			if r.page == .Layout &&
			   d.id == "layout/clipped" &&
			   d.code == "layout.Container_Overflow" {d.expected = true}
			if d.severity == .Error ||
			   (d.severity == .Warning &&
					   !d.expected) {g.inspection.offending_storage[bad] = d; bad += 1}
		}
		g.inspection.offending = g.inspection.offending_storage[:bad]
		g.observation = {
			selected_section = section_id(r.model.page),
			locale           = "ru" if r.model.locale == .Russian else "en",
			scale            = r.model.scale,
			pixel_perfect    = r.model.pixel_perfect,
			effects          = r.model.effects,
		}
		g.observation.unsupported, ae = make(
			[]string,
			len(TOOL_UNSUPPORTED_PROJECTIONS),
			r.allocator,
		)
		if ae != nil {return nil, false}
		copy(g.observation.unsupported, TOOL_UNSUPPORTED_PROJECTIONS)
		// Values are actual app fields plus the current materialized text model,
		// not a copy of a virtual dataset or private family machinery.
		values: [256]Tool_Value; count := 0
		for text in c.texts[:c.nt] {values[count] = {text.id, text.text}; count += 1}
		m := r.model
		if m.page == .Controls {
			values[count] = {"controls/checkbox", m.checkbox}; count += 1
			values[count] = {"controls/toggle", m.toggle}; count += 1
			values[count] = {"controls/slider", m.slider}; count += 1
		}
		if m.page == .Hud || m.page == .Lab_Hud {
			values[count] = {
				"hud/hp",
				i64(m.lab_hp if m.page == .Lab_Hud else m.hud_hp),
			}; count += 1
			values[count] = {
				"hud/count",
				m.lab_hold_count if m.page == .Lab_Hud else m.hud_count,
			}; count += 1
		}
		if v, selected := r.content.(^Lab_Menu_Runtime); selected {
			values[count] = {"lab/draft-name", m.lab_name.draft}; count += 1
			values[count] = {"lab/applied-name", m.lab_name.applied}; count += 1
			values[count] = {"lab/draft-enabled", m.lab_enabled}; count += 1
			values[count] = {"lab/applied-enabled", m.lab_applied_enabled}; count += 1
			values[count] = {"lab/draft-amount", m.lab_amount}; count += 1
			values[count] = {"lab/applied-amount", m.lab_applied_amount}; count += 1
			values[count] = {"lab/dirty", lab_dirty(r)}; count += 1
			phase :=
				"confirm" if v.confirm else "discard" if v.discard else "settings" if v.settings else "menu"
			values[count] = {"lab/modal-phase", phase}; count += 1
		}
		inventory_names: [24][128]u8; inventory_at := 0
		if v, selected := r.content.(^Lab_Inventory_Runtime); selected {
			values[count] = {"lab/selected", m.lab_selected}; count += 1
			values[count] = {"lab/reverse", m.lab_reverse}; count += 1
			values[count] = {"lab/pending-transfer", v.has_pending}; count += 1
			for &panel in v.model.panels {for card, index in panel.cards[:panel.count] {
					order := panel.count - 1 - index if m.lab_reverse else index
					values[count] = {
						card,
						fmt.bprintf(inventory_names[inventory_at][:], "%s/%d", panel.id, order),
					}; count += 1; inventory_at += 1
				}}
		}
		g.observation.values, ae = make(
			[]Tool_Value,
			count,
			r.allocator,
		); if ae != nil {return nil, false}
		for value, i in values[:count] {
			target := &g.observation.values[i]
			target.id, ae = strings.clone(value.id, r.allocator); if ae != nil {return nil, false}
			if s, is_string := value.value.(string); is_string {
				copy, error := strings.clone(
					s,
					r.allocator,
				); if error != nil {return nil, false}; target.value = copy
			} else {target.value = value.value}
		}
		if t := r.tools_state.trace; t != nil && t.has_last {
			record, ok := clone_tool_record(t.last, r.allocator)
			if !ok {return nil, false}; g.observation.last_action = record
		}
		complete = true; return g, true

	}
}
