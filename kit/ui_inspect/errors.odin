package ui_inspect
error_name :: proc(e: Inspect_Error) -> string {
	switch e {
	case .None:
		return "None"
	case .Metadata_Mismatch:
		return "Metadata_Mismatch"
	case .Invalid_Query:
		return "Invalid_Query"
	case .Not_Found:
		return "Not_Found"
	case .Allocation:
		return "Allocation"
	case .Invalid_Policy:
		return "Invalid_Policy"
	}
	return "Metadata_Mismatch"
}
