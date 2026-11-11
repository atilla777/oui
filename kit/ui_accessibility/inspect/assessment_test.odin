package ui_accessibility_inspect
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import wire "../../ui_wire"
import ui "../projection"
import "core:testing"

@(test)
contrast_target_and_owning_records_keep_original_oracles :: proc(t: ^testing.T) {
	testing.expect(t, accessibility_ratio({255, 255, 255, 255}, {0, 0, 0, 255}) == 21)
	p, _ := base.create(context.allocator); s, _ := base.begin_attempt(&p, 3)
	nodes := [1]layout.Node {
		{
			id = "button",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); testing.expect(t, e.code == .None)
	targets := [1]interaction.Target{{"button", "button", true, true}}
	f, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); testing.expect(t, code == .Applied)
	n := g.nodes[0]
	wn := [1]wire.Resolved_Node {
		{
			description = {
				id = "button",
				text = "Text",
				role = .Button,
				enabled = true,
				visible = true,
				layout = nodes[0].layout,
			},
			bounds = n.bounds,
			content = n.content,
			clip = n.clip,
			paint_clip = n.paint_clip,
			enabled = true,
			visible = true,
			availability = .Applied,
			style = {
				foreground = {255, 255, 255, 255},
				background = {0, 0, 0, 255},
				font_size = 16,
			},
		},
	}
	projection := ui.Frame {
		nodes    = wn[:],
		id       = g.id,
		stamp    = g.stamp,
		drawable = g.drawable,
		ui_scale = g.ui_scale,
	}
	input := Inspection_Input {
		frame = &projection,
		common = {
			frame = &g,
			interaction = &f,
			ready = true,
			model_revision = 3,
			published_revision = 3,
		},
	}
	a, ae := capture_accessibility(
		input,
		default_accessibility_policy(),
		context.allocator,
		u64(1),
		u64(1),
	); testing.expect(t, ae == .None)
	defer destroy_accessibility_inspection(&a)
	// IV16-R1-001: positive finite projection values are not evidence that
	// they belong to this frozen common frame. Check current and historical.
	for historical in ([]bool{false, true}) {
		input.common.ready = !historical
		for field in 0 ..< 3 {
			projection.drawable, projection.ui_scale = g.drawable, g.ui_scale
			switch field {case 0:
				projection.ui_scale = 10; case 1:
				projection.drawable.w = 101; case 2:
				projection.drawable.h = 101}
			bad, be := capture_accessibility(
				input,
				default_accessibility_policy(),
				context.allocator,
				u64(1),
				u64(1),
			)
			testing.expect(t, be == .Metadata_Mismatch, "mixed scale/drawable must be refused")
			destroy_accessibility_inspection(&bad)
		}
		projection.drawable, projection.ui_scale = g.drawable, g.ui_scale
		valid, ve := capture_accessibility(
			input,
			default_accessibility_policy(),
			context.allocator,
			u64(1),
			u64(1),
		)
		testing.expect(t, ve == .None && valid.inspection.historical == historical)
		destroy_accessibility_inspection(&valid)
	}
	input.common.ready = true
	_, mismatch := capture_accessibility(
		input,
		default_accessibility_policy(),
		context.allocator,
		u64(1),
		u64(2),
	); testing.expect(t, mismatch == .Metadata_Mismatch)
	layout.destroy_frame(&g); interaction.destroy_frame(&f); base.destroy(&p)
	wn[0].description.id = "gone"
	contrast, target := false, false
	for r in a.records {
		if r.check ==
		   .Contrast {ratio, has := r.ratio.?; contrast = has && ratio == 21 && r.status == .Pass && r.id == "button"}
		if r.check ==
		   .Target_Size {target = r.status == .Warning && r.reason == "target_below_minimum" && r.id == "button"}
	}
	testing.expect(t, contrast && target && a.source == nil && !accessibility_strict_result(&a).ok)
}
