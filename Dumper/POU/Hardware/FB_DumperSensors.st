FUNCTION_BLOCK FB_DumperSensors
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
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

	// Агрегированные выходы
	xErrorSafetySensors : BOOL;  // Любая ошибка датчиков безопасности
	xWarningSafetySensors : BOOL; // Любое предупреждение датчиков безопасности
END_VAR

// ========================================
// FB_DumperSensors - Обработка датчиков безопасности отвалообразователя
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Мониторинг всех датчиков безопасности
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
//
// ВЫХОДЫ:
// - Индивидуальные флаги для каждого датчика
// - Агрегированные флаги (Any) для групп датчиков
// - Общие флаги ошибок и предупреждений
//
// ========================================

// ========================================
// ДАТЧИКИ СХОДА ЛЕНТЫ (ZQ) - ALARM
// ========================================
// Логика: 1 = Норма, 0 = Тревога (сход ленты)

xErrorZQ1 := NOT Dumper.fbZQAlarm[1].qxSignal;
xErrorZQ2 := NOT Dumper.fbZQAlarm[2].qxSignal;
xErrorZQ3 := NOT Dumper.fbZQAlarm[3].qxSignal;
xErrorZQ4 := NOT Dumper.fbZQAlarm[4].qxSignal;

xErrorZQ_Any := xErrorZQ1 OR xErrorZQ2 OR xErrorZQ3 OR xErrorZQ4;

// ========================================
// ДАТЧИКИ СХОДА ЛЕНТЫ (ZQ) - WARNING
// ========================================
// Логика: 1 = Норма, 0 = Предупреждение (лента близка к сходу)

xWarningZQ1 := NOT Dumper.fbZQWarning[1].qxSignal;
xWarningZQ2 := NOT Dumper.fbZQWarning[2].qxSignal;
xWarningZQ3 := NOT Dumper.fbZQWarning[3].qxSignal;
xWarningZQ4 := NOT Dumper.fbZQWarning[4].qxSignal;

xWarningZQ_Any := xWarningZQ1 OR xWarningZQ2 OR xWarningZQ3 OR xWarningZQ4;

// ========================================
// КАБЕЛЬ-ТРОСОВЫЕ ВЫКЛЮЧАТЕЛИ (HQ)
// ========================================
// Логика: 1 = Норма, 0 = Аварийная остановка (трос натянут)

xErrorHQ1 := NOT Dumper.fbHQ_IsOk[1].qxSignal;
xErrorHQ2 := NOT Dumper.fbHQ_IsOk[2].qxSignal;
xErrorHQ3 := NOT Dumper.fbHQ_IsOk[3].qxSignal;
xErrorHQ4 := NOT Dumper.fbHQ_IsOk[4].qxSignal;

xErrorHQ_Any := xErrorHQ1 OR xErrorHQ2 OR xErrorHQ3 OR xErrorHQ4;

// ========================================
// КОНТРОЛЬ ОГРАЖДЕНИЯ БАРАБАНА (SQ)
// ========================================
// Логика: 1 = Норма (ограждение закрыто), 0 = Тревога (ограждение открыто)

xErrorSQ1 := NOT Dumper.fbSQ_IsOk[1].qxSignal;
xErrorSQ2 := NOT Dumper.fbSQ_IsOk[2].qxSignal;

xErrorSQ_Any := xErrorSQ1 OR xErrorSQ2;

// ========================================
// КОНТРОЛЬ ЗАШТЫБОВКИ (GS)
// ========================================
// Логика: 1 = Норма, 0 = Тревога (заштыбовка материала)

xErrorGS := NOT Dumper.fbGS1.qxSignal;

// ========================================
// ДАТЧИКИ СКОРОСТИ (QR)
// ========================================
// Логика: Проверка наличия импульсов (детектирование остановки при работающем моторе)
// Ошибка определяется на верхнем уровне по сравнению с состоянием мотора

xErrorQR1 := FALSE; // Резерв для будущей реализации
xErrorQR2 := FALSE; // Резерв для будущей реализации

xErrorQR_Any := xErrorQR1 OR xErrorQR2;

// ========================================
// КОНТРОЛЬ ПРОДОЛЬНОГО РАЗРЫВА (YS)
// ========================================
// Логика: 1 = Норма, 0 = Тревога (продольный разрыв ленты)

xErrorYS := NOT Dumper.fbYS1.qxSignal;

// ========================================
// АГРЕГИРОВАНИЕ ОШИБОК И ПРЕДУПРЕЖДЕНИЙ
// ========================================

// Все критические ошибки датчиков безопасности
xErrorSafetySensors := xErrorZQ_Any    // Сход ленты (критический уровень)
                    OR xErrorHQ_Any     // Аварийная остановка по тросу
                    OR xErrorSQ_Any     // Открыто ограждение
                    OR xErrorGS         // Заштыбовка
                    OR xErrorQR_Any     // Остановка барабана
                    OR xErrorYS;        // Продольный разрыв

// Все предупреждения датчиков безопасности
xWarningSafetySensors := xWarningZQ_Any; // Предупреждение схода ленты

END_FUNCTION_BLOCK
