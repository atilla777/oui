// Explicit combined input for the existing accessibility assessment. Borrowed
// synchronously, not an owning UI frame, runtime or implicit family selection.
package ui_accessibility_projection
import base "../../ui_base"
import custom "../../ui_custom"
import editor "../../ui_editor"
import gestures "../../ui_gestures"
import hold "../../ui_hold"
import layers "../../ui_layers"
import rich "../../ui_rich"
import scroll "../../ui_scroll"
import style "../../ui_style"
import text "../../ui_text"
import tr "../../ui_transitions"
import wire "../../ui_wire"
Extent :: base.Extent
Rect :: base.Rect
Color :: base.Color
Resolved_Node :: wire.Resolved_Node
Visual_Geometry :: base.Frozen_Geometry
Transition_Property :: tr.Property
Paint_Property :: style.Paint_Property
Rich_Block :: rich.Rich_Block
Frame :: struct {
	nodes:                           []Resolved_Node,
	id:                              u64,
	stamp:                           base.Frame_Stamp,
	drawable:                        Extent,
	ui_scale:                        f64,
	modal:                           layers.Modal,
	layer_paint:                     []layers.Paint,
	presentation:                    []style.Presentation,
	text_blocks:                     []text.Text_Block,
	rich_blocks:                     []rich.Rich_Block,
	scroll:                          []scroll.Region,
	progress:                        []hold.Progress,
	hold:                            hold.Hold_State,
	editors:                         []editor.View,
	gestures:                        []gestures.Description,
	custom:                          []custom.Description,
	gesture_model_revision:          u64,
	transition_mode, reduced_motion: bool,
	transition_version:              u64,
	transitions:                     []tr.View,
	presences:                       []tr.Presence,
	geometry:                        []base.Geometry_Entry,
}
find :: proc(f: ^Frame, id: string) -> (^Resolved_Node, wire.Code) {for &n in f.nodes {if n.description.id ==
		   id {return &n, .Applied}}
	return nil, .Not_Found}
inspect_presentation :: proc(f: ^Frame, id: string) -> (^style.Presentation, bool) {for &v in f.presentation {if v.id ==
		   id {return &v, true}}
	return nil, false}
inspect_progress :: proc(f: ^Frame, id: string) -> (^hold.Progress, bool) {for &v in f.progress {if v.id ==
		   id {return &v, true}}
	return nil, false}
transition_color :: tr.color
visual_rect :: base.forward_rect
visual_geometry :: proc(f: ^Frame, id: string) -> (Visual_Geometry, bool) {
	for e in f.geometry {if e.id == id {return e.geometry, true}}
	n, c := find(f, id); if c != .Applied || f.transition_mode {return {}, false}
	return {
			scale = 1,
			opacity = 1,
			bounds = n.bounds,
			content = n.content,
			clip = n.paint_clip,
			content_clip = n.clip,
		},
		true
}
