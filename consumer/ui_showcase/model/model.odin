package showcase_model

import accessibility "../../accessibility_demo/model"
import profiles "../../controls_demo/model"

Page :: enum {
	Catalogue,
	Layout,
	Controls,
	Profiles,
	Styling,
	Atlas,
	Text,
	Rich_Text,
	Text_Input,
	Scroll_Table,
	Collections,
	Layers,
	Hud,
	Gestures,
	Composition,
	Custom,
	Transitions,
	Accessibility,
	World,
	Diagnostics_Performance,
	Lab_Menu,
	Lab_Settings,
	Lab_Hud,
	Lab_Inventory,
}
Locale :: enum {
	Russian,
	English,
}
Style_Model :: struct {
	dark, selected, disabled: bool,
	missing_image:            bool,
	count:                    u64,
}
Atlas_Model :: struct {
	dark:                          bool,
	alternate, selected, disabled: bool,
	count, reload:                 u64,
}
Text_Model :: struct {
	short:         bool,
	limit_fixture: int,
}
Rich_Model :: struct {
	ellipsis: bool,
}
Composition_Model :: struct {
	parent_count, child_count: u64,
	stop, child_present:       bool,
}
World_Model :: struct {
	object, camera: [2]f64,
	zoomed:         bool,
	policy:         int,
}
Name_State :: struct {
	draft, applied:             string,
	value_revision:             u64,
	owned_draft, owned_applied: bool,
}
Transition_Model :: struct {
	slider:                    i64,
	target_b, reduced, hidden: bool,
	easing:                    int,
	count:                     u64,
}
Model :: struct {
	lab_name:                                          Name_State,
	catalogue_lab:                                     bool,
	lab_selected:                                      string,
	lab_reverse:                                       bool,
	lab_hp:                                            int,
	lab_hold_count:                                    u64,
	lab_enabled, lab_applied_enabled:                  bool,
	lab_amount, lab_applied_amount:                    i64,
	lab_submenu:                                       bool,
	performance_name:                                  Name_State,
	accessibility:                                     accessibility.State,
	measurements_off:                                  bool,
	transition:                                        Transition_Model,
	custom_counts:                                     [2]u64,
	custom_style, custom_slot_absent, custom_disabled: bool,
	world:                                             World_Model,
	composition:                                       Composition_Model,
	name, gesture_name:                                Name_State,
	layer_counts:                                      [3]u64,
	layer_checked:                                     bool,
	hud_hp:                                            int,
	hud_count:                                         u64,
	table_dataset, table_fixture, table_selected:      int,
	layout_details, layout_safe_area:                  bool,
	styling:                                           Style_Model,
	atlas:                                             Atlas_Model,
	text:                                              Text_Model,
	rich:                                              Rich_Model,
	page:                                              Page,
	locale:                                            Locale,
	scale:                                             f64,
	pixel_perfect:                                     bool,
	checkbox, toggle:                                  bool,
	slider:                                            i64,
	profiles:                                          profiles.State,
	catalogue_offset:                                  int,
	revision, effects:                                 u64,
}
Intent_Kind :: enum {
	Catalogue,
	Layout,
	Controls,
	Language,
	Scale,
	Mode,
	Checkbox,
	Toggle,
	Slider,
	Section,
	Catalogue_Next,
	Catalogue_Previous,
	Catalogue_Lab,
	Gallery,
}
Intent :: struct {
	kind:    Intent_Kind,
	boolean: bool,
	integer: i64,
	page:    Page,
	id:      string,
}
initial :: proc() -> Model {return {
		lab_name = {draft = "Алексей", applied = "Алексей", value_revision = 1},
		lab_hp = 60,
		lab_amount = 50,
		lab_applied_amount = 50,
		performance_name = {
			draft = "Алексей",
			applied = "Алексей",
			value_revision = 1,
		},
		accessibility = accessibility.create(),
		transition = {slider = 50},
		composition = {stop = true, child_present = true},
		scale = 1,
		slider = 50,
		profiles = profiles.create(),
		name = {draft = "Алексей", applied = "Алексей", value_revision = 1},
		gesture_name = {draft = "Алексей", applied = "Алексей", value_revision = 1},
		hud_hp = 60,
	}}
apply :: proc(m: ^Model, intent: Intent) -> bool {
	if m.revision == max(u64) || m.effects == max(u64) {return false}
	next := m^
	switch intent.kind {
	case .Catalogue:
		next.page = .Catalogue
	case .Layout:
		next.page = .Layout
	case .Controls:
		next.page = .Controls
	case .Section:
		if intent.page < .Catalogue || intent.page > .Lab_Inventory {return false}
		next.page = intent.page
	case .Catalogue_Next:
		if next.page != .Catalogue {return false}
		next.catalogue_offset = (next.catalogue_offset + 2) % 20
	case .Catalogue_Previous:
		if next.page != .Catalogue {return false}
		next.catalogue_offset = (next.catalogue_offset + 18) % 20
	case .Catalogue_Lab:
		if next.page != .Catalogue {return false}
		next.catalogue_lab = !next.catalogue_lab
	case .Gallery:
		switch intent.id {
		case "performance/instrumentation":
			if next.page != .Diagnostics_Performance {return false}
			next.measurements_off = !next.measurements_off
		case "transitions/a",
		     "transitions/b",
		     "transitions/reduced",
		     "transitions/presence",
		     "transitions/easing",
		     "transitions/count",
		     "transitions/hold",
		     "transitions/slider":
			if next.page != .Transitions {return false}
			switch intent.id {
			case "transitions/a":
				next.transition.target_b = false
			case "transitions/b":
				next.transition.target_b = true
			case "transitions/reduced":
				next.transition.reduced = !next.transition.reduced
			case "transitions/presence":
				next.transition.hidden = !next.transition.hidden
			case "transitions/easing":
				next.transition.easing = (next.transition.easing + 1) % 4
			case "transitions/count", "transitions/hold":
				if next.transition.hidden || next.transition.count == max(u64) {return false}
				next.transition.count += 1
			case "transitions/slider":
				if intent.integer < 0 || intent.integer > 100 {return false}
				next.transition.slider = intent.integer
			}
		case "node:4:left7:content6:circle", "node:5:right7:content6:circle":
			if next.page != .Custom || next.custom_disabled {return false}
			i := 0; if intent.id == "node:5:right7:content6:circle" {i = 1}
			if next.custom_counts[i] == max(u64) {return false}; next.custom_counts[i] += 1
		case "custom/style", "custom/slot", "custom/disabled":
			if next.page != .Custom {return false}
			switch intent.id {case "custom/style":
				next.custom_style = !next.custom_style
			case "custom/slot":
				next.custom_slot_absent = !next.custom_slot_absent
			case "custom/disabled":
				next.custom_disabled = !next.custom_disabled}
		case "world/object-left",
		     "world/object-right",
		     "world/object-up",
		     "world/object-down",
		     "world/camera-left",
		     "world/camera-right",
		     "world/camera-up",
		     "world/camera-down",
		     "world/zoom",
		     "world/policy",
		     "world/reset":
			if next.page != .World {return false}
			switch intent.id {
			case "world/object-left":
				next.world.object.x -= 64
			case "world/object-right":
				next.world.object.x += 64
			case "world/object-up":
				next.world.object.y -= 64
			case "world/object-down":
				next.world.object.y += 64
			case "world/camera-left":
				next.world.camera.x -= 64
			case "world/camera-right":
				next.world.camera.x += 64
			case "world/camera-up":
				next.world.camera.y -= 64
			case "world/camera-down":
				next.world.camera.y += 64
			case "world/zoom":
				next.world.zoomed = !next.world.zoomed
			case "world/policy":
				next.world.policy = (next.world.policy + 1) % 3
			case "world/reset":
				next.world = {}
			}
		case "composition/stop", "composition/presence", "composition/parent", "composition/child":
			if next.page != .Composition {return false}
			switch intent.id {
			case "composition/stop":
				next.composition.stop = !next.composition.stop
			case "composition/presence":
				next.composition.child_present = !next.composition.child_present
			case "composition/parent":
				if next.composition.parent_count == max(u64) {return false}
				next.composition.parent_count += 1
			case "composition/child":
				if !next.composition.child_present ||
				   next.composition.child_count == max(u64) {return false}
				if !next.composition.stop &&
				   next.composition.parent_count == max(u64) {return false}
				next.composition.child_count += 1
				if !next.composition.stop {next.composition.parent_count += 1}
			}
		case "table/dataset":
			if next.page != .Scroll_Table {return false}
			next.table_dataset = 1 - next.table_dataset
		case "hud/minus", "hud/plus", "hud/restore":
			if next.page != .Hud {return false}
			if intent.id == "hud/minus" {next.hud_hp = max(0, next.hud_hp - 10)}
			if intent.id == "hud/plus" {next.hud_hp = min(100, next.hud_hp + 10)}
			if intent.id ==
			   "hud/restore" {if next.hud_count == max(u64) {return false}; next.hud_hp = 100; next.hud_count += 1}
		case "table/select":
			if next.page != .Scroll_Table ||
			   intent.integer < 1 ||
			   intent.integer > 33 {return false}
			next.table_selected = int(intent.integer)
		case "table/fixture":
			if next.page != .Scroll_Table {return false}
			next.table_fixture = (next.table_fixture + 1) % 5
		case "layout/more":
			if next.page != .Layout {return false}; next.layout_details = !next.layout_details
		case "layout/safe-area":
			if next.page != .Layout {return false}; next.layout_safe_area = !next.layout_safe_area
		case "styling/fallback":
			if next.page != .Styling {return false}
			next.styling.missing_image = !next.styling.missing_image
		case "styling/theme":
			if next.page != .Styling {return false}; next.styling.dark = !next.styling.dark
		case "styling/selected":
			if next.page != .Styling {return false}; next.styling.selected = !next.styling.selected
		case "styling/disabled":
			if next.page != .Styling {return false}; next.styling.disabled = !next.styling.disabled
		case "styling/count":
			if next.page != .Styling ||
			   next.styling.disabled ||
			   next.styling.count == max(u64) {return false}
			next.styling.count += 1
		case "atlas/assets":
			if next.page != .Atlas {return false}; next.atlas.alternate = !next.atlas.alternate
		case "atlas/theme":
			if next.page != .Atlas {return false}; next.atlas.dark = !next.atlas.dark
		case "atlas/button":
			if next.page != .Atlas ||
			   next.atlas.disabled ||
			   next.atlas.count == max(u64) {return false}
			next.atlas.count += 1
		case "atlas/reload":
			if next.page != .Atlas || next.atlas.reload == max(u64) {return false}
			next.atlas.reload += 1
		case "atlas/selected":
			if next.page != .Atlas {return false}; next.atlas.selected = !next.atlas.selected
		case "atlas/disabled":
			if next.page != .Atlas {return false}; next.atlas.disabled = !next.atlas.disabled
		case "atlas/count":
			if next.page != .Atlas ||
			   next.atlas.disabled ||
			   next.atlas.count == max(u64) {return false}
			next.atlas.count += 1
		case "text/key":
			if next.page != .Text {return false}; next.text.short = !next.text.short
		case "text/limit":
			if next.page != .Text {return false}
			next.text.limit_fixture = (next.text.limit_fixture + 1) % 4
		case "rich/limit":
			if next.page != .Rich_Text {return false}; next.rich.ellipsis = !next.rich.ellipsis
		case:
			return false
		}
	case .Language:
		if next.locale == .Russian {next.locale = .English} else {next.locale = .Russian}
	case .Scale:
		if next.scale ==
		   1 {next.scale = 1.5} else if next.scale == 1.5 {next.scale = 2} else {next.scale = 1}
		if next.pixel_perfect && next.scale == 1.5 {return false}
	case .Mode:
		if next.scale == 1.5 {return false}
		next.pixel_perfect = !next.pixel_perfect
	case .Checkbox:
		if next.page != .Controls {return false}; next.checkbox = intent.boolean
	case .Toggle:
		if next.page != .Controls {return false}; next.toggle = intent.boolean
	case .Slider:
		if next.page != .Controls || intent.integer < 0 || intent.integer > 100 {return false}
		next.slider = intent.integer
	}
	if next.page == .Scroll_Table && next.table_selected != 0 {
		count := 32 + next.table_dataset
		if next.table_fixture == 3 {count = 3}; if next.table_fixture == 4 {count = 0}
		found := false
		for i in 0 ..< count {
			n :=
				i +
				1 -
				next.table_dataset; if next.table_fixture == 2 {n = count - i - next.table_dataset}
			if next.table_fixture == 1 && n == 5 {continue}
			found ||= n + 1 == next.table_selected
		}
		if !found {next.table_selected = 0}
	}
	clamped_hud_request :=
		intent.kind == .Gallery &&
		next.page == .Hud &&
		(intent.id == "hud/plus" || intent.id == "hud/minus")
	if next == m^ && !clamped_hud_request {return false}
	next.revision += 1; next.effects += 1; m^ = next; return true
}
