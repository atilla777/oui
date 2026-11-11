package sections

import model "../model"
import "core:mem"
import composition "ui:ui_composition"
import controls "ui:ui_controls"
import gestures "ui:ui_gestures"
import hold "ui:ui_hold"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import scroll "ui:ui_scroll"
import style "ui:ui_style"
import text "ui:ui_text"
import world "ui:ui_world"

Page_Model :: model.Model
Page_Input :: struct {
	model:     Page_Model,
	allocator: mem.Allocator,
}
Gesture_Description :: gestures.Description
// Borrowed structural descriptions. Recipes retain their own owners; all backing
// buffers remain live through prepare/copy/commit and are released by destroy.
Page_Composition :: struct {
	accessibility_paint:  [4][5]style.Declaration,
	accessibility_buffer: [256]u8,
	page_allocator:       mem.Allocator,
	transition_buffer:    [96]u8,
	route_paint:          [4]style.Declaration,
	panels:               [2]composition.Composition,
	custom_colors:        [2]style.Declaration,
	custom_declarations:  [32][8]style.Declaration,
	custom_buffers:       [2][64]u8,
	world:                [3]world.Placement,
	world_triangles:      [3][3][2]f64,
	world_paint:          [9][5]style.Declaration,
	world_buffer:         [128]u8,
	route_buffer:         [96]u8,
	gestures:             [20]Gesture_Description,
	ngestures:            int,
	layer_scroll:         [3]scroll.Description,
	holds:                [3]hold.Description,
	nscroll, nholds:      int,
	nodes:                [256]layout.Node,
	texts:                [192]text.Text_Node,
	targets:              [96]interaction.Target,
	styles:               [256]style.Description,
	n, nt, ni, ns:        int,
	recipes:              [3]controls.Composition,
	profiles:             Profile_Recipes,
	content:              Content,
	table:                ^Table,
	select_open:          bool,
	popups:               [2]layers.Popup,
	tooltips:             [2]layers.Tooltip,
	modals:               [2]layers.Modal,
	np, ntool, nm:        int,
	rows:                 [2]layout.Track,
	columns:              [2]layout.Track,
	outer_rows:           [3]layout.Track,
	initial_focus:        string,
	buffer:               [64]u8,
}
page_node :: proc(c: ^Page_Composition, id, parent: string, kind: layout.Kind, l: layout.Layout) {
	c.nodes[c.n] = {
		id      = id,
		parent  = parent,
		role    = kind,
		layout  = l,
		enabled = true,
		visible = true,
	}; c.n += 1
}
page_label :: proc(c: ^Page_Composition, id, parent, value: string, l: layout.Layout) {
	page_node(
		c,
		id,
		parent,
		.Content,
		l,
	); c.texts[c.nt] = {id, value, {"own"}, 14, {vertical = .Center}}; c.nt += 1
}
page_button :: proc(c: ^Page_Composition, id, text_id, parent, value: string) {
	page_node(
		c,
		id,
		parent,
		.Stack,
		{x = {mode = .Fill}, y = {mode = .Fill}, padding = {3, 1, 3, 1}},
	)
	page_label(c, text_id, id, value, {x = {mode = .Fill}, y = {mode = .Fill}})
	c.targets[c.ni] = {id, "button", true, true}; c.ni += 1
}
destroy_page :: proc(c: ^Page_Composition) {
	for &p in c.panels {composition.destroy(&p)}
	destroy_table(&c.table); destroy_profiles(&c.profiles)
	for &recipe in c.recipes {controls.destroy_composition(&recipe)}; c^ = {}
}
node :: page_node
label :: proc {
	content_label,
	page_label,
}
button :: proc {
	content_button,
	page_button,
}
