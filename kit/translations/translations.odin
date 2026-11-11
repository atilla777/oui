package translations

// texts follows the exact language order passed to init; an empty cell is missing.
Entry :: struct {
	key:   string,
	texts: []string,
}

// Borrowed view. Obtain through init, not a struct literal. All backing arrays,
// keys and strings must remain alive and immutable while this or returned text
// is used. No destroy: the caller retains ownership of every byte.
Catalog :: struct {
	languages: []string,
	entries:   []Entry,
}

Init_Error_Kind :: enum {
	Empty_Language,
	Duplicate_Language,
	Empty_Key,
	Duplicate_Key,
	Invalid_Translation_Count,
}

Init_Error :: struct {
	kind:          Init_Error_Kind,
	key, language: string,
}

Lookup_Error :: enum {
	Unsupported_Language,
	Unknown_Key,
	Missing_Translation,
}
Lookup_Result :: union {
	string,
	Lookup_Error,
}
Init_Result :: union {
	Catalog,
	Init_Error,
}
Complete :: struct {}
Completeness_Error :: struct {
	key, language: string,
}
Validation_Result :: union {
	Complete,
	Completeness_Error,
}

// Checks structure only, not completeness. Empty lists are allowed; identifiers
// are compared exactly. Failure returns no Catalog. Does not allocate or copy.
init :: proc(languages: []string, entries: []Entry) -> Init_Result {
	for language, i in languages {
		if len(language) == 0 {return Init_Error{kind = .Empty_Language}}
		for previous in languages[:i] {
			if previous == language {
				return Init_Error{kind = .Duplicate_Language, language = language}
			}
		}
	}
	for entry, i in entries {
		if len(entry.key) == 0 {return Init_Error{kind = .Empty_Key}}
		for previous in entries[:i] {
			if previous.key == entry.key {
				return Init_Error{kind = .Duplicate_Key, key = entry.key}
			}
		}
		if len(entry.texts) != len(languages) {
			return Init_Error{kind = .Invalid_Translation_Count, key = entry.key}
		}
	}
	return Catalog{languages, entries}
}

// Requires a successfully initialized, unmodified catalog. No allocation,
// normalization, trimming, fallback, formatting or implicit language selection.
// Error priority: language, key, cell. A failure has no string variant.
lookup :: proc(catalog: Catalog, key, language: string) -> Lookup_Result {
	for candidate, i in catalog.languages {
		if candidate != language {continue}
		for entry in catalog.entries {
			if entry.key == key {
				if len(entry.texts[i]) == 0 {return Lookup_Error.Missing_Translation}
				return entry.texts[i]
			}
		}
		return Lookup_Error.Unknown_Key
	}
	return Lookup_Error.Unsupported_Language
}

// Requires a successfully initialized, unmodified catalog. Returns the first
// empty cell in entry order, then language order, without allocating.
validate_complete :: proc(catalog: Catalog) -> Validation_Result {
	for entry in catalog.entries {
		for text, i in entry.texts {
			if len(text) == 0 {return Completeness_Error{entry.key, catalog.languages[i]}}
		}
	}
	return Complete{}
}
