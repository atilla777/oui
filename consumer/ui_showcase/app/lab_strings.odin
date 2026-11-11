package app

Lab_String :: enum {
	Lab_Group,
	Gallery_Group,
	Settings,
	Main_Menu,
	Submenu,
	Enabled,
	Amount,
	Settings_Summary,
	Catalogue,
	Discard_Question,
	Apply_Question,
	Stay,
	Edit,
	Discard,
	Confirm,
	Hud,
	Popup,
	Explain,
	Mock,
	Close,
	Hold_Help,
	Inventory,
	Backpack,
	Chest,
	Reverse,
	Drag,
	Transfer_Question,
	Cancel,
	Transfer_Confirm,
	Transfer_Ready,
	Transfer_Same,
	Transfer_Stale,
	Transfer_Refused,
	Transfer_Cancelled,
	Transfer_Done,
}
Lab_Word :: struct {
	en, ru: string,
}
// Static text resources only; reducers keep semantic IDs and never translate data.
LAB_WORDS := [Lab_String]Lab_Word {
	.Lab_Group          = {"Lab", "Лаборатория"},
	.Gallery_Group      = {"Gallery", "Галерея"},
	.Settings_Summary   = {
		"Enabled: %t | Amount: %d",
		"Включено: %t | Количество: %d",
	},
	.Settings           = {"Settings", "Настройки"},
	.Main_Menu          = {"Main menu", "Главное меню"},
	.Submenu            = {"Open submenu", "Открыть подменю"},
	.Enabled            = {"Enabled", "Включено"},
	.Amount             = {"Amount", "Количество"},
	.Catalogue          = {"Back to catalogue", "Вернуться в каталог"},
	.Discard_Question   = {"Discard changes?", "Отбросить изменения?"},
	.Apply_Question     = {"Apply this draft?", "Применить этот черновик?"},
	.Stay               = {"Stay", "Остаться"},
	.Edit               = {"Keep editing", "Продолжить редактирование"},
	.Discard            = {"Discard changes", "Отбросить изменения"},
	.Confirm            = {"Confirm", "Подтвердить"},
	.Hud                = {"Lab / HUD", "Лаборатория / HUD"},
	.Popup              = {"Open popup", "Открыть popup"},
	.Explain            = {"Explain hold", "Пояснение удержания"},
	.Mock               = {
		"Mock HP. No combat simulation.",
		"Учебные HP. Не симуляция боя.",
	},
	.Close              = {"Close", "Закрыть"},
	.Hold_Help          = {
		"Hold 1000 ms restores HP once. Release cancels.",
		"1000 мс восстанавливают HP один раз. Отпускание отменяет.",
	},
	.Inventory          = {"Lab / Inventory", "Лаборатория / Инвентарь"},
	.Backpack           = {"Backpack", "Рюкзак"},
	.Chest              = {"Chest", "Сундук"},
	.Reverse            = {
		"Reverse display order",
		"Обратный порядок показа",
	},
	.Drag               = {
		"Drag selected item",
		"Перетащить выбранный предмет",
	},
	.Transfer_Question  = {
		"Move selected item?",
		"Перенести выбранный предмет?",
	},
	.Cancel             = {"Cancel", "Отмена"},
	.Transfer_Confirm   = {"Confirm move", "Подтвердить перенос"},
	.Transfer_Ready     = {
		"Select an item, then drag its handle to the other header.",
		"Выберите предмет и перетащите ручку к другому заголовку.",
	},
	.Transfer_Same      = {
		"Refused: item is already in this container.",
		"Отказ: предмет уже в этом контейнере.",
	},
	.Transfer_Stale     = {
		"Refused: inventory changed; make a new request.",
		"Отказ: инвентарь изменился; повторите запрос.",
	},
	.Transfer_Refused   = {
		"Transfer refused by the application.",
		"Приложение отклонило перенос.",
	},
	.Transfer_Cancelled = {
		"Transfer cancelled; membership unchanged.",
		"Перенос отменён; состав контейнеров не изменён.",
	},
	.Transfer_Done      = {
		"Item moved once; stable selection preserved.",
		"Предмет перенесён один раз; выбор сохранён.",
	},
}

LAB_CARDS := [12]Lab_Word {
	{"Compass", "Компас"},
	{"Torch", "Факел"},
	{"Map", "Карта"},
	{"Rope", "Верёвка"},
	{"Flask", "Фляга"},
	{"Key", "Ключ"},
	{"Book", "Книга"},
	{"Hammer", "Молоток"},
	{"Gloves", "Перчатки"},
	{"Lantern", "Фонарь"},
	{"Cloak", "Плащ"},
	{"Boots", "Сапоги"},
}
lab_card_name :: proc(r: ^Runtime, id: string) -> string {
	if len(id) != 7 {return id}
	n := int(id[5] - '0') * 10 + int(id[6] - '0') - 1
	if n < 0 || n >= len(LAB_CARDS) {return id}
	word := LAB_CARDS[n]; return word.en if r.model.locale == .English else word.ru
}
