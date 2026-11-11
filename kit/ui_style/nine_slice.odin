package ui_style

import "core:math"

// Source rectangles are source pixels; destinations are snapped logical units.
// Consumers use nearest sampling and apply the node's paint clip, not a rescale.
Image_Patch :: struct {
	source, destination: Rect,
}
Slice_Result :: enum {
	Ok,
	Invalid_Metadata,
	Below_Minimum,
	Patch_Limit,
	Invalid_Scale,
	Invalid_Geometry,
	Allocation,
}

// Explicit opt-in only: no metadata padding is applied by styled update.
slice_padding :: proc(metadata: Nine_Slice_Metadata) -> Maybe(Insets) {return metadata.padding}
MAX_IMAGE_PATCHES :: 4096

// Caller owns the returned slice, including on failure (which returns no patches).
nine_slice_patches :: proc(
	image: Image_Metadata,
	area: Rect,
	ui_scale: f64,
	mode: Scale_Mode,
	allocator := context.allocator,
) -> (
	[]Image_Patch,
	Slice_Result,
) {
	if !valid_image_metadata(image) {return nil, .Invalid_Metadata}
	nine, has := image.nine_slice.?
	if !has {return nil, .Invalid_Metadata}
	if !finite_nonnegative(ui_scale) ||
	   ui_scale == 0 ||
	   (mode != .Normal && mode != .Pixel_Perfect) {return nil, .Invalid_Scale}
	for v in ([6]f64{area.x, area.y, area.x + area.w, area.y + area.h, area.x * ui_scale, area.y * ui_scale}) {
		if math.is_nan(v) || math.is_inf(v) {return nil, .Invalid_Geometry}
	}
	if !finite_nonnegative(area.w) ||
	   !finite_nonnegative(area.h) ||
	   !finite_nonnegative((area.x + area.w) * ui_scale - area.x * ui_scale) ||
	   !finite_nonnegative(
			   (area.y + area.h) * ui_scale - area.y * ui_scale,
		   ) {return nil, .Invalid_Geometry}
	l, top, r, b :=
		f64(nine.border[0]), f64(nine.border[1]), f64(nine.border[2]), f64(nine.border[3])
	s := nine.texture_scale
	product := s * ui_scale
	if mode == .Pixel_Perfect &&
	   (!finite_nonnegative(product) ||
			   product == 0 ||
			   math.round(product) != product) {return nil, .Invalid_Scale}
	if area.w < (l + r) * s || area.h < (top + b) * s {return nil, .Below_Minimum}
	sx := [4]f64{0, l, image.source.w - r, image.source.w}
	sy := [4]f64{0, top, image.source.h - b, image.source.h}
	dx := [4]f64{area.x, area.x + l * s, area.x + area.w - r * s, area.x + area.w}
	dy := [4]f64{area.y, area.y + top * s, area.y + area.h - b * s, area.y + area.h}
	for &x in dx {x = math.round(x * ui_scale) / ui_scale}
	for &y in dy {y = math.round(y * ui_scale) / ui_scale}
	patches: [dynamic]Image_Patch
	count := 0
	// First pass bounds the complete plan before allocation or emitting any patch.
	for pass in 0 ..< 2 {
		if pass == 1 {
			allocated, e := make([dynamic]Image_Patch, 0, count, allocator)
			if e != nil {return nil, .Allocation}
			patches = allocated
		}
		for y in 0 ..< 3 {for x in 0 ..< 3 {
				if x == 1 && y == 1 && nine.omit_center {continue}
				if dx[x + 1] <= dx[x] || dy[y + 1] <= dy[y] {continue}
				rx :=
					x == 1 &&
					((y == 1 && nine.center_x == .Repeat) || (y != 1 && nine.edges == .Repeat))
				ry :=
					y == 1 &&
					((x == 1 && nine.center_y == .Repeat) || (x != 1 && nine.edges == .Repeat))
				sw, sh := sx[x + 1] - sx[x], sy[y + 1] - sy[y]
				if sw <= 0 || sh <= 0 {continue}
				tw, th := dx[x + 1] - dx[x], dy[y + 1] - dy[y]
				if rx {tw = sw * s}; if ry {th = sh * s}
				cx, cy := math.ceil((dx[x + 1] - dx[x]) / tw), math.ceil((dy[y + 1] - dy[y]) / th)
				if pass == 0 {
					if !(cx * cy <= f64(MAX_IMAGE_PATCHES - count)) {return nil, .Patch_Limit}
					count += int(cx * cy)
					continue
				}
				nx, ny := int(cx), int(cy)
				for iy in 0 ..< ny {for ix in 0 ..< nx {
						x0, y0 := dx[x] + f64(ix) * tw, dy[y] + f64(iy) * th
						x1, y1 :=
							min(dx[x + 1], dx[x] + f64(ix + 1) * tw),
							min(dy[y + 1], dy[y] + f64(iy + 1) * th)
						w, h := sw, sh
						if rx {w = (x1 - x0) / s}; if ry {h = (y1 - y0) / s}
						dest := snap({x0, y0, x1 - x0, y1 - y0}, ui_scale)
						if dest.w > 0 &&
						   dest.h > 0 {append(&patches, Image_Patch{{sx[x], sy[y], w, h}, dest})}
					}}
			}}
	}
	return patches[:], .Ok
}
