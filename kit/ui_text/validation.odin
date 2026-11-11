package ui_text

import base "../ui_base"
import layout "../ui_layout"

validate_candidate :: proc(p: ^base.Publication, c: ^Candidate) -> bool {
	return(
		c.text.allocator.procedure != nil &&
		c.text.stamp == c.geometry.stamp &&
		c.text.drawable == c.geometry.drawable &&
		c.text.ui_scale == c.geometry.ui_scale &&
		layout.validate_candidate(p, &c.geometry) \
	)
}
describe_error :: proc(e: Text_Update_Result, stage := base.Stage.Prepare) -> base.Error {
	id := e.id; if id == "" {id = e.existing.id}
	return {
		family = .Text,
		stage = stage,
		code = u32(e.code),
		existing_code = u32(e.existing.code),
		id = id,
		byte_offset = e.byte_offset,
	}
}
