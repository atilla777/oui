package ui_style

import base "../ui_base"
import layout "../ui_layout"
import "core:testing"

@(test)
legacy_negative_style_fixtures_keep_addressed_diagnostics :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	nodes := [1]layout.Node {
		{
			id = "button",
			role = .Box,
			layout = layout.Layout{x = {mode = .Fixed, value = 4}, y = {mode = .Fixed, value = 4}},
			enabled = true,
			visible = true,
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	defer layout.destroy_frame(&g)
	if !testing.expect(t, ge.code == .None) {return}
	for expected in ([5]Diagnostic_Kind{.Missing_Image, .Missing_Style, .Missing_Token, .Invalid_Metadata, .Below_Slice_Minimum}) {
		descriptions := [1]Description{{id = "button", role = "button"}}
		decl := [1]Declaration{{.Image, Image_ID{"fixture"}}}
		images := [1]Image_Metadata{{id = "fixture", source = {16, 16}}}
		resources := Resource_Catalog {
			revision = "fixture",
			images   = images[:],
		}
		#partial switch expected {
		case .Missing_Image:
			resources.images = nil
		case .Missing_Style:
			descriptions[0].appearance.style_id = "missing-style"
		case .Missing_Token:
			decl[0] = {.Foreground, Token_Ref{"missing-token"}}
		case .Invalid_Metadata:
			images[0].source = {}
		case .Below_Slice_Minimum:
			images[0].nine_slice = Nine_Slice_Metadata {
				border        = {4, 4, 4, 4},
				texture_scale = 1,
			}
		}
		descriptions[0].appearance.local.states[.Normal] = decl[:]
		f, e := prepare(&g, descriptions[:], {}, resources, context.allocator)
		defer destroy_frame(&f)
		testing.expect(
			t,
			e.code == .None,
			"diagnostic fixture keeps an inspectable paint projection",
		)
		found := false
		for d in f.diagnostics {if d.kind == expected {found = true; testing.expect(t, d.id == "button" && d.reference != "")}}
		testing.expect(t, found, "the expected negative style diagnostic must not disappear")
	}
}

@(test)
owning_projection_focus_and_image_fallback :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	nodes := [1]layout.Node {
		{
			id = "button",
			role = .Box,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
			enabled = true,
			visible = true,
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	defer layout.destroy_frame(&g)
	testing.expect(t, ge.code == .None)
	decl := [1]Declaration{{.Image, Image_ID{"missing"}}}
	descriptions := [1]Description{{id = "button", role = "button", states = {.Focused}}}
	descriptions[0].appearance.local.states[.Normal] = decl[:]
	f, e := prepare(&g, descriptions[:], {}, {}, context.allocator)
	if !testing.expect(t, e.code == .None, "style must prepare owning paint projection") {return}
	defer destroy_frame(&f)
	decl[0] = {.Foreground, Token_Ref{"gone"}}
	token_frame, token_error := prepare(&g, descriptions[:], {}, {}, context.allocator)
	defer destroy_frame(&token_frame)
	for value in ([]Paint_Value{f64(2), Token_Ref{"alias"}, Image_Off{}}) {
		tokens := [1]Paint_Token{{"bad", value}}
		bad, error := prepare(&g, descriptions[:], {tokens = tokens[:]}, {}, context.allocator)
		testing.expect(
			t,
			error.code == .Invalid_Appearance && error.id == "bad",
			"unsupported token values must refuse",
		)
		destroy_frame(&bad)
	}
	testing.expect(
		t,
		token_error.code == .None &&
		len(token_frame.diagnostics) == 1 &&
		token_frame.diagnostics[0].kind == .Missing_Token &&
		token_frame.diagnostics[0].reference == "gone",
	)
	testing.expect(
		t,
		len(f.presentation) == 1 &&
		f.presentation[0].focus_indicator &&
		f.presentation[0].focus_width >= 1,
	)
	testing.expect(t, f.presentation[0].fallback != nil && len(f.diagnostics) == 1)
}
