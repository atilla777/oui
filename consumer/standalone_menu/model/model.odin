package model

Page :: enum {
	Main,
	Submenu,
}
Locale :: enum {
	English,
	Russian,
}
Intent :: enum {
	Action,
	Open,
	Language,
	Back,
}
Model :: struct {
	page:                     Page,
	locale:                   Locale,
	count, effects, revision: u64,
}
// The application, not the UI, owns and accepts these outcomes.
apply :: proc(m: ^Model, intent: Intent) -> bool {
	if m.effects == max(u64) || m.revision == max(u64) {return false}
	switch intent {
	case .Action:
		if m.page != .Main || m.count == max(u64) {return false}
		m.count += 1
	case .Open:
		if m.page != .Main {return false}
		m.page = .Submenu
	case .Language:
		if m.page != .Submenu {return false}
		if m.locale == .English {m.locale = .Russian} else {m.locale = .English}
	case .Back:
		if m.page != .Submenu {return false}
		m.page = .Main
	}
	m.effects += 1; m.revision += 1
	return true
}
