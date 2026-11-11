package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import layers "../ui_layers"
import layout "../ui_layout"
import style "../ui_style"
import text "../ui_text"
import "core:testing"
import "core:unicode/utf8"

font_metrics :: proc(
	id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Font_Metrics,
	text.Text_Metric_Error,
) {return {8, 2, 10, "fixture"}, .None}
measure :: proc(
	s, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Line_Metrics,
	text.Text_Metric_Error,
) {w := f64(utf8.rune_count_in_string(s)) * 5; return {w, {w, 10}}, .None}
valid_text :: proc(
	s, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Metric_Error,
	int,
) {return .None, 0}
Fixture :: struct {
	recipe:      Composition,
	geometry:    layout.Frame,
	interaction: interaction.Frame,
	layer:       layers.State,
}
destroy_fixture :: proc(f: ^Fixture) {layers.destroy(&f.layer); interaction.destroy_frame(
		&f.interaction,
	)
	layout.destroy_frame(&f.geometry)
	destroy_composition(&f.recipe)
	f^ = {}}
make_fixture :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	kind: Kind,
	checked: bool = false,
	open: bool = true,
) -> Fixture {
	f: Fixture
	d := Description {
		id       = "choice",
		kind     = kind,
		label    = "Выбор / Choice",
		body     = "Body",
		on_text  = "On",
		off_text = "Off",
	}
	if kind == .Checkbox || kind == .Toggle {d.checked = checked}
	if kind == .Slider {d.maximum = 100; d.step = 10; d.value = 50}
	if kind == .Tabs ||
	   kind == .List ||
	   kind == .Select ||
	   kind ==
		   .Dialog {d.items = []Item{{id = "one", label = "Один"}, {id = "two", label = "Two"}}; d.selected_id = "two"}
	if kind == .Dialog || kind == .Select {d.open = open}
	if kind == .Dialog {d.cancel_id = "two"}
	if kind == .Tooltip {d.trigger_id = "trigger"}
	e: Error; f.recipe, e = compose_control(d, "base", "root", context.allocator); if !testing.expect(t, e.code == .None) {return f}
	nodes := make([dynamic]layout.Node); defer delete(nodes)
	append(
		&nodes,
		layout.Node {
			id = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 500},
				y = {mode = .Fixed, value = 500},
			},
		},
		layout.Node {
			id = "base",
			parent = "root",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		layout.Node {
			id = "trigger",
			parent = "base",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
	)
	append(&nodes, ..f.recipe.nodes[:])
	stamp, _ := base.begin_attempt(p, 1)
	c, te := text.prepare(
		f.recipe.texts[:],
		nodes[:],
		{drawable = {500, 500}, ui_scale = 1},
		{font_metrics, measure, valid_text, nil},
		context.allocator,
		stamp,
	)
	if !testing.expect(t, te.code == .None) {text.destroy_candidate(&c); return f}
	f.geometry = c.geometry; c.geometry = {}; text.destroy_candidate(&c)
	targets := make(
		[dynamic]interaction.Target,
	); defer delete(targets); append(&targets, interaction.Target{"trigger", "button", true, true}); append(&targets, ..f.recipe.targets[:])
	modals: [1]layers.Modal; popups: [1]layers.Popup; tips: [1]layers.Tooltip
	plan := layers.Layers {
		base_root_id = "base",
	}
	if v, ok := f.recipe.modal.?; ok {modals[0] = v; plan.modals = modals[:]}
	if v, ok := f.recipe.popup.?; ok {popups[0] = v; plan.popups = popups[:]}
	if v, ok := f.recipe.tooltip.?; ok {tips[0] = v; plan.tooltips = tips[:]}
	ctx := interaction.create(context.allocator, p); defer interaction.destroy(&ctx)
	f.layer = layers.create(context.allocator)
	lc, le := layers.prepare(
		&f.layer,
		&ctx,
		&f.geometry,
		targets[:],
		nil,
		plan,
		context.allocator,
	); defer layers.destroy_candidate(&lc)
	if !testing.expect(t, le.code == .None) {return f}
	f.interaction = lc.interaction; lc.interaction = {}; f.layer.frame = lc.frame; lc.frame = {}
	return f
}

@(test)
all_recipes_pass_real_text_layout_layer_binding_and_selected_style_projection :: proc(
	t: ^testing.T,
) {
	for kind in Kind {
		p, _ := base.create(context.allocator)
		f := make_fixture(t, &p, kind)
		if f.geometry.nodes != nil && f.interaction.targets != nil {
			ds := [1]Description{f.recipe.control}
			c, e := prepare(
				&f.interaction,
				f.layer.frame.layers,
				ds[:],
				context.allocator,
				&f.geometry,
			)
			testing.expect(
				t,
				e.code == .None,
				"a valid recipe must satisfy actual owner/layer bindings",
			)
			paint, pe := style.prepare(&f.geometry, f.recipe.styles[:], {}, {}, context.allocator)
			testing.expect(t, pe.code == .None)
			if kind == .Tabs ||
			   kind == .List ||
			   kind ==
				   .Select {for v in paint.presentation {if v.id == f.recipe.control.items[1].node_id {testing.expect(t, .Selected in v.states)}}}
			style.destroy_frame(&paint); destroy_candidate(&c)
		}
		destroy_fixture(&f); base.destroy(&p)
	}
}
