// Fixed protocol DTOs, not a runtime facade. Never cast new internal enums to
// these enums. Optional payloads below are synchronous wire projections only.
package ui_wire

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"

Role :: enum {
	Column          = 0,
	Label           = 1,
	Button          = 2,
	Overlay         = 3,
	Row             = 4,
	Stack           = 5,
	Grid            = 6,
	Absolute        = 7,
	Box             = 8,
	ScrollContainer = 9,
	ProgressBar     = 10,
}
Width :: enum {
	Content = 0,
	Fill    = 1,
	Fixed   = 2,
}
Code :: enum {
	Applied                 = 0,
	Not_Found               = 1,
	Disabled                = 2,
	Not_Visible             = 3,
	Invalid_Action          = 4,
	Not_Ready               = 5,
	Blocked_By_Modal        = 6,
	Hold_Required           = 7,
	Non_Interactive_Overlay = 8,
	Gesture_Busy            = 9,
}
Frame_Family :: enum {
	None,
	Legacy,
	Layout,
	Styled,
	Text,
	Scroll,
	Hold,
	Layered,
	Rich,
}
Style :: struct {
	font_size:                      f64,
	foreground, background, border: base.Color,
	border_width, focus_width:      f64,
}
Node :: struct {
	layout:                    Maybe(layout.Layout),
	id, parent, text:          string,
	role:                      Role,
	enabled, visible:          bool,
	width:                     Width,
	fixed_width, padding, gap: f64,
	style:                     Style,
}
Resolved_Node :: struct {
	transition_blocked:                          bool `json:"-"`,
	rows, columns:                               []f64,
	description:                                 Node,
	bounds, content, clip, paint_clip:           base.Rect,
	measured:                                    base.Extent,
	style:                                       Style,
	enabled, visible, focused, hovered, pressed: bool,
	availability:                                Code,
}
code :: proc(c: interaction.Code) -> (Code, bool) {
	#partial switch c {
	case .Applied:
		return .Applied, true
	case .Not_Found:
		return .Not_Found, true
	case .Disabled:
		return .Disabled, true
	case .Not_Visible:
		return .Not_Visible, true
	case .Invalid_Action:
		return .Invalid_Action, true
	case .Not_Ready:
		return .Not_Ready, true
	case .Blocked_By_Modal:
		return .Blocked_By_Modal, true
	case .Non_Interactive_Overlay:
		return .Non_Interactive_Overlay, true
	case:
		return {}, false
	}
}
role :: proc(k: layout.Kind) -> (Role, bool) {
	switch k {
	case .Column:
		return .Column, true
	case .Row:
		return .Row, true
	case .Stack:
		return .Stack, true
	case .Grid:
		return .Grid, true
	case .Absolute:
		return .Absolute, true
	case .Box:
		return .Box, true
	case .Content:
		return {}, false
	}
	return {}, false
}
