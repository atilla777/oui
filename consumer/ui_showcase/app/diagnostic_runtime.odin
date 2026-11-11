package app

import "core:fmt"
import "core:strings"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import fonts "ui:ui_sdl_text"

Diagnostic_Observation :: struct {
	family, stage, id: string,
	code:              u32,
	model_revision:    u64,
	attempt:           u64,
	has, expected:     bool,
}
diagnostic_failure :: proc(r: ^Runtime) {
	p, selected := r.content.(^Performance_Page_Runtime)
	if !selected || r.error == .None {return}
	stage := "Prepare"
	switch r.error {
	case .Copy:
		stage = "Copy"
	case .Publish:
		stage = "Publish"
	case .Resource:
		stage = "Resource"
	case .Render:
		stage = "Render"
	case .Readback:
		stage = "Readback"
	case .Present:
		stage = "Present"
	case .Text_Lifecycle:
		stage = "Text_Lifecycle"
	case .Entry:
		stage = "Entry"
	case .None, .Prepare:
	}
	if p.diagnostic.has {delete(p.diagnostic.id, r.allocator)}
	// Static stage names and an empty ID need no allocation on a failing path.
	p.diagnostic = {
		family         = "Showcase",
		stage          = stage,
		code           = u32(r.error),
		has            = true,
		model_revision = r.model.revision,
		attempt        = r.publication.attempt,
	}
}
diagnostic_probe :: proc(r: ^Runtime, id: string) -> bool {
	p, selected := r.content.(^Performance_Page_Runtime); if !selected {return false}
	if !strings.has_prefix(id, "diagnostics/") {return false}
	if r.model.revision == max(u64) {return false}
	observation := Diagnostic_Observation {
		stage          = "Prepare",
		has            = true,
		expected       = true,
		model_revision = r.model.revision + 1,
	}
	borrowed := "diagnostics/fixture"
	if id == "diagnostics/resource" {
		bytes := [4]u8{0, 1, 2, 3}
		generation, e := fonts.create_generation(
			r.renderer,
			"invalid-font",
			[]fonts.Font_Source{{"fixture", 14, bytes[:]}},
			1,
			r.allocator,
			r.ledger,
		)
		defer fonts.release_generation(&generation)
		observation.family, observation.stage, observation.code = "Font", "Resource", u32(e.code)
	} else if id == "diagnostics/ownership" {
		target := r.live.interaction.targets[0].description
		candidate, code := interaction.prepare(
			&r.live.geometry,
			[]interaction.Target{target},
			[]interaction.Capture_Claim{{target.id, "editor"}, {target.id, "slider"}},
			r.allocator,
		)
		defer interaction.destroy_candidate(&candidate)
		observation.family, observation.code, borrowed = "Interaction", u32(code), target.id
	} else {
		nodes := [2]layout.Node {
			{
				id = "fixture",
				role = .Box,
				enabled = true,
				visible = true,
				layout = {x = {mode = .Fixed, value = 40}, y = {mode = .Fixed, value = 40}},
			},
			{id = "fixture", role = .Box, enabled = true, visible = true},
		}
		options := layout.Layout_Options {
			drawable = r.drawable,
			ui_scale = 1,
		}
		count := 1
		switch id {
		case "diagnostics/duplicate":
			count = 2
		case "diagnostics/invalid":
			nodes[0].layout = layout.Layout {
				x = {mode = .Fixed, value = -1},
			}
		case "diagnostics/unsupported":
			options.ui_scale = 1.5; options.scale_mode = .Pixel_Perfect
		case:
			return false
		}
		candidate, e := layout.prepare(
			nodes[:count],
			options,
			{},
			r.allocator,
			reader_stamp(&r.live),
		); defer layout.destroy_frame(&candidate)
		observation.family, observation.code = "Layout", u32(e.code)
		if e.id != "" {if e.id != "fixture" {return false}; borrowed = "fixture"}
	}
	if observation.code == 0 {return false}
	copy, ae := strings.clone(
		borrowed,
		r.allocator,
	); if ae != nil {return false}; observation.id = copy
	if p.diagnostic.has {delete(p.diagnostic.id, r.allocator)}
	p.diagnostic = observation; r.model.revision += 1; return true
}
diagnostic_message :: proc(r: ^Runtime, p: ^Performance_Page_Runtime) -> string {
	d := p.diagnostic
	state := "current-model"; if d.model_revision != r.model.revision {state = "historical"}
	if !d.expected && d.attempt != r.publication.attempt {state = "historical"}
	format := "expected=%t %s family=%s stage=%s code=%d id=%s; source destroyed; actions require current bundle; R retries without replay"
	if r.model.locale ==
	   .Russian {format = "expected=%t %s family=%s stage=%s code=%d id=%s; источник уничтожен; действия требуют актуального кадра; R без повтора"}
	return fmt.bprintf(p.buffer[:], format, d.expected, state, d.family, d.stage, d.code, d.id)
}
