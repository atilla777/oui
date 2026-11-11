package main

import app "../ui_showcase/app"
import model "../ui_showcase/model"
import "core:fmt"
import profile "profile"
import base "ui:ui_base"
import collections "ui:ui_collections"
import inspect "ui:ui_inspect"

Section :: struct {
	id, group, name, fixture, status, limitations: string,
	resources_available:                           bool,
	resource_reason:                               string,
}
Action_Status :: struct {
	action:                        string,
	capability, suitable, allowed: bool,
	reason:                        string,
}
Node :: struct {
	id, parent_id:                               string,
	children:                                    []string,
	structural_role, role, name, text:           string,
	source_hint:                                 string `json:"source_hint,omitempty"`,
	bounds, content, clip, paint_clip:           base.Rect,
	visible, enabled, focused, hovered, pressed: bool,
	availability:                                string,
	actions:                                     []Action_Status,
	unsupported:                                 []string,
}
Dispatch :: struct {
	code, target, source: string,
	sequence:             u64,
	has_event:            bool,
}
Application :: struct {
	status, reason: string,
}
Action_Result :: struct {
	dispatch:                      Dispatch,
	application:                   Application,
	effects_before, effects_after: u64,
	observation:                   app.Tool_Observation,
}
Error :: struct {
	code, id, phase: string,
}
Reply :: struct {
	protocol:                                                   int,
	request_id:                                                 string,
	ok:                                                         bool,
	error:                                                      Error,
	ready, historical:                                          bool,
	section:                                                    string,
	screen_epoch, frame_id, model_revision, published_revision: u64,
	result:                                                     any,
}
OPERATIONS :: []string {
	"capabilities",
	"list-sections",
	"select-section",
	"tree",
	"find",
	"inspect",
	"geometry",
	"diagnostics",
	"assert-no-errors",
	"focus",
	"navigate",
	"activate",
	"cancel",
	"scroll",
	"begin-hold",
	"advance-hold",
	"release-hold",
	"cancel-hold",
	"snapshot",
}
UNSUPPORTED :: []string {
	"set_value",
	"drag",
	"overlays",
	"crop",
	"finish-transitions",
	"editor-rpc",
	"gesture-rpc",
	"editor-assessment",
	"gesture-assessment",
	"accessibility-assessment",
	"logical-item-lookup",
}

section_inventory :: proc(h: ^Host) -> []Section {
	locale := model.Locale.Russian
	if h.shell != nil {locale = h.shell.model.locale}
	ru := [24]string {
		"Каталог",
		"Компоновка",
		"Элементы",
		"Профили",
		"Оформление",
		"Атлас",
		"Текст",
		"Смешанный текст",
		"Ввод текста",
		"Таблица",
		"Коллекции",
		"Слои",
		"HUD",
		"Жесты",
		"Композиция",
		"Свои элементы",
		"Переходы",
		"Доступность",
		"Мировые подписи",
		"Диагностика и измерения",
		"Меню",
		"Настройки",
		"HUD лаборатории",
		"Инвентарь",
	}
	en := [24]string {
		"Catalogue",
		"Layout",
		"Controls",
		"Profiles",
		"Styling",
		"Atlas",
		"Text",
		"Rich text",
		"Text input",
		"Scroll table",
		"Collections",
		"Layers",
		"HUD",
		"Gestures",
		"Composition",
		"Custom",
		"Transitions",
		"Accessibility",
		"World",
		"Diagnostics and performance",
		"Menu",
		"Settings",
		"Lab HUD",
		"Inventory",
	}
	result := make([]Section, 24, context.temp_allocator)
	gallery, lab := model.SECTIONS, model.LAB_SECTIONS
	for &section, index in result {
		page := model.Page(index)
		if index == 0 {section = {
				id      = "catalogue",
				group   = "catalogue",
				fixture = "catalogue",
				status  = "experimental",
			}} else {
			s := model.Section{}
			if index <
			   20 {s = gallery[index - 1]; section.group = "gallery"} else {s = lab[index - 20]; section.group = "Lab"}
			page = s.page
			section.id, section.fixture, section.status, section.limitations =
				s.id, s.fixture, s.status, model.section_limitations(s, locale)
		}
		section.name = ru[index] if locale == .Russian else en[index]
		section.resources_available = h.shell != nil && len(h.shell.font_data) > 0
		if !section.resources_available {section.resource_reason = "Font_Not_Supplied"}
		if h.shell != nil &&
		   page == .Rich_Text &&
		   len(h.shell.sources.fallback) ==
			   0 {section.resources_available = false; section.resource_reason = "Fallback_Not_Supplied"}
		if h.shell != nil &&
		   page == .Atlas &&
		   h.shell.sources.assets ==
			   "" {section.resources_available = false; section.resource_reason = "Assets_Not_Supplied"}
	}
	return result
}
selected_reader :: proc(h: ^Host) -> (^app.Reader, bool) {
	if h.shell == nil {return nil, false}
	r := &h.shell.runtime
	if r.live.tools != nil {return &r.live, app.current(r)}
	if h.shell.tools.history.tools != nil {return &h.shell.tools.history, false}
	return nil, false
}
metadata_error :: proc(h: ^Host) -> string {
	if h.shell == nil {return "Not_Ready"}
	r := &h.shell.runtime
	g := r.live.tools
	if g != nil {
		stamp := app.reader_stamp(&r.live)
		if g.inspection.frame.stamp != stamp ||
		   g.inspection.interaction.stamp != stamp ||
		   g.inspection.model_revision != stamp.model_revision ||
		   g.inspection.published_revision != stamp.model_revision ||
		   g.screen_epoch != r.tools_state.epoch ||
		   g.observation.selected_section != app.section_id(r.page) {
			app.block(r); return "Metadata_Mismatch"
		}
	}
	return ""
}
observation :: proc(h: ^Host) -> app.Tool_Observation {
	reader, _ := selected_reader(h)
	if reader == nil {return {}}
	result := reader.tools.observation
	result.selected_section = app.section_id(h.shell.model.page)
	if t := h.shell.tools.runtime.trace; t != nil && t.has_last {result.last_action = t.last}
	return result
}
node_projection :: proc(reader: ^app.Reader, ready: bool, id: string) -> (Node, bool) {
	i := reader.tools.inspection; i.ready, i.historical = ready, !ready
	v, error := inspect.inspect(&i, id); if error != .None {return {}, false}
	n := v.resolved
	result := Node {
		id              = id,
		parent_id       = n.description.parent,
		children        = make([]string, len(v.children), context.temp_allocator),
		structural_role = fmt.tprintf("%v", v.structural_role),
		role            = v.role,
		name            = v.name,
		source_hint     = v.source_hint,
		bounds          = n.bounds,
		content         = n.content,
		clip            = n.clip,
		paint_clip      = n.paint_clip,
		visible         = n.visible,
		enabled         = n.enabled,
		focused         = v.focused,
		hovered         = v.hovered,
		pressed         = v.pressed,
		availability    = "Invalid_Action",
		unsupported     = make([]string, len(UNSUPPORTED), context.temp_allocator),
	}
	copy(result.unsupported, UNSUPPORTED)
	for index, k in v.children {result.children[k] = i.frame.nodes[index].description.id}
	for text in reader.text.text_blocks {if text.node_id == id {result.text = text.original_text; break}}
	if v.target != nil {result.availability = app.tool_code_name(v.target.availability)}
	actions := make([dynamic]Action_Status, 0, 0, context.temp_allocator)
	for action in ([]string{"focus", "activate", "begin-hold", "scroll"}) {
		status := Action_Status {
			action     = action,
			capability = true,
			reason     = "Unsupported_Action",
		}
		if action == "focus" || action == "activate" {
			s := inspect.action_status(&i, id, .Focus if action == "focus" else .Activate)
			status.suitable, status.allowed, status.reason =
				s.suitable, s.code == .Applied, app.tool_code_name(s.code)
			if action == "activate" && v.target != nil {
				owner := v.target.activation_owner
				if owner == "hold" {status.allowed = false; status.reason = "Hold_Required"}
				if owner == "controls" &&
				   v.target.availability == .Applied &&
				   ready {status.allowed = true; status.reason = "Applied"}
				if owner == "collections" && ready && v.target.availability == .Applied {
					frames, count := collection_frames(reader)
					for f in frames[:count] {for item in f.nodes {if item.description.id == id {
								code := f.owner_gate
								if !f.bound || f.stamp != i.frame.stamp {code = .Not_Ready}
								status.allowed, status.reason =
									code == .Applied, app.tool_code_name(code)
							}}}
				}
			}
			if action == "activate" &&
			   v.target != nil &&
			   v.target.activation_owner == "custom" &&
			   ready &&
			   v.target.availability == .Applied {
				supported := false
				if _, selected := reader.content.(app.Custom_Page_Reader);
				   selected {for circle in app.CUSTOM_CIRCLES {supported ||= circle == id}}
				if _, selected := reader.content.(app.Rich_Page_Reader);
				   selected {supported = id == "rich/circle"}
				if supported {status.allowed, status.reason = true, "Applied"}
			}
		} else if action == "begin-hold" {
			status.suitable = v.target != nil && v.target.activation_owner == "hold"
			if status.suitable {status.allowed = ready && v.target.availability == .Applied; status.reason = app.tool_code_name(v.target.availability)}
		} else {
			for region in reader.scroll.regions {if region.id == id {status.suitable = true; status.allowed = ready && region.availability == .Applied; status.reason = app.tool_code_name(region.availability)}}
			frames, count := collection_frames(reader)
			for f in frames[:count] {for view in f.collections {if view.description.scroll_id == id {
						code := f.owner_gate
						if !f.bound || f.stamp != i.frame.stamp {code = .Not_Ready}
						if code == .Applied {
							if v.target == nil {code = .Not_Found} else {
								code = v.target.availability
								if code == .Invalid_Action &&
								   v.target.description.role == "" {code = .Applied}
							}
						}
						status.suitable, status.allowed, status.reason =
							true, ready && code == .Applied, app.tool_code_name(code)
					}}}
		}
		if !ready {status.allowed = false; status.reason = "Not_Ready"}
		append(&actions, status)
	}
	result.actions = actions[:]
	return result, true
}
collection_frames :: proc(reader: ^app.Reader) -> ([2]collections.Frame, int) {
	frames: [2]collections.Frame; count := 0
	if v, selected := reader.content.(app.Collection_Page_Reader);
	   selected {frames[0], count = v.frame, 1}
	if v, selected := reader.content.(app.Performance_Page_Reader);
	   selected {frames[0], count = v.collection.frame, 1}
	if v, selected := reader.content.(app.Lab_Inventory_Reader);
	   selected {frames, count = v.frames, 2}
	return frames, count
}
make_reply :: proc(h: ^Host, request: profile.Request, result: any, code, phase: string) -> Reply {
	r := Reply {
		protocol = 19,
		request_id = request.request_id,
		ok = code == "",
		error = {code = code, phase = phase},
		result = result,
	}
	if h.shell !=
	   nil {r.model_revision = h.shell.model.revision; r.section = app.section_id(h.shell.model.page)}
	reader, ready := selected_reader(h)
	if reader != nil {
		stamp := app.reader_stamp(reader)
		r.ready, r.historical, r.section = ready, !ready, reader.tools.observation.selected_section
		r.screen_epoch, r.frame_id, r.published_revision =
			reader.tools.screen_epoch, stamp.attempt, stamp.model_revision
	}
	return r
}
