package app

import sections "../sections"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"

LAYER_COUNTS := sections.LAYER_COUNTS
LAYER_HOLDS := sections.LAYER_HOLDS
LAYER_VIEWPORTS := sections.LAYER_VIEWPORTS
LAYER_CONTENTS := sections.LAYER_CONTENTS
LAYER_POPUPS := sections.LAYER_POPUPS
compose_layer_page :: proc(r: ^Runtime, c: ^Page_Composition) -> bool {
	h, _ := r.content.(^Hold_Page_Runtime)
	return sections.compose_layer_page(
		{r.model^, r.allocator},
		c,
		{h.depth, h.popup, h.tooltip, h.cancel_allowed, &h.counts},
	)
}
layer_change :: proc(r: ^Runtime, id: string) -> bool {
	h, ok := r.content.(^Hold_Page_Runtime); if !ok {return false}
	if r.model.revision == max(u64) || r.model.effects == max(u64) {return false}
	for target, i in LAYER_COUNTS {if id == target || id == LAYER_HOLDS[i] {
			if r.model.layer_counts[i] == max(u64) {return false}
			r.model.layer_counts[i] += 1; r.model.effects += 1; r.model.revision += 1; return true
		}}
	switch id {case "layers/open":
		h.depth = 1; h.popup, h.tooltip = false, false
	case "layers/open-b":
		h.depth = 2; h.popup, h.tooltip = false, false
	case "layers/close":
		h.depth = max(0, h.depth - 1); h.popup, h.tooltip = false, false
	case "layers/popup":
		h.popup = !h.popup
	case "layers/popup-close":
		h.popup = false
	case "layers/tooltip":
		h.tooltip = !h.tooltip
	case "layers/policy":
		h.cancel_allowed = !h.cancel_allowed
	case:
		return false}
	r.model.revision += 1; return true
}
layer_cancel :: proc(r: ^Runtime, action: interaction.Action) -> interaction.Code {
	h, _ := r.content.(^Hold_Page_Runtime)
	if h.popup {
		if code := interaction.guard_common(&r.interaction, action.source);
		   code != .Applied {return code}
		if r.model.revision == max(u64) ||
		   base.advance_sequence(&r.publication) != .None {return .Exhausted}
		if !consume(r, reader_stamp(&r.live), r.publication.sequence) {return .Invalid_Action}
		layer_change(r, "layers/popup-close"); return .Applied
	}
	result := layers.dispatch(&r.layers, &r.interaction, action)
	if event, ok := result.cancel.?;
	   ok {if consume(r, reader_stamp(&r.live), event.sequence) {layer_change(r, "layers/close")}}
	return result.dispatch.code
}
