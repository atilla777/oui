package main

// Consumer-owned resources. No Slyx translations or library-owned UI words.
Strings :: struct {
	main, submenu, action, open, language, back, counter, failed: string,
}
EN :: Strings {
	"Menu",
	"Submenu",
	"Action",
	"Submenu",
	"Русский",
	"Back",
	"Count: %d",
	"Unavailable — press R",
}
RU :: Strings {
	"Меню",
	"Подменю",
	"Действие",
	"Подменю",
	"English",
	"Назад",
	"Счётчик: %d",
	"Отказ — нажмите R",
}
