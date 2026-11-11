package ui_controls

import interaction "../ui_interaction"
import layers "../ui_layers"

Actions :: bit_set[Action_Kind]
View :: struct {
	description:  Description,
	role:         string,
	availability: interaction.Code,
	actions:      Actions,
}
inspect_control :: proc(f: ^Frame, id: string) -> (View, bool) {
	for c, k in f.controls {if c.id == id {
			v := View {
				description  = c,
				availability = .Not_Ready,
			}
			if k < len(f.gates) {v.availability = f.gates[k]}
			switch c.kind {
			case .Checkbox:
				v.role = "checkbox"; v.actions = {.Focus, .Activate}
			case .Toggle:
				v.role = "switch"; v.actions = {.Focus, .Activate}
			case .Slider:
				v.role = "slider"; v.actions = {.Focus, .Adjust, .Set_Value}
			case .Select:
				v.role = "combobox"; v.actions = {.Focus, .Activate}
				if c.open {v.actions += {.Cancel}}
			case .Tabs:
				v.role = "tablist"; v.actions = {.Focus, .Activate}
			case .List:
				v.role = "list"; v.actions = {.Focus, .Move_Item, .Activate}
			case .Tooltip:
				v.role = "tooltip"; v.availability = .Non_Interactive_Overlay
			case .Dialog:
				v.role = "dialog"
				if c.open {v.actions = {.Activate}; if c.cancel_id != "" {v.actions += {.Cancel}}}
			}
			if v.availability != .Applied {v.actions = {}}
			return v, true
		}}
	return {}, false
}
tooltip_for_controls :: proc(
	f: ^Frame,
	i: ^interaction.Frame,
	focus, hover: string,
) -> Maybe(layers.Tooltip) {
	if f.stamp != i.stamp {return nil}
	for trigger in ([]string{focus, hover}) {
		if trigger == "" {continue}
		n, found := interaction.find(
			i,
			trigger,
		); if !found || n.availability != .Applied {continue}
		for c in f.controls {if c.kind == .Tooltip && c.owner_scope_id == f.scope_id && c.trigger_id == trigger {return layers.Tooltip{c.layer_id, c.owner_scope_id}}}
	}
	return nil
}
