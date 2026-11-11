package app

import base "ui:ui_base"
import hold "ui:ui_hold"
import transitions "ui:ui_transitions"

Transition_Page_Runtime :: struct {
	hold:            Hold_Page_Runtime,
	presence_timing: bool,
	state:           transitions.State,
	step:            transitions.Step,
	clock:           transitions.Transition_Clock,
}
Transition_Page_Reader :: struct {
	frame: transitions.Frame,
	hold:  hold.Frame,
}
transition_geometry :: proc(r: ^Runtime) -> base.Geometry_View {
	if v, selected := r.live.content.(Rich_Page_Reader);
	   selected {return transitions.geometry_view(&v.visual)}
	if a, selected := r.live.content.(Accessibility_Page_Reader);
	   selected {return transitions.geometry_view(&a.visual)}
	if v, selected := r.live.content.(Transition_Page_Reader);
	   selected {return transitions.geometry_view(&v.frame)}
	return {}
}
active_transition :: proc(r: ^Runtime) -> (^Transition_Page_Runtime, bool) {
	if v, selected := r.content.(Rich_Page_Runtime);
	   selected && v.combined != nil {return &v.combined.visual, true}
	if v, selected := r.content.(^Transition_Page_Runtime); selected {return v, true}
	if a, selected := r.content.(^Accessibility_Page_Runtime); selected {return &a.visual, true}
	return nil, false
}

prepare_transition :: proc(r: ^Runtime, stamp: base.Frame_Stamp) -> (transitions.Candidate, bool) {
	v, selected := active_transition(r); if !selected {return {}, false}
	if r.page == .Rich_Text {
		offset := [2]f64{}; if r.model.rich.ellipsis {offset = {30, 0}}
		c, e := transitions.prepare(
			&v.state,
			stamp,
			[]transitions.Description {
				{
					node_id = "rich/circle",
					present = true,
					tracks = []transitions.Track {
						{property = .Offset, target = offset, timing = {400, 0, .Linear}},
					},
				},
			},
			v.step,
			false,
			r.allocator,
		)
		return c, e.code == .None
	}
	m := r.model.transition
	if r.page ==
	   .Accessibility {m.target_b, m.hidden, m.reduced = r.model.accessibility.target_b, !r.model.accessibility.present, r.model.accessibility.reduced}
	offset := [2]f64{}; scale, opacity, progress := f64(1), f64(1), f64(.25)
	background := [4]f64{35, 66, 96, 255}
	foreground, border := [4]f64{240, 240, 240, 255}, [4]f64{155, 185, 210, 255}
	if m.target_b {offset = {120, 24}; scale, opacity, progress = .8, .6, .75; background = {90, 45, 75, 255}}
	if m.target_b {foreground, border = {255, 220, 140, 255}, {230, 150, 65, 255}}
	timing := transitions.Timing{1000, 200, transitions.Easing(m.easing)}
	presence := transitions.Timing{400, 0, transitions.Easing(m.easing)}
	tracks := [7]transitions.Track {
		{property = .Foreground, target = foreground, timing = timing},
		{property = .Background, target = background, timing = timing},
		{property = .Border, target = border, timing = timing},
		{property = .Opacity, target = opacity, timing = timing},
		{property = .Offset, target = offset, timing = timing},
		{property = .Scale, target = scale, timing = timing},
		{property = .Progress, target = progress, timing = timing},
	}
	// Presence tracks use the original enter/exit fixture only during entry,
	// explicit hide/show, or while finishing that presence transition.
	if v.presence_timing {
		tracks[3].timing, tracks[4].timing, tracks[5].timing = presence, presence, presence
	}
	tracks[3].presence = transitions.Endpoints{f64(0), f64(0)}
	tracks[4].presence = transitions.Endpoints{[2]f64{0, -24}, offset + [2]f64{0, 24}}
	tracks[5].presence = transitions.Endpoints{f64(.9), f64(.9)}
	caption := "transitions/caption"; if r.page == .Accessibility {caption = "accessibility/motion"}
	c, e := transitions.prepare(
		&v.state,
		stamp,
		[]transitions.Description {
			{node_id = "transitions/card", present = !m.hidden, tracks = tracks[:6]},
			{node_id = "transitions/progress", tracks = tracks[6:]},
			{node_id = caption, tracks = tracks[:1]},
		},
		v.step,
		m.reduced,
		r.allocator,
	)
	return c, e.code == .None
}
