FUNCTION FC_Bunker_CheckEmptyBunker : BOOL
VAR_INPUT
	Bunker1 : REFERENCE TO ST_Bunker;
	Bunker2 : REFERENCE TO ST_Bunker;
	Bunker3 : REFERENCE TO ST_Bunker;
END_VAR
VAR
END_VAR
// ========================================
// ПРОВЕРКА ПОЛНОГО ОПУСТОШЕНИЯ БУНКЕРОВ
// ========================================
// Функция возвращает TRUE, если хотя бы один из бункеров полностью пуст.
//
// ЛОГИКА:
// Как только один из бункеров становится пустым (rWeight <= BUNKER_MINIMAL_WEIGHT),
// необходимо сразу остановить ВСЕ бункеры. Конвейер и отвалообразователь
// продолжают свою работу для транспортировки оставшегося материала.

FC_Bunker_CheckEmptyBunker :=
	(Bunker1.rWeight <= BUNKER_MINIMAL_WEIGHT)
	OR (Bunker2.rWeight <= BUNKER_MINIMAL_WEIGHT)
	OR (Bunker3.rWeight <= BUNKER_MINIMAL_WEIGHT);

END_FUNCTION