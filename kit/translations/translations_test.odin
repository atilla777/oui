package translations

import "core:mem"
import "core:testing"

@(test)
catalog_and_results_borrow_without_allocating :: proc(t: ^testing.T) {
	languages := []string{"ru", "en"}
	texts := []string{"Текст", "Text"}
	entries := []Entry{{"key", texts}}
	tracker, temp_tracker: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracker, context.allocator)
	defer mem.tracking_allocator_destroy(&tracker)
	mem.tracking_allocator_init(&temp_tracker, context.temp_allocator)
	defer mem.tracking_allocator_destroy(&temp_tracker)
	previous := context
	context.allocator = mem.tracking_allocator(&tracker)
	context.temp_allocator = mem.tracking_allocator(&temp_tracker)
	result := init(languages, entries)
	catalog, ok := result.(Catalog)
	borrowed :=
		ok &&
		raw_data(catalog.languages) == raw_data(languages) &&
		raw_data(catalog.entries) == raw_data(entries)
	correct := true
	for _ in 0 ..< 1000 {
		text, found := lookup(catalog, "key", "ru").(string)
		correct = correct && found && text == "Текст" && raw_data(text) == raw_data(texts[0])
		_, complete := validate_complete(catalog).(Complete)
		correct = correct && complete
	}
	context = previous
	testing.expect(t, borrowed && correct)
	testing.expect(
		t,
		tracker.total_allocation_count == 0 && temp_tracker.total_allocation_count == 0,
	)
}

@(test)
explicit_keys_languages_and_unchanged_text :: proc(t: ^testing.T) {
	languages := []string{"ru", "en", "ja"}
	entries := []Entry {
		{
			"demo.action",
			[]string{"  Продолжить 👩‍💻 é\n", "Continue", "続行"},
		},
		{"demo.action.short", []string{"Далее", "Go", "次"}},
	}
	catalog, ok := init(languages, entries).(Catalog)
	if !testing.expect(t, ok) {return}
	testing.expect(
		t,
		lookup(catalog, "demo.action", "ru") ==
		Lookup_Result("  Продолжить 👩‍💻 é\n"),
	)
	testing.expect(t, lookup(catalog, "demo.action", "en") == Lookup_Result("Continue"))
	testing.expect(
		t,
		lookup(catalog, "demo.action", "ru") ==
		Lookup_Result("  Продолжить 👩‍💻 é\n"),
	)
	testing.expect(t, lookup(catalog, "demo.action.short", "ru") == Lookup_Result("Далее"))
	testing.expect(t, lookup(catalog, "demo.action.short", "en") == Lookup_Result("Go"))
	testing.expect(t, lookup(catalog, "demo.action", "ja") == Lookup_Result("続行"))
}

@(test)
lookup_errors_are_exclusive_and_language_has_priority :: proc(t: ^testing.T) {
	catalog, ok := init(
		[]string{"ru", "en"},
		[]Entry{{"known", []string{"Есть", ""}}},
	).(Catalog)
	if !testing.expect(t, ok) {return}
	cases := []struct {
		key, language: string,
		error:         Lookup_Error,
	} {
		{"known", "fr", .Unsupported_Language},
		{"absent", "fr", .Unsupported_Language},
		{"absent", "ru", .Unknown_Key},
		{"known", "en", .Missing_Translation},
		{"Known", "ru", .Unknown_Key},
		{"known", "RU", .Unsupported_Language},
		{"", "ru", .Unknown_Key},
		{"known", "", .Unsupported_Language},
	}
	for item in cases {
		result := lookup(catalog, item.key, item.language)
		error, is_error := result.(Lookup_Error)
		testing.expect(t, is_error && error == item.error)
		_, has_text := result.(string)
		testing.expect(t, !has_text, "an error must not carry fallback text")
	}
}

@(test)
init_rejects_ambiguous_or_malformed_structure :: proc(t: ^testing.T) {
	cases := []struct {
		languages: []string,
		entries:   []Entry,
		kind:      Init_Error_Kind,
	} {
		{[]string{""}, nil, .Empty_Language},
		{[]string{"ru", "ru"}, nil, .Duplicate_Language},
		{[]string{"ru"}, []Entry{{"", []string{"text"}}}, .Empty_Key},
		{[]string{"ru"}, []Entry{{"key", []string{"a"}}, {"key", []string{"b"}}}, .Duplicate_Key},
		{[]string{"ru", "en"}, []Entry{{"key", []string{"text"}}}, .Invalid_Translation_Count},
		{[]string{"ru"}, []Entry{{"key", []string{"a", "b"}}}, .Invalid_Translation_Count},
		{[]string{"ru"}, []Entry{{"key", nil}}, .Invalid_Translation_Count},
	}
	for item in cases {
		result := init(item.languages, item.entries)
		error, ok := result.(Init_Error)
		testing.expect(t, ok && error.kind == item.kind)
		_, usable := result.(Catalog)
		testing.expect(t, !usable)
	}
	// Comparisons are exact: case and Unicode normalization are not folded.
	_, ok := init(
		[]string{"ru", "RU"},
		[]Entry{{"é", []string{"a", "b"}}, {"é", []string{"c", "d"}}},
	).(Catalog)
	testing.expect(t, ok)
}

@(test)
completeness_reports_first_empty_cell_in_dictionary_order :: proc(t: ^testing.T) {
	catalog, ok := init(
		[]string{"ru", "en"},
		[]Entry{{"first", []string{"Первый", ""}}, {"second", []string{"", "Second"}}},
	).(Catalog)
	if !testing.expect(t, ok, "init allows incomplete resources") {return}
	problem, incomplete := validate_complete(catalog).(Completeness_Error)
	testing.expect(t, incomplete && problem == Completeness_Error{"first", "en"})
	second, _ := init([]string{"ru", "en"}, []Entry{{"second", []string{"", "Second"}}}).(Catalog)
	problem, incomplete = validate_complete(second).(Completeness_Error)
	testing.expect(t, incomplete && problem == Completeness_Error{"second", "ru"})
	full, _ := init([]string{"ru", "en"}, []Entry{{"space", []string{" ", "\t"}}}).(Catalog)
	_, complete := validate_complete(full).(Complete)
	testing.expect(t, complete, "whitespace is preserved, not treated as empty")
	empty, _ := init(nil, nil).(Catalog)
	_, complete = validate_complete(empty).(Complete)
	testing.expect(t, complete, "no pairs require translations in an empty dictionary")
	testing.expect(
		t,
		lookup(empty, "any", "ru") == Lookup_Result(Lookup_Error.Unsupported_Language),
	)
}
