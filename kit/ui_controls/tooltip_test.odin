package ui_controls

import interaction "../ui_interaction"
import "core:testing"

@(test)
all_control_views_report_role_actions_and_frozen_refusals :: proc(t: ^testing.T) {
	roles := [8]string {
		"checkbox",
		"switch",
		"slider",
		"combobox",
		"tablist",
		"list",
		"tooltip",
		"dialog",
	}
	for kind in Kind {
		ds := [1]Description{{id = "control", kind = kind, open = true, cancel_id = "cancel"}}
		gates := [1]interaction.Code{.Applied}
		f := Frame {
			controls = ds[:],
			gates    = gates[:],
		}
		v, found := inspect_control(&f, "control")
		testing.expect(t, found && v.role == roles[int(kind)])
		if kind == .Slider {testing.expect(t, .Set_Value in v.actions && .Adjust in v.actions)}
		if kind == .Select || kind == .Dialog {testing.expect(t, .Cancel in v.actions)}
		gates[0] = .Disabled
		v, found = inspect_control(&f, "control")
		testing.expect(t, found && v.actions == {})
	}
}

@(test)
tooltip_prefers_available_focus_then_hover_independent_of_descriptor_order :: proc(t: ^testing.T) {
	for reverse in ([]bool{false, true}) {
		controls := [2]Description {
			{
				id = "hover-tip",
				kind = .Tooltip,
				node_id = "tip-h",
				layer_id = "tip-h",
				trigger_id = "hover",
				owner_scope_id = "active",
			},
			{
				id = "focus-tip",
				kind = .Tooltip,
				node_id = "tip-f",
				layer_id = "tip-f",
				trigger_id = "focus",
				owner_scope_id = "active",
			},
		}
		if reverse {controls[0], controls[1] = controls[1], controls[0]}
		gates := [2]interaction.Code{.Non_Interactive_Overlay, .Non_Interactive_Overlay}
		f := Frame {
			controls = controls[:],
			gates    = gates[:],
			scope_id = "active",
		}
		views := [2]interaction.Target_View {
			{description = {id = "focus"}, availability = .Applied},
			{description = {id = "hover"}, availability = .Applied},
		}
		i := interaction.Frame {
			targets = views[:],
		}
		tip := tooltip_for_controls(&f, &i, "focus", "hover")
		testing.expect(t, tip != nil && tip.?.root_id == "tip-f")
		views[0].availability = .Disabled
		tip = tooltip_for_controls(&f, &i, "focus", "hover")
		testing.expect(t, tip != nil && tip.?.root_id == "tip-h")
		for &d in controls {d.owner_scope_id = "inactive"}
		testing.expect(t, tooltip_for_controls(&f, &i, "focus", "hover") == nil)
		view, found := inspect_control(&f, "hover-tip")
		testing.expect(
			t,
			found &&
			view.role == "tooltip" &&
			view.actions == {} &&
			view.availability == .Non_Interactive_Overlay,
		)
	}
}
