FUNCTION_BLOCK FB_ConveyorSensors
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
	xReset : BOOL; // Команда сброса зафиксированных ошибок

	// Уставки задержки срабатывания для каждого типа датчика
	itDelayZQ_Alarm : TIME;   // Задержка срабатывания датчика схода ленты (Alarm)
	itDelayZQ_Warning : TIME; // Задержка срабатывания датчика схода ленты (Warning)
	itDelayHQ : TIME;         // Задержка срабатывания кабель-тросового выключателя
	itDelaySQ : TIME;         // Задержка срабатывания датчика ограждения барабана
	itDelayGS : TIME;         // Задержка срабатывания датчика заштыбовки
	itDelayYS : TIME;         // Задержка срабатывания датчика продольного разрыва
	itDelayYE : TIME;         // Задержка срабатывания металлодетектора
	itDelayQR : TIME;         // Задержка срабатывания датчика скорости
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

	// TON таймеры задержки срабатывания для каждого датчика
	// Датчики схода ленты (ZQ Alarm)
	_fbDelayZQ1Alarm : TON;
	_fbDelayZQ2Alarm : TON;
	_fbDelayZQ3Alarm : TON;
	_fbDelayZQ4Alarm : TON;

	// Датчики схода ленты (ZQ Warning)
	_fbDelayZQ1Warning : TON;
	_fbDelayZQ2Warning : TON;
	_fbDelayZQ3Warning : TON;
	_fbDelayZQ4Warning : TON;

	// Кабель-тросовые выключатели (HQ)
	_fbDelayHQ1 : TON;
	_fbDelayHQ2 : TON;
	_fbDelayHQ3 : TON;
	_fbDelayHQ4 : TON;

	// Ограждения барабана (SQ)
	_fbDelaySQ1 : TON;
	_fbDelaySQ2 : TON;

	// Заштыбовка (GS)
	_fbDelayGS : TON;

	// Датчики скорости (QR)
	_fbDelayQR1 : TON;
	_fbDelayQR2 : TON;

	// Продольный разрыв (YS)
	_fbDelayYS : TON;

	// Металлодетектор (YE)
	_fbDelayYE : TON;
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

// Таймеры задержки срабатывания (сигнал должен удерживаться itDelayZQ_Alarm перед фиксацией)
_fbDelayZQ1Alarm(IN := NOT Conveyor.fbZQAlarm[1].qxSignal, PT := itDelayZQ_Alarm);
_fbDelayZQ2Alarm(IN := NOT Conveyor.fbZQAlarm[2].qxSignal, PT := itDelayZQ_Alarm);
_fbDelayZQ3Alarm(IN := NOT Conveyor.fbZQAlarm[3].qxSignal, PT := itDelayZQ_Alarm);
_fbDelayZQ4Alarm(IN := NOT Conveyor.fbZQAlarm[4].qxSignal, PT := itDelayZQ_Alarm);

// Определяем текущее состояние датчиков (после задержки)
_xCurrentErrorZQ1 := _fbDelayZQ1Alarm.Q;
_xCurrentErrorZQ2 := _fbDelayZQ2Alarm.Q;
_xCurrentErrorZQ3 := _fbDelayZQ3Alarm.Q;
_xCurrentErrorZQ4 := _fbDelayZQ4Alarm.Q;

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

// Таймеры задержки срабатывания (сигнал должен удерживаться itDelayZQ_Warning перед фиксацией)
_fbDelayZQ1Warning(IN := NOT Conveyor.fbZQWarning[1].qxSignal, PT := itDelayZQ_Warning);
_fbDelayZQ2Warning(IN := NOT Conveyor.fbZQWarning[2].qxSignal, PT := itDelayZQ_Warning);
_fbDelayZQ3Warning(IN := NOT Conveyor.fbZQWarning[3].qxSignal, PT := itDelayZQ_Warning);
_fbDelayZQ4Warning(IN := NOT Conveyor.fbZQWarning[4].qxSignal, PT := itDelayZQ_Warning);

// Определяем текущее состояние датчиков (после задержки)
_xCurrentWarningZQ1 := _fbDelayZQ1Warning.Q;
_xCurrentWarningZQ2 := _fbDelayZQ2Warning.Q;
_xCurrentWarningZQ3 := _fbDelayZQ3Warning.Q;
_xCurrentWarningZQ4 := _fbDelayZQ4Warning.Q;

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

// Таймеры задержки срабатывания (сигнал должен удерживаться itDelayHQ перед фиксацией)
_fbDelayHQ1(IN := NOT Conveyor.fbHQ_IsOk[1].qxSignal, PT := itDelayHQ);
_fbDelayHQ2(IN := NOT Conveyor.fbHQ_IsOk[2].qxSignal, PT := itDelayHQ);
_fbDelayHQ3(IN := NOT Conveyor.fbHQ_IsOk[3].qxSignal, PT := itDelayHQ);
_fbDelayHQ4(IN := NOT Conveyor.fbHQ_IsOk[4].qxSignal, PT := itDelayHQ);

// Определяем текущее состояние датчиков (после задержки)
_xCurrentErrorHQ1 := _fbDelayHQ1.Q;
_xCurrentErrorHQ2 := _fbDelayHQ2.Q;
_xCurrentErrorHQ3 := _fbDelayHQ3.Q;
_xCurrentErrorHQ4 := _fbDelayHQ4.Q;

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

// Таймеры задержки срабатывания (сигнал должен удерживаться itDelaySQ перед фиксацией)
_fbDelaySQ1(IN := NOT Conveyor.fbSQ_IsOk[1].qxSignal, PT := itDelaySQ);
_fbDelaySQ2(IN := NOT Conveyor.fbSQ_IsOk[2].qxSignal, PT := itDelaySQ);

// Определяем текущее состояние датчиков (после задержки)
_xCurrentErrorSQ1 := _fbDelaySQ1.Q;
_xCurrentErrorSQ2 := _fbDelaySQ2.Q;

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

// Таймер задержки срабатывания (сигнал должен удерживаться itDelayGS перед фиксацией)
_fbDelayGS(IN := NOT Conveyor.fbGS1.qxSignal, PT := itDelayGS);

// Определяем текущее состояние датчика (после задержки)
_xCurrentErrorGS := _fbDelayGS.Q;

// Фиксируем ошибку через RS-триггер
_fbLatchErrorGS(SET := _xCurrentErrorGS, RESET1 := xReset);

// Выход - зафиксированная ошибка
xErrorGS := _fbLatchErrorGS.Q1;

// ========================================
// ДАТЧИКИ СКОРОСТИ (QR)
// ========================================
// Логика: Проверка наличия импульсов (детектирование остановки при работающем моторе)
// Ошибка определяется на верхнем уровне по сравнению с состоянием мотора

// Таймеры задержки срабатывания (резерв для будущей реализации)
_fbDelayQR1(IN := FALSE, PT := itDelayQR); // Резерв для будущей реализации
_fbDelayQR2(IN := FALSE, PT := itDelayQR); // Резерв для будущей реализации

// Определяем текущее состояние датчиков (после задержки)
_xCurrentErrorQR1 := _fbDelayQR1.Q;
_xCurrentErrorQR2 := _fbDelayQR2.Q;

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

// Таймер задержки срабатывания (сигнал должен удерживаться itDelayYS перед фиксацией)
_fbDelayYS(IN := Conveyor.fbYS1.qxSignal, PT := itDelayYS);

// Определяем текущее состояние датчика (после задержки)
_xCurrentErrorYS := _fbDelayYS.Q;

// Фиксируем ошибку через RS-триггер
_fbLatchErrorYS(SET := _xCurrentErrorYS, RESET1 := xReset);

// Выход - зафиксированная ошибка
xErrorYS := _fbLatchErrorYS.Q1;

// ========================================
// МЕТАЛЛОДЕТЕКТОР (YE)
// ========================================
// Логика: 1 = Норма, 0 = Тревога (обнаружен металл)

// Таймер задержки срабатывания (сигнал должен удерживаться itDelayYE перед фиксацией)
_fbDelayYE(IN := NOT Conveyor.fbYE1.qxSignal, PT := itDelayYE);

// Определяем текущее состояние датчика (после задержки)
_xCurrentErrorYE := _fbDelayYE.Q;

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
