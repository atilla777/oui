package ui_layout

import base "../ui_base"
import "core:testing"

fixed :: proc(n: f64) -> Axis_Size {return {mode = .Fixed, value = n}}
fill :: proc() -> Axis_Size {return {mode = .Fill}}
node :: proc(id, parent: string, role: Kind, l: Layout) -> Node {return {
		id,
		parent,
		role,
		l,
		true,
		true,
	}}

@(test)
grid_characterization_and_reader_copy :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	rows := [1]Track{{mode = .Fixed, value = 50}}
	columns := [2]Track{{mode = .Fixed, value = 20}, {mode = .Fixed, value = 120}}
	nodes := [2]Node {
		node(
			"grid",
			"",
			.Grid,
			{x = fill(), y = fill(), rows = rows[:], columns = columns[:], gap = 5},
		),
		node("child", "grid", .Box, {x = fixed(10), y = fixed(10)}),
	}
	f, e := prepare(nodes[:], {drawable = {100, 100}, ui_scale = 1}, {}, context.allocator, s)
	if !testing.expect(t, e.code == .None) {return}
	defer destroy_frame(&f)
	n, found := find(&f, "grid")
	testing.expect(t, found && n.columns[0] == 20 && n.columns[1] == 120)
	found = false
	for d in f.diagnostics {if d.id == "grid" && d.required == (Extent{145, 50}) && d.available == (Extent{100, 100}) {found = true}}
	testing.expect(t, found, "unoccupied fixed track overflow must not shrink")
	reader, copied := try_copy_frame(&f, context.allocator)
	if !testing.expect(t, copied, "owning reader must copy geometry") {return}
	defer destroy_frame(&reader)
	destroy_frame(&f)
	n, found = find(&reader, "grid")
	testing.expect(t, found && n.columns[1] == 120)
}

@(test)
validation_grid_limits_scale_and_clipping_characterization :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 0)
	options := Layout_Options {
		drawable = {100, 100},
		ui_scale = 1,
	}
	valid := [3]Node {
		node("root", "", .Stack, {x = fill(), y = fill()}),
		node("a", "root", .Box, {x = fixed(200), y = fixed(20)}),
		node("b", "root", .Box, {x = fixed(10), y = fixed(10)}),
	}
	for variant in 0 ..< 7 {
		nodes := valid
		expected := Error_Code.None
		switch variant {
		case 0:
			nodes[1].id = "root"; expected = .Duplicate_ID
		case 1:
			nodes[1].parent = "missing"; expected = .Missing_Parent
		case 2:
			nodes[1].parent = "b"; nodes[2].parent = "a"; expected = .Invalid_Tree
		case 3:
			nodes[1].layout = Layout {
				x = fixed(-1),
			}; expected = .Invalid_Layout
		case 4:
			nodes[0].role = .Grid; expected = .Invalid_Grid
		case 5:
			nodes[1].visible = false
		case 6:
		}
		f, e := prepare(nodes[:], options, {}, context.allocator, s)
		testing.expect(t, e.code == expected)
		if variant == 6 && e.code == .None {
			n, _ := find(&f, "a")
			testing.expect(t, n.bounds.w == 200 && n.paint_clip.w == 100 && len(f.diagnostics) > 0)
		}
		destroy_frame(&f)
	}
	for variant in 0 ..< 4 {
		o := options; expected := Error_Code.Invalid_Scale
		switch variant {
		case 0:
			o.ui_scale = 0
		case 1:
			o.ui_scale = 1.5; o.scale_mode = .Pixel_Perfect; expected = .Unsupported_Scale_Mode
		case 2:
			o.safe_area = Rect{90, 0, 20, 10}; expected = .Invalid_Safe_Area
		case 3:
			o.drawable.w = transmute(f64)u64(0x7ff8000000000000); expected = .Invalid_Size
		}
		f, e := prepare(valid[:], o, {}, context.allocator, s); destroy_frame(&f)
		testing.expect(t, e.code == expected)
	}
}

@(test)
row_flex_safe_area_and_addressed_refusal :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 0)
	nodes := [3]Node {
		node("row", "", .Row, {x = fill(), y = fill(), gap = 10}),
		node("a", "row", .Box, {x = {mode = .Fill, max = f64(30)}, y = fixed(20)}),
		node("b", "row", .Box, {x = fill(), y = fixed(20)}),
	}
	f, e := prepare(
		nodes[:],
		{{240, 120}, 2, .Normal, Rect{20, 10, 200, 100}},
		{},
		context.allocator,
		s,
	)
	if !testing.expect(t, e.code == .None) {return}
	defer destroy_frame(&f)
	a, _ := find(&f, "a"); b, _ := find(&f, "b")
	testing.expect(t, a.bounds == Rect{10, 5, 30, 20} && b.bounds == Rect{50, 5, 60, 20})
	nodes[2].role = .Content
	bad, error := prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	defer destroy_frame(&bad)
	testing.expect(t, error.code == .Metrics_Failed && error.id == "b")
}
