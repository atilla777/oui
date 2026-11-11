package showcase_model

// gallery-f479-v1: process-lifetime metadata, never a runtime plugin registry.
Section :: struct {
	id:                                         string,
	page:                                       Page,
	capabilities, fixture, status, limitations: string,
}
SECTIONS :: [?]Section {
	{
		"layout",
		.Layout,
		"G01 G02",
		"layout-geometry / layout-viewport",
		"experimental",
		"No wrap, span or auto-placement",
	},
	{
		"controls",
		.Controls,
		"G03",
		"controlled-values",
		"experimental",
		"Controlled values; slider 0..100 / 1",
	},
	{
		"profiles",
		.Profiles,
		"G04",
		"profile-workflow",
		"experimental",
		"Process-local draft/applied; no disk persistence",
	},
	{
		"styling",
		.Styling,
		"G05",
		"theme-states",
		"experimental",
		"Existing primitives and theme cascade only",
	},
	{
		"atlas",
		.Atlas,
		"G06",
		"atlas-reload",
		"experimental",
		"Manifest v1; RGB8/RGBA8 noninterlaced PNG; explicit reload",
	},
	{
		"text",
		.Text,
		"G07",
		"localized-paragraph",
		"experimental",
		"65536 bytes / 4096 lines; no shaping or bidi",
	},
	{
		"rich-text",
		.Rich_Text,
		"G08",
		"rich-card",
		"experimental",
		"Existing rich grammar/fonts; not HTML or editable rich",
	},
	{
		"text-input",
		.Text_Input,
		"G09",
		"name-editor",
		"experimental",
		"Single line; Unicode 15.1 EGC; no IME/undo/normalization",
	},
	{
		"scroll-table",
		.Scroll_Table,
		"G10",
		"ordinary-table",
		"experimental",
		"Vertical non-nested scroll; three Fixed tracks",
	},
	{
		"collections",
		.Collections,
		"G11",
		"virtual-list-grid",
		"experimental",
		"Uniform geometry; one offset owner",
	},
	{
		"layers",
		.Layers,
		"G12",
		"nested-scopes",
		"experimental",
		"Explicit modal/popup scopes; tooltip noninteractive",
	},
	{
		"hud",
		.Hud,
		"G13",
		"hold-progress",
		"experimental",
		"Hold 1000 ms; Activate cannot bypass hold",
	},
	{
		"gestures",
		.Gestures,
		"G14",
		"cards-repeat-pan",
		"experimental",
		"No inertia; proposal is not application move",
	},
	{
		"composition",
		.Composition,
		"G15",
		"nested-route",
		"experimental",
		"Callbacks record intentions; no reentry",
	},
	{
		"custom",
		.Custom,
		"G16",
		"two-panels-circle",
		"experimental",
		"Two namespaced recipes; pure circle hit",
	},
	{
		"transitions",
		.Transitions,
		"G17",
		"card-presence",
		"experimental",
		"Frozen paint/hit; no layout animation",
	},
	{
		"accessibility",
		.Accessibility,
		"G18",
		"assessment-confirm",
		"experimental",
		"Warning/Unassessed are not conformance",
	},
	{"world", .World, "G19", "anchors", "experimental", "Application owns camera; no Game Bridge"},
	{
		"diagnostics-performance",
		.Diagnostics_Performance,
		"G20 G21",
		"diagnostics / editor-collection-costs",
		"experimental",
		"No debugger transport, GPU time or numerical SLA",
	},
}
section_page :: proc(id: string) -> (Page, bool) {
	if id == "catalogue" {return .Catalogue, true}
	for section in SECTIONS {if section.id == id {return section.page, true}}
	for section in LAB_SECTIONS {if section.id == id {return section.page, true}}
	return {}, false
}

// F4 is a separate consumer group, not an amendment to frozen gallery-f479-v1.
LAB_SECTIONS :: [?]Section {
	{
		"lab-menu",
		.Lab_Menu,
		"Lab",
		"menu-settings",
		"experimental",
		"Mock settings; process-local",
	},
	{
		"lab-settings",
		.Lab_Settings,
		"Lab",
		"settings-direct",
		"experimental",
		"Single-line name; no IME",
	},
	{"lab-hud", .Lab_Hud, "Lab", "hud-popup-hold", "experimental", "Mock HP; hold 1000 ms"},
	{
		"lab-inventory",
		.Lab_Inventory,
		"Lab",
		"inventory-transfer",
		"experimental",
		"Two uniform lists; no row drag-reorder",
	},
}

section_limitations :: proc(section: Section, locale: Locale) -> string {
	if locale == .English {return section.limitations}
	switch section.page {
	case .Layout:
		return "Нет wrap, span и auto-placement"
	case .Controls:
		return "Управляемые значения; ползунок 0..100 / 1"
	case .Profiles:
		return "Черновик и результат живут только в процессе"
	case .Styling:
		return "Только существующие примитивы и каскад темы"
	case .Atlas:
		return "Manifest v1; RGB8/RGBA8 PNG; явный Reload"
	case .Text:
		return "65536 байт / 4096 строк; нет shaping и bidi"
	case .Rich_Text:
		return "Своя grammar/fonts; не HTML и не rich editor"
	case .Text_Input:
		return "Одна строка; EGC 15.1; нет IME, undo и normalization"
	case .Scroll_Table:
		return "Вертикальная прокрутка; три Fixed tracks"
	case .Collections:
		return "Равномерная геометрия; один offset owner"
	case .Layers:
		return "Явные scopes; tooltip не принимает ввод"
	case .Hud:
		return "Hold 1000 ms; Activate не обходит удержание"
	case .Gestures:
		return "Нет inertia; proposal сам не перемещает объект"
	case .Composition:
		return "Callbacks записывают намерения; нет reentry"
	case .Custom:
		return "Два namespace; чистая проверка круга"
	case .Transitions:
		return "Frozen paint/hit; layout не анимируется"
	case .Accessibility:
		return "Warning/Unassessed не означают conformance"
	case .World:
		return "Камерой владеет приложение; нет Game Bridge"
	case .Diagnostics_Performance:
		return "Нет debugger transport, GPU time или SLA"
	case .Catalogue:
		return ""
	case .Lab_Menu, .Lab_Settings, .Lab_Hud, .Lab_Inventory:
		return(
			"Учебные данные; состояние только до завершения процесса" \
		)
	}
	return ""
}
