package ui_interaction

import base "../ui_base"

validate_candidate :: proc(p: ^base.Publication, c: ^Candidate) -> bool {
	return len(c.targets) > 0 && c.allocator.procedure != nil && base.validate(p, c.stamp) == .None
}
describe_error :: proc(
	code: Code,
	id: string,
	stage := base.Stage.Prepare,
) -> base.Error {return {family = .Interaction, stage = stage, code = u32(code), id = id}}
