package loader

import "core:testing"

valid_rgba_fixture :: proc() -> [74]u8 {
	return [74]u8 {
		137,
		80,
		78,
		71,
		13,
		10,
		26,
		10,
		0,
		0,
		0,
		13,
		73,
		72,
		68,
		82,
		0,
		0,
		0,
		2,
		0,
		0,
		0,
		2,
		8,
		6,
		0,
		0,
		0,
		114,
		182,
		13,
		36,
		0,
		0,
		0,
		17,
		73,
		68,
		65,
		84,
		120,
		156,
		99,
		248,
		207,
		192,
		240,
		31,
		132,
		65,
		8,
		12,
		1,
		69,
		204,
		7,
		249,
		202,
		39,
		25,
		207,
		0,
		0,
		0,
		0,
		73,
		69,
		78,
		68,
		174,
		66,
		96,
		130,
	}
}
@(test)
png_valid_rgba_owns_exact_top_down_pixels_and_rejects_every_truncation :: proc(t: ^testing.T) {
	b := valid_rgba_fixture()
	image, e := decode_png(b[:])
	if !testing.expect(t, e.stage == "", "valid RGBA PNG must decode") {return}
	defer destroy_decoded(&image)
	testing.expect(t, image.width == 2 && image.height == 2 && len(image.pixels) == 16)
	for expected, i in ([]u8{255, 0, 0, 255, 255, 0, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255}) {testing.expect_value(t, image.pixels[i], expected)}
	for n in 0 ..< len(b) {
		bad, err := decode_png(b[:n])
		testing.expect(t, err.stage != "" && len(bad.pixels) == 0)
		destroy_decoded(&bad)
	}
}
