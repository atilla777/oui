package ui_inspect

import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:strings"

Semantic :: struct {
	id, role, name, source_hint: string,
}
Inspect_Error :: enum {
	None,
	Metadata_Mismatch,
	Invalid_Query,
	Not_Found,
	Allocation,
	Invalid_Policy,
}
Action :: enum {
	Focus,
	Activate,
	Scroll_By,
	Begin,
	Navigate,
	Cancel,
	Release,
	Advance,
	Hold_Cancel,
}
Action_Status :: struct {
	capability, suitable: bool,
	code:                 interaction.Code,
}
Inspection_Input :: struct {
	frame:                              ^layout.Frame,
	interaction:                        ^interaction.Frame,
	focus_id, hover_id, pressed_id:     string,
	ready:                              bool,
	model_revision, published_revision: u64,
	semantics:                          []Semantic,
	diagnostics:                        []Diagnostic_Record,
	capabilities:                       [Action]bool,
}
Inspection :: struct {
	frame:                                     layout.Frame,
	interaction:                               interaction.Frame,
	focus_id, hover_id, pressed_id:            string,
	children:                                  [][]int,
	semantics:                                 []Semantic,
	diagnostics, offending, offending_storage: []Diagnostic_Record,
	capabilities:                              [Action]bool,
	ready, historical:                         bool,
	model_revision, published_revision:        u64,
	allocator:                                 mem.Allocator,
}
Node_View :: struct {
	parent_index:              Maybe(int),
	children:                  []int,
	structural_role:           layout.Kind,
	resolved:                  ^layout.Resolved_Node,
	target:                    ^interaction.Target_View,
	focused, hovered, pressed: bool,
	role, name, source_hint:   string,
}
Query_Kind :: enum {
	ID,
	Role,
	Name,
}
Query :: struct {
	kind:         Query_Kind,
	exact_string: string,
}

// Every retained byte is copied. Family owners are deliberately not members of
// this reader: selected <family>/inspect readers are captured explicitly.
capture :: proc(input: Inspection_Input, a: mem.Allocator) -> (Inspection, Inspect_Error) {
	if input.ready &&
	   (input.frame == nil ||
			   input.frame.stamp.lifetime == nil ||
			   !input.frame.stamp.lifetime.alive) {return {}, .Metadata_Mismatch}
	for d in input.diagnostics {
		if d.phase == .update && d.severity == .Error && d.code != "" {
			revision, has := d.attempt_revision.?
			if !has ||
			   input.ready ||
			   revision > input.model_revision ||
			   revision < input.published_revision {return {}, .Metadata_Mismatch}
		}
	}
	has := input.frame != nil && len(input.frame.nodes) > 0
	if input.published_revision > input.model_revision ||
	   (!has && input.published_revision != 0) ||
	   (input.ready &&
			   (!has ||
					   input.model_revision !=
						   input.published_revision)) {return {}, .Metadata_Mismatch}
	if has &&
	   input.frame.stamp.model_revision != input.published_revision {return {}, .Metadata_Mismatch}
	if input.interaction != nil &&
	   (!has || input.interaction.stamp != input.frame.stamp) {return {}, .Metadata_Mismatch}
	for s, n in input.semantics {
		if !has || s.id == "" {return {}, .Metadata_Mismatch}
		if _, found := layout.find(input.frame, s.id); !found {return {}, .Metadata_Mismatch}
		for prior in input.semantics[:n] {if prior.id == s.id {return {}, .Metadata_Mismatch}}
	}
	r := Inspection {
		allocator          = a,
		ready              = input.ready,
		historical         = has && !input.ready,
		model_revision     = input.model_revision,
		published_revision = input.published_revision,
		capabilities       = input.capabilities,
	}
	complete := false
	defer {if !complete {destroy_inspection(&r)}}
	ok: bool
	if input.frame !=
	   nil {r.frame, ok = layout.try_copy_frame(input.frame, a); if !ok {return {}, .Allocation}}
	if input.interaction !=
	   nil {r.interaction, ok = interaction.try_copy_frame(input.interaction, a); if !ok {return {}, .Allocation}}
	e: mem.Allocator_Error
	r.focus_id, e = strings.clone(input.focus_id, a); if e != nil {return {}, .Allocation}
	r.hover_id, e = strings.clone(input.hover_id, a); if e != nil {return {}, .Allocation}
	r.pressed_id, e = strings.clone(input.pressed_id, a); if e != nil {return {}, .Allocation}
	r.children, e = make([][]int, len(r.frame.nodes), a); if e != nil {return {}, .Allocation}
	for n, k in r.frame.nodes {
		count := 0; for c in r.frame.nodes {if c.description.parent == n.description.id {count += 1}}
		r.children[k], e = make([]int, count, a); if e != nil {return {}, .Allocation}
		at := 0; for c, j in r.frame.nodes {if c.description.parent == n.description.id {r.children[k][at] = j; at += 1}}
	}
	r.semantics, e = make(
		[]Semantic,
		len(input.semantics),
		a,
	); if e != nil {return {}, .Allocation}
	for s, k in input.semantics {
		v := &r.semantics[k]
		v.id, e = strings.clone(s.id, a); if e != nil {return {}, .Allocation}
		v.role, e = strings.clone(s.role, a); if e != nil {return {}, .Allocation}
		v.name, e = strings.clone(s.name, a); if e != nil {return {}, .Allocation}
		v.source_hint, e = strings.clone(s.source_hint, a); if e != nil {return {}, .Allocation}
	}
	if !copy_diagnostics(&r, input.diagnostics) {return {}, .Allocation}
	complete = true
	return r, .None
}
destroy_inspection :: proc(i: ^Inspection) {
	for cs in i.children {delete(cs, i.allocator)}; delete(i.children, i.allocator)
	for s in i.semantics {for v in ([4]string{s.id, s.role, s.name, s.source_hint}) {delete(v, i.allocator)}}
	delete(i.semantics, i.allocator)
	for d in i.diagnostics {destroy_diagnostic(d, i.allocator)}
	delete(i.diagnostics, i.allocator); delete(i.offending_storage, i.allocator)
	delete(
		i.focus_id,
		i.allocator,
	); delete(i.hover_id, i.allocator); delete(i.pressed_id, i.allocator)
	layout.destroy_frame(&i.frame); interaction.destroy_frame(&i.interaction); i^ = {}
}
inspect :: proc(i: ^Inspection, id: string) -> (Node_View, Inspect_Error) {
	n, found := layout.find(&i.frame, id); if !found {return {}, .Not_Found}
	v := Node_View {
		resolved        = n,
		structural_role = n.description.role,
		role            = "container",
		focused         = i.focus_id == id,
		hovered         = i.hover_id == id,
		pressed         = i.pressed_id == id,
	}
	v.target, _ = interaction.find(&i.interaction, id)
	if v.target != nil && v.target.description.role != "" {v.role = v.target.description.role}
	for other, k in i.frame.nodes {
		if other.description.id == id {v.children = i.children[k]}
		if other.description.id == n.description.parent {v.parent_index = k}
	}
	for s in i.semantics {if s.id == id {
			if s.role != "" {v.role = s.role}; v.name, v.source_hint = s.name, s.source_hint; break
		}}
	return v, .None
}
find :: proc(i: ^Inspection, q: Query, a: mem.Allocator) -> ([]int, Inspect_Error) {
	if q.exact_string == "" || q.kind < .ID || q.kind > .Name {return nil, .Invalid_Query}
	r := make([dynamic]int, 0, 0, a)
	for n, k in i.frame.nodes {
		v, _ := inspect(i, n.description.id)
		value := n.description.id
		switch q.kind {case .ID:; case .Role:
			value = v.role; case .Name:
			value = v.name}
		if value ==
		   q.exact_string {if _, e := append(&r, k); e != nil {delete(r); return nil, .Allocation}}
	}
	return r[:], .None
}
action_status :: proc(i: ^Inspection, id: string, action: Action) -> Action_Status {
	if action < .Focus || action > .Hold_Cancel {return {code = .Invalid_Action}}
	r := Action_Status {
		capability = i.capabilities[action],
		code       = .Invalid_Action,
	}
	v, e := inspect(i, id)
	if action == .Focus ||
	   action ==
		   .Activate {r.suitable = e == .None && v.target != nil && v.target.description.role != ""}
	if action == .Navigate {r.suitable = true}
	if !r.capability {return r}; if !is_ready(i) {r.code = .Not_Ready; return r}
	if action == .Focus || action == .Activate {
		if e != .None {r.code = .Not_Found} else if v.target != nil {
			r.code = v.target.availability
			if action == .Activate &&
			   r.code == .Applied &&
			   v.target.activation_owner != "" {r.code = .Activation_Required}
		}
	} else if action ==
	   .Navigate {for target in i.interaction.targets {if target.availability == .Applied {r.code = .Applied; break}}}
	return r
}
