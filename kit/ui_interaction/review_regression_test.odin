package ui_interaction

import base "../ui_base"
import layout "../ui_layout"
import "core:mem"
import "core:testing"

review_geometry :: proc(t: ^testing.T, p: ^base.Publication, a: mem.Allocator) -> layout.Frame {
	nodes := [1]layout.Node {
		{
			id = "button",
			role = .Box,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 20},
				y = {mode = .Fixed, value = 20},
			},
			enabled = true,
			visible = true,
		},
	}
	f, e := layout.prepare(nodes[:], {drawable = {100, 100}, ui_scale = 1}, {}, a, p.published)
	testing.expect(t, e.code == .None)
	return f
}

@(test)
duplicate_targets_conflict_releases_every_owned_role_IMPL_001 :: proc(t: ^testing.T) {
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(&live, context.allocator)
	defer mem.tracking_allocator_destroy(&live)
	a := mem.tracking_allocator(&live)
	p, pe := base.create(a); defer base.destroy(&p)
	if !testing.expect(t, pe == .None) {return}
	ctx := create(a, &p); defer destroy(&ctx)
	targets := [2]Target {
		{"button", "first-role", true, true},
		{"button", "second-role", true, true},
	}
	if !testing.expect(t, publish_fixture(&ctx, targets[:1]) == .Applied) {return}
	geometry := review_geometry(t, &p, a); defer layout.destroy_frame(&geometry)
	before, allocations, refs :=
		live.current_memory_allocated, len(live.allocation_map), p.lifetime.references
	published, sequence := p.published, p.sequence
	c, code := prepare(&geometry, targets[:], nil, a)
	destroy_candidate(&c)
	testing.expect(t, code == .Conflict && c.stamp.lifetime == nil)
	testing.expect(
		t,
		live.current_memory_allocated == before && len(live.allocation_map) == allocations,
		"IMPL-001: rejected duplicate targets must release every owning role",
	)
	testing.expect(
		t,
		p.lifetime.references == refs &&
		p.published == published &&
		p.sequence == sequence &&
		ready(&ctx),
	)
	n, found := find(&ctx.frame, "button")
	testing.expect(t, found && n.description.role == "first-role")
	layout.destroy_frame(&geometry); destroy(&ctx); base.destroy(&p)
	testing.expect(
		t,
		live.current_memory_allocated == 0 &&
		len(live.allocation_map) == 0 &&
		len(live.bad_free_array) == 0,
		"IMPL-001: complete destroy must leave no allocation",
	)
}

// Existing guards: regression-only, not a claim of a historical RED cycle.
@(test)
invalid_kind_and_claim_identifiers_preserve_state_IMPL_002 :: proc(t: ^testing.T) {
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&live,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&live)
	a := mem.tracking_allocator(&live)
	p, _ := base.create(a); defer base.destroy(&p)
	ctx := create(a, &p); defer destroy(&ctx)
	targets := [1]Target{{"button", "button", true, true}}
	if !testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied) {return}
	geometry := review_geometry(t, &p, a); defer layout.destroy_frame(&geometry)
	before, allocations, refs :=
		live.current_memory_allocated, len(live.allocation_map), p.lifetime.references
	published, sequence := p.published, p.sequence
	r := dispatch(&ctx, {Action_Kind(99), "button", .Agent, false})
	testing.expect(
		t,
		r.code == .Invalid_Action &&
		!r.has_event &&
		ready(&ctx) &&
		p.published == published &&
		p.sequence == sequence,
	)
	for test in ([]struct {
			claim:    Capture_Claim,
			expected: Code,
		}{{{"", "owner"}, .Conflict}, {{"button", ""}, .Conflict}, {{"missing", "owner"}, .Not_Found}}) {
		claims := [1]Capture_Claim{test.claim}
		c, code := prepare(&geometry, targets[:], claims[:], a)
		destroy_candidate(&c)
		testing.expect(t, code == test.expected && c.stamp.lifetime == nil)
		testing.expect(
			t,
			live.current_memory_allocated == before &&
			len(live.allocation_map) == allocations &&
			p.lifetime.references == refs,
		)
		testing.expect(t, p.published == published && p.sequence == sequence && ready(&ctx))
	}
}
