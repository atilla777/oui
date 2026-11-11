package ui_controls

import "core:strings"
import "core:testing"

@(test)
recipes_own_descriptions_and_preserve_all_eight_component_shapes :: proc(t: ^testing.T) {
	for kind in Kind {
		label := strings.clone("Original")
		d := Description {
			id       = "choice",
			kind     = kind,
			label    = label,
			on_text  = "On",
			off_text = "Off",
			body     = "Body",
		}
		if kind == .Checkbox || kind == .Toggle {d.checked = true}
		if kind == .Slider {d.minimum = 0; d.maximum = 100; d.step = 10; d.value = 50}
		if kind == .Tabs ||
		   kind == .List ||
		   kind == .Select ||
		   kind ==
			   .Dialog {d.items = []Item{{id = "one", label = "One"}, {id = "two", label = "Two"}}; d.selected_id = "two"}
		if kind == .Select || kind == .Dialog {d.open = true}
		if kind == .Dialog {d.cancel_id = "two"}
		if kind == .Tooltip {d.trigger_id = "trigger"}
		p, e := compose_control(d, "base", "root", context.allocator)
		delete(label)
		if !testing.expect(
			t,
			e.code == .None,
			"valid recipe must produce an owning typed composition",
		) {continue}
		testing.expect(
			t,
			p.control.label == "Original" && p.control.node_id != "" && len(p.nodes) > 0,
		)
		if kind == .Checkbox || kind == .Toggle {
			found :=
				false; for n in p.texts {if strings.has_prefix(n.text, "[x] Original") {found = true}}
			testing.expect(
				t,
				found && len(p.targets) == 1,
				"bool recipe needs a mark and one ordinary target",
			)
		}
		if kind == .Slider {
			found :=
				false; for n in p.nodes {if n.id == p.control.track_id {l := n.layout.?; found = n.role == .Absolute && l.x.value == 120 && l.y.value == 10}}
			testing.expect(
				t,
				found && p.control.decrement_id != "" && p.control.increment_id != "",
				"slider owns separate rail geometry and auxiliary buttons",
			)
		}
		if kind ==
		   .List {testing.expect(t, len(p.scroll) == 1 && p.scroll[0].id == p.control.node_id && p.control.items[0].node_id == "6:choice3:one")}
		if kind == .Tabs {testing.expect(t, p.nodes[0].role == .Row)}
		if kind ==
		   .Select {testing.expect(t, p.popup != nil && p.popup.?.return_focus_id == p.control.node_id)}
		if kind ==
		   .Dialog {testing.expect(t, p.modal != nil && p.modal.?.cancel_allowed && p.modal.?.initial_focus_id == p.control.items[0].node_id)}
		if kind ==
		   .Tooltip {testing.expect(t, p.tooltip != nil && len(p.targets) == 0 && p.control.node_id == p.control.layer_id)}
		destroy_composition(&p)
	}
}

@(test)
item_identity_is_reversible_not_position_or_translation_based :: proc(t: ^testing.T) {
	a, ok := item_node_id(
		"a:b",
		"c",
		context.allocator,
	); if !testing.expect(t, ok) {return}; defer delete(a)
	b, bok := item_node_id(
		"a",
		"b:c",
		context.allocator,
	); if !testing.expect(t, bok) {return}; defer delete(b)
	testing.expect(t, a == "3:a:b1:c" && b == "1:a3:b:c" && a != b)
}
