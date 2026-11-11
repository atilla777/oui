package ui_layers

import base "../ui_base"

describe_error :: proc(e: Error, stage: base.Stage = .Prepare) -> base.Error {return {
		family = .Layers,
		stage = stage,
		code = u32(e.code),
		existing_code = u32(e.interaction),
		id = e.id,
	}}
