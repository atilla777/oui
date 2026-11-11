package ui_wire
code_name :: proc(c: Code) -> string {
	switch c {
	case .Applied:
		return "Applied"
	case .Not_Found:
		return "Not_Found"
	case .Disabled:
		return "Disabled"
	case .Not_Visible:
		return "Not_Visible"
	case .Invalid_Action:
		return "Invalid_Action"
	case .Not_Ready:
		return "Not_Ready"
	case .Blocked_By_Modal:
		return "Blocked_By_Modal"
	case .Hold_Required:
		return "Hold_Required"
	case .Non_Interactive_Overlay:
		return "Non_Interactive_Overlay"
	case .Gesture_Busy:
		return "Gesture_Busy"
	}
	return "Invalid_Action"
}
