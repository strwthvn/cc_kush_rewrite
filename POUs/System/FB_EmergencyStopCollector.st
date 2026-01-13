FUNCTION_BLOCK FB_EmergencyStopCollector
VAR_INPUT
	// == ГАРАНТИРОВАННЫЕ ИСТОЧНИКИ (NC контакты: TRUE = норма, FALSE = нажата) ==
	ixEStopButton : BOOL;                 // Кнопка E-Stop на общем ПМУ
	ixScadaCommand : BOOL;                // Команда SCADA cmdEmergencyStopCommon (импульс)
	ixEStopDumper : BOOL;                 // Кнопка E-Stop отвалообразователя
	ixEStopConveyor : BOOL;               // Кнопка E-Stop конвейера
	ixEStopBunker1 : BOOL;                // Кнопка E-Stop бункера 1
	ixEStopBunker2 : BOOL;                // Кнопка E-Stop бункера 2
	ixEStopBunker3 : BOOL;                // Кнопка E-Stop бункера 3

	// == СИСТЕМНЫЕ СИГНАЛЫ ==
	ixScadaLoss : BOOL;                   // Потеря связи со SCADA
	ixProportionError : BOOL;             // Ошибка суммы пропорций

	// == ОШИБКИ ДАТЧИКОВ ОТВАЛООБРАЗОВАТЕЛЯ ==
	ixDumperErrorZQ : BOOL;               // ZQ (сход ленты)
	ixDumperErrorHQ : BOOL;               // HQ (кабель-тросовые)
	ixDumperErrorSQ : BOOL;               // SQ (ограждения)
	ixDumperErrorGS : BOOL;               // GS (заштыбовка)
	ixDumperErrorYS : BOOL;               // YS (продольный разрыв)
	ixDumperErrorQR : BOOL;               // QR (скорость)

	// == ОШИБКИ ДАТЧИКОВ КОНВЕЙЕРА ==
	ixConveyorErrorZQ : BOOL;             // ZQ (сход ленты)
	ixConveyorErrorHQ : BOOL;             // HQ (кабель-тросовые)
	ixConveyorErrorSQ : BOOL;             // SQ (ограждения)
	ixConveyorErrorGS : BOOL;             // GS (заштыбовка)
	ixConveyorErrorYS : BOOL;             // YS (продольный разрыв)
	ixConveyorErrorYE : BOOL;             // YE (металлодетектор)
	ixConveyorErrorQR : BOOL;             // QR (скорость)

	// == ЗАВИСИМОСТИ И ТОК ==
	ixDependencyError : BOOL;             // Ошибка блокировочных зависимостей
	ixMotorCurrentHH : BOOL;              // Любой мотор с HH уровнем тока

	// == ОШИБКИ VFD (аварийный сигнал от частотного преобразователя) ==
	ixDumperVFD_Failure : BOOL;           // Авария VFD отвалообразователя
	ixConveyorVFD_Failure : BOOL;         // Авария VFD конвейера

	// == КОМАНДА СБРОСА ==
	ixReset : BOOL;                       // Общий сброс
END_VAR
VAR_OUTPUT
	// == ГЛОБАЛЬНАЯ АВАРИЙНАЯ ОСТАНОВКА ==
	qxGlobalEmergencyStop : BOOL;         // Итоговый сигнал глобальной аварийной остановки

	// == ПРИЧИНЫ (для диагностики и SCADA) ==
	qxReason_EStopButton : BOOL;          // Причина: кнопка E-Stop на общем ПМУ
	qxReason_ScadaCommand : BOOL;         // Причина: команда SCADA
	qxReason_EStopLocal : BOOL;           // Причина: локальная кнопка E-Stop секции
	qxReason_ScadaLoss : BOOL;            // Причина: потеря связи SCADA
	qxReason_ProportionError : BOOL;      // Причина: ошибка пропорций
	qxReason_ZQ : BOOL;                   // Причина: датчик схода ленты
	qxReason_HQ : BOOL;                   // Причина: кабель-тросовый выключатель
	qxReason_SQ : BOOL;                   // Причина: ограждение барабана
	qxReason_GS : BOOL;                   // Причина: заштыбовка
	qxReason_YS : BOOL;                   // Причина: продольный разрыв
	qxReason_YE : BOOL;                   // Причина: металлодетектор
	qxReason_QR : BOOL;                   // Причина: датчик скорости
	qxReason_Dependencies : BOOL;         // Причина: блокировочные зависимости
	qxReason_MotorCurrent : BOOL;         // Причина: аварийный ток мотора
	qxReason_VFD_Failure : BOOL;          // Причина: авария VFD (частотного преобразователя)

	// == СИГНАЛЫ АВАРИЙНОЙ ОСТАНОВКИ ПО СЕКЦИЯМ ==
	qxSectionStop_Dumper : BOOL;          // Остановка отвалообразователя
	qxSectionStop_Conveyor : BOOL;        // Остановка конвейера
	qxSectionStop_Bunker1 : BOOL;         // Остановка бункера 1
	qxSectionStop_Bunker2 : BOOL;         // Остановка бункера 2
	qxSectionStop_Bunker3 : BOOL;         // Остановка бункера 3

	// == ДИАГНОСТИКА ==
	qxResetBlocked : BOOL;                // Сброс заблокирован (причина не устранена)
	qnReasonCode : INT;                   // Код причины для SCADA (0 = нет ошибки)
	qxAnyLocalEStopPressed : BOOL;        // Любая локальная кнопка E-Stop нажата
END_VAR
VAR
	// RS-триггер для фиксации команды SCADA (импульсный сигнал)
	_fbLatchScadaCommand : RS;
	_xScadaCommandLatched : BOOL;
END_VAR

// ========================================
// FB_EmergencyStopCollector - Централизованный сбор сигналов аварийной остановки
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Сбор всех сигналов аварийной остановки в одном месте
// - Разделение на гарантированные и настраиваемые источники
// - Формирование сигналов по секциям с учётом опций
// - Диагностика причин для SCADA
//
// УРОВНИ ОСТАНОВКИ:
// 1. ГАРАНТИРОВАННЫЕ (всегда активны, не отключаются):
//    - Кнопка E-Stop на общем ПМУ (stCommonSignals.fbEmergencyStopBtn)
//    - Команда SCADA cmdEmergencyStopCommon
//    - Локальные кнопки E-Stop секций (fbBtnEmergencyStop)
//
// 2. НАСТРАИВАЕМЫЕ (через опции ENABLE_GLOBAL_ESTOP_*):
//    - Датчики ZQ, HQ, SQ, GS, YS, YE, QR
//    - Потеря связи SCADA
//    - Ошибка пропорций
//    - Блокировочные зависимости
//    - Аварийный ток мотора
//
// 3. ЗАВИСИМОСТИ ПО СЕКЦИЯМ (через ENABLE_ESTOP_DEPENDENCIES_*):
//    - ENABLE_ESTOP_DEPENDENCIES_DUMPER - для отвалообразователя
//    - ENABLE_ESTOP_DEPENDENCIES_CONVEYOR - для конвейера
//    - ENABLE_ESTOP_DEPENDENCIES_BUNKER1/2/3 - для бункеров
//
// ========================================

// ========================================
// ОБРАБОТКА ГАРАНТИРОВАННЫХ ИСТОЧНИКОВ
// ========================================

// Кнопка E-Stop на общем ПМУ (NC контакт: FALSE = нажата)
qxReason_EStopButton := NOT ixEStopButton;

// Команда SCADA (импульсная, фиксируется до сброса)
_fbLatchScadaCommand(SET := ixScadaCommand, RESET1 := ixReset);
_xScadaCommandLatched := _fbLatchScadaCommand.Q1;
qxReason_ScadaCommand := _xScadaCommandLatched;

// Локальные кнопки E-Stop секций (NC контакты: FALSE = нажата)
qxAnyLocalEStopPressed := NOT ixEStopDumper OR NOT ixEStopConveyor
                       OR NOT ixEStopBunker1 OR NOT ixEStopBunker2 OR NOT ixEStopBunker3;
qxReason_EStopLocal := qxAnyLocalEStopPressed;

// ========================================
// ОБРАБОТКА НАСТРАИВАЕМЫХ ИСТОЧНИКОВ
// ========================================

// Потеря связи SCADA
qxReason_ScadaLoss := ENABLE_GLOBAL_ESTOP_SCADA_LOSS AND ixScadaLoss;

// Ошибка пропорций
qxReason_ProportionError := ENABLE_GLOBAL_ESTOP_PROPORTION AND ixProportionError;

// Датчики ZQ (сход ленты) - агрегация от обеих секций
qxReason_ZQ := ENABLE_GLOBAL_ESTOP_ZQ AND (ixDumperErrorZQ OR ixConveyorErrorZQ);

// Датчики HQ (кабель-тросовые)
qxReason_HQ := ENABLE_GLOBAL_ESTOP_HQ AND (ixDumperErrorHQ OR ixConveyorErrorHQ);

// Датчики SQ (ограждения)
qxReason_SQ := ENABLE_GLOBAL_ESTOP_SQ AND (ixDumperErrorSQ OR ixConveyorErrorSQ);

// Датчики GS (заштыбовка)
qxReason_GS := ENABLE_GLOBAL_ESTOP_GS AND (ixDumperErrorGS OR ixConveyorErrorGS);

// Датчики YS (продольный разрыв)
qxReason_YS := ENABLE_GLOBAL_ESTOP_YS AND (ixDumperErrorYS OR ixConveyorErrorYS);

// Датчики YE (металлодетектор) - только на конвейере
qxReason_YE := ENABLE_GLOBAL_ESTOP_YE AND ixConveyorErrorYE;

// Датчики QR (скорость)
qxReason_QR := ENABLE_GLOBAL_ESTOP_QR AND (ixDumperErrorQR OR ixConveyorErrorQR);

// Блокировочные зависимости
// Используется только ENABLE_GLOBAL_ESTOP_DEPENDENCIES (TRUE = активны, FALSE = отключены)
qxReason_Dependencies := ENABLE_GLOBAL_ESTOP_DEPENDENCIES AND ixDependencyError;

// Аварийный ток мотора
qxReason_MotorCurrent := ENABLE_GLOBAL_ESTOP_MOTOR_CURRENT_HH AND ixMotorCurrentHH;

// Авария VFD (частотного преобразователя)
qxReason_VFD_Failure := ENABLE_GLOBAL_ESTOP_VFD_FAILURE AND (ixDumperVFD_Failure OR ixConveyorVFD_Failure);

// ========================================
// ФОРМИРОВАНИЕ ГЛОБАЛЬНОГО СИГНАЛА АВАРИЙНОЙ ОСТАНОВКИ
// ========================================

// Глобальная остановка при:
// 1. Гарантированных источниках (ВСЕГДА активны)
// 2. Настраиваемых источниках (управляются через ENABLE_GLOBAL_ESTOP_*)

qxGlobalEmergencyStop :=
	// ГАРАНТИРОВАННЫЕ ИСТОЧНИКИ (всегда активны)
	qxReason_EStopButton
	OR qxReason_ScadaCommand
	OR qxReason_EStopLocal
	// НАСТРАИВАЕМЫЕ ИСТОЧНИКИ (каждый управляется своей опцией ENABLE_GLOBAL_ESTOP_*)
	OR qxReason_ScadaLoss
	OR qxReason_ProportionError
	OR qxReason_ZQ
	OR qxReason_HQ
	OR qxReason_SQ
	OR qxReason_GS
	OR qxReason_YS
	OR qxReason_YE
	OR qxReason_QR
	OR qxReason_Dependencies
	OR qxReason_MotorCurrent
	OR qxReason_VFD_Failure;

// ========================================
// ФОРМИРОВАНИЕ СИГНАЛОВ ОСТАНОВКИ ПО СЕКЦИЯМ
// ========================================

// Отвалообразователь
qxSectionStop_Dumper := qxGlobalEmergencyStop
	OR NOT ixEStopDumper  // Локальная кнопка E-Stop
	OR (ENABLE_ESTOP_DEPENDENCIES_DUMPER AND qxReason_Dependencies);

// Конвейер
qxSectionStop_Conveyor := qxGlobalEmergencyStop
	OR NOT ixEStopConveyor  // Локальная кнопка E-Stop
	OR (ENABLE_ESTOP_DEPENDENCIES_CONVEYOR AND qxReason_Dependencies);

// Бункер 1
qxSectionStop_Bunker1 := qxGlobalEmergencyStop
	OR NOT ixEStopBunker1  // Локальная кнопка E-Stop
	OR (ENABLE_ESTOP_DEPENDENCIES_BUNKER1 AND qxReason_Dependencies);

// Бункер 2
qxSectionStop_Bunker2 := qxGlobalEmergencyStop
	OR NOT ixEStopBunker2  // Локальная кнопка E-Stop
	OR (ENABLE_ESTOP_DEPENDENCIES_BUNKER2 AND qxReason_Dependencies);

// Бункер 3
qxSectionStop_Bunker3 := qxGlobalEmergencyStop
	OR NOT ixEStopBunker3  // Локальная кнопка E-Stop
	OR (ENABLE_ESTOP_DEPENDENCIES_BUNKER3 AND qxReason_Dependencies);

// ========================================
// КОНТРОЛЬ СБРОСА
// ========================================

// Сброс заблокирован, если причина не устранена
// Примечание: qxReason_ScadaCommand исключена, т.к. это импульсный сигнал
qxResetBlocked := qxReason_EStopButton
	OR qxReason_EStopLocal
	OR qxReason_ScadaLoss
	OR qxReason_ProportionError
	OR qxReason_ZQ
	OR qxReason_HQ
	OR qxReason_SQ
	OR qxReason_GS
	OR qxReason_YS
	OR qxReason_YE
	OR qxReason_QR
	OR qxReason_Dependencies
	OR qxReason_MotorCurrent
	OR qxReason_VFD_Failure;

// ========================================
// КОД ПРИЧИНЫ ДЛЯ SCADA
// ========================================

// Приоритет причин: от наиболее критичных к менее критичным
IF qxReason_EStopButton THEN
	qnReasonCode := 1;   // E-Stop кнопка на общем ПМУ
ELSIF qxReason_ScadaCommand THEN
	qnReasonCode := 2;   // Команда SCADA
ELSIF qxReason_EStopLocal THEN
	qnReasonCode := 3;   // Локальная кнопка E-Stop секции
ELSIF qxReason_HQ THEN
	qnReasonCode := 10;  // HQ (кабель-тросовый)
ELSIF qxReason_ZQ THEN
	qnReasonCode := 11;  // ZQ (сход ленты)
ELSIF qxReason_YS THEN
	qnReasonCode := 12;  // YS (продольный разрыв)
ELSIF qxReason_YE THEN
	qnReasonCode := 13;  // YE (металлодетектор)
ELSIF qxReason_SQ THEN
	qnReasonCode := 14;  // SQ (ограждение)
ELSIF qxReason_GS THEN
	qnReasonCode := 15;  // GS (заштыбовка)
ELSIF qxReason_QR THEN
	qnReasonCode := 16;  // QR (скорость)
ELSIF qxReason_ScadaLoss THEN
	qnReasonCode := 20;  // Потеря связи SCADA
ELSIF qxReason_Dependencies THEN
	qnReasonCode := 21;  // Блокировочные зависимости
ELSIF qxReason_ProportionError THEN
	qnReasonCode := 22;  // Ошибка пропорций
ELSIF qxReason_MotorCurrent THEN
	qnReasonCode := 30;  // Аварийный ток мотора (HH)
ELSIF qxReason_VFD_Failure THEN
	qnReasonCode := 31;  // Авария VFD (частотного преобразователя)
ELSE
	qnReasonCode := 0;   // Нет ошибки
END_IF

END_FUNCTION_BLOCK
