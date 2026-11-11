package ui_composition

import layout "../ui_layout"
import style "../ui_style"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"

Node :: struct {
	node:       layout.Node,
	appearance: style.Appearance,
}
Slot :: struct {
	name:       string,
	nodes:      []Node,
	appearance: style.Appearance,
}
Error :: enum {
	None,
	Invalid_Namespace,
	Invalid_Slot,
	Invalid_Tree,
	Allocation,
}
Composition :: struct {
	nodes:     []Node,
	allocator: mem.Allocator,
	storage:   ^mem.Rollback_Stack,
}
compose_panel :: proc(
	namespace, parent: string,
	geometry: layout.Layout,
	appearance: style.Appearance,
	slots: []Slot,
	allocator := context.allocator,
) -> (
	Composition,
	Error,
) {
	if namespace == "" {return {}, .Invalid_Namespace}
	count := 4
	for s, i in slots {
		if s.name != "title" &&
		   s.name != "content" &&
		   s.name != "footer" {return {}, .Invalid_Slot}
		for prior in slots[:i] {if prior.name == s.name {return {}, .Invalid_Slot}}
		if len(s.nodes) > max(int) - count {return {}, .Allocation}
		count += len(s.nodes)
		for n, j in s.nodes {
			if n.node.id == "" {return {}, .Invalid_Tree}
			for prior in s.nodes[:j] {if prior.node.id == n.node.id {return {}, .Invalid_Tree}}
			cursor := n.node.parent
			for depth := 0; cursor != ""; depth += 1 {
				if depth >= len(s.nodes) {return {}, .Invalid_Tree}
				found := false
				for candidate in s.nodes {if candidate.node.id == cursor {cursor = candidate.node.parent; found = true; break}}
				if !found {return {}, .Invalid_Tree}
			}
		}
	}
	c := Composition {
		allocator = allocator,
	}
	complete := false; defer {if !complete {destroy(&c)}}
	ae: mem.Allocator_Error
	c.storage, ae = new(mem.Rollback_Stack, allocator); if ae != nil {return {}, .Allocation}
	if mem.rollback_stack_init_dynamic(c.storage, 4096, allocator) != nil {return {}, .Allocation}
	a := mem.rollback_stack_allocator(c.storage)
	c.nodes, ae = make([]Node, count, a); if ae != nil {return {}, .Allocation}
	root, re := root_id(namespace, a); if re != nil {return {}, .Allocation}
	if root == parent {return {}, .Invalid_Tree}
	c.nodes[0], ae = clone_node(
		{
			node = {
				id = root,
				parent = parent,
				role = .Column,
				layout = geometry,
				enabled = true,
				visible = true,
			},
			appearance = appearance,
		},
		a,
	)
	if ae != nil {return {}, .Allocation}
	k := 1
	for name in ([]string{"title", "content", "footer"}) {
		s := Slot {
			name = name,
		}
		for input in slots {if input.name == name {s = input; break}}
		sid, se := slot_id(namespace, name, a); if se != nil {return {}, .Allocation}
		if parent == sid {return {}, .Invalid_Tree}
		c.nodes[k], ae = clone_node(
			{
				node = {
					id = sid,
					parent = root,
					role = .Column,
					layout = layout.Layout{},
					enabled = true,
					visible = true,
				},
				appearance = s.appearance,
			},
			a,
		)
		if ae != nil {return {}, .Allocation}; k += 1
		for input in s.nodes {
			n := input
			n.node.id, ae = node_id(
				namespace,
				name,
				input.node.id,
				a,
			); if ae != nil {return {}, .Allocation}
			if n.node.id == parent {return {}, .Invalid_Tree}
			n.node.parent = sid
			if input.node.parent !=
			   "" {n.node.parent, ae = node_id(namespace, name, input.node.parent, a); if ae != nil {return {}, .Allocation}}
			c.nodes[k], ae = clone_node(n, a); if ae != nil {return {}, .Allocation}; k += 1
		}
	}
	complete = true
	return c, .None
}
node_id :: proc(
	namespace, slot, local: string,
	a := context.allocator,
) -> (
	string,
	mem.Allocator_Error,
) {
	b1, b2, b3: [32]u8
	return strings.concatenate(
		[]string {
			"node:",
			fmt.bprintf(b1[:], "%d:", len(namespace)),
			namespace,
			fmt.bprintf(b2[:], "%d:", len(slot)),
			slot,
			fmt.bprintf(b3[:], "%d:", len(local)),
			local,
		},
		a,
	)
}
root_id :: proc(namespace: string, a := context.allocator) -> (string, mem.Allocator_Error) {
	b: [32]u8
	return strings.concatenate(
		[]string{"root:", fmt.bprintf(b[:], "%d:", len(namespace)), namespace},
		a,
	)
}
slot_id :: proc(namespace, slot: string, a := context.allocator) -> (string, mem.Allocator_Error) {
	b1, b2: [32]u8
	return strings.concatenate(
		[]string {
			"slot:",
			fmt.bprintf(b1[:], "%d:", len(namespace)),
			namespace,
			fmt.bprintf(b2[:], "%d:", len(slot)),
			slot,
		},
		a,
	)
}
clone_node :: proc(n: Node, a: mem.Allocator) -> (r: Node, e: mem.Allocator_Error) {
	r.node = layout.try_clone_description(n.node, a) or_return
	r.appearance.style_id = strings.clone(n.appearance.style_id, a) or_return
	for state in style.Visual_State {
		r.appearance.local.states[state] = slice.clone(
			n.appearance.local.states[state],
			a,
		) or_return
		for &d in r.appearance.local.states[state] {d.value = style.clone_value(d.value, a) or_return}
	}
	return r, nil
}
destroy :: proc(c: ^Composition) {
	if c.storage != nil {mem.rollback_stack_destroy(c.storage); free(c.storage, c.allocator)}
	c^ = {}
}
try_copy :: proc(source: ^Composition, allocator := context.allocator) -> (Composition, Error) {
	c := Composition {
		allocator = allocator,
	}
	complete := false; defer {if !complete {destroy(&c)}}
	ae: mem.Allocator_Error
	c.storage, ae = new(mem.Rollback_Stack, allocator); if ae != nil {return {}, .Allocation}
	if mem.rollback_stack_init_dynamic(c.storage, 4096, allocator) != nil {return {}, .Allocation}
	a := mem.rollback_stack_allocator(c.storage)
	c.nodes, ae = make([]Node, len(source.nodes), a); if ae != nil {return {}, .Allocation}
	for n, i in source.nodes {c.nodes[i], ae = clone_node(n, a); if ae != nil {return {}, .Allocation}}
	complete = true
	return c, .None
}
