package ui_style

import base "../ui_base"

validate_candidate :: proc(p: ^base.Publication, c: ^Frame) -> bool {
	return c.storage != nil && base.validate(p, c.stamp) == .None
}
describe_error :: proc(e: Error, stage := base.Stage.Prepare) -> base.Error {return {
		family = .Style,
		stage = stage,
		code = u32(e.code),
		id = e.id,
	}}
