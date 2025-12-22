FUNCTION FC_Bunker_GetLightColor : E_LightColor
VAR_INPUT
	irWeight : REAL; // Вес текущего бункера
	xCriticalWeightDetected : BOOL; // Глобальный флаг критического веса (хотя бы один бункер достиг критической уставки)
	xThisBunkerIsCritical : BOOL; // Флаг того, что ЭТОТ конкретный бункер находится в критическом состоянии
	xBunkerWorking : BOOL; // Бункер работает (питатели активны)
END_VAR
VAR
END_VAR

// ========================================
// ПРИОРИТЕТНАЯ ПРОВЕРКА: КРИТИЧЕСКИЙ ВЕС
// ========================================
// ЛОГИКА:
// 1. Если хотя бы один бункер достиг критически низкого веса (сырье закончилось),
//    то ЭТОТ конкретный бункер горит ЗЕЛЁНЫМ (приоритет на заполнение),
//    а ВСЕ ОСТАЛЬНЫЕ бункеры горят КРАСНЫМ (остановить заполнение).
// 2. Как только критический бункер выходит на норму (вес >= BUNKER_WEIGHT_LIGHT_GREEN),
//    система возвращается к обычному режиму работы светофоров.

IF xCriticalWeightDetected THEN
	// Если этот конкретный бункер находится в критическом состоянии
	IF xThisBunkerIsCritical THEN
		// Этот бункер горит ЗЕЛЁНЫМ (срочно заполнить!)
		FC_Bunker_GetLightColor := E_LightColor.GREEN;
	ELSE
		// Все остальные бункеры горят КРАСНЫМ (прекратить заполнение!)
		FC_Bunker_GetLightColor := E_LightColor.RED;
	END_IF;
	RETURN;
END_IF;

// ========================================
// ОБЫЧНАЯ РАБОТА: ОПРЕДЕЛЕНИЕ ЦВЕТА ПО ВЕСУ
// ========================================
IF irWeight >= BUNKER_WEIGHT_LIGHT_RED THEN
	// Вес выше или равен уставке RED - красный сигнал (бункер полный, прекратить загрузку)
	FC_Bunker_GetLightColor := E_LightColor.RED;

ELSIF irWeight >= BUNKER_WEIGHT_LIGHT_YELLOW THEN
	// Вес между YELLOW и RED - жёлтый сигнал (бункер заполнен умеренно)
	FC_Bunker_GetLightColor := E_LightColor.YELLOW;

ELSIF irWeight >= BUNKER_WEIGHT_LIGHT_GREEN THEN
	// Вес между GREEN и YELLOW - зелёный сигнал (можно загружать)
	FC_Bunker_GetLightColor := E_LightColor.GREEN;

ELSE
	// Вес ниже GREEN - выключен (недостаточный вес для работы)
	// Если бункер работает, оставляем зелёный, иначе - выключен
	IF xBunkerWorking THEN
		FC_Bunker_GetLightColor := E_LightColor.GREEN;
	ELSE
		FC_Bunker_GetLightColor := E_LightColor.OFF;
	END_IF;
END_IF;

END_FUNCTION
