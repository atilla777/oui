package ui_hold

import base "../ui_base"

describe_error :: proc(e: Error, stage: base.Stage = .Prepare) -> base.Error {return {
		family = .Hold,
		stage = stage,
		code = u32(e.code),
		id = e.id,
	}}
