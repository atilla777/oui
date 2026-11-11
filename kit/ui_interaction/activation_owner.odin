package ui_interaction

import "core:strings"

// Candidate-only: the binding is immutable after publication.
bind_activation_owner :: proc(f: ^Frame, id, owner: string) -> Code {
	n, ok := find(f, id); if !ok {return .Not_Found}
	if owner == "" {return .Invalid_Action}
	if n.activation_owner !=
	   "" {if n.activation_owner == owner {return .Applied}; return .Conflict}
	value, e := strings.clone(owner, f.allocator); if e != nil {return .Allocation}
	n.activation_owner = value
	return .Applied
}
dispatch_owned :: proc(ctx: ^Context, action: Action, owner: string) -> Dispatch_Result {
	if owner == "" || action.kind != .Activate {return {code = .Invalid_Action}}
	return route_result(ctx, dispatch_internal(ctx, action, owner))
}
