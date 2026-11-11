package gesture_fixture
import base "../../../kit/ui_base"
import gestures "../../../kit/ui_gestures"
import interaction "../../../kit/ui_interaction"
import layout "../../../kit/ui_layout"
import scroll "../../../kit/ui_scroll"
import "core:mem"

Runtime :: struct {
	publication: base.Publication,
	interaction: interaction.Context,
	gestures:    gestures.State,
	scroll:      scroll.State,
	allocator:   mem.Allocator,
}
init :: proc(r: ^Runtime, a := context.allocator) -> bool {
	p, e := base.create(a); if e != .None {return false}
	r.publication, r.allocator = p, a
	r.interaction = interaction.create(
		a,
		&r.publication,
	); r.gestures = gestures.create(a); r.scroll = scroll.create(a)
	return true
}
destroy :: proc(r: ^Runtime) {gestures.destroy(&r.gestures); scroll.destroy(&r.scroll)
	interaction.destroy(&r.interaction)
	base.destroy(&r.publication)
	r^ = {}}
publish :: proc(r: ^Runtime, focus := "source", height: f64 = 100, scale: f64 = 1) -> bool {
	stamp, pe := base.begin_attempt(&r.publication, 7); if pe != .None {return false}
	nodes := [8]layout.Node {
		{
			id = "root",
			role = .Row,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 300},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "source",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 50},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "target",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 50},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "repeat",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 20},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "viewport",
			parent = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "content",
			parent = "viewport",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 100}, y = {mode = .Content}},
		},
		{
			id = "one",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 150},
			},
		},
		{
			id = "two",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 150},
			},
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {300 * scale, height * scale}, ui_scale = scale},
		{},
		r.allocator,
		stamp,
	)
	if ge.code != .None {return false}; defer layout.destroy_frame(&g)
	targets := [4]interaction.Target {
		{"source", "button", true, true},
		{"target", "drop", true, true},
		{"repeat", "button", true, true},
		{"viewport", "scroll", true, true},
	}
	i, ie := interaction.prepare(
		&g,
		targets[:],
		nil,
		r.allocator,
	); if ie != .Applied {return false}; defer interaction.destroy_frame(&i)
	sc, se := scroll.prepare(
		&r.scroll,
		&g,
		&i,
		[]scroll.Description{{"viewport", "content"}},
		r.allocator,
	); if se.code != .None {return false}; defer scroll.destroy_candidate(&sc)
	interaction.destroy_frame(&i)
	i, ie = interaction.prepare(
		&sc.geometry,
		targets[:],
		[]interaction.Capture_Claim {
			{"source", "gestures"},
			{"repeat", "gestures"},
			{"viewport", "gestures"},
		},
		r.allocator,
	); if ie != .Applied {return false}
	ds := [4]gestures.Description {
		{
			id = "drag",
			node_id = "source",
			payload_id = "card",
			payload_type = "card",
			kind = .Drag_Source,
		},
		{id = "drop", node_id = "target", kind = .Drop_Target, accept_types = []string{"card"}},
		{
			id = "repeat",
			node_id = "repeat",
			kind = .Repeat_Scroll,
			scroll_id = "viewport",
			step = 24,
			delay_ms = 300,
			interval_ms = 100,
		},
		{id = "pan", node_id = "viewport", kind = .Pan_Scroll, scroll_id = "viewport"},
	}
	c, ce := gestures.prepare(
		&r.gestures,
		&sc.geometry,
		&i,
		&sc.frame,
		ds[:],
		7,
		r.allocator,
	); if ce.code != .None {return false}; defer gestures.destroy_candidate(&c)
	if !gestures.validate_candidate(&r.publication, &r.gestures, &c) ||
	   !scroll.validate_candidate(&r.publication, &r.scroll, &sc) ||
	   !interaction.validate_candidate(&r.publication, &i) {return false}
	if base.enter_commit(&r.publication, stamp) != .None {return false}
	interaction.commit(
		&r.interaction,
		&i,
		focus,
	); scroll.commit(&r.scroll, &sc); gestures.commit(&r.gestures, &c); base.finish_commit(&r.publication, stamp)
	return true
}
