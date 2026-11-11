package ui_testing
import "core:testing"
@(test)
ordinary_testing_keeps_public_event_outcome_oracle :: proc(t: ^testing.T) {
	expect_event(
		t,
		{
			dispatch = {
				code = .Applied,
				event = {id = "button", source = .Agent, sequence = 7},
				has_event = true,
			},
			outcome = .Applied,
		},
		{target = "button", source = .Agent, sequence = 7, outcome = .Applied},
	)
}
