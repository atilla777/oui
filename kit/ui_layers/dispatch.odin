package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"

Cancel_Requested :: struct {
	root_id:  string,
	source:   interaction.Source,
	sequence: u64,
}
Result :: struct {
	dispatch: interaction.Dispatch_Result,
	cancel:   Maybe(Cancel_Requested),
}
dispatch :: proc(s: ^State, ctx: ^interaction.Context, action: interaction.Action) -> Result {
	if code := interaction.guard_common(ctx, action.source);
	   code != .Applied {return {dispatch = {code = code}}}
	if s.frame.stamp != ctx.frame.stamp {return {dispatch = {code = .Not_Ready}}}
	if action.kind != .Cancel {return {dispatch = interaction.dispatch_routed(ctx, action)}}
	modals := s.frame.layers.modals
	if len(modals) == 0 ||
	   !modals[len(modals) - 1].cancel_allowed {return {dispatch = {code = .Invalid_Action}}}
	if base.advance_sequence(ctx.publication) != .None {return {dispatch = {code = .Exhausted}}}
	return {
		dispatch = {code = .Applied},
		cancel = Cancel_Requested {
			modals[len(modals) - 1].root_id,
			action.source,
			ctx.publication.sequence,
		},
	}
}
hit_test :: proc(
	f: ^Frame,
	g: ^layout.Frame,
	targets: ^interaction.Frame,
	x, y: f64,
	predicate: interaction.Hit_Predicate = nil,
	user: rawptr = nil,
) -> (
	^interaction.Target_View,
	interaction.Code,
) {
	if f.stamp != g.stamp || f.stamp != targets.stamp || g.ui_scale <= 0 {return nil, .Not_Ready}
	xl, yl := x / g.ui_scale, y / g.ui_scale
	for gi := len(f.groups) - 1; gi >= 0; gi -= 1 {
		group := f.groups[gi]; if group.kind == .Tooltip {continue}
		root := g.nodes[group.root_index]
		for i := len(targets.targets) - 1; i >= 0; i -= 1 {
			n := &targets.targets[i]
			if n.availability == .Applied &&
			   within(g, n.description.id, root.description.id) &&
			   base.contains(n.bounds, xl, yl) &&
			   base.contains(n.clip, xl, yl) &&
			   (predicate == nil ||
					   predicate(n.description.id, {xl, yl}, user)) {return n, .Applied}
		}
		if group.kind == .Popup &&
		   root.visible &&
		   base.contains(root.bounds, xl, yl) &&
		   base.contains(root.paint_clip, xl, yl) {return nil, .Not_Found}
	}
	return nil, .Not_Found
}
