package app

import "core:testing"

@(test)
tools_launch_requires_explicit_profile_build_and_clock_permission :: proc(t: ^testing.T) {
	// The ordinary entrypoint must keep rejecting these flags. A selected tools
	// composition may run without an endpoint, but cannot imply a profile.
	base := []string{"--font", "provided.ttf", "--ui-debug", "--ui-profile", "showcase-v19"}
	_, accepted := parse_options(base)
	allowed :: #config(UI_SHOWCASE_TOOLS, false) && (ODIN_DEBUG || #config(UI_DEMO_TEST, false))
	testing.expect(t, accepted == allowed, "tools launch gate/profile contract")
	_, clock := parse_options(
		[]string {
			"--font",
			"provided.ttf",
			"--ui-debug",
			"--ui-profile",
			"showcase-v19",
			"--test-time",
		},
	)
	testing.expect(
		t,
		clock == (allowed && #config(UI_DEMO_TEST, false)),
		"test clock needs separate compile permission",
	)
	for args in ([][]string{{"--font", "provided.ttf", "--ui-debug"}, {"--font", "provided.ttf", "--ui-profile", "showcase-v19"}, {"--font", "provided.ttf", "--test-time"}, {"--font", "provided.ttf", "--ui-debug", "--ui-profile", "unknown"}, {"--font", "provided.ttf", "--ui-debug", "--ui-profile", "showcase-v19", "--ui-debug"}}) {
		_, ok := parse_options(args)
		testing.expect(
			t,
			!ok,
			"partial/unknown/duplicate tools options must fail before resources",
		)
	}
}
