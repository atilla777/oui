package ui_accessibility_debug

import base "../../ui_base"
import debug "../../ui_debug"
import layout "../../ui_layout"
import wire "../../ui_wire"
import inspect "../inspect"
import projection "../projection"
import "core:mem"
import "core:strings"
import "core:testing"

Projection_Probe :: struct {
	g:          ^layout.Frame,
	f:          ^projection.Frame,
	corruption: int,
	historical: bool,
	snapshots:  int,
}
probe_capture :: proc(user: rawptr, a: mem.Allocator) -> Accessibility_Capture {
	u := cast(^Projection_Probe)user
	revision := u64(1); if u.historical {revision = 2}
	i, e := inspect.capture_accessibility(
		{
			frame = u.f,
			common = {
				frame = u.g,
				ready = !u.historical,
				model_revision = revision,
				published_revision = 1,
			},
		},
		inspect.default_accessibility_policy(),
		a,
		u64(1),
		u64(1),
	)
	c := Accessibility_Capture {
		assessment = i,
		frame = {drawable = u.g.drawable, ui_scale = u.g.ui_scale},
		strict_accessibility = true,
	}
	if e != .None {c.error = inspect.error_name(e); return c}
	c.observation = transmute([]u8)strings.clone("{}", a)
	count := 1; if u.corruption == 4 {count = 0}; if u.corruption == 13 {count = 2}
	c.nodes = make([]Wire_Node, count, a)
	for &n in c.nodes {n, _ = debug.node_projection(&c.assessment.inspection, "button", u.f.nodes[0].description)}
	switch u.corruption {
	case 1:
		c.frame.ui_scale = 999
	case 2:
		c.frame.drawable.w = 1
	case 3:
		c.frame.drawable.h = 1
	case 5:
		c.nodes[0].resolved.description.id = "missing"
	case 6:
		c.nodes[0].resolved.description.parent = "other"
	case 7:
		c.nodes[0].resolved.bounds.w += 1
	case 8:
		c.nodes[0].resolved.content.w += 1
	case 9:
		c.nodes[0].resolved.clip.w += 1
	case 10:
		c.nodes[0].resolved.paint_clip.w += 1
	case 11:
		c.nodes[0].resolved.enabled = false
	case 12:
		c.nodes[0].resolved.visible = false
	case:
	}
	return c
}
probe_snapshot :: proc(
	user: rawptr,
	options: debug.Snapshot_Options,
	a: mem.Allocator,
) -> debug.Snapshot_Reply {
	u := cast(^Projection_Probe)user; u.snapshots += 1; return {path = strings.clone("snapshot.png", a)}
}
@(test)
profile17_binds_live_tree_inspect_and_snapshot_to_owning_frame :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	nodes := [1]layout.Node {
		{
			id = "button",
			role = .Box,
			enabled = true,
			visible = true,
			layout = {x = {mode = .Fixed, value = 40}, y = {mode = .Fixed, value = 40}},
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); defer layout.destroy_frame(&g)
	if !testing.expect(t, ge.code == .None) {return}
	n := g.nodes[0]
	wn := [1]wire.Resolved_Node {
		{
			description = {
				id = "button",
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
		},
	}
	f := projection.Frame {
		nodes    = wn[:],
		id       = g.id,
		stamp    = g.stamp,
		drawable = g.drawable,
		ui_scale = g.ui_scale,
	}
	u := Projection_Probe {
		g = &g,
		f = &f,
	}
	h := Host {
		allowed = true,
		user = &u,
		capture_accessibility = probe_capture,
		snapshot = probe_snapshot,
		capabilities = {snapshot = true},
	}
	for historical in ([]bool{false, true}) {
		u.historical = historical
		for corruption in 0 ..< 14 {
			u.corruption = corruption
			c := probe_capture(&u, context.allocator)
			_, found := node_projection(&c, "unknown")
			testing.expect(
				t,
				!found,
				"missing wire node is not a zero-valued successful projection",
			)
			document := encode_accessibility_snapshot(
				&c,
				&h,
				{window_size = {100, 100}},
				context.allocator,
			)
			testing.expect(
				t,
				(document != nil) == (corruption == 0 && !historical),
				"snapshot must reject mixed projections and historical reads",
			)
			if corruption == 0 && !historical {
				testing.expect(
					t,
					strings.contains(string(document), `"frame_id":1`) &&
					strings.contains(string(document), `"id":"button"`) &&
					strings.contains(string(document), `"target_at_least_minimum"`) &&
					strings.contains(string(document), `"strict":{"ok":true`),
					string(document),
				)
			}
			delete(document); destroy_accessibility_capture(&c, context.allocator)
			when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
				for line in ([]string{`{"protocol":17,"request_id":"r","op":"tree"}`, `{"protocol":17,"request_id":"r","op":"inspect","id":"button"}`, `{"protocol":17,"request_id":"r","op":"snapshot"}`}) {
					before := u.snapshots
					r := handle_accessibility(&h, transmute([]u8)line, context.allocator)
					if corruption != 0 {
						testing.expect(
							t,
							strings.contains(string(r), `"Metadata_Mismatch"`) &&
							!strings.contains(string(r), `"frame_id"`) &&
							u.snapshots == before,
							string(r),
						)
					} else if historical {
						testing.expect(
							t,
							strings.contains(string(r), `"historical":true`) &&
							u.snapshots == before,
							string(r),
						)
					} else {testing.expect(
							t,
							strings.contains(string(r), `"ok":true`) &&
							strings.contains(string(r), `"ready":true`),
							string(r),
						)}
					delete(r)
				}
			}
		}
	}
	when ODIN_DEBUG || #config(UI_DEMO_TEST, false) {
		u.corruption = 0; u.historical = false
		r := handle_accessibility(
			&h,
			transmute([]u8)string(
				`{"protocol":17,"request_id":"r","op":"inspect","id":"unknown"}`,
			),
			context.allocator,
		); defer delete(r)
		testing.expect(
			t,
			strings.contains(string(r), `"Not_Found"`) &&
			strings.contains(string(r), `"frame_id":1`),
			string(r),
		)
	}
}
