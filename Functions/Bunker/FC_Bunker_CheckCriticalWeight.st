FUNCTION FC_Bunker_CheckCriticalWeight : BOOL
VAR_INPUT
	Bunker1 : REFERENCE TO ST_Bunker;
	Bunker2 : REFERENCE TO ST_Bunker;
	Bunker3 : REFERENCE TO ST_Bunker;
END_VAR
VAR
END_VAR

// ========================================
// ПРОВЕРКА КРИТИЧЕСКИ НИЗКОГО ВЕСА
// ========================================
// Функция возвращает TRUE, если хотя бы один из бункеров достиг
// критически низкого уровня веса (сырье закончилось)
//
// ЛОГИКА:
// Когда определенное сырье заканчивается, вес бункера становится
// критически низким (rWeight <= BUNKER_WEIGHT_LIGHT_RED_SPECIAL).
// В этом случае необходимо подать красный сигнал на ВСЕ 3 бункера,
// чтобы прекратить подачу остального сырья. Далее они спокойно
// опустошаются в обычном автоматическом режиме.

FC_Bunker_CheckCriticalWeight :=
	(Bunker1.rWeight <= BUNKER_WEIGHT_LIGHT_RED_SPECIAL)
	OR (Bunker2.rWeight <= BUNKER_WEIGHT_LIGHT_RED_SPECIAL)
	OR (Bunker3.rWeight <= BUNKER_WEIGHT_LIGHT_RED_SPECIAL);

END_FUNCTION
