package ui_foundation_test

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import style "ui:ui_style"
import text "ui:ui_text"

Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}
fault_allocator :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := cast(^Fault)data
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode == .Resize_Non_Zeroed) {
		f.requests += 1
		if f.requests == f.refuse {return nil, .Out_Of_Memory}
	}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
font :: proc(
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
) {return {f64(len(s)) * 5, {f64(len(s)) * 5, 10}}, .None}
validate :: proc(
	s, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Metric_Error,
	int,
) {return .None, 0}
Operation :: enum {
	Publication_Init,
	Error_Copy,
	Registration_Add,
	Layout_Prepare,
	Layout_Copy,
	Interaction_Prepare,
	Interaction_Copy,
	Text_Prepare,
	Text_Copy,
	Style_Prepare,
	Style_Copy,
}
Sources :: struct {
	publication: ^base.Publication,
	nodes:       [2]layout.Node,
	texts:       [1]text.Text_Node,
	targets:     [1]interaction.Target,
	styles:      [1]style.Description,
	options:     layout.Layout_Options,
	stamp:       base.Frame_Stamp,
	geometry:    layout.Frame,
	interaction: interaction.Frame,
	text:        text.Candidate,
	style:       style.Frame,
}
exercise :: proc(op: Operation, s: ^Sources, a: mem.Allocator) -> bool {
	switch op {
	case .Publication_Init:
		p, e := base.create(a); defer base.destroy(&p); return e == .None
	case .Error_Copy:
		e, ok := base.try_copy_error(
			{family = .Text, stage = .Prepare, code = 2, id = "button"},
			a,
		)
		defer base.destroy_error(&e)
		return ok
	case .Registration_Add:
		ctx := interaction.create(a, s.publication); defer interaction.destroy(&ctx)
		f, ok := interaction.try_copy_frame(
			&s.interaction,
			context.allocator,
		); if !ok {return false}; ctx.frame = f
		_, code := interaction.register_handler(&ctx, "button", handler)
		return code == .Applied
	case .Layout_Prepare:
		f, e := layout.prepare(s.nodes[:], s.options, {intrinsic = intrinsic}, a, s.stamp)
		defer layout.destroy_frame(&f)
		return e.code == .None
	case .Layout_Copy:
		f, ok := layout.try_copy_frame(&s.geometry, a); defer layout.destroy_frame(&f); return ok
	case .Interaction_Prepare:
		f, e := interaction.prepare(&s.geometry, s.targets[:], nil, a)
		defer interaction.destroy_frame(&f)
		return e == .Applied
	case .Interaction_Copy:
		f, ok := interaction.try_copy_frame(&s.interaction, a); defer interaction.destroy_frame(&f)
		return ok
	case .Text_Prepare:
		f, e := text.prepare(
			s.texts[:],
			s.nodes[:],
			s.options,
			{font, measure, validate, nil},
			a,
			s.stamp,
		)
		defer text.destroy_candidate(&f)
		return e.code == .None
	case .Text_Copy:
		f, ok := text.try_copy_frame(&s.text.text, a); defer text.destroy_frame(&f); return ok
	case .Style_Prepare:
		f, e := style.prepare(
			&s.geometry,
			s.styles[:],
			{revision = "theme"},
			{revision = "resources"},
			a,
		)
		defer style.destroy_frame(&f)
		return e.code == .None
	case .Style_Copy:
		f, ok := style.try_copy_frame(&s.style, a); defer style.destroy_frame(&f); return ok
	}
	return false
}
intrinsic :: proc(id: string, user: rawptr) -> (base.Extent, bool) {return {30, 10}, true}
handler :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {return(
		.Continue \
	)}
@(test)
every_owning_allocation_refusal_rolls_back :: proc(t: ^testing.T) {
	p, pe := base.create(context.allocator); defer base.destroy(&p)
	if !testing.expect(t, pe == .None) {return}
	s: Sources
	s.publication = &p
	s.stamp, _ = base.begin_attempt(&p, 1)
	s.options = {
		drawable = {100, 100},
		ui_scale = 1,
	}
	s.nodes = {
		{
			id = "root",
			role = .Column,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
			enabled = true,
			visible = true,
		},
		{
			id = "button",
			parent = "root",
			role = .Content,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Content}},
			enabled = true,
			visible = true,
		},
	}
	s.texts = {{"button", "abc def", {"fixture"}, 10, {wrap = .WordWrap}}}
	s.targets = {{"button", "button", true, true}}
	s.styles = {{id = "button", role = "button", states = {.Focused}}}
	s.geometry, _ = layout.prepare(
		s.nodes[:],
		s.options,
		{intrinsic = intrinsic},
		context.allocator,
		s.stamp,
	); defer layout.destroy_frame(&s.geometry)
	s.interaction, _ = interaction.prepare(
		&s.geometry,
		s.targets[:],
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&s.interaction)
	s.text, _ = text.prepare(
		s.texts[:],
		s.nodes[:],
		s.options,
		{font, measure, validate, nil},
		context.allocator,
		s.stamp,
	); defer text.destroy_candidate(&s.text)
	s.style, _ = style.prepare(
		&s.geometry,
		s.styles[:],
		{revision = "theme"},
		{revision = "resources"},
		context.allocator,
	); defer style.destroy_frame(&s.style)
	testing.expect(
		t,
		s.style.drawable == s.geometry.drawable && s.style.ui_scale == s.geometry.ui_scale,
		"style retains viewport/scale association",
	)
	testing.expect(
		t,
		s.interaction.drawable == s.geometry.drawable,
		"interaction retains viewport association",
	)
	testing.expect(
		t,
		s.text.text.drawable == s.text.geometry.drawable,
		"text retains viewport association",
	)
	testing.expect(
		t,
		layout.validate_candidate(&p, &s.geometry),
		"prepared layout candidate must validate",
	)
	testing.expect(
		t,
		interaction.validate_candidate(&p, &s.interaction),
		"prepared interaction candidate must validate",
	)
	testing.expect(
		t,
		text.validate_candidate(&p, &s.text),
		"prepared text candidate must validate",
	)
	testing.expect(
		t,
		style.validate_candidate(&p, &s.style),
		"prepared style candidate must validate",
	)
	claims := [2]interaction.Capture_Claim{{"button", "first"}, {"button", "second"}}
	conflict, conflict_code := interaction.prepare(
		&s.geometry,
		s.targets[:],
		claims[:],
		context.allocator,
	)
	testing.expect(t, conflict_code == .Conflict && conflict.stamp.lifetime == nil)
	interaction.destroy_candidate(&conflict)
	testing.expect(t, base.enter_commit(&p, s.stamp) == .None)
	base.finish_commit(&p, s.stamp)
	for op in Operation {
		live: mem.Tracking_Allocator
		mem.tracking_allocator_init(&live, context.allocator)
		live.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
		fault := Fault {
			backing = mem.tracking_allocator(&live),
		}
		a := mem.Allocator{fault_allocator, &fault}
		refs := p.lifetime.references
		if !testing.expect(
			t,
			exercise(op, &s, a),
			fmt.tprintf("successful operation required: %v", op),
		) {mem.tracking_allocator_destroy(&live); continue}
		requests := fault.requests
		fmt.printf(
			"foundation %v: requests=%d bytes=%d peak=%d live-after-destroy=%d\n",
			op,
			requests,
			live.total_memory_allocated,
			live.peak_memory_allocated,
			live.current_memory_allocated,
		)
		testing.expect(
			t,
			requests > 0 && len(live.allocation_map) == 0 && p.lifetime.references == refs,
		)
		for refusal in 1 ..= requests {
			fault.requests, fault.refuse = 0, refusal
			testing.expect(t, !exercise(op, &s, a), fmt.tprintf("%v refusal %d", op, refusal))
			testing.expect(
				t,
				len(live.allocation_map) == 0 &&
				len(live.bad_free_array) == 0 &&
				p.lifetime.references == refs,
				fmt.tprintf("rollback %v/%d", op, refusal),
			)
		}
		mem.tracking_allocator_destroy(&live)
	}
	other, _ := base.create(context.allocator); defer base.destroy(&other)
	testing.expect(
		t,
		!layout.validate_candidate(&other, &s.geometry) &&
		!interaction.validate_candidate(&other, &s.interaction) &&
		!text.validate_candidate(&other, &s.text) &&
		!style.validate_candidate(&other, &s.style),
	)
	_, next_error := base.begin_attempt(&p, 2)
	testing.expect(
		t,
		next_error == .None &&
		!layout.validate_candidate(&p, &s.geometry) &&
		!interaction.validate_candidate(&p, &s.interaction) &&
		!text.validate_candidate(&p, &s.text) &&
		!style.validate_candidate(&p, &s.style),
	)
	fmt.printf(
		"owner sizes common Publication=%d Lifetime=%d; layout Frame=%d Node=%d; interaction Context=%d Frame=%d; style Frame=%d; text Frame=%d\n",
		size_of(base.Publication),
		size_of(base.Lifetime),
		size_of(layout.Frame),
		size_of(layout.Node),
		size_of(interaction.Context),
		size_of(interaction.Frame),
		size_of(style.Frame),
		size_of(text.Frame),
	)
}
