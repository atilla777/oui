package loader

import "core:testing"

@(test)
accepted_codec_pair_is_used_by_the_loader :: proc(t: ^testing.T) {
	testing.expect_value(t, string(png_get_libpng_ver(nil)), "1.6.59")
	testing.expect_value(t, png_access_version_number(), u32(10659))
	testing.expect_value(t, string(zlibVersion()), "1.4")
	testing.expect(t, runtime_versions_match(), "accepted pair must pass the production guard")
}
