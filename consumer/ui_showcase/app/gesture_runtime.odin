package app

import gesture_model "../../gestures_demo/model"
import sections "../sections"
import base "ui:ui_base"
import gestures "ui:ui_gestures"
import gesture_sdl "ui:ui_gestures/sdl"

Gesture_Page_Runtime :: struct {
	state:   gestures.State,
	input:   gesture_sdl.Adapter,
	editing: Name_Page_Runtime,
	model:   ^gesture_model.State,
	outcome: gesture_model.Outcome,
	ids:     [12][2][64]u8,
	status:  [256]u8,
}
Gesture_Page_Reader :: struct {
	editing: Name_Page_Reader,
	frame:   gestures.Frame,
}
GESTURE_VIEWPORTS := sections.GESTURE_VIEWPORTS
GESTURE_CONTENTS := sections.GESTURE_CONTENTS
compose_gesture_page :: proc(r: ^Runtime, c: ^Page_Composition) -> bool {
	g, _ := r.content.(^Gesture_Page_Runtime)
	return sections.compose_gesture_page(
		{r.model^, r.allocator},
		c,
		{
			state = {live = g.state.live},
			model = g.model,
			outcome = g.outcome,
			ids = &g.ids,
			status = g.status[:],
		},
	)
}
accept_gesture_page :: proc(r: ^Runtime, result: gestures.Result) -> bool {
	g, ok := r.content.(^Gesture_Page_Runtime); if !ok {return false}
	if !result.has_proposal {return true}
	p := result.proposal
	if !consume(r, reader_stamp(&r.live), p.sequence) ||
	   r.model.revision == max(u64) ||
	   r.model.effects == max(u64) {return false}
	request := gesture_model.Drop_Request {
		source_id      = p.source_id,
		target_id      = p.target_id,
		payload_id     = p.payload_id,
		payload_type   = p.payload_type,
		cycle          = p.cycle,
		sequence       = p.sequence,
		frame_id       = p.frame_id,
		model_revision = p.model_revision,
	}
	next, outcome := gesture_model.reduce(g.model^, request)
	g.model^, g.outcome = next, outcome
	r.model.revision += 1; if outcome.applied {r.model.effects += 1}
	base.invalidate(&r.publication); return true
}
