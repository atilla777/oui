package app

import model "../model"
import "core:fmt"
import "core:os"
import "core:testing"

@(test)
c07_first_failed_publication_does_not_retain_new_transition_identity :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Catalogue) {return}
	fallback, e := os.read_entire_file("resources/fallback.ttf", context.allocator)
	if !testing.expect(t, e == nil) {return}; defer delete(fallback)
	exercise_content_boundary(t, f.renderer, f.font, fallback, .Rich_Text, .First_Rebuild, 500)
}

@(test)
g15_g21_each_owning_boundary_refuses_without_leaks_or_partial_publication :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Catalogue) {return}
	for page in ([]model.Page{.Composition, .Custom, .Transitions, .Accessibility, .World, .Diagnostics_Performance}) {
		for boundary in ([]Interaction_Boundary{.Entry, .Rebuild, .Copy}) {
			requests := exercise_interaction_boundary(t, f.renderer, f.font, page, boundary, 0)
			fmt.printf(
				"G15-G21 allocation page=%v boundary=%v requests=%d\n",
				page,
				boundary,
				requests,
			)
			for refusal in 1 ..= requests {exercise_interaction_boundary(t, f.renderer, f.font, page, boundary, refusal)}
		}
	}
}

@(test)
c07_each_added_rich_owning_allocation_refusal :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Catalogue) {return}
	fallback, e := os.read_entire_file("resources/fallback.ttf", context.allocator)
	if !testing.expect(t, e == nil) {return}; defer delete(fallback)
	for boundary in ([]Content_Allocation_Boundary{.Init, .First_Rebuild, .Rebuild, .Scale}) {
		requests := exercise_content_boundary(
			t,
			f.renderer,
			f.font,
			fallback,
			.Rich_Text,
			boundary,
			0,
		)
		fmt.printf("C07 allocation boundary=%v requests=%d\n", boundary, requests)
		for refusal in 1 ..= requests {exercise_content_boundary(t, f.renderer, f.font, fallback, .Rich_Text, boundary, refusal)}
	}
}
