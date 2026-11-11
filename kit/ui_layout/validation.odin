package ui_layout

import base "../ui_base"

validate_candidate :: proc(p: ^base.Publication, c: ^Layout_Candidate) -> bool {
	return(
		len(c.nodes) > 0 &&
		!c.allocation_failed &&
		c.allocator.procedure != nil &&
		base.validate(p, c.stamp) == .None \
	)
}
describe_error :: proc(e: Update_Error, stage := base.Stage.Prepare) -> base.Error {return {
		family = .Layout,
		stage = stage,
		code = u32(e.code),
		id = e.id,
	}}
