package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:strings"

Modal :: struct {
	root_id, initial_focus_id: string,
	cancel_allowed:            bool,
}
Popup :: struct {
	root_id, owner_scope_id, return_focus_id: string,
}
Tooltip :: struct {
	root_id, owner_scope_id: string,
}
Layers :: struct {
	base_root_id: string,
	modals:       []Modal,
	popups:       []Popup,
	tooltips:     []Tooltip,
}
Paint_Kind :: enum {
	Draw_Node,
	Draw_Focus,
	Scrim,
}
Paint :: struct {
	kind:       Paint_Kind,
	node_index: int,
}
Group_Kind :: enum {
	Main,
	Popup,
	Tooltip,
}
Group :: struct {
	root_index: int,
	kind:       Group_Kind,
}
Frame :: struct {
	layers:    Layers,
	returns:   []string,
	paint:     [dynamic]Paint,
	groups:    [dynamic]Group,
	stamp:     base.Frame_Stamp,
	allocator: mem.Allocator,
}
State :: struct {
	frame: Frame,
}
Candidate :: struct {
	origin:                         ^interaction.Context,
	base_pressed:                   string,
	base_hover:                     string,
	frame:                          Frame,
	interaction:                    interaction.Candidate,
	focus_id, hover_id, pressed_id: string, // Borrow candidate interaction.
}
Error_Code :: enum {
	None,
	Invalid_Layers,
	Invalid_Transition,
	Allocation,
	Interaction,
}
Error :: struct {
	code:        Error_Code,
	id:          string,
	interaction: interaction.Code,
}
create :: proc(a: mem.Allocator) -> State {return {frame = {allocator = a}}}
destroy_frame :: proc(f: ^Frame) {
	a := f.allocator
	delete(f.layers.base_root_id, a)
	for m in f.layers.modals {delete(m.root_id, a); delete(m.initial_focus_id, a)}
	for p in f.layers.popups {delete(p.root_id, a); delete(p.owner_scope_id, a); delete(p.return_focus_id, a)}
	for p in f.layers.tooltips {delete(p.root_id, a); delete(p.owner_scope_id, a)}
	for id in f.returns {delete(id, a)}
	delete(
		f.layers.modals,
		a,
	); delete(f.layers.popups, a); delete(f.layers.tooltips, a); delete(f.returns, a)
	delete(f.paint); delete(f.groups); base.release(f.stamp); f^ = {}
}
destroy :: proc(s: ^State) {destroy_frame(&s.frame)}
destroy_candidate :: proc(c: ^Candidate) {delete(c.base_hover, c.frame.allocator); delete(
		c.base_pressed,
		c.frame.allocator,
	)
	destroy_frame(&c.frame)
	interaction.destroy_candidate(&c.interaction)
	c^ = {}}
active_scope :: proc(l: Layers) -> string {if len(l.modals) == 0 {return ""}; return(
		l.modals[len(l.modals) - 1].root_id \
	)}
within :: proc(g: ^layout.Frame, id, root: string) -> bool {
	for at := id; at != ""; {
		if at == root {return true}
		n, ok := layout.find(g, at); if !ok {return false}; at = n.description.parent
	}
	return false
}
scope_contains :: proc(g: ^layout.Frame, l: Layers, id, scope: string) -> bool {
	root := scope; if root == "" {root = l.base_root_id}
	if within(g, id, root) {return true}
	for p in l.popups {if p.owner_scope_id == scope && within(g, id, p.root_id) {return true}}
	for p in l.tooltips {if p.owner_scope_id == scope && within(g, id, p.root_id) {return true}}
	return false
}
@(private)
valid_owner :: proc(l: Layers, id: string) -> bool {if id == "" {return true}; for m in l.modals {if m.root_id ==
		   id {return true}}
	return false}
@(private)
validate :: proc(g: ^layout.Frame, old, next: Layers, targets: []interaction.Target) -> Error {
	if next.base_root_id == "" {return {.Invalid_Layers, "", {}}}
	// Same partition oracle as the former layers implementation: every root is
	// a distinct immediate child of one Stack/Absolute common root.
	count := 1 + len(next.modals) + len(next.popups) + len(next.tooltips)
	common := ""
	for i in 0 ..< count {
		id := root_at(next, i)
		n, ok := layout.find(g, id)
		if !ok || id == "" || n.description.parent == "" {return {.Invalid_Layers, id, {}}}
		for t in targets {if t.id == id && t.role == "button" {return {.Invalid_Layers, id, {}}}}
		for j in 0 ..< i {if root_at(next, j) == id {return {.Invalid_Layers, id, {}}}}
		if common == "" {common = n.description.parent}
		if common != n.description.parent {return {.Invalid_Layers, id, {}}}
	}
	r, ok := layout.find(g, common)
	if !ok ||
	   r.description.parent != "" ||
	   (r.description.role != .Stack &&
			   r.description.role != .Absolute) {return {.Invalid_Layers, common, {}}}
	for t in targets {if t.id == common && t.role == "button" {return {.Invalid_Layers, common, {}}}}
	for n in g.nodes {if n.description.parent == common {
			found :=
				false; for i in 0 ..< count {if root_at(next, i) == n.description.id {found = true}}
			if !found {return {.Invalid_Layers, n.description.id, {}}}
		}}
	for m in next.modals {n, _ := layout.find(g, m.root_id); if !n.enabled || !n.visible {return {.Invalid_Layers, m.root_id, {}}}}
	for p in next.popups {if !valid_owner(next, p.owner_scope_id) {return {.Invalid_Layers, p.root_id, {}}}}
	for p in next.tooltips {
		if !valid_owner(next, p.owner_scope_id) {return {.Invalid_Layers, p.root_id, {}}}
		for t in targets {if within(g, t.id, p.root_id) {return {.Invalid_Layers, t.id, {}}}}
	}
	if old.base_root_id != "" &&
	   old.base_root_id != next.base_root_id {return {.Invalid_Transition, next.base_root_id, {}}}
	for m, i in next.modals {if i > len(old.modals) || (i < len(old.modals) && m.root_id != old.modals[i].root_id) {return {.Invalid_Transition, m.root_id, {}}}}
	return {}
}
@(private)
root_at :: proc(l: Layers, i: int) -> string {
	if i == 0 {return l.base_root_id}; j := i - 1
	if j < len(l.modals) {return l.modals[j].root_id}; j -= len(l.modals)
	if j < len(l.popups) {return l.popups[j].root_id}; return l.tooltips[j - len(l.popups)].root_id
}
@(private)
clone_layers :: proc(l: Layers, a: mem.Allocator) -> (Frame, bool) {
	f: Frame
	f.allocator = a; complete := false; defer {if !complete {destroy_frame(&f)}}
	e: mem.Allocator_Error
	f.layers.base_root_id, e = strings.clone(l.base_root_id, a); if e != nil {return {}, false}
	f.layers.modals, e = make([]Modal, len(l.modals), a); if e != nil {return {}, false}
	for m, i in l.modals {f.layers.modals[i].cancel_allowed = m.cancel_allowed; f.layers.modals[i].root_id, e = strings.clone(m.root_id, a); if e != nil {return {}, false}; f.layers.modals[i].initial_focus_id, e = strings.clone(m.initial_focus_id, a); if e != nil {return {}, false}}
	f.layers.popups, e = make([]Popup, len(l.popups), a); if e != nil {return {}, false}
	for p, i in l.popups {d := &f.layers.popups[i]; d.root_id, e = strings.clone(p.root_id, a); if e != nil {return {}, false}; d.owner_scope_id, e = strings.clone(p.owner_scope_id, a); if e != nil {return {}, false}; d.return_focus_id, e = strings.clone(p.return_focus_id, a); if e != nil {return {}, false}}
	f.layers.tooltips, e = make([]Tooltip, len(l.tooltips), a); if e != nil {return {}, false}
	for p, i in l.tooltips {d := &f.layers.tooltips[i]; d.root_id, e = strings.clone(p.root_id, a); if e != nil {return {}, false}; d.owner_scope_id, e = strings.clone(p.owner_scope_id, a); if e != nil {return {}, false}}
	complete = true; return f, true
}
@(private)
subtree_plan :: proc(g: ^layout.Frame, index: int, paint: ^[dynamic]Paint) -> bool {
	if _, e := append(paint, Paint{.Draw_Node, index}); e != nil {return false}
	for n, i in g.nodes {if n.description.parent == g.nodes[index].description.id {if !subtree_plan(g, i, paint) {return false}}}
	_, e := append(paint, Paint{.Draw_Focus, index}); return e == nil
}
prepare :: proc(
	s: ^State,
	ctx: ^interaction.Context,
	g: ^layout.Frame,
	targets: []interaction.Target,
	claims: []interaction.Capture_Claim,
	l: Layers,
	a: mem.Allocator,
) -> (
	result: Candidate,
	error: Error,
) {
	c: Candidate
	if error = validate(g, s.frame.layers, l, targets); error.code != .None {return {}, error}
	complete := false; defer {if !complete {destroy_candidate(&c)}}
	var_ok: bool
	c.frame, var_ok = clone_layers(l, a); if !var_ok {return {}, {code = .Allocation}}
	c.origin = ctx
	base_pressed, be := strings.clone(
		ctx.pressed_id,
		a,
	); if be != nil {return {}, {code = .Allocation}}; c.base_pressed = base_pressed
	c.base_hover, be = strings.clone(
		ctx.hover_id,
		a,
	); if be != nil {return {}, {code = .Allocation}}
	if !base.retain(g.stamp) {return {}, {code = .Allocation}}; c.frame.stamp = g.stamp
	code: interaction.Code
	c.interaction, code = interaction.prepare(
		g,
		targets,
		claims,
		a,
	); if code != .Applied {return {}, {code = .Interaction, interaction = code}}
	for &n in c.interaction.targets {
		if n.availability == .Disabled || n.availability == .Not_Visible {continue}
		if len(l.modals) > 0 &&
		   !scope_contains(
				   g,
				   l,
				   n.description.id,
				   active_scope(l),
			   ) {n.availability = .Blocked_By_Modal}
		for p in l.tooltips {if within(g, n.description.id, p.root_id) {n.availability = .Non_Interactive_Overlay}}
		// Routed delivery stops at the selected layer root, not at the common
		// physical root. Layout ancestry is not changed.
		for i in 0 ..< 1 + len(l.modals) + len(l.popups) + len(l.tooltips) {if n.description.id == root_at(l, i) {delete(n.parent, a); n.parent = ""}}
	}
	c.frame.paint = make([dynamic]Paint, 0, 0, a); c.frame.groups = make([dynamic]Group, 0, 0, a)
	for depth in 0 ..= len(l.modals) {
		scope := ""; root := l.base_root_id
		if depth >
		   0 {scope = l.modals[depth - 1].root_id; root = scope; if _, e := append(&c.frame.paint, Paint{.Scrim, -1}); e != nil {return {}, {code = .Allocation}}}
		start := len(c.frame.groups)
		for n, i in g.nodes {if n.description.id == root {if _, e := append(&c.frame.groups, Group{i, .Main}); e != nil {return {}, {code = .Allocation}}}}
		for p in l.popups {if p.owner_scope_id == scope {for n, i in g.nodes {if n.description.id == p.root_id {if _, e := append(&c.frame.groups, Group{i, .Popup}); e != nil {return {}, {code = .Allocation}}}}}}
		for p in l.tooltips {if p.owner_scope_id == scope {for n, i in g.nodes {if n.description.id == p.root_id {if _, e := append(&c.frame.groups, Group{i, .Tooltip}); e != nil {return {}, {code = .Allocation}}}}}}
		for group in c.frame.groups[start:] {if !subtree_plan(g, group.root_index, &c.frame.paint) {return {}, {code = .Allocation}}}
	}
	old_depth, depth := len(s.frame.layers.modals), len(l.modals)
	e: mem.Allocator_Error
	c.frame.returns, e = make([]string, depth, a); if e != nil {return {}, {code = .Allocation}}
	for i in 0 ..< min(old_depth, depth) {c.frame.returns[i], e = strings.clone(s.frame.returns[i], a); if e != nil {return {}, {code = .Allocation}}}
	focus := ctx.focus_id
	if depth > old_depth {
		m := l.modals[depth - 1]; n, ok := interaction.find(&c.interaction, m.initial_focus_id)
		if !ok ||
		   n.availability != .Applied ||
		   !within(
				   g,
				   m.initial_focus_id,
				   m.root_id,
			   ) {return {}, {.Invalid_Layers, m.initial_focus_id, {}}}
		c.frame.returns[depth - 1], e = strings.clone(
			ctx.focus_id,
			a,
		); if e != nil {return {}, {code = .Allocation}}; focus = m.initial_focus_id
	} else if depth < old_depth {focus = s.frame.returns[depth]
	} else {
		for old in s.frame.layers.popups {
			present := false
			for next in l.popups {if next.root_id == old.root_id && next.owner_scope_id == old.owner_scope_id {
					n, found := layout.find(
						g,
						next.root_id,
					); present = found && n.enabled && n.visible
				}}
			if !present &&
			   old.owner_scope_id == active_scope(l) &&
			   target_within(&ctx.frame, ctx.focus_id, old.root_id) {
				focus = old.return_focus_id
				if !scope_contains(g, l, focus, old.owner_scope_id) {focus = ""}
				break
			}
		}
	}
	c.focus_id = interaction.retained_id(&c.interaction, focus)
	if c.focus_id ==
	   "" {for command in c.frame.paint {if command.kind == .Draw_Node {n := c.interaction.targets[command.node_index]; if n.availability == .Applied {c.focus_id = n.description.id; break}}}}
	if depth == old_depth && popup_order_equal(s.frame.layers, l) {
		c.hover_id = interaction.retained_id(
			&c.interaction,
			ctx.hover_id,
		); c.pressed_id = interaction.retained_id(&c.interaction, ctx.pressed_id)
	}
	// Keep the common interaction algorithm as the sole navigator/hit owner;
	// freeze layer descriptor order in its projection instead of maintaining a
	// second focus/navigation state machine. Paint indices still address g.
	ordered, oe := make([]interaction.Target_View, len(c.interaction.targets), a)
	if oe != nil {return {}, {code = .Allocation}}
	cursor := 0
	for n in c.interaction.targets {if n.parent == "" {
			// Only the physical common root is outside all layer subtrees.
			original, _ := layout.find(g, n.description.id)
			if original.description.parent == "" {ordered[cursor] = n; cursor += 1}
		}}
	for command in c.frame.paint {if command.kind == .Draw_Node {ordered[cursor] = c.interaction.targets[command.node_index]; cursor += 1}}
	delete(c.interaction.targets, a); c.interaction.targets = ordered
	complete = true; return c, {}
}
@(private)
target_within :: proc(f: ^interaction.Frame, id, root: string) -> bool {
	for at := id; at != ""; {
		if at == root {return true}
		n, ok := interaction.find(f, at); if !ok {return false}; at = n.parent
	}
	return false
}
@(private)
popup_order_equal :: proc(a, b: Layers) -> bool {
	if len(a.popups) != len(b.popups) {return false}
	for p, i in a.popups {if p.root_id != b.popups[i].root_id || p.owner_scope_id != b.popups[i].owner_scope_id {return false}}
	return true
}
validate_candidate :: proc(p: ^base.Publication, c: ^Candidate) -> bool {return(
		base.validate(p, c.frame.stamp) == .None &&
		c.origin != nil &&
		c.origin.publication == p &&
		c.origin.hover_id == c.base_hover &&
		c.origin.pressed_id == c.base_pressed &&
		c.frame.stamp == c.interaction.stamp &&
		interaction.validate_candidate(p, &c.interaction) \
	)}
// Only inside the typed publisher's validated infallible commit section.
commit :: proc(s: ^State, ctx: ^interaction.Context, c: ^Candidate) {
	interaction.commit(ctx, &c.interaction)
	ctx.focus_id, ctx.hover_id, ctx.pressed_id = c.focus_id, c.hover_id, c.pressed_id
	delete(c.base_pressed, c.frame.allocator)
	delete(c.base_hover, c.frame.allocator)
	old := s.frame; s.frame = c.frame; c.frame = {}; c^ = {}; destroy_frame(&old)
}
