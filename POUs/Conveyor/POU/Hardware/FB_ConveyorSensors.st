FUNCTION_BLOCK FB_ConveyorSensors
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
	xReset : BOOL; // Команда сброса зафиксированных ошибок
END_VAR
VAR_OUTPUT
	// Ошибки по датчикам схода ленты (ZQ Alarm)
	xErrorZQ1 : BOOL;
	xErrorZQ2 : BOOL;
	xErrorZQ3 : BOOL;
	xErrorZQ4 : BOOL;
	xErrorZQ_Any : BOOL; // Любая ошибка ZQ

	// Предупреждения по датчикам схода ленты (ZQ Warning)
	xWarningZQ1 : BOOL;
	xWarningZQ2 : BOOL;
	xWarningZQ3 : BOOL;
	xWarningZQ4 : BOOL;
	xWarningZQ_Any : BOOL; // Любое предупреждение ZQ

	// Ошибки по кабель-тросовым выключателям (HQ)
	xErrorHQ1 : BOOL;
	xErrorHQ2 : BOOL;
	xErrorHQ3 : BOOL;
	xErrorHQ4 : BOOL;
	xErrorHQ_Any : BOOL; // Любая ошибка HQ

	// Ошибки по ограждениям барабана (SQ)
	xErrorSQ1 : BOOL;
	xErrorSQ2 : BOOL;
	xErrorSQ_Any : BOOL; // Любая ошибка SQ

	// Ошибка контроля заштыбовки (GS)
	xErrorGS : BOOL;

	// Ошибки датчиков скорости (QR)
	xErrorQR1 : BOOL;
	xErrorQR2 : BOOL;
	xErrorQR_Any : BOOL; // Любая ошибка QR

	// Ошибка контроля продольного разрыва (YS)
	xErrorYS : BOOL;

	// Ошибка металлодетектора (YE)
	xErrorYE : BOOL;

	// Агрегированные выходы
	xErrorSafetySensors : BOOL;  // Любая ошибка датчиков безопасности
	xWarningSafetySensors : BOOL; // Любое предупреждение датчиков безопасности
END_VAR
VAR
	// Внутренние переменные для фиксации ошибок (текущие состояния без фиксации)
	_xCurrentErrorZQ1 : BOOL;
	_xCurrentErrorZQ2 : BOOL;
	_xCurrentErrorZQ3 : BOOL;
	_xCurrentErrorZQ4 : BOOL;

	_xCurrentWarningZQ1 : BOOL;
	_xCurrentWarningZQ2 : BOOL;
	_xCurrentWarningZQ3 : BOOL;
	_xCurrentWarningZQ4 : BOOL;

	_xCurrentErrorHQ1 : BOOL;
	_xCurrentErrorHQ2 : BOOL;
	_xCurrentErrorHQ3 : BOOL;
	_xCurrentErrorHQ4 : BOOL;

	_xCurrentErrorSQ1 : BOOL;
	_xCurrentErrorSQ2 : BOOL;

	_xCurrentErrorGS : BOOL;
	_xCurrentErrorQR1 : BOOL;
	_xCurrentErrorQR2 : BOOL;
	_xCurrentErrorYS : BOOL;
	_xCurrentErrorYE : BOOL;

	// RS-триггеры для фиксации ошибок
	_fbLatchErrorZQ1 : RS;
	_fbLatchErrorZQ2 : RS;
	_fbLatchErrorZQ3 : RS;
	_fbLatchErrorZQ4 : RS;

	_fbLatchWarningZQ1 : RS;
	_fbLatchWarningZQ2 : RS;
	_fbLatchWarningZQ3 : RS;
	_fbLatchWarningZQ4 : RS;

	_fbLatchErrorHQ1 : RS;
	_fbLatchErrorHQ2 : RS;
	_fbLatchErrorHQ3 : RS;
	_fbLatchErrorHQ4 : RS;

	_fbLatchErrorSQ1 : RS;
	_fbLatchErrorSQ2 : RS;

	_fbLatchErrorGS : RS;
	_fbLatchErrorQR1 : RS;
	_fbLatchErrorQR2 : RS;
	_fbLatchErrorYS : RS;
	_fbLatchErrorYE : RS;
END_VAR

// ========================================
// FB_ConveyorSensors - Обработка датчиков безопасности сборного конвейера
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Мониторинг всех датчиков безопасности
// - Фиксация ошибок через RS-триггеры (память до сброса)
// - Формирование индивидуальных флагов ошибок
// - Агрегирование ошибок и предупреждений
//
// ДАТЧИКИ:
// - ZQ (1-4): Контроль схода ленты (Alarm + Warning)
// - HQ (1-4): Кабель-тросовый выключатель (аварийная остановка)
// - SQ (1-2): Контроль ограждения барабана
// - GS: Контроль заштыбовки
// - QR (1-2): Измерение скорости вращения барабана
// - YS: Контроль продольного разрыва ленты
// - YE: Металлодетектор
//
// ЛОГИКА ФИКСАЦИИ:
// - При возникновении ошибки она фиксируется (SET в RS-триггер)
// - Ошибка сохраняется даже после устранения неисправности датчика
// - Сброс всех зафиксированных ошибок через вход xReset
//
// ВЫХОДЫ:
// - Индивидуальные флаги для каждого датчика (зафиксированные)
// - Агрегированные флаги (Any) для групп датчиков
// - Общие флаги ошибок и предупреждений
//
// ========================================

// ========================================
// ДАТЧИКИ СХОДА ЛЕНТЫ (ZQ) - ALARM
// ========================================
// Логика: 1 = Норма, 0 = Тревога (сход ленты)

// Определяем текущее состояние датчиков
_xCurrentErrorZQ1 := NOT Conveyor.fbZQAlarm[1].qxSignal;
_xCurrentErrorZQ2 := NOT Conveyor.fbZQAlarm[2].qxSignal;
_xCurrentErrorZQ3 := NOT Conveyor.fbZQAlarm[3].qxSignal;
_xCurrentErrorZQ4 := NOT Conveyor.fbZQAlarm[4].qxSignal;

// Фиксируем ошибки через RS-триггеры (SET при ошибке, RESET по команде xReset)
_fbLatchErrorZQ1(SET := _xCurrentErrorZQ1, RESET1 := xReset);
_fbLatchErrorZQ2(SET := _xCurrentErrorZQ2, RESET1 := xReset);
_fbLatchErrorZQ3(SET := _xCurrentErrorZQ3, RESET1 := xReset);
_fbLatchErrorZQ4(SET := _xCurrentErrorZQ4, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorZQ1 := _fbLatchErrorZQ1.Q1;
xErrorZQ2 := _fbLatchErrorZQ2.Q1;
xErrorZQ3 := _fbLatchErrorZQ3.Q1;
xErrorZQ4 := _fbLatchErrorZQ4.Q1;

xErrorZQ_Any := xErrorZQ1 OR xErrorZQ2 OR xErrorZQ3 OR xErrorZQ4;

// ========================================
// ДАТЧИКИ СХОДА ЛЕНТЫ (ZQ) - WARNING
// ========================================
// Логика: 1 = Норма, 0 = Предупреждение (лента близка к сходу)

// Определяем текущее состояние датчиков
_xCurrentWarningZQ1 := NOT Conveyor.fbZQWarning[1].qxSignal;
_xCurrentWarningZQ2 := NOT Conveyor.fbZQWarning[2].qxSignal;
_xCurrentWarningZQ3 := NOT Conveyor.fbZQWarning[3].qxSignal;
_xCurrentWarningZQ4 := NOT Conveyor.fbZQWarning[4].qxSignal;

// Фиксируем предупреждения через RS-триггеры
_fbLatchWarningZQ1(SET := _xCurrentWarningZQ1, RESET1 := xReset);
_fbLatchWarningZQ2(SET := _xCurrentWarningZQ2, RESET1 := xReset);
_fbLatchWarningZQ3(SET := _xCurrentWarningZQ3, RESET1 := xReset);
_fbLatchWarningZQ4(SET := _xCurrentWarningZQ4, RESET1 := xReset);

// Выходы - зафиксированные предупреждения
xWarningZQ1 := _fbLatchWarningZQ1.Q1;
xWarningZQ2 := _fbLatchWarningZQ2.Q1;
xWarningZQ3 := _fbLatchWarningZQ3.Q1;
xWarningZQ4 := _fbLatchWarningZQ4.Q1;

xWarningZQ_Any := xWarningZQ1 OR xWarningZQ2 OR xWarningZQ3 OR xWarningZQ4;

// ========================================
// КАБЕЛЬ-ТРОСОВЫЕ ВЫКЛЮЧАТЕЛИ (HQ)
// ========================================
// Логика: 1 = Норма, 0 = Аварийная остановка (трос натянут)

// Определяем текущее состояние датчиков
_xCurrentErrorHQ1 := NOT Conveyor.fbHQ_IsOk[1].qxSignal;
_xCurrentErrorHQ2 := NOT Conveyor.fbHQ_IsOk[2].qxSignal;
_xCurrentErrorHQ3 := NOT Conveyor.fbHQ_IsOk[3].qxSignal;
_xCurrentErrorHQ4 := NOT Conveyor.fbHQ_IsOk[4].qxSignal;

// Фиксируем ошибки через RS-триггеры
_fbLatchErrorHQ1(SET := _xCurrentErrorHQ1, RESET1 := xReset);
_fbLatchErrorHQ2(SET := _xCurrentErrorHQ2, RESET1 := xReset);
_fbLatchErrorHQ3(SET := _xCurrentErrorHQ3, RESET1 := xReset);
_fbLatchErrorHQ4(SET := _xCurrentErrorHQ4, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorHQ1 := _fbLatchErrorHQ1.Q1;
xErrorHQ2 := _fbLatchErrorHQ2.Q1;
xErrorHQ3 := _fbLatchErrorHQ3.Q1;
xErrorHQ4 := _fbLatchErrorHQ4.Q1;

xErrorHQ_Any := xErrorHQ1 OR xErrorHQ2 OR xErrorHQ3 OR xErrorHQ4;

// ========================================
// КОНТРОЛЬ ОГРАЖДЕНИЯ БАРАБАНА (SQ)
// ========================================
// Логика: 1 = Норма (ограждение закрыто), 0 = Тревога (ограждение открыто)

// Определяем текущее состояние датчиков
_xCurrentErrorSQ1 := NOT Conveyor.fbSQ_IsOk[1].qxSignal;
_xCurrentErrorSQ2 := NOT Conveyor.fbSQ_IsOk[2].qxSignal;

// Фиксируем ошибки через RS-триггеры
_fbLatchErrorSQ1(SET := _xCurrentErrorSQ1, RESET1 := xReset);
_fbLatchErrorSQ2(SET := _xCurrentErrorSQ2, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorSQ1 := _fbLatchErrorSQ1.Q1;
xErrorSQ2 := _fbLatchErrorSQ2.Q1;

xErrorSQ_Any := xErrorSQ1 OR xErrorSQ2;

// ========================================
// КОНТРОЛЬ ЗАШТЫБОВКИ (GS)
// ========================================
// Логика: 1 = Норма, 0 = Тревога (заштыбовка материала)

// Определяем текущее состояние датчика
_xCurrentErrorGS := NOT Conveyor.fbGS1.qxSignal;

// Фиксируем ошибку через RS-триггер
_fbLatchErrorGS(SET := _xCurrentErrorGS, RESET1 := xReset);

// Выход - зафиксированная ошибка
xErrorGS := _fbLatchErrorGS.Q1;

// ========================================
// ДАТЧИКИ СКОРОСТИ (QR)
// ========================================
// Логика: Проверка наличия импульсов (детектирование остановки при работающем моторе)
// Ошибка определяется на верхнем уровне по сравнению с состоянием мотора

// Определяем текущее состояние датчиков (резерв для будущей реализации)
_xCurrentErrorQR1 := FALSE; // Резерв для будущей реализации
_xCurrentErrorQR2 := FALSE; // Резерв для будущей реализации

// Фиксируем ошибки через RS-триггеры
_fbLatchErrorQR1(SET := _xCurrentErrorQR1, RESET1 := xReset);
_fbLatchErrorQR2(SET := _xCurrentErrorQR2, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorQR1 := _fbLatchErrorQR1.Q1;
xErrorQR2 := _fbLatchErrorQR2.Q1;

xErrorQR_Any := xErrorQR1 OR xErrorQR2;

// ========================================
// КОНТРОЛЬ ПРОДОЛЬНОГО РАЗРЫВА (YS)
// ========================================
// Логика: 1 = Норма, 0 = Тревога (продольный разрыв ленты)

// Определяем текущее состояние датчика
_xCurrentErrorYS := NOT Conveyor.fbYS1.qxSignal;

// Фиксируем ошибку через RS-триггер
_fbLatchErrorYS(SET := _xCurrentErrorYS, RESET1 := xReset);

// Выход - зафиксированная ошибка
xErrorYS := _fbLatchErrorYS.Q1;

// ========================================
// МЕТАЛЛОДЕТЕКТОР (YE)
// ========================================
// Логика: 1 = Норма, 0 = Тревога (обнаружен металл)

// Определяем текущее состояние датчика
_xCurrentErrorYE := NOT Conveyor.fbYE1.qxSignal;

// Фиксируем ошибку через RS-триггер
_fbLatchErrorYE(SET := _xCurrentErrorYE, RESET1 := xReset);

// Выход - зафиксированная ошибка
xErrorYE := _fbLatchErrorYE.Q1;

// ========================================
// АГРЕГИРОВАНИЕ ОШИБОК И ПРЕДУПРЕЖДЕНИЙ
// ========================================

// Все критические ошибки датчиков безопасности
xErrorSafetySensors := xErrorZQ_Any    // Сход ленты (критический уровень)
                    OR xErrorHQ_Any     // Аварийная остановка по тросу
                    OR xErrorSQ_Any     // Открыто ограждение
                    OR xErrorGS         // Заштыбовка
                    OR xErrorQR_Any     // Остановка барабана
                    OR xErrorYS         // Продольный разрыв
                    OR xErrorYE;        // Обнаружен металл

// Все предупреждения датчиков безопасности
xWarningSafetySensors := xWarningZQ_Any; // Предупреждение схода ленты

END_FUNCTION_BLOCK
