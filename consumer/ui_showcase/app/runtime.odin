package app

import loader "../../atlas_catalog/loader"
import model "../model"
import sections "../sections"
import "core:fmt"
import "core:mem"
import base "ui:ui_base"
import collections "ui:ui_collections"
import controls "ui:ui_controls"
import controls_sdl "ui:ui_controls/sdl"
import custom "ui:ui_custom"
import painter "ui:ui_custom/sdl"
import editor "ui:ui_editor"
import editor_sdl "ui:ui_editor/sdl"
import gestures "ui:ui_gestures"
import gesture_sdl "ui:ui_gestures/sdl"
import hold "ui:ui_hold"
import hold_sdl "ui:ui_hold/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import rich "ui:ui_rich"
import rich_fonts "ui:ui_rich/sdl"
import scroll "ui:ui_scroll"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import style "ui:ui_style"
import text "ui:ui_text"
import transitions "ui:ui_transitions"
import sdl "vendor:sdl3"

Reader :: struct {
	tools:       Tools_Slot,
	content:     union {
		Lab_Inventory_Reader,
		Accessibility_Page_Reader,
		Performance_Page_Reader,
		Transition_Page_Reader,
		Custom_Page_Reader,
		Rich_Page_Reader,
		Name_Page_Reader,
		Collection_Page_Reader,
		Hold_Page_Reader,
		Gesture_Page_Reader,
	},
	geometry:    layout.Frame,
	interaction: interaction.Frame,
	text:        text.Frame,
	paint:       style.Frame,
	images:      ^backend.Generation,
	fonts:       ^fonts.Generation,
	controls:    controls.Frame,
	layers:      layers.Frame,
	scroll:      scroll.Frame,
}
Resource_Source :: struct {
	fallback:                 []u8,
	assets, alternate_assets: string,
}
Runtime_Page :: model.Page
Runtime :: struct {
	qualification:                               Qualification_Samples,
	tools_state:                                 Tools_Runtime,
	composition_route:                           Composition_Route,
	atlas_before_commit:                         proc(_: rawptr),
	atlas_test_user:                             rawptr,
	content:                                     union {
		^Lab_Inventory_Runtime,
		^Lab_Menu_Runtime,
		^Accessibility_Page_Runtime,
		^Performance_Page_Runtime,
		^Transition_Page_Runtime,
		^Custom_Page_Runtime,
		Rich_Page_Runtime,
		^Name_Page_Runtime,
		^Collection_Page_Runtime,
		^Hold_Page_Runtime,
		^Gesture_Page_Runtime,
	},
	sources:                                     Resource_Source,
	atlas_loaded, atlas_alternate, force_reload: bool,
	atlas_reload:                                u64,
	model:                                       ^model.Model,
	page:                                        Runtime_Page,
	publication:                                 base.Publication,
	interaction:                                 interaction.Context,
	live:                                        Reader,
	images:                                      ^backend.Generation,
	fonts:                                       ^fonts.Generation,
	allocator:                                   mem.Allocator,
	renderer:                                    ^sdl.Renderer,
	drawable:                                    base.Extent,
	last_sequence:                               u64,
	controls:                                    controls.State,
	select_open:                                 bool,
	layers:                                      layers.State,
	scroll:                                      scroll.State,
	adapter:                                     controls_sdl.Adapter,
	error:                                       Fault,
	diagnostic:                                  base.Error,
	fault:                                       Fault,
	ledger:                                      ^backend.Resource_Ledger,
}
Fault :: enum {
	None,
	Entry,
	Prepare,
	Resource,
	Copy,
	Publish,
	Render,
	Readback,
	Present,
	Text_Lifecycle,
}
init :: proc(
	r: ^Runtime,
	renderer: ^sdl.Renderer,
	data: []u8,
	m: ^model.Model,
	a: mem.Allocator,
	ledger: ^backend.Resource_Ledger = nil,
	sources: Resource_Source = {},
) -> bool {
	complete := false; defer {if !complete {destroy(r)}}
	r.model, r.allocator, r.renderer, r.ledger = m, a, renderer, ledger
	r.page = m.page
	if m.page == .Lab_Inventory {
		v, ae := new(Lab_Inventory_Runtime, a); if ae != nil {return false}; r.content = v
		v.gesture = gestures.create(a)
		for &state in v.states {state = collections.create(a)}
	}
	if lab_menu(m.page) {
		v, ae := new(Lab_Menu_Runtime, a); if ae != nil {return false}; r.content = v
		v.editing.state = editor.create(a); v.editing.input = editor_sdl.create(a)
		v.settings = m.page == .Lab_Settings
		if v.settings {m.lab_submenu = true}
	}
	r.sources = sources
	p, e := base.create(a); if e != .None {return false}; r.publication = p
	r.interaction = interaction.create(a, &r.publication)
	if m.page == .Accessibility {
		v, ae := new(
			Accessibility_Page_Runtime,
			a,
		); if ae != nil {return false}; r.content = v; v.hold.state = hold.create(a)
		v.visual.state = transitions.create(a); v.visual.presence_timing = true
		v.extra_editor, v.extra_gestures = editor.create(a), gestures.create(a)
		generation, e := painter.create_generation(
			renderer,
			"assessment-background",
			[]painter.Painter{{"circle", "1", circle_draw}},
			a,
		); if e.code != .None {return false}; v.painters = generation
	}
	if m.page == .Diagnostics_Performance {
		v, ae := new(Performance_Page_Runtime, a); if ae != nil {return false}; r.content = v
		v.editing.state = editor.create(a); v.editing.input = editor_sdl.create(a)
		v.collection.state = collections.create(a)
		v.collection.items, ae = make(
			[]collections.Collection_Item,
			10000,
			a,
		); if ae != nil {return false}
	}
	if m.page == .Transitions {
		v, ae := new(Transition_Page_Runtime, a); if ae != nil {return false}
		v.state = transitions.create(
			a,
		); v.hold.state = hold.create(a); v.presence_timing = true; r.content = v
	}
	if m.page == .Custom {
		c, ae := new(Custom_Page_Runtime, a); if ae != nil {return false}; r.content = c
		g, e := painter.create_generation(
			renderer,
			"custom-1",
			[]painter.Painter{{"circle", "1", circle_draw}},
			a,
		)
		if e.code != .None {return false}; c.painters = g
	}
	if m.page == .Gestures {
		g, ae := new(Gesture_Page_Runtime, a); if ae != nil {return false}
		g.state = gestures.create(
			a,
		); g.editing.state = editor.create(a); g.editing.input = editor_sdl.create(a)
		r.content = g; r.scroll = scroll.create(a)
	}
	if m.page == .Hud || m.page == .Layers || m.page == .Lab_Hud {
		h, ae := new(Hold_Page_Runtime, a); if ae != nil {return false}
		h.state = hold.create(a); h.cancel_allowed = true; r.content = h
	}
	if m.page == .Collections {
		n, ae := new(Collection_Page_Runtime, a); if ae != nil {return false}
		n.state = collections.create(a); r.content = n
		n.items, ae = make([]collections.Collection_Item, 10000, a); if ae != nil {return false}
	}
	if m.page == .Text_Input {
		n, ae := new(Name_Page_Runtime, a); if ae != nil {return false}
		n.state = editor.create(a); n.input = editor_sdl.create(a); r.content = n
	}
	if uses_controls(
		m.page,
	) {r.controls = controls.create(); r.layers = layers.create(a); r.scroll = scroll.create(a); r.adapter = controls_sdl.create(a)}
	if m.page == .Scroll_Table {r.scroll = scroll.create(a)}
	pixels: [12 * 12 * 4]u8
	for y in 0 ..< 12 {for x in 0 ..< 12 {i := (y * 12 + x) * 4; pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3] = u8(x * 20), u8(y * 20), 100, 255}}
	imgs: []backend.RGBA_Image
	if m.page == .Styling {imgs = []backend.RGBA_Image{{"icon", 12, 12, pixels[:]}}}
	images, ie := backend.create_generation(renderer, "images-1", imgs, a, ledger)
	if ie.code != .None {return false}; r.images = images
	sources := [1]fonts.Font_Source{{"own", 14, data}}
	f, fe := fonts.create_generation(renderer, "font-1", sources[:], m.scale, a, ledger)
	if fe.code != .None {return false}; r.fonts = f
	if m.page == .Rich_Text {
		q, ae := new(Rich_Combined_Runtime, a); if ae != nil {return false}
		q.visual.state = transitions.create(a)
		r.content = Rich_Page_Runtime {
			combined = q,
		}
		painters, pe := painter.create_generation(
			renderer,
			"rich-custom",
			[]painter.Painter{{"circle", "1", circle_draw}},
			a,
		)
		if pe.code != .None {return false}; q.painters = painters
		g, ok := new_rich_generation(
			r,
			data,
			m.scale,
		); if !ok {return false}; r.content = Rich_Page_Runtime{g, q}
		if !backend.retain_generation(
			g.images,
		) {return false}; backend.release_generation(&r.images); r.images = g.images
	}
	complete = true; return true
}
destroy_reader :: proc(reader: ^Reader) {
	when TOOLS {release_tools_generation(&reader.tools)}
	if v, ok := reader.content.(Lab_Inventory_Reader); ok {
		gestures.destroy_frame(&v.gesture)
		for &frame in v.frames {collections.destroy_frame(&frame)}; reader.content = nil
	}
	if v, selected := reader.content.(Accessibility_Page_Reader);
	   selected {release_c08(&v.c08); v.c08 = nil; reader.content = v}
	if v, selected := reader.content.(Accessibility_Page_Reader);
	   selected {transitions.destroy_frame(&v.visual); release_assessment(&v.assessment); hold.destroy_frame(&v.hold); custom.destroy_frame(&v.custom); painter.release_generation(&v.painters); reader.content = nil}
	if v, selected := reader.content.(Performance_Page_Reader);
	   selected {editor.destroy_frame(&v.editing.frame); collections.destroy_frame(&v.collection.frame); reader.content = nil}
	if v, ok := reader.content.(Transition_Page_Reader);
	   ok {transitions.destroy_frame(&v.frame); hold.destroy_frame(&v.hold); reader.content = nil}
	if content, ok := reader.content.(Custom_Page_Reader);
	   ok {custom.destroy_frame(&content.frame); painter.release_generation(&content.painters); reader.content = nil}
	if content, ok := reader.content.(Gesture_Page_Reader);
	   ok {editor.destroy_frame(&content.editing.frame); gestures.destroy_frame(&content.frame); reader.content = nil}
	if content, ok := reader.content.(Hold_Page_Reader);
	   ok {hold.destroy_frame(&content.frame); reader.content = nil}
	if content, ok := reader.content.(Collection_Page_Reader);
	   ok {collections.destroy_frame(&content.frame); reader.content = nil}
	if content, ok := reader.content.(Name_Page_Reader);
	   ok {editor.destroy_frame(&content.frame); reader.content = nil}
	if content, ok := reader.content.(Rich_Page_Reader);
	   ok {reader.content = nil; rich.destroy_frame(&content.frame); rich_fonts.release_generation(&content.fonts); transitions.destroy_frame(&content.visual); custom.destroy_frame(&content.custom); painter.release_generation(&content.painters)}
	layout.destroy_frame(&reader.geometry); interaction.destroy_frame(&reader.interaction)
	text.destroy_frame(&reader.text); style.destroy_frame(&reader.paint)
	controls.destroy_frame(&reader.controls); layers.destroy_frame(&reader.layers)
	scroll.destroy_frame(&reader.scroll)
	backend.release_generation(
		&reader.images,
	); fonts.release_generation(&reader.fonts); reader^ = {}
}
block :: proc(r: ^Runtime) {
	if v, ok := r.content.(^Lab_Menu_Runtime); ok {v.departure_press = ""}
	if v, ok := r.content.(^Lab_Inventory_Runtime); ok {
		gestures.block(&v.gesture, &r.publication); v.input.clock.has_base = false
		v.input.pending, v.input.pending_point = nil, nil
	}
	if v, ok := active_transition(r);
	   ok {transitions.block(&v.state, &r.publication); transitions.reset_transition_clock(&v.clock); v.step = {}}
	if g, ok := r.content.(^Gesture_Page_Runtime); ok {
		gestures.block(
			&g.state,
			&r.publication,
		); g.input.clock.has_base = false; g.input.pending, g.input.pending_point = nil, nil
	}
	if h, ok := active_hold(r); ok {hold_sdl.block(&h.input, &r.interaction)}
	controls_sdl.block(&r.adapter, &r.interaction)
	if n, ok := active_name(r); ok {editor_sdl.cancel_capture(&n.input); n.has_clock = false}
}
current :: proc(r: ^Runtime) -> bool {
	stamp := reader_stamp(&r.live)
	if v, selected := r.content.(^Lab_Inventory_Runtime); selected {
		if v.model == nil ||
		   v.gesture.frame.stamp != stamp ||
		   v.gesture.frame.model_revision != v.model.revision {return false}
		for &state in v.states {
			if state.frame.stamp != stamp ||
			   !state.frame.bound ||
			   len(state.frame.collections) != 1 ||
			   state.frame.collections[0].description.data_revision !=
				   v.model.revision {return false}
		}
	}
	if v, selected := active_transition(r); selected && v.state.frame.stamp != stamp {return false}
	if h, selected := active_hold(r); selected && h.state.frame.stamp != stamp {return false}
	if !selected_reader_matches(&r.live) {return false}
	if r.model == nil ||
	   r.page != r.model.page ||
	   !base.is_current(&r.publication, stamp) ||
	   stamp.model_revision != r.model.revision ||
	   r.live.geometry.stamp != stamp ||
	   r.live.interaction.stamp != stamp ||
	   r.interaction.frame.stamp != stamp ||
	   r.live.paint.stamp != stamp ||
	   r.live.geometry.drawable != r.drawable ||
	   r.live.geometry.ui_scale != r.model.scale {return false}
	if uses_controls(r.model.page) &&
	   (r.controls.frame.stamp != stamp ||
			   r.live.controls.stamp != stamp ||
			   r.layers.frame.stamp != stamp ||
			   r.live.layers.stamp != stamp) {return false}
	if (r.model.page == .Profiles ||
		   r.model.page == .Scroll_Table ||
		   r.model.page == .Layers ||
		   r.model.page == .Gestures) &&
	   (r.scroll.frame.stamp != stamp || r.live.scroll.stamp != stamp) {return false}
	if r.model.page == .Rich_Text {
		content, ok := r.live.content.(Rich_Page_Reader); if !ok {return false}
		return(
			rich_fonts.matches(content.fonts, &content.frame, &r.live.paint) &&
			r.images != nil &&
			backend.generation_matches(r.live.images, &r.live.paint) \
		)
	}
	if n, ok := active_name(r); ok {
		reader, selected := r.live.content.(Name_Page_Reader)
		if p, combined := r.live.content.(Performance_Page_Reader);
		   combined {reader, selected = p.editing, true}
		if g, combined := r.live.content.(Gesture_Page_Reader);
		   combined {reader, selected = g.editing, true}
		if !selected ||
		   reader.frame.stamp != stamp ||
		   n.state.frame.stamp != stamp ||
		   !editor_sdl.matches(r.live.fonts, &reader.frame) {return false}
	}
	if n, ok := active_collection(r); ok {
		if n.model == nil ||
		   n.state.frame.stamp != stamp ||
		   !n.state.frame.bound ||
		   len(n.state.frame.collections) != 1 ||
		   n.state.frame.collections[0].description.data_revision !=
			   n.model.revision {return false}
	}
	if h, ok := r.content.(^Hold_Page_Runtime); ok {if h.state.frame.stamp != stamp {return false}}
	if g, ok := r.content.(^Gesture_Page_Runtime); ok {
		if g.model == nil ||
		   g.state.frame.stamp != stamp ||
		   g.editing.state.frame.stamp != stamp ||
		   g.state.frame.model_revision != g.model.revision {return false}
	}
	return(
		r.images != nil &&
		r.fonts != nil &&
		r.images.renderer == r.renderer &&
		r.fonts.renderer == r.renderer &&
		backend.generation_matches(r.live.images, &r.live.paint) &&
		fonts.matches(r.live.fonts, &r.live.text, &r.live.paint) \
	)
}
selected_reader_matches :: proc(reader: ^Reader) -> bool {
	stamp := reader.geometry.stamp
	if v, ok := reader.content.(Lab_Inventory_Reader); ok {
		if v.gesture.stamp != stamp {return false}
		for frame in v.frames {if frame.stamp != stamp || !frame.bound {return false}}; return true
	}
	if v, selected := reader.content.(Rich_Page_Reader);
	   selected {return v.visual.stamp == stamp && v.visual.bound && v.custom.stamp == stamp && painter.preflight(v.painters, &v.custom, &reader.paint).code == .None}
	if v, selected := reader.content.(Accessibility_Page_Reader);
	   selected {return v.c08 != nil && v.c08.rich.stamp == stamp && v.c08.editor.stamp == stamp && v.c08.gestures.stamp == stamp && rich_fonts.matches(v.c08.fonts, &v.c08.rich, &reader.paint) && editor_sdl.matches(reader.fonts, &v.c08.editor) && v.visual.stamp == stamp && v.hold.stamp == stamp && v.custom.stamp == stamp && v.assessment != nil && v.assessment.value.inspection.frame.stamp == stamp && painter.preflight(v.painters, &v.custom, &reader.paint).code == .None}
	if v, selected := reader.content.(Performance_Page_Reader);
	   selected {return v.editing.frame.stamp == stamp && editor_sdl.matches(reader.fonts, &v.editing.frame) && v.collection.frame.stamp == stamp && v.collection.frame.bound}
	if v, ok := reader.content.(Transition_Page_Reader);
	   ok {return v.frame.stamp == stamp && v.frame.bound}
	if c, ok := reader.content.(Custom_Page_Reader);
	   ok {return c.frame.stamp == stamp && painter.preflight(c.painters, &c.frame, &reader.paint).code == .None}
	if n, ok := reader.content.(Name_Page_Reader);
	   ok {return n.frame.stamp == stamp && editor_sdl.matches(reader.fonts, &n.frame)}
	if n, ok := reader.content.(Collection_Page_Reader);
	   ok {return n.frame.stamp == stamp && n.frame.bound}
	if n, ok := reader.content.(Hold_Page_Reader); ok {return n.frame.stamp == stamp}
	if n, ok := reader.content.(Gesture_Page_Reader);
	   ok {return n.frame.stamp == stamp && n.editing.frame.stamp == stamp && editor_sdl.matches(reader.fonts, &n.editing.frame)}
	return true
}
destroy :: proc(r: ^Runtime, measured: ^Phase_Sample = nil) {
	if v, ok := r.content.(^Lab_Inventory_Runtime); ok {
		clear_lab_pending(r, v); gesture_sdl.close(&v.input); gestures.destroy(&v.gesture)
		for &state in v.states {collections.destroy(&state)}; free(v, r.allocator); r.content = nil
	}
	if v, ok := r.content.(^Lab_Menu_Runtime); ok {
		assert(!v.editing.input.text_active)
		editor_sdl.cancel_capture(&v.editing.input); editor.destroy(&v.editing.state)
		free(v, r.allocator); r.content = nil
	}
	start := sample_begin(r)
	enabled := false
	if _, selected := r.content.(^Performance_Page_Runtime);
	   selected {enabled = !r.model.measurements_off}
	defer {if measured != nil {measured^ = destroy_sample_end(start, enabled)}}
	if v, selected := r.content.(^Accessibility_Page_Runtime);
	   selected {editor.destroy(&v.extra_editor); gestures.destroy(&v.extra_gestures); transitions.destroy(&v.visual.state); hold.destroy(&v.hold.state); custom.destroy(&v.custom); painter.release_generation(&v.painters); free(v, r.allocator); r.content = nil}
	if v, selected := r.content.(^Performance_Page_Runtime);
	   selected && v.diagnostic.has {delete(v.diagnostic.id, r.allocator)}
	if v, selected := r.content.(^Performance_Page_Runtime); selected {
		assert(
			!v.editing.input.text_active,
		); editor_sdl.cancel_capture(&v.editing.input); editor.destroy(&v.editing.state)
		collections.destroy(
			&v.collection.state,
		); delete(v.collection.items, r.allocator); free(v, r.allocator); r.content = nil
	}
	if v, ok := r.content.(^Transition_Page_Runtime);
	   ok {hold.destroy(&v.hold.state); transitions.destroy(&v.state); free(v, r.allocator); r.content = nil}
	if c, ok := r.content.(^Custom_Page_Runtime);
	   ok {custom.destroy(&c.state); painter.release_generation(&c.painters); free(c, r.allocator); r.content = nil}
	if g, ok := r.content.(^Gesture_Page_Runtime); ok {
		assert(!g.editing.input.text_active); editor_sdl.cancel_capture(&g.editing.input)
		gesture_sdl.close(
			&g.input,
		); gestures.destroy(&g.state); editor.destroy(&g.editing.state); free(g, r.allocator); r.content = nil
	}
	if h, ok := r.content.(^Hold_Page_Runtime);
	   ok {hold.destroy(&h.state); free(h, r.allocator); r.content = nil}
	if n, ok := r.content.(^Collection_Page_Runtime); ok {
		collections.destroy(
			&n.state,
		); delete(n.items, r.allocator); free(n, r.allocator); r.content = nil
	}
	if n, ok := r.content.(^Name_Page_Runtime); ok {
		assert(!n.input.text_active)
		editor_sdl.cancel_capture(
			&n.input,
		); editor.destroy(&n.state); free(n, r.allocator); r.content = nil
	}
	if content, ok := r.content.(Rich_Page_Runtime);
	   ok {r.content = nil; rich_fonts.release_generation(&content.fonts); if content.combined != nil {q := content.combined; transitions.destroy(&q.visual.state); custom.destroy(&q.custom); painter.release_generation(&q.painters); free(q, r.allocator)}}
	if r.interaction.publication != nil {block(r)}
	destroy_reader(&r.live); controls_sdl.destroy(&r.adapter); controls.destroy(&r.controls)
	scroll.destroy(&r.scroll); layers.destroy(&r.layers)
	fonts.release_generation(&r.fonts); backend.release_generation(&r.images)
	base.destroy_error(
		&r.diagnostic,
	); interaction.destroy(&r.interaction); base.destroy(&r.publication); r^ = {}
}
remember :: proc(r: ^Runtime, error: base.Error) {
	base.destroy_error(&r.diagnostic)
	r.diagnostic, _ = base.try_copy_error(error, r.allocator)
	fmt.eprintf(
		"showcase stage=%v family=%v code=%d id=%s\n",
		r.error,
		error.family,
		error.code,
		error.id,
	)
}
injected :: proc(r: ^Runtime, stage: Fault) -> bool {
	when TEST {if r.fault == stage {r.fault = .None; return true}}; return false
}
copy_reader :: proc(source: ^Reader, a: mem.Allocator) -> (Reader, bool) {
	next: Reader; complete := false; defer {if !complete {destroy_reader(&next)}}
	when TOOLS {if source.tools != nil {
			if source.tools.references == max(u64) {return {}, false}
			source.tools.references += 1; next.tools = source.tools
		}}
	ok: bool
	if v, selected := source.content.(Lab_Inventory_Reader); selected {
		copied: Lab_Inventory_Reader
		for &frame, index in copied.frames {
			frame, ok = collections.try_copy_frame(&v.frames[index], a)
			if !ok {for &prior in copied.frames {collections.destroy_frame(&prior)}; return {}, false}
		}
		next.content = copied
		copied.gesture, ok = gestures.try_copy_frame(&v.gesture, a); if !ok {return {}, false}
		next.content = copied
	}
	next.geometry, ok = layout.try_copy_frame(&source.geometry, a); if !ok {return {}, false}
	if v, selected := source.content.(Accessibility_Page_Reader); selected {
		if v.assessment == nil || v.assessment.references == max(u64) {return {}, false}
		h, hc := hold.try_copy_frame(&v.hold, a); if !hc {return {}, false}
		c, cc := custom.try_copy_frame(
			&v.custom,
			a,
		); if !cc {hold.destroy_frame(&h); return {}, false}
		if !painter.retain_generation(
			v.painters,
		) {hold.destroy_frame(&h); custom.destroy_frame(&c); return {}, false}
		v.assessment.references += 1; next.content = Accessibility_Page_Reader {
			assessment = v.assessment,
			hold       = h,
			custom     = c,
			painters   = v.painters,
		}
		visual, vc := transitions.try_copy_frame(&v.visual, a); if !vc {return {}, false}
		next.content = Accessibility_Page_Reader {
			visual     = visual,
			assessment = v.assessment,
			hold       = h,
			custom     = c,
			painters   = v.painters,
		}
		if v.c08 == nil || v.c08.references == max(u64) {return {}, false}
		v.c08.references += 1
		next.content = Accessibility_Page_Reader {
			c08        = v.c08,
			visual     = visual,
			assessment = v.assessment,
			hold       = h,
			custom     = c,
			painters   = v.painters,
		}
	}
	if v, selected := source.content.(Performance_Page_Reader); selected {
		e, ec := editor.try_copy_frame(&v.editing.frame, a); if !ec {return {}, false}
		c, cc := collections.try_copy_frame(
			&v.collection.frame,
			a,
		); if !cc {editor.destroy_frame(&e); return {}, false}
		next.content = Performance_Page_Reader{{e, v.editing.focused}, {c}}
	}
	if v, selected := source.content.(Transition_Page_Reader); selected {
		frame, copied := transitions.try_copy_frame(&v.frame, a); if !copied {return {}, false}
		h, hc := hold.try_copy_frame(
			&v.hold,
			a,
		); if !hc {transitions.destroy_frame(&frame); return {}, false}; next.content = Transition_Page_Reader{frame, h}
	}
	next.interaction, ok = interaction.try_copy_frame(
		&source.interaction,
		a,
	); if !ok {return {}, false}
	if content, selected := source.content.(Rich_Page_Reader); selected {
		frame, copied := rich.try_copy_frame(&content.frame, a); if !copied {return {}, false}
		if !rich_fonts.retain_generation(
			content.fonts,
		) {rich.destroy_frame(&frame); return {}, false}; next.content = Rich_Page_Reader {
			frame = frame,
			fonts = content.fonts,
		}
		visual, vc := transitions.try_copy_frame(&content.visual, a); if !vc {return {}, false}
		next.content = Rich_Page_Reader {
			frame  = frame,
			fonts  = content.fonts,
			visual = visual,
		}
		cc, copied_custom := custom.try_copy_frame(
			&content.custom,
			a,
		); if !copied_custom {return {}, false}
		next.content = Rich_Page_Reader {
			frame  = frame,
			fonts  = content.fonts,
			visual = visual,
			custom = cc,
		}
		if !painter.retain_generation(content.painters) {return {}, false}
		next.content = Rich_Page_Reader{frame, content.fonts, visual, cc, content.painters}
	} else {next.text, ok = text.try_copy_frame(&source.text, a); if !ok {return {}, false}}
	if content, selected := source.content.(Name_Page_Reader); selected {
		frame, copied := editor.try_copy_frame(&content.frame, a); if !copied {return {}, false}
		next.content = Name_Page_Reader{frame, content.focused}
	}
	if content, selected := source.content.(Custom_Page_Reader); selected {
		frame, copied := custom.try_copy_frame(&content.frame, a); if !copied {return {}, false}
		if !painter.retain_generation(
			content.painters,
		) {custom.destroy_frame(&frame); return {}, false}
		next.content = Custom_Page_Reader{frame, content.painters}
	}
	if content, selected := source.content.(Gesture_Page_Reader); selected {
		editing, copied := editor.try_copy_frame(
			&content.editing.frame,
			a,
		); if !copied {return {}, false}
		frame, copied_gesture := gestures.try_copy_frame(&content.frame, a)
		if !copied_gesture {editor.destroy_frame(&editing); return {}, false}
		next.content = Gesture_Page_Reader{{editing, content.editing.focused}, frame}
	}
	if content, selected := source.content.(Hold_Page_Reader); selected {
		frame, copied := hold.try_copy_frame(&content.frame, a); if !copied {return {}, false}
		next.content = Hold_Page_Reader{frame}
	}
	if content, selected := source.content.(Collection_Page_Reader); selected {
		frame, copied := collections.try_copy_frame(
			&content.frame,
			a,
		); if !copied {return {}, false}
		next.content = Collection_Page_Reader{frame}
	}
	next.paint, ok = style.try_copy_frame(&source.paint, a); if !ok {return {}, false}
	if source.controls.stamp.lifetime !=
	   nil {next.controls, ok = controls.try_copy_frame(&source.controls, a); if !ok {return {}, false}}
	if source.layers.stamp.lifetime !=
	   nil {next.layers, ok = layers.try_copy_frame(&source.layers, a); if !ok {return {}, false}}
	if source.scroll.stamp.lifetime !=
	   nil {next.scroll, ok = scroll.try_copy_frame(&source.scroll, a); if !ok {return {}, false}}
	if !backend.retain_generation(source.images) {return {}, false}; next.images = source.images
	if !fonts.retain_generation(source.fonts) {return {}, false}; next.fonts = source.fonts
	complete = true; return next, true
}
rebuild :: proc(r: ^Runtime) -> bool {
	when QUALIFICATION {r.qualification.phases = {}}
	prepare_start := sample_begin(r)
	transition_fresh := false
	if v, selected := active_transition(r); selected {transition_fresh = v.state.identity == nil}
	r.error = .Prepare
	stamp, be := base.begin_attempt(
		&r.publication,
		r.model.revision,
	); if be != .None {return false}
	complete := false; defer {if !complete {
			diagnostic_failure(r); block(r)
			// prepare may lazily establish an identity. A refused first publication
			// must not retain even this new owner beside the unchanged prior bundle.
			if transition_fresh {if v, selected := active_transition(r); selected {transitions.destroy(&v.state); v.state = transitions.create(r.allocator)}}
		}}
	if injected(r, .Prepare) {return false}
	font_candidate := r.fonts
	image_candidate := r.images
	if image_candidate == nil ||
	   !backend.retain_generation(image_candidate) {r.error = .Resource; return false}
	defer backend.release_generation(&image_candidate)
	loaded: loader.Loaded_Set
	defer loader.destroy_loaded_set(&loaded)
	atlas_changed := false
	if r.model.page == .Atlas &&
	   (!r.atlas_loaded ||
			   r.force_reload ||
			   r.atlas_reload != r.model.atlas.reload ||
			   r.atlas_alternate != r.model.atlas.alternate) {
		r.error = .Resource
		path := r.sources.assets; if r.model.atlas.alternate {path = r.sources.alternate_assets}
		if path ==
		   "" {fmt.eprintln("Atlas page requires explicit --assets / --alternate-assets"); return false}
		set, e := loader.load_set(path, r.allocator)
		if e.stage !=
		   "" {fmt.eprintf("atlas path=%s stage=%s field=%s\n", path, e.stage, e.field); return false}; loaded = set
		pages: [16]backend.Decoded_Atlas_Page
		for page, i in loaded.catalog.pages {d := loaded.decoded[i]; pages[i] = {page.id, i32(page.size[0]), i32(page.size[1]), d.pixels}}
		g, ge := backend.create_atlas_generation(
			r.renderer,
			loaded.catalog,
			pages[:len(loaded.catalog.pages)],
			r.allocator,
			r.ledger,
		)
		if ge.code !=
		   .None {return false}; backend.release_generation(&image_candidate); image_candidate = g; atlas_changed = true
	}
	if r.fonts == nil || r.images == nil {r.error = .Resource; return false}
	if r.fonts.scale != r.model.scale {
		source :=
			r.fonts.fonts[0]; sources := [1]fonts.Font_Source{{source.id, source.size, source.data}}
		f, e := fonts.create_generation(
			r.renderer,
			"font-1",
			sources[:],
			r.model.scale,
			r.allocator,
			r.ledger,
		)
		if e.code != .None {r.error = .Resource; return false}; font_candidate = f
	} else if !fonts.retain_generation(font_candidate) {r.error = .Resource; return false}
	defer fonts.release_generation(&font_candidate)
	rich_candidate: ^rich_fonts.Generation
	defer rich_fonts.release_generation(&rich_candidate)
	if r.model.page == .Rich_Text {
		old, ok := r.content.(Rich_Page_Runtime); if !ok {return false}
		if old.fonts.scale !=
		   r.model.scale {rich_candidate, ok = new_rich_generation(r, font_candidate.fonts[0].data, r.model.scale); if !ok {r.error = .Resource; return false}} else {if !rich_fonts.retain_generation(old.fonts) {return false}; rich_candidate = old.fonts}
		if !backend.retain_generation(
			rich_candidate.images,
		) {return false}; backend.release_generation(&image_candidate); image_candidate = rich_candidate.images
	}
	resources := style.Resource_Catalog {
		revision = image_candidate.revision,
	}
	owned_resources := false
	defer {if owned_resources {style.destroy_atlas_resources(&resources, r.allocator)}}
	if r.model.page == .Atlas {
		pages: [16]style.Atlas_Page_Metadata
		for p, i in image_candidate.atlas_pages {pages[i] = {p.id, {int(p.width), int(p.height)}}}
		ok: bool
		resources, ok = style.atlas_resources(
			{
				image_candidate.revision,
				pages[:len(image_candidate.atlas_pages)],
				image_candidate.atlas_regions,
			},
			r.allocator,
		)
		if !ok {r.error = .Resource; return false}; owned_resources = true
	} else if r.model.page ==
	   .Styling {resources.images = []style.Image_Metadata{{id = "icon", source = {12, 12}}}}
	if injected(r, .Resource) {r.error = .Resource; return false}
	r.error = .Prepare
	c := Page_Composition {
		select_open = r.select_open,
	}; defer destroy_composition(&c)
	if !compose_page(
		&c,
		r.model^,
		r.allocator,
		image_candidate.atlas_regions,
		fonts.metrics(font_candidate),
		r.drawable.w / r.model.scale,
	) {return false}
	if r.model.page == .Hud {compose_hud(r, &c)}
	if r.page == .Catalogue {compose_lab_catalogue(r, &c)}
	if r.page == .Lab_Hud {compose_lab_hud(r, &c)}
	if lab_menu(r.page) {compose_lab_menu(r, &c)}
	if r.model.page == .World && !sections.compose_world(&c, r.model^, r.drawable) {return false}
	if v, ok := r.content.(^Custom_Page_Runtime);
	   ok {if !sections.compose_custom(&c, r.model^, v.popup, v.tooltip, r.allocator) {return false}}
	if r.model.page == .Layers && !compose_layer_page(r, &c) {return false}
	if r.model.page == .Gestures && !compose_gesture_page(r, &c) {return false}
	compose_name_status(r, &c)
	lab_inventory_candidates: Lab_Inventory_Candidates
	defer destroy_lab_inventory_candidates(r, &lab_inventory_candidates)
	if r.page == .Lab_Inventory &&
	   !compose_lab_inventory(r, &c, stamp, &lab_inventory_candidates) {return false}
	collection_candidate: collections.Candidate; defer collections.destroy_candidate(&collection_candidate)
	materialized: []layout.Node; defer collections.destroy_nodes(materialized, r.allocator)
	if _, selected := active_collection(r); selected {
		ok: bool
		collection_candidate, materialized, ok = compose_collection(r, &c, stamp)
		if !ok {return false}
	}
	compose_performance_status(r, &c)
	compose_accessibility_status(r, &c)
	if r.model.page == .Profiles {
		for &n in c.nodes[:c.n] {
			if n.id ==
			   c.profiles.items[7].control.node_id {n.visible = r.model.profiles.dialog == .None && (r.interaction.focus_id == "profiles/intensity" || r.interaction.hover_id == "profiles/intensity")}
		}
	}
	mode := layout.Scale_Mode.Normal; if r.model.pixel_perfect {mode = .Pixel_Perfect}
	options := layout.Layout_Options {
		drawable   = r.drawable,
		ui_scale   = r.model.scale,
		scale_mode = mode,
	}
	if r.model.page == .Layout &&
	   r.model.layout_safe_area {options.safe_area = base.Rect{12, 18, max(0, r.drawable.w - 24), max(0, r.drawable.h - 36)}}
	tc: text.Candidate; rc: rich.Candidate
	defer text.destroy_candidate(&tc); defer rich.destroy_candidate(&rc)
	transition_candidate: transitions.Candidate; defer transitions.destroy_candidate(&transition_candidate)
	transition_nodes: []layout.Node; defer transitions.destroy_nodes(transition_nodes, r.allocator)
	page_nodes := c.nodes[:c.n]
	if _, selected := active_transition(r); selected {
		ok: bool; transition_candidate, ok = prepare_transition(r, stamp); if !ok {return false}
		e: transitions.Error; transition_nodes, e = transitions.project_nodes(&transition_candidate, page_nodes, r.allocator); if e.code != .None {return false}; page_nodes = transition_nodes
	}
	geometry := &tc.geometry
	if r.model.page == .Rich_Text {
		ds: [98]rich.Description
		for t, i in c.texts[:c.nt] {ds[i] = {
				id = t.id,
				source = t.text,
				base_style = {font_id = "own", size = 14, color = {240, 240, 240, 255}},
				options = t.options,
			}}
		for d, i in c.content.rich[:c.content.nr] {ds[c.nt + i] = d}
		e: rich.Rich_Error
		rc, e = rich.prepare(
			page_nodes,
			options,
			ds[:c.nt + c.content.nr],
			rich_fonts.rich_metrics(rich_candidate),
			r.allocator,
			stamp,
		)
		if e.code !=
		   .None {fmt.eprintf("showcase family=Rich code=%v id=%s source=%v reason=%s\n", e.code, e.id, e.source_range, e.reason); return false}; geometry = &rc.geometry
	} else {
		e: text.Text_Update_Result
		tc, e = text.prepare(
			c.texts[:c.nt],
			page_nodes,
			options,
			performance_metrics(r, fonts.metrics(font_candidate)),
			r.allocator,
			stamp,
		)
		if e.code != .None {remember(r, text.describe_error(e)); return false}
	}
	for d in geometry.diagnostics {
		if r.page == .Lab_Inventory &&
		   d.kind == .Container_Overflow &&
		   d.required.w <= d.available.w &&
		   d.required.h > d.available.h {
			expected := false
			for id in LAB_VIEWPORTS {expected ||= d.id == id}; for id in LAB_CONTENTS {expected ||= d.id == id}
			if expected {continue}
		}
		if r.page == .Accessibility &&
		   d.kind == .Content_Overflow &&
		   d.required.h <= d.available.h &&
		   (d.id == "accessibility/status" ||
				   d.id == "accessibility/bad-description" ||
				   d.id == "accessibility/unknown-description" ||
				   d.id == "accessibility/explanation") {continue}
		if r.page == .Accessibility &&
		   (d.id == "accessibility/c08-scroll" || d.id == "accessibility/c08-content") &&
		   d.kind == .Container_Overflow &&
		   d.required.h > d.available.h &&
		   d.required.w <= d.available.w {continue}
		if r.page == .Accessibility &&
		   (d.id == "accessibility/target-clip" || d.id == "accessibility/clipped-target") &&
		   d.kind == .Container_Overflow &&
		   d.required.w == 40 &&
		   d.available.w == 20 {continue}
		if r.page == .Diagnostics_Performance &&
		   d.id == "name/status" &&
		   d.kind == .Content_Overflow &&
		   d.required.h <= d.available.h {continue} 	// WordWrap's natural width; actual wrapped height fits.
		if r.page == .Diagnostics_Performance &&
		   d.id == "performance/status" &&
		   d.kind == .Content_Overflow &&
		   d.required.h <= d.available.h {continue}
		if r.model.page == .Gestures &&
		   d.kind == .Container_Overflow &&
		   d.required.h > d.available.h &&
		   d.required.w <= d.available.w {
			expected :=
				false; for id in GESTURE_VIEWPORTS {expected ||= d.id == id}; for id in GESTURE_CONTENTS {expected ||= d.id == id}; if expected {continue}
		}
		if r.model.page == .Layers &&
		   d.kind == .Container_Overflow &&
		   d.required.h > d.available.h &&
		   d.required.w <= d.available.w {
			expected :=
				false; for id in LAYER_VIEWPORTS {expected ||= d.id == id}; for id in LAYER_CONTENTS {expected ||= d.id == id}; if expected {continue}
		}
		if (r.model.page == .Collections || r.model.page == .Diagnostics_Performance) &&
		   (d.id == "collections/viewport" || d.id == "collections/content") &&
		   d.kind == .Container_Overflow &&
		   d.required.h > d.available.h &&
		   d.required.w <= d.available.w {continue}
		if r.model.page == .Scroll_Table &&
		   (d.id == "table/viewport" || d.id == "table/content") &&
		   d.kind == .Container_Overflow &&
		   d.required.h > d.available.h &&
		   d.required.w <= d.available.w {continue}
		if r.model.page == .Text &&
		   r.model.text.limit_fixture >= 2 &&
		   d.id == "text/probe" &&
		   d.kind == .Content_Overflow &&
		   d.required.w > d.available.w &&
		   d.available.w == 30 &&
		   d.required.h <= d.available.h {continue}
		if r.model.page == .Atlas &&
		   d.id == "atlas/body" &&
		   d.kind == .Container_Overflow &&
		   (r.drawable.w < 1280 * r.model.scale || r.drawable.h < 960 * r.model.scale) {continue}
		if r.model.page == .Rich_Text &&
		   d.kind == .Content_Overflow &&
		   (d.id == "rich/card" || d.id == "rich/ellipsis") &&
		   d.required.w > d.available.w &&
		   d.required.h <= d.available.h {continue} 	// Natural unwrapped X; actual display overflow stays in rich blocks.
		if d.id == "layout/clipped" && d.kind == .Container_Overflow {continue} 	// The only deliberate fixture diagnostic.
		if r.model.page == .Profiles &&
		   d.id == "profiles/body" &&
		   d.kind == .Container_Overflow &&
		   (r.drawable.w < 1280 * r.model.scale || r.drawable.h < 960 * r.model.scale) {continue}
		fmt.eprintf(
			"unexpected layout diagnostic %v %s required=%v available=%v\n",
			d.kind,
			d.id,
			d.required,
			d.available,
		)
		return false
	}
	collection_geometry: layout.Frame; defer layout.destroy_frame(&collection_geometry)
	lab_geometry: [2]layout.Frame; defer {for &frame in lab_geometry {layout.destroy_frame(&frame)}}
	if r.page == .Lab_Inventory {
		ds := [2]collections.Collection_Description {
			lab_inventory_candidates.values[0].frame.collections[0].description,
			lab_inventory_candidates.values[1].frame.collections[0].description,
		}
		if collections.validate_regions(geometry, ds[:]).code != .None {return false}
		for &candidate, index in lab_inventory_candidates.values {
			e: collections.Update_Error
			lab_geometry[index], e = collections.project_layout(&candidate, geometry, r.allocator)
			if e.code != .None {return false}; geometry = &lab_geometry[index]
		}
		for &b in tc.text.text_blocks {
			before, _ := layout.find(
				&tc.geometry,
				b.node_id,
			); after, _ := layout.find(geometry, b.node_id)
			dx, dy := after.content.x - before.content.x, after.content.y - before.content.y
			for &line, index in b.lines {
				line.logical_rect.x += dx; line.logical_rect.y += dy; line.baseline += dy
				line.displayed =
					index < b.visible_line_count &&
					after.visible &&
					after.content.w > 0 &&
					after.clip.w > 0 &&
					after.clip.h > 0
			}
		}
	}
	if _, selected := active_collection(r); selected {
		e: collections.Update_Error
		collection_geometry, e = collections.project_layout(&collection_candidate, geometry)
		if e.code !=
		   .None {fmt.eprintf("collections project code=%v id=%s\n", e.code, e.id); return false}; geometry = &collection_geometry
		for &b in tc.text.text_blocks {
			before, _ := layout.find(
				&tc.geometry,
				b.node_id,
			); after, _ := layout.find(geometry, b.node_id)
			dx, dy := after.content.x - before.content.x, after.content.y - before.content.y
			for &line, index in b.lines {
				line.logical_rect.x += dx; line.logical_rect.y += dy; line.baseline += dy
				line.displayed =
					index < b.visible_line_count &&
					after.visible &&
					after.content.w > 0 &&
					after.clip.w > 0 &&
					after.clip.h > 0
			}
		}
	}
	ic: interaction.Candidate; lc: layers.Candidate; cc: controls.Candidate
	sc: scroll.Candidate; defer scroll.destroy_candidate(&sc)
	defer interaction.destroy_candidate(
		&ic,
	); defer layers.destroy_candidate(&lc); defer controls.destroy_candidate(&cc)
	active := &ic
	plain_claims: [24]interaction.Capture_Claim; npc := 0
	if r.model.page == .Gestures {
		plain_claims[0], plain_claims[1] =
			{"name/field", "editor"}, {"name/value", "editor"}; npc = 2
		for d in c.gestures[:c.ngestures] {plain_claims[npc] = {d.node_id, "gestures"}; npc += 1}
	}
	if uses_controls(r.model.page) {
		le: layers.Error
		layer_claims: [96]interaction.Capture_Claim
		for v, i in c.holds[:c.nholds] {layer_claims[i] = {v.id, "hold"}}
		nclaims := c.nholds
		if r.page == .Lab_Inventory {
			for target in c.targets[:c.ni] {
				if _, _, valid := collections.decode_item_node_id(target.id);
				   valid {layer_claims[nclaims] = {target.id, "collections"}; nclaims += 1}
			}
			if r.model.lab_selected !=
			   "" {layer_claims[nclaims] = {"lab/drag-handle", "gestures"}; nclaims += 1}
		}
		if lab_menu(r.page) {
			layer_claims[nclaims] = {"name/field", "editor"}; nclaims += 1
			layer_claims[nclaims] = {"name/value", "editor"}; nclaims += 1
		}
		if r.page ==
		   .Accessibility {layer_claims[nclaims] = {"accessibility/c08-editor", "editor"}; nclaims += 1; layer_claims[nclaims] = {"accessibility/c08-value", "editor"}; nclaims += 1; layer_claims[nclaims] = {"accessibility/c08-gesture", "gestures"}; nclaims += 1}
		if r.model.page ==
		   .Custom {for id in CUSTOM_CIRCLES {layer_claims[nclaims] = {id, "custom"}; nclaims += 1}}
		lc, le = layers.prepare(
			&r.layers,
			&r.interaction,
			geometry,
			c.targets[:c.ni],
			layer_claims[:nclaims],
			{
				base_root_id = "root",
				popups = c.popups[:c.np],
				tooltips = c.tooltips[:c.ntool],
				modals = c.modals[:c.nm],
			},
			r.allocator,
		)
		if le.code != .None {remember(r, layers.describe_error(le)); return false}
		active = &lc.interaction
		if lab_menu(r.page) && c.nm == 0 {
			if _, found := interaction.find(active, r.interaction.focus_id); !found {
				lc.focus_id = interaction.retained_id(active, c.initial_focus)
			}
		}
		if r.model.page == .Profiles || r.model.page == .Layers || r.model.page == .Accessibility {
			e: scroll.Error
			descriptions := c.layer_scroll[:c.nscroll]
			if r.model.page == .Profiles {descriptions = c.profiles.items[0].scroll[:]}
			sc, e = scroll.prepare(
				&r.scroll,
				geometry,
				active,
				descriptions,
				r.allocator,
				lc.focus_id,
			)
			if e.code != .None {remember(r, scroll.describe_error(e)); return false}
			geometry = &sc.geometry
			if sc.has_focus {lc.focus_id = interaction.retained_id(active, sc.focus_id)}
			for &target in active.targets {n, found := layout.find(geometry, target.description.id); if !found {return false}; target.bounds, target.clip = n.bounds, n.paint_clip}
			for &b in tc.text.text_blocks {
				before, _ := layout.find(
					&tc.geometry,
					b.node_id,
				); after, _ := layout.find(geometry, b.node_id)
				dx, dy := after.content.x - before.content.x, after.content.y - before.content.y
				for &line, index in b.lines {
					line.logical_rect.x += dx; line.logical_rect.y += dy; line.baseline += dy
					line.displayed =
						index < b.visible_line_count &&
						after.visible &&
						after.content.w > 0 &&
						after.clip.w > 0 &&
						after.clip.h > 0
				}
			}
		}
		// layers.prepare falls back to its first paint target when no prior
		// focus exists. On cold publication the page, not shell paint order,
		// owns initial focus. Later publications retain layer trap/return focus.
		if r.interaction.frame.stamp.attempt == 0 {
			lc.focus_id = interaction.retained_id(active, c.initial_focus)
		}
		if n, ok := interaction.find(active, lc.focus_id);
		   !ok ||
		   n.availability !=
			   .Applied {lc.focus_id = interaction.retained_id(active, c.initial_focus)}
		ds := [9]controls.Description {
			c.recipes[0].control,
			c.recipes[1].control,
			c.recipes[2].control,
			{},
			{},
			{},
			{},
			{},
			{},
		}
		count := 3
		if r.page == .Lab_Hud {count = 0}
		if r.page == .Lab_Inventory {count = 0}
		if lab_menu(r.page) {count = 2}
		if r.model.page == .Accessibility {count = 1; ds[0] = c.recipes[0].control}
		if r.model.page == .Transitions {count = 1; ds[0] = c.recipes[0].control}
		if r.model.page == .Custom {count = 0}
		if r.model.page == .Layers {count = 1}
		if r.model.page ==
		   .Profiles {count = c.profiles.count; for recipe, i in c.profiles.items[:count] {ds[i] = recipe.control}}
		ce: controls.Error
		cc, ce = controls.prepare(active, lc.frame.layers, ds[:count], r.allocator, geometry)
		if ce.code != .None {remember(r, controls.describe_error(ce)); return false}
	} else {
		ie: interaction.Code
		claims := plain_claims[:npc]
		if r.model.page ==
		   .Rich_Text {claims = []interaction.Capture_Claim{{"rich/circle", "custom"}}}
		if r.model.page == .Hud {claims = []interaction.Capture_Claim{{"hud/restore", "hold"}}}
		if r.model.page == .Text_Input ||
		   r.model.page ==
			   .Diagnostics_Performance {claims = []interaction.Capture_Claim{{"name/field", "editor"}, {"name/value", "editor"}}}
		ic, ie = interaction.prepare(geometry, c.targets[:c.ni], claims, r.allocator)
		if ie != .Applied {remember(r, interaction.describe_error(ie, "")); return false}
	}
	if r.model.page == .Scroll_Table || r.model.page == .Gestures {
		e: scroll.Error
		descriptions := c.layer_scroll[:c.nscroll]
		if r.model.page ==
		   .Scroll_Table {descriptions = []scroll.Description{{"table/viewport", "table/content"}}}
		sc, e = scroll.prepare(
			&r.scroll,
			geometry,
			active,
			descriptions,
			r.allocator,
			r.interaction.focus_id,
		)
		if e.code != .None {remember(r, scroll.describe_error(e)); return false}
		geometry = &sc.geometry
		interaction.destroy_candidate(&ic)
		ie: interaction.Code
		ic, ie = interaction.prepare(geometry, c.targets[:c.ni], plain_claims[:npc], r.allocator)
		if ie != .Applied {return false}
		for &b in tc.text.text_blocks {
			before, _ := layout.find(
				&tc.geometry,
				b.node_id,
			); after, _ := layout.find(geometry, b.node_id)
			dx, dy := after.content.x - before.content.x, after.content.y - before.content.y
			for &line, index in b.lines {
				line.logical_rect.x += dx; line.logical_rect.y += dy; line.baseline += dy
				line.displayed =
					index < b.visible_line_count &&
					after.visible &&
					after.content.w > 0 &&
					after.clip.w > 0 &&
					after.clip.h > 0
			}
		}
	}
	focus := r.interaction.focus_id
	if r.page == .Lab_Inventory {
		for &candidate in lab_inventory_candidates.values {
			if e := collections.bind_candidate(&candidate, geometry, active);
			   e.code != .None {return false}
			if candidate.has_focus {lc.focus_id = interaction.retained_id(active, candidate.frame.collections[0].focus_node_id)}
		}
	}
	if _, selected := active_transition(r); selected {
		if transitions.bind_geometry(&transition_candidate, geometry, active, progress_ids = []string{"transitions/progress"}).code !=
			   .None ||
		   !transitions.sample_interaction(&transition_candidate.frame, active) {return false}
	}
	if _, selected := active_collection(r); selected {
		if e := collections.bind_candidate(&collection_candidate, geometry, active);
		   e.code !=
		   .None {vp, _ := layout.find(geometry, "collections/viewport"); fmt.eprintf("collections bind code=%v id=%s viewport=%v expected=%v\n", e.code, e.id, vp.clip, collection_candidate.frame.collections[0].viewport); return false}
		if collection_candidate.has_focus {focus = collection_candidate.frame.collections[0].focus_node_id}
	}
	if (r.model.page == .Scroll_Table || r.model.page == .Gestures) &&
	   sc.has_focus {focus = sc.focus_id}
	if n, ok := interaction.find(active, focus);
	   !ok || n.availability != .Applied {focus = c.initial_focus}
	if uses_controls(r.model.page) {focus = lc.focus_id}
	// The local ID must already borrow the NEXT interaction, not the Context
	// frame that interaction.commit destroys before the collection commit.
	focus = interaction.retained_id(active, focus)
	name_candidate: editor.Candidate; defer editor.destroy_candidate(&name_candidate)
	c08_editor: editor.Candidate; defer editor.destroy_candidate(&c08_editor)
	c08_gestures: gestures.Candidate; defer gestures.destroy_candidate(&c08_gestures)
	c08: ^C08_Reader; defer release_c08(&c08)
	custom_candidate: custom.Candidate; defer custom.destroy_frame(&custom_candidate)
	if r.page == .Rich_Text {
		if interaction.bind_activation_owner(active, "rich/circle", "custom") !=
		   .Applied {return false}
		e: custom.Error
		custom_candidate, e = custom.prepare(
			geometry,
			active,
			[]custom.Description {
				{
					node_id = "rich/circle",
					type_id = "circle",
					revision = "1",
					payload = []u8{1, 72},
					validate = circle_validate,
					measure = circle_measure,
					hit = circle_hit,
				},
			},
			r.allocator,
		)
		if e.code != .None ||
		   !custom.sample_candidate(
				   &custom_candidate,
				   transitions.geometry_view(&transition_candidate.frame),
			   ) {return false}
	}
	if _, selected := r.content.(^Accessibility_Page_Runtime); selected {
		e: custom.Error; custom_candidate, e = custom.prepare(geometry, active, []custom.Description{{node_id = "accessibility/unknown", type_id = "circle", revision = "1", payload = []u8{1, 72}, validate = circle_validate, measure = circle_measure}}, r.allocator); if e.code != .None {return false}
	}
	if v, selected := r.content.(^Accessibility_Page_Runtime); selected {
		ee: editor.Error
		c08_editor, ee = editor.prepare(
			&v.extra_editor,
			geometry,
			active,
			&tc.text,
			[]editor.Description {
				{
					id = "c08-name",
					node_id = "accessibility/c08-editor",
					text_node_id = "accessibility/c08-value",
					label = "Assessment-only name",
					value = "Имя",
					revision = 1,
				},
			},
			fonts.metrics(font_candidate),
			r.allocator,
		)
		if ee.code != .None {return false}
		ge: gestures.Error
		c08_gestures, ge = gestures.prepare(
			&v.extra_gestures,
			geometry,
			active,
			&sc.frame,
			[]gestures.Description {
				{
					id = "c08-drag",
					node_id = "accessibility/c08-gesture",
					kind = .Drag_Source,
					payload_id = "assessment",
					payload_type = "card",
				},
			},
			r.model.revision,
			r.allocator,
		)
		if ge.code != .None {return false}
		ok: bool; c08, ok = prepare_c08_reader(r, geometry, font_candidate, &c08_editor, &c08_gestures); if !ok {return false}
	}
	if _, selected := r.content.(^Custom_Page_Runtime); selected {
		for id in CUSTOM_CIRCLES {if interaction.bind_activation_owner(active, id, "custom") != .Applied {return false}}
		descriptions: [2]custom.Description
		for id, i in CUSTOM_CIRCLES {descriptions[i] = {
				node_id         = id,
				type_id         = "circle",
				revision        = "1",
				semantic_name   = "Circle",
				hit_description = "strict circle",
				payload         = []u8{1, 72},
				validate        = circle_validate,
				measure         = circle_measure,
				hit             = circle_hit,
			}}
		e: custom.Error; custom_candidate, e = custom.prepare(geometry, active, descriptions[:], r.allocator)
		if e.code != .None {return false}
	}
	if n, ok := active_name(r); ok {
		values := name_values(r)
		e: editor.Error
		name_candidate, e = editor.prepare(
			&n.state,
			geometry,
			active,
			&tc.text,
			[]editor.Description {
				{
					id = "name",
					node_id = "name/field",
					text_node_id = "name/value",
					label = "Name",
					value = values.draft,
					revision = values.value_revision,
					resolution = n.resolution,
					max_graphemes = 64,
				},
			},
			performance_metrics(r, fonts.metrics(font_candidate)),
			r.allocator,
			scope_id = layers.active_scope(lc.frame.layers),
		)
		if e.code !=
		   .None {fmt.eprintf("showcase family=Editor code=%v id=%s rejection=%v\n", e.code, e.id, e.rejection); return false}
	}
	hold_candidate: hold.Candidate; defer hold.destroy_candidate(&hold_candidate)
	gesture_candidate: gestures.Candidate; defer gestures.destroy_candidate(&gesture_candidate)
	if v, ok := r.content.(^Lab_Inventory_Runtime); ok {
		e: gestures.Error
		gesture_candidate, e = gestures.prepare(
			&v.gesture,
			geometry,
			active,
			nil,
			c.gestures[:c.ngestures],
			v.model.revision,
			r.allocator,
			scope_id = layers.active_scope(lc.frame.layers),
		)
		if e.code !=
		   .None {fmt.eprintf("Lab gestures prepare=%v id=%s\n", e.code, e.id); return false}
	}
	if g, ok := r.content.(^Gesture_Page_Runtime); ok {
		e: gestures.Error
		gesture_candidate, e = gestures.prepare(
			&g.state,
			geometry,
			active,
			&sc.frame,
			c.gestures[:c.ngestures],
			g.model.revision,
			r.allocator,
		)
		if e.code != .None {fmt.eprintf("gesture prepare=%v id=%s\n", e.code, e.id); return false}
	}
	if h, ok := active_hold(r); ok {
		e: hold.Error
		progress := []hold.Progress_Description {
			{"hud/hp-bar", f64(r.model.hud_hp), 100},
			{"hud/hold-bar", f64(h.state.live.elapsed_ms), 1000},
		}
		holds := []hold.Description{{"hud/restore", 1000}}
		if r.model.page == .Layers {progress = nil; holds = c.holds[:c.nholds]}
		if r.page == .Lab_Hud {
			progress[0].value = f64(r.model.lab_hp)
			holds = c.holds[:c.nholds]
		}
		if r.model.page == .Accessibility {progress = nil; holds = c.holds[:c.nholds]}
		if r.model.page ==
		   .Transitions {progress = nil; holds = []hold.Description{{"transitions/hold", 1000}}}
		hold_candidate, e = hold.prepare(
			&h.state,
			&r.interaction,
			geometry,
			active,
			progress,
			holds,
			r.allocator,
		)
		if e.code != .None {remember(r, hold.describe_error(e)); return false}
	}
	ds: [256]style.Description
	plain := [4]style.Declaration {
		{.Background, style.Color{}},
		{.Border_Width, f64(0)},
		{.Font, style.Font_ID{"own"}},
		{.Font_Size, f64(14)},
	}
	box := [6]style.Declaration {
		{.Background, style.Color{35, 66, 96, 255}},
		{.Border, style.Color{155, 185, 210, 255}},
		{.Focus_Color, style.Color{255, 218, 110, 255}},
		{.Focus_Width, f64(3)},
		{.Font, style.Font_ID{"own"}},
		{.Font_Size, f64(14)},
	}
	top := box; top[0] = {.Background, style.Color{93, 57, 40, 255}}
	for n, i in c.nodes[:c.n] {
		ds[i] = {
			id   = n.id,
			role = "plain",
		}; ds[i].appearance.local.states[.Normal] = plain[:]
		for target in c.targets[:c.ni] {if n.id == target.id {ds[i].role = target.role; ds[i].appearance.local.states[.Normal] = box[:]}}
		if n.parent == "layout/fixtures" ||
		   n.id == "layout/bottom" {ds[i].appearance.local.states[.Normal] = box[:]}
		if n.id == "layout/top" {ds[i].appearance.local.states[.Normal] = top[:]}
		for recipe in c.styles[:c.ns] {if recipe.id == n.id {ds[i] = recipe}}
		if n.id == focus {ds[i].states += {.Focused}}
		if n.id == r.interaction.pressed_id {ds[i].states += {.Pressed}}
		if n.id == r.interaction.hover_id {ds[i].states += {.Hovered}}
	}
	theme := style.Theme {
		revision = "showcase-1",
	}; if r.model.page == .Styling {theme = c.content.theme}
	paint, pe := style.prepare(geometry, ds[:c.n], theme, resources, r.allocator, mode)
	if pe.code !=
	   .None {remember(r, style.describe_error(pe)); return false}; defer style.destroy_frame(&paint)
	if _, selected := active_transition(r);
	   selected && !transitions.sample_style(&transition_candidate.frame, &paint) {return false}
	if _, selected := active_transition(r); selected {
		for &p in paint.presentation {if p.id == "transitions/progress" {
				p.area.w *= transitions.progress_value(&transition_candidate.frame, p.id, .25)
				p.computed[.Background].value = style.Color{65, 180, 120, 255}
			}}
	}
	r.error = .Publish
	prepared := text.validate_candidate(&r.publication, &tc)
	if v, ok := r.content.(^Custom_Page_Runtime);
	   ok {if !custom.validate_candidate(&r.publication, &custom_candidate) || painter.preflight(v.painters, &custom_candidate, &paint).code != .None {return false}}
	text_matches := fonts.matches(font_candidate, &tc.text, &paint)
	if r.model.page ==
	   .Rich_Text {prepared = rich.validate_candidate(&r.publication, &rc); text_matches = rich_fonts.matches(rich_candidate, &rc.frame, &paint)}
	if !prepared ||
	   !interaction.validate_candidate(&r.publication, active) ||
	   !style.validate_candidate(&r.publication, &paint) ||
	   image_candidate.renderer != r.renderer ||
	   font_candidate.renderer != r.renderer ||
	   !backend.generation_matches(image_candidate, &paint) ||
	   !text_matches {return false}
	if uses_controls(r.model.page) &&
	   (!layers.validate_candidate(&r.publication, &lc) ||
			   !controls.validate_candidate(&r.publication, &cc)) {return false}
	if (r.model.page == .Profiles ||
		   r.model.page == .Scroll_Table ||
		   r.model.page == .Layers ||
		   r.model.page == .Gestures ||
		   r.model.page == .Accessibility) &&
	   !scroll.validate_candidate(&r.publication, &r.scroll, &sc) {return false}
	if n, ok := active_name(r);
	   ok {if !editor.validate_candidate(&r.publication, &n.state, &name_candidate) {return false}}
	source := Reader {
		geometry    = geometry^,
		interaction = active^,
		text        = tc.text,
		paint       = paint,
		images      = image_candidate,
		fonts       = font_candidate,
		controls    = cc,
		layers      = lc.frame,
		scroll      = sc.frame,
	}
	assessment_candidate: ^Assessment_Generation; defer release_assessment(&assessment_candidate)
	if r.page == .Lab_Inventory {
		if !validate_lab_inventory(r, &lab_inventory_candidates) {return false}
		v, _ := r.content.(^Lab_Inventory_Runtime)
		if !gestures.validate_candidate(
			&r.publication,
			&v.gesture,
			&gesture_candidate,
		) {return false}
		source.content = Lab_Inventory_Reader {
			frames  = {
				lab_inventory_candidates.values[0].frame,
				lab_inventory_candidates.values[1].frame,
			},
			gesture = gesture_candidate.frame,
		}
	}
	if v, selected := r.content.(^Accessibility_Page_Runtime); selected {
		ae: mem.Allocator_Error; assessment_candidate, ae = new(Assessment_Generation, r.allocator); if ae != nil {return false}
		assessment_candidate.allocator, assessment_candidate.references = r.allocator, 1
		ok: bool; assessment_candidate.value, ok = capture_assessment(r, geometry, active, &paint, &tc.text, &custom_candidate, &hold_candidate.frame, &transition_candidate.frame, &lc.frame, c08, sc.frame.regions, focus); if !ok {return false}
		if !editor.validate_candidate(&r.publication, &v.extra_editor, &c08_editor) ||
		   !gestures.validate_candidate(&r.publication, &v.extra_gestures, &c08_gestures) ||
		   !rich_fonts.matches(c08.fonts, &c08.rich, &paint) {return false}
		if !transitions.validate_candidate(
			&r.publication,
			&v.visual.state,
			&transition_candidate,
		) {return false}
		if !hold.validate_candidate(&r.publication, &hold_candidate) ||
		   !custom.validate_candidate(&r.publication, &custom_candidate) ||
		   painter.preflight(v.painters, &custom_candidate, &paint).code != .None {return false}
		source.content = Accessibility_Page_Reader {
			c08        = c08,
			visual     = transition_candidate.frame,
			assessment = assessment_candidate,
			hold       = hold_candidate.frame,
			custom     = custom_candidate,
			painters   = v.painters,
		}
	}
	if v, selected := r.content.(^Transition_Page_Runtime); selected {
		if !transitions.validate_candidate(
			&r.publication,
			&v.state,
			&transition_candidate,
		) {return false}
		if !hold.validate_candidate(&r.publication, &hold_candidate) {return false}
		source.content = Transition_Page_Reader{transition_candidate.frame, hold_candidate.frame}
	}
	if v, selected := r.content.(Rich_Page_Runtime); selected {
		q := v.combined
		if !transitions.validate_candidate(
			   &r.publication,
			   &q.visual.state,
			   &transition_candidate,
		   ) ||
		   !custom.validate_candidate(&r.publication, &custom_candidate) ||
		   painter.preflight(q.painters, &custom_candidate, &paint).code != .None {return false}
		source.content = Rich_Page_Reader {
			rc.frame,
			rich_candidate,
			transition_candidate.frame,
			custom_candidate,
			q.painters,
		}
	}
	if v, ok := r.content.(^Custom_Page_Runtime);
	   ok {source.content = Custom_Page_Reader{custom_candidate, v.painters}}
	if g, ok := r.content.(^Gesture_Page_Runtime); ok {
		if !gestures.validate_candidate(
			&r.publication,
			&g.state,
			&gesture_candidate,
		) {return false}
		source.content = Gesture_Page_Reader {
			{name_candidate.frame, focus == "name/field"},
			gesture_candidate.frame,
		}
	}
	if _, ok := r.content.(^Hold_Page_Runtime); ok {
		if !hold.validate_candidate(&r.publication, &hold_candidate) {return false}
		source.content = Hold_Page_Reader{hold_candidate.frame}
	}
	if n, ok := r.content.(^Collection_Page_Runtime); ok {
		if !collections.validate_candidate(
			&r.publication,
			&n.state,
			&collection_candidate,
		) {return false}
		source.content = Collection_Page_Reader{collection_candidate.frame}
	}
	if r.model.page ==
	   .Text_Input {source.content = Name_Page_Reader{name_candidate.frame, focus == "name/field"}}
	if lab_menu(
		r.page,
	) {source.content = Name_Page_Reader{name_candidate.frame, focus == "name/field"}}
	if n, selected := r.content.(^Performance_Page_Runtime); selected {
		if !collections.validate_candidate(
			&r.publication,
			&n.collection.state,
			&collection_candidate,
		) {return false}
		source.content = Performance_Page_Reader {
			{name_candidate.frame, focus == "name/field"},
			{collection_candidate.frame},
		}
	}
	r.error = .Copy; if injected(r, .Copy) {return false}
	defer {when TOOLS {release_tools_generation(&source.tools)}}
	when TOOLS {if r.tools_state.enabled {
			ok: bool
			source.tools, ok = prepare_tools_generation(r, &source, &c, focus)
			if !ok {return false}
		}}
	sample_end(r, .Prepare, prepare_start)
	copy_start := sample_begin(r)
	reader, copied := copy_reader(
		&source,
		r.allocator,
	); if !copied {return false}; defer destroy_reader(&reader)
	sample_end(r, .Copy, copy_start)
	commit_start := sample_begin(r)
	r.error = .Publish; if injected(r, .Publish) {return false}
	if atlas_changed {
		when TEST {hook := r.atlas_before_commit; r.atlas_before_commit = nil
			if hook != nil {hook(r.atlas_test_user)}}
		if e := loader.recheck_set(&loaded);
		   e.stage !=
		   "" {r.error = .Resource; fmt.eprintf("atlas precommit stage=%s field=%s\n", e.stage, e.field); return false}
	}
	if r.model.revision != stamp.model_revision ||
	   base.enter_commit(&r.publication, stamp) != .None {return false}
	old, old_fonts := r.live, r.fonts
	old_images := r.images
	old_content := r.content
	if v, selected := r.content.(Rich_Page_Runtime);
	   selected {r.content = Rich_Page_Runtime{rich_candidate, v.combined}; rich_candidate = nil}
	r.images = image_candidate; image_candidate = nil
	r.live = reader; reader = {}; r.fonts = font_candidate; font_candidate = nil
	if uses_controls(
		r.model.page,
	) {layers.commit(&r.layers, &r.interaction, &lc); controls.commit(&r.controls, &cc)} else {interaction.commit(&r.interaction, &ic, c.initial_focus)}
	if (r.model.page == .Scroll_Table || r.model.page == .Gestures) &&
	   sc.has_focus {focus = interaction.retained_id(&r.interaction.frame, sc.focus_id); r.interaction.focus_id = focus}
	if r.model.page == .Profiles ||
	   r.model.page == .Scroll_Table ||
	   (r.model.page == .Layers ||
			   r.model.page == .Gestures ||
			   r.model.page == .Accessibility) {scroll.commit(&r.scroll, &sc)}
	if n, ok := active_name(r); ok {editor.commit(&n.state, &name_candidate)}
	if v, ok := r.content.(^Lab_Inventory_Runtime); ok {
		for &candidate, index in lab_inventory_candidates.values {collections.commit(&v.states[index], &candidate)}
		gestures.commit(&v.gesture, &gesture_candidate)
	}
	if n, ok := active_collection(r); ok {
		r.interaction.focus_id = interaction.retained_id(&r.interaction.frame, focus)
		collections.commit(&n.state, &collection_candidate)
	}
	if h, ok := active_hold(r); ok {hold.commit(&h.state, &hold_candidate)}
	if g, ok := r.content.(^Gesture_Page_Runtime);
	   ok {gestures.commit(&g.state, &gesture_candidate)}
	base.finish_commit(&r.publication, stamp)
	if v, selected := active_transition(r);
	   selected {transitions.commit(&v.state, &transition_candidate); v.step = {}}
	if v, ok := r.content.(^Custom_Page_Runtime); ok {custom.commit(&v.state, &custom_candidate)}
	if v, selected := r.content.(^Accessibility_Page_Runtime);
	   selected {custom.commit(&v.custom, &custom_candidate); editor.commit(&v.extra_editor, &c08_editor); gestures.commit(&v.extra_gestures, &c08_gestures)}
	if v, selected := r.content.(Rich_Page_Runtime);
	   selected {custom.commit(&v.combined.custom, &custom_candidate)}
	if r.model.page ==
	   .Atlas {r.atlas_loaded = true; r.atlas_alternate = r.model.atlas.alternate; r.atlas_reload = r.model.atlas.reload; r.force_reload = false}
	if uses_controls(
		r.model.page,
	) {controls_sdl.reconcile(&r.adapter, &r.controls, &r.interaction, &r.live.geometry, view = transition_geometry(r))}
	interaction.reconcile_registrations(&r.interaction)
	destroy_reader(&old); fonts.release_generation(&old_fonts)
	backend.release_generation(&old_images)
	if old, ok := old_content.(Rich_Page_Runtime); ok {rich_fonts.release_generation(&old.fonts)}
	if !register_composition(r) {return false}
	base.destroy_error(
		&r.diagnostic,
	); r.error = .None; complete = true; sample_end(r, .Commit, commit_start); return true
}

uses_controls :: proc(page: model.Page) -> bool {return(
		lab_menu(page) ||
		page == .Lab_Hud ||
		page == .Lab_Inventory ||
		page == .Controls ||
		page == .Profiles ||
		page == .Custom ||
		page == .Transitions ||
		page == .Accessibility ||
		page == .Layers \
	)}
