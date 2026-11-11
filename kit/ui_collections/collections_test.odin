package ui_collections

import "core:testing"

@(test)
copy_retains_immutable_metadata_after_source_destroy :: proc(t: ^testing.T) {
	items := [1]Collection_Item{{"a", "Я", true, true, ""}}
	f, e := prepare_collection(fixture_description(items[:]), {w = 100, h = 20}, 0)
	if !testing.expect(t, e.code == .None) {return}
	items[0].semantic_name = "changed"
	r, copied := try_copy_frame(&f)
	destroy_frame(&f)
	defer destroy_frame(&r)
	if !testing.expect(t, copied) {return}
	v, code := lookup_collection_item(&r, "list", "a")
	testing.expect(t, code == .Applied && v.item.semantic_name == "Я")
}

@(test)
uniform_grid_gaps_identity_and_disabled_overscan :: proc(t: ^testing.T) {
	items := [4]Collection_Item {
		{"a", "Same", true, true, ""},
		{"b", "Same", true, false, "locked"},
		{"h", "Hidden", false, false, "hidden"},
		{"c", "Same", true, true, ""},
	}
	d := Collection_Description {
		id            = "list",
		scroll_id     = "scroll",
		content_id    = "content",
		mode          = .Grid,
		items         = items[:],
		selected_id   = "b",
		height        = 10,
		card_width    = 10,
		gap           = 2,
		overscan_rows = 1,
	}
	f, e := prepare_collection(d, {x = 5, y = 7, w = 3, h = 10}, 0)
	defer destroy_frame(&f)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		f.collections[0].columns == 1 && f.nodes[0].bounds.w == 10 && f.nodes[0].clip.w == 3,
	)
	v, code := lookup_collection_item(&f, "list", "b")
	testing.expect(
		t,
		code == .Applied &&
		v.selected &&
		v.materialized &&
		!v.in_viewport &&
		f.nodes[1].availability == .Not_Visible,
	)
	d.mode = .List; d.overscan_rows = 0
	gap, ge := prepare_collection(d, {w = 100, h = 1}, 10.5)
	defer destroy_frame(&gap)
	testing.expect(
		t,
		ge.code == .None &&
		gap.collections[0].visible_start == 1 &&
		gap.collections[0].visible_end == 1 &&
		len(gap.nodes) == 0,
	)
	d.data_revision = 1; items[0], items[1] = items[1], items[0]
	g, re := prepare_collection(d, {w = 24, h = 30}, 0, previous = &f)
	defer destroy_frame(&g)
	if !testing.expect(t, re.code == .None) {return}
	w, wc := lookup_collection_item(&g, "list", "b")
	testing.expect(
		t,
		wc == .Applied &&
		w.logical_ordinal == 0 &&
		g.nodes[w.node_index.?].description.id == f.nodes[v.node_index.?].description.id,
	)
}
