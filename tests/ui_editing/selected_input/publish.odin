package main
import base "ui:ui_base"
import editor "ui:ui_editor"
import gestures "ui:ui_gestures"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import scroll "ui:ui_scroll"
import fonts "ui:ui_sdl_text"
import style "ui:ui_style"
import text "ui:ui_text"

publish :: proc(r: ^Runtime) -> bool {
	stamp, pe := base.begin_attempt(&r.publication, r.revision); if pe != .None {return false}
	if r.fail_next {r.fail_next = false; return false}
	nodes := []layout.Node {
		{
			id = "root",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fill},
				y = {mode = .Fill},
				padding = {12, 12, 12, 12},
				gap = 12,
			},
		},
		{
			id = "title",
			parent = "root",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fixed, value = 28}},
		},
		{
			id = "field",
			parent = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fill},
				y = {mode = .Fixed, value = 34},
				padding = {4, 3, 4, 3},
			},
		},
		{
			id = "value",
			parent = "field",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "body",
			parent = "root",
			role = .Row,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fixed, value = 100}, gap = 4},
		},
		{
			id = "source",
			parent = "body",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 76}, y = {mode = .Fill}},
		},
		{
			id = "source-label",
			parent = "source",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "target",
			parent = "body",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 76}, y = {mode = .Fill}},
		},
		{
			id = "target-label",
			parent = "target",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "repeat",
			parent = "body",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 32}, y = {mode = .Fill}},
		},
		{
			id = "repeat-label",
			parent = "repeat",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "viewport",
			parent = "body",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 84}, y = {mode = .Fill}},
		},
		{
			id = "content",
			parent = "viewport",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Content}},
		},
		{
			id = "one",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fixed, value = 100}},
		},
		{
			id = "two",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fixed, value = 100}},
		},
		{
			id = "language",
			parent = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}},
		},
		{
			id = "language-label",
			parent = "language",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "recover",
			parent = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fixed, value = 32}},
		},
		{
			id = "recover-label",
			parent = "recover",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
	}
	title, source, target, recover :=
		"Редактор и жесты", "Карточка", "Сюда", "Обновить / R"
	if r.english {title, source, target, recover = "Editor and gestures", "Card", "Drop", "Rebuild / R"}
	if r.dropped {target = "OK"}
	labels := []text.Text_Node {
		{"title", title, {"font"}, 16, {}},
		{"value", r.value, {"font"}, 16, {}},
		{"source-label", source, {"font"}, 16, {horizontal = .Center, vertical = .Center}},
		{"target-label", target, {"font"}, 16, {horizontal = .Center, vertical = .Center}},
		{"repeat-label", "+", {"font"}, 16, {horizontal = .Center, vertical = .Center}},
		{"language-label", "RU / EN", {"font"}, 16, {horizontal = .Center, vertical = .Center}},
		{"recover-label", recover, {"font"}, 16, {horizontal = .Center, vertical = .Center}},
	}
	tc, te := text.prepare(
		labels,
		nodes,
		{drawable = r.drawable, ui_scale = r.fonts.scale},
		fonts.metrics(r.fonts),
		r.allocator,
		stamp,
	)
	if te.code != .None {return false}; defer text.destroy_candidate(&tc)
	targets := []interaction.Target {
		{"field", "editor", true, true},
		{"source", "button", true, true},
		{"repeat", "button", true, true},
		{"viewport", "scroll", true, true},
		{"language", "button", true, true},
		{"recover", "button", true, true},
	}
	i, ie := interaction.prepare(
		&tc.geometry,
		targets,
		nil,
		r.allocator,
	); if ie != .Applied {return false}; defer interaction.destroy_frame(&i)
	sc, se := scroll.prepare(
		&r.scroll,
		&tc.geometry,
		&i,
		[]scroll.Description{{"viewport", "content"}},
		r.allocator,
	)
	if se.code != .None {return false}; defer scroll.destroy_candidate(&sc)
	interaction.destroy_frame(&i)
	claims := []interaction.Capture_Claim {
		{"field", "editor"},
		{"value", "editor"},
		{"source", "gestures"},
		{"target", "gestures"},
		{"repeat", "gestures"},
		{"viewport", "gestures"},
	}
	i, ie = interaction.prepare(
		&sc.geometry,
		targets,
		claims,
		r.allocator,
	); if ie != .Applied {return false}
	ec, ee := editor.prepare(
		&r.editing,
		&sc.geometry,
		&i,
		&tc.text,
		[]editor.Description {
			{
				id = "name",
				node_id = "field",
				text_node_id = "value",
				label = "Name",
				value = r.value,
				revision = r.value_revision,
				resolution = r.resolution,
				max_graphemes = 64,
			},
		},
		fonts.metrics(r.fonts),
		r.allocator,
	)
	if ee.code != .None {return false}; defer editor.destroy_candidate(&ec)
	ds := []gestures.Description {
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
	gc, ge := gestures.prepare(
		&r.gestures,
		&sc.geometry,
		&i,
		&sc.frame,
		ds,
		r.revision,
		r.allocator,
	)
	if ge.code != .None {return false}; defer gestures.destroy_candidate(&gc)
	plain := []style.Declaration {
		{.Background, style.Color{0, 0, 0, 0}},
		{.Border_Width, f64(0)},
		{.Font, style.Font_ID{"font"}},
		{.Font_Size, f64(16)},
	}
	descs, da := make(
		[]style.Description,
		len(nodes),
		r.allocator,
	); if da != nil {return false}; defer delete(descs, r.allocator)
	for n, k in nodes {descs[k] = {
			id   = n.id,
			role = "plain",
		}; descs[k].appearance.local.states[.Normal] = plain}
	paint, spe := style.prepare(
		&sc.geometry,
		descs,
		{revision = "selected-theme"},
		{revision = "none"},
		r.allocator,
	)
	if spe.code != .None {return false}; defer style.destroy_frame(&paint)
	reader: Reader; complete := false; defer {if !complete {destroy_reader(&reader)}}
	ok: bool
	reader.editor, ok = editor.try_copy_frame(&ec.frame, r.allocator); if !ok {return false}
	reader.gestures, ok = gestures.try_copy_frame(&gc.frame, r.allocator); if !ok {return false}
	reader.text, ok = text.try_copy_frame(&tc.text, r.allocator); if !ok {return false}
	reader.paint, ok = style.try_copy_frame(&paint, r.allocator); if !ok {return false}
	if !fonts.retain_generation(r.fonts) {return false}; reader.fonts = r.fonts
	if !editor.validate_candidate(&r.publication, &r.editing, &ec) ||
	   !gestures.validate_candidate(&r.publication, &r.gestures, &gc) ||
	   !scroll.validate_candidate(&r.publication, &r.scroll, &sc) ||
	   !interaction.validate_candidate(&r.publication, &i) {return false}
	if base.enter_commit(&r.publication, stamp) != .None {return false}
	old := r.reader; r.reader = reader; reader = {}; complete = true
	interaction.commit(
		&r.interaction,
		&i,
		"field",
	); scroll.commit(&r.scroll, &sc); editor.commit(&r.editing, &ec); gestures.commit(&r.gestures, &gc); base.finish_commit(&r.publication, stamp)
	destroy_reader(&old); interaction.reconcile_registrations(&r.interaction)
	return true
}
