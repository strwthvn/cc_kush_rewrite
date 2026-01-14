FUNCTION_BLOCK FB_BunkerControl
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
	xLocalMode : BOOL; // TRUE = местный режим (ПМУ), FALSE = дистанционный режим (SCADA)
	xStart : BOOL; // Команда запуска вибропитателей (дистанционный режим)
	xStop : BOOL; // Команда остановки (дистанционный режим)
	xEmergencyStop : BOOL; // Аварийная остановка (переводит бункер в ERROR)
	xEmergencyStopVibrator : BOOL; // Аварийная остановка вибраторов (только отключает вибраторы)
	xReset : BOOL; // Сброс ошибок
	irManualFrequency : REAL; // Частота вибропитателей для ручного режима управления
	irManualFrequencyVibrator : REAL; // Частота вибраторов для ручного режима управления
END_VAR
VAR_OUTPUT
	eStage : E_StageWithPreStartAlarm; // Текущая стадия запуска вибропитателей
	eStageToSCADA : E_ScadaStatesDevice; // Передача состояния скаде
END_VAR
VAR
	// === I/O обработка ===
	fbBunkerIO : FB_BunkerIO;

	// === Аппаратное управление ===
	fbVibFeederMotors : FB_BunkerVibFeederMotors;
	fbVibratorMotors : FB_BunkerVibratorMotors;
	fbMotorErrors : FB_BunkerMotorErrors;
	fbSensors : FB_BunkerSensors;

	// === Вспомогательные блоки ===
	fbPneumoControl : FB_PneumoCollapseControl;

	// === Состояния ===
	STAGE : E_StageWithPreStartAlarm := E_StageWithPreStartAlarm.IDLE;

	// === Объединенные команды (ПМУ или SCADA в зависимости от режима) ===
	xStartCommand : BOOL; // Фактическая команда запуска (из ПМУ или SCADA)
	xStopCommand : BOOL; // Фактическая команда остановки (из ПМУ или SCADA)

	// === Команды для аппаратных блоков ===
	xStartVibFeeder : BOOL;
	xStopVibFeeder : BOOL;
	xSelectedVibrators : ARRAY[1..4] OF BOOL; // Выбор вибраторов (промежуточная переменная)

	// === Состояние схемы контакторов (TRUE = схема собрана, FALSE = схема разобрана) ===
	xCircuitBuilt : BOOL := FALSE;
	xCircuitBuiltVibrator : BOOL := FALSE;

	// === Целевая частота вибропитателей ===
	rTargetFreqVibFeeder : REAL := 0.0;

	// === Таймеры контроля выполнения команд ===
	fbTimerStarting : TON; // Тайм-аут запуска (STARTING → WORK)
	fbTimerStopping : TON; // Тайм-аут остановки (WORK → IDLE)

END_VAR

// ========================================
// FB_BunkerControl - Управление бункером
// ========================================
//
// РЕЖИМЫ УПРАВЛЕНИЯ:
//
// 1. МЕСТНЫЙ РЕЖИМ (xLocalMode = TRUE):
//    - Команды берутся с кнопок ПМУ (Bunker.fbBtnStart, fbBtnStop)
//    - ПУСК/СТОП вибропитателей по фронтам кнопок
//    - Автоматически устанавливает eStateRemote = Manual
//
// 2. ДИСТАНЦИОННЫЙ РЕЖИМ (xLocalMode = FALSE):
//    - Команды берутся из входов ФБ (xStart, xStop)
//    - Режим устанавливается через SCADA (Manual/Remote/Auto)
//
// УПРАВЛЕНИЕ ВИБРОПИТАТЕЛЯМИ:
// - ПУСК: включение вибропитателей с заданной частотой
// - СТОП: остановка вибропитателей
// - Частота: Auto - от ПИД, Manual/Repair - от irManualFrequency
//
// УПРАВЛЕНИЕ ВИБРАТОРАМИ:
// - Независимо от режима вибропитателей
// - Режимы:
//   * Auto - циклическая работа по таймеру (ACTIVE ↔ PAUSE)
//     - Работает только в стадии WORK вибропитателей
//     - Параметры: VIBRATOR_SETTINGS.TIME_ACTIVE, TIME_PAUSE_VIBRATOR
//     - Частота: irManualFrequencyVibrator
//   * Manual - выборочное управление через cmdAddVib1..4
//     - СТАРТ/СТОП по командам cmdStartVibrator/cmdStopVibrator
//     - Частота: irManualFrequencyVibrator
//   * Repair - все вибраторы остановлены
//
// ========================================

// ========================================
// ОБРАБОТКА I/O (все сигналы и устройства)
// ========================================

fbBunkerIO(Bunker := Bunker);

// ========================================
// АППАРАТНОЕ УПРАВЛЕНИЕ ВИБРОПИТАТЕЛЕЙ
// ========================================

fbVibFeederMotors(
	Bunker := Bunker,
	xStart := xStartVibFeeder,
	xStop := xStopVibFeeder,
	xEmergencyStop := xEmergencyStop OR NOT Bunker.fbBtnEmergencyStop.qxSignal,
	xReset := xReset,
	rTargetFrequency := rTargetFreqVibFeeder
);

// ========================================
// АППАРАТНОЕ УПРАВЛЕНИЕ ВИБРАТОРОВ
// ========================================

// Передача выбора вибраторов через промежуточную переменную
xSelectedVibrators[1] := Bunker.cmdAddVib1;
xSelectedVibrators[2] := Bunker.cmdAddVib2;
xSelectedVibrators[3] := Bunker.cmdAddVib3;
xSelectedVibrators[4] := Bunker.cmdAddVib4;

fbVibratorMotors(
	Bunker := Bunker,
	xEmergencyStop := xEmergencyStopVibrator,
	xReset := xReset,
	eVibratorMode := Bunker.eVibratorStateRemote,
	xManualStart := Bunker.cmdStartVibrator,
	xManualStop := Bunker.cmdStopVibrator,
	xSelectedVibrators := xSelectedVibrators,
	rTargetFrequency := irManualFrequencyVibrator,
	stVibratorSettings := VIBRATOR_SETTINGS,
	xEnableAutoMode := (STAGE = E_StageWithPreStartAlarm.WORK)
);

// ========================================
// ПРОВЕРКА ОШИБОК
// ========================================

fbMotorErrors(
	Bunker := Bunker,
	xReset := xReset
);

fbSensors(
	Bunker := Bunker,
	xReset := xReset
);

// Агрегация ошибок для отчёта в SCADA
Bunker.xStateFailure := fbMotorErrors.xErrorMotorVibFeeder_Any
                     OR fbMotorErrors.xErrorBunker;

// ========================================
// ОПРЕДЕЛЕНИЕ СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Проверка предупреждений вибропитателей:
// 1. Контроль тока моторов вибропитателей - уровень L или H
// 2. Температура подшипников - уровень L или H
Bunker.xStateWarning := Bunker.MotorVibFeeder[1].VFD.fbRangeDiagnostic.qxWarningActive
                     OR Bunker.MotorVibFeeder[2].VFD.fbRangeDiagnostic.qxWarningActive
                     OR Bunker.MotorVibFeeder[1].fbRangeDiagnostic[1].qxWarningActive
                     OR Bunker.MotorVibFeeder[1].fbRangeDiagnostic[2].qxWarningActive
                     OR Bunker.MotorVibFeeder[2].fbRangeDiagnostic[1].qxWarningActive
                     OR Bunker.MotorVibFeeder[2].fbRangeDiagnostic[2].qxWarningActive;

// ========================================
// ВЫБОР ИСТОЧНИКА КОМАНД (ПМУ ИЛИ SCADA)
// ========================================

// В местном режиме (xLocalMode = TRUE) - команды берутся с ПМУ (кнопки)
// В дистанционном режиме (xLocalMode = FALSE) - команды берутся из SCADA (входы ФБ)
IF xLocalMode THEN
	// Местный режим - команды с ПМУ
	xStartCommand := Bunker.fbBtnStart.qxRisingEdge; // ПУСК по фронту кнопки
	xStopCommand := Bunker.fbBtnStop.qxRisingEdge;   // СТОП по фронту кнопки
ELSE
	// Дистанционный режим - команды из SCADA
	xStartCommand := xStart;
	xStopCommand := xStop;
END_IF;

// ========================================
// АВТОМАТ СОСТОЯНИЙ ЗАПУСКА ВИБРОПИТАТЕЛЕЙ
// ========================================

// ПРИОРИТЕТНАЯ ПРОВЕРКА АВАРИЙНОЙ ОСТАНОВКИ ВИБРОПИТАТЕЛЕЙ
// Аварийная остановка питателей имеет наивысший приоритет и срабатывает в любой стадии
// 1. Внешний сигнал аварийной остановки (от FB_EmergencyStopCollector)
// 2. Кнопка аварийной остановки на ПМУ (NC контакт: FALSE = кнопка нажата) - ГАРАНТИРОВАННАЯ
IF xEmergencyStop OR NOT Bunker.fbBtnEmergencyStop.qxSignal THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// ПРОВЕРКА ТАЙМ-АУТОВ ВЫПОЛНЕНИЯ КОМАНД
// Тайм-аут запуска: не удалось запустить вибропитатели за установленное время
IF fbTimerStarting.Q THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// Тайм-аут остановки: не удалось остановить вибропитатели за установленное время
IF fbTimerStopping.Q THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// Обработка команды останова (общий блок для всех стадий, кроме IDLE и ERROR)
IF xStopCommand AND (STAGE <> E_StageWithPreStartAlarm.IDLE) AND (STAGE <> E_StageWithPreStartAlarm.ERROR) THEN
	// Запуск таймера остановки (тайм-аут на остановку вибропитателей)
	fbTimerStopping(
		IN := TRUE,
		PT := TIME_TIMEOUT_STOP_BUNKER
	);

	// Команда остановки через агрегатный ФБ
	xStopVibFeeder := TRUE;

	// Проверка остановки VFD через агрегатный ФБ
	IF fbVibFeederMotors.eStage = E_StageActuator.IDLE THEN
		// Сброс таймера остановки (успешная остановка)
		fbTimerStopping(IN := FALSE);
		STAGE := E_StageWithPreStartAlarm.IDLE;
	END_IF;
END_IF

CASE STAGE OF
	E_StageWithPreStartAlarm.IDLE:
		// Сброс таймеров запуска и остановки
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);

		// Сброс целевых частот
		rTargetFreqVibFeeder := 0.0;

		// Сброс команд
		xStartVibFeeder := FALSE;
		xStopVibFeeder := FALSE;

		// Переход в STARTING при получении команды запуска
		IF xStartCommand THEN
			STAGE := E_StageWithPreStartAlarm.STARTING;
		END_IF

	E_StageWithPreStartAlarm.STARTING:
		// Запуск таймера запуска (тайм-аут на запуск вибропитателей)
		// Для бункеров используем соответствующую уставку (TIME_AFTER_START_BUNKER_1/2/3)
		// Но так как это общий FB, используем универсальную уставку
		fbTimerStarting(
			IN := TRUE,
			PT := TIME_AFTER_START_BUNKER_1 // Можно сделать параметром VAR_INPUT если нужно разные уставки для разных бункеров
		);

		// Команда ПУСК через агрегатный ФБ
		xStartVibFeeder := TRUE;

		// Выбор источника частоты в зависимости от режима управления
		IF Bunker.eStateRemote = E_StateRemote.Auto THEN
			// Автоматический режим - частота от ПИД
			rTargetFreqVibFeeder := irManualFrequency; // TODO ВРЕМЕННО Bunker.rMotorVibFeederCommonFrequency
		ELSE
			// Ручной/Ремонт режим - частота от входного параметра irManualFrequency
			rTargetFreqVibFeeder := irManualFrequency;
		END_IF;

		// Переход в WORK по включению оборудования (через агрегатный ФБ)
		IF fbVibFeederMotors.eStage = E_StageActuator.WORK THEN
			// Сброс таймера запуска (успешный запуск)
			fbTimerStarting(IN := FALSE);
			STAGE := E_StageWithPreStartAlarm.WORK;
		END_IF

	E_StageWithPreStartAlarm.WORK:

		// Выбор источника частоты в зависимости от режима управления
		IF Bunker.eStateRemote = E_StateRemote.Auto THEN
			// Автоматический режим - динамическая частота от ПИД
			rTargetFreqVibFeeder := irManualFrequency; // TODO ВРЕМЕННО Bunker.rMotorVibFeederCommonFrequency
		ELSE
			// Ручной/Ремонт режим - частота от входного параметра irManualFrequency
			rTargetFreqVibFeeder := irManualFrequency;
		END_IF;

	E_StageWithPreStartAlarm.ERROR:
		// Состояние ошибки - аварийная остановка и ожидание сброса
		// (используется при серьезных неисправностях, не для штатной остановки)

		// Сброс таймеров
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);

		// Аварийная остановка вибропитателей (обрабатывается в агрегатном ФБ через xEmergencyStop)
		xStartVibFeeder := FALSE;
		xStopVibFeeder := FALSE;

		// Сброс целевых частот
		rTargetFreqVibFeeder := 0.0;

		// Разборка схемы контакторов (аварийная остановка)
		IF Bunker.eStateRemote = E_StateRemote.Auto THEN
			xCircuitBuilt := FALSE;
		END_IF;
		// Контакторы управляются отдельно через импульсные команды
		// cmdBuildCircuitOn/Off (см. секцию УПРАВЛЕНИЕ КОНТАКТОРАМИ)

		// Сброс ошибки и переход в IDLE при отсутствии ошибок
		// Для выхода из ERROR требуется:
		// 1. Команда сброса (xReset)
		// 2. Снятие сигнала аварийной остановки (NOT xEmergencyStop)
		// 3. Кнопка аварийной остановки отпущена (NC контакт: TRUE = кнопка отпущена)
		// 4. Отсутствие ошибок оборудования (NOT Bunker.xStateFailure)
		IF xReset AND NOT xEmergencyStop AND Bunker.fbBtnEmergencyStop.qxSignal AND NOT Bunker.xStateFailure THEN
			STAGE := E_StageWithPreStartAlarm.IDLE;
		END_IF

END_CASE;

// Выходной параметр - текущая стадия
eStage := STAGE;

// ========================================
// ОБНОВЛЕНИЕ РЕЖИМА УПРАВЛЕНИЯ
// ========================================

// Если установлен местный режим (xLocalMode = TRUE), то переводим в Manual
// Manual может работать как дистанционно (от SCADA), так и местно (от ПМУ)
IF xLocalMode THEN
	Bunker.eStateRemote := E_StateRemote.Manual;
END_IF;

// ========================================
// УПРАВЛЕНИЕ РЕЖИМАМИ ВИБРАТОРОВ
// ========================================

// Обработка команд переключения режима управления вибраторов
IF Bunker.cmdVibratorSetModeAuto THEN
	Bunker.eVibratorStateRemote := E_StateRemote.Auto;
ELSIF Bunker.cmdVibratorSetModeManual THEN
	Bunker.eVibratorStateRemote := E_StateRemote.Manual;
ELSIF Bunker.cmdVibratorSetModeRepair THEN
	Bunker.eVibratorStateRemote := E_StateRemote.Repair;
END_IF;

// ========================================
// УПРАВЛЕНИЕ КОНТАКТОРАМИ
// ========================================

// РУЧНОЙ РЕЖИМ (Manual):
// - Схема управляется ТОЛЬКО импульсными командами cmdBuildCircuitOn/Off
// - Автоматическая сборка/разборка схемы ОТКЛЮЧЕНА
//
// АВТОМАТИЧЕСКИЙ РЕЖИМ (Auto/Remote):
// - Схема собирается АВТОМАТИЧЕСКИ при отсутствии ошибок секции:
//   * Нет ошибок по оборудованию бункера (FC_Bunker_GetErrorBunker = FALSE)
//   * Секция НЕ в стадии ERROR
// - Схема разбирается АВТОМАТИЧЕСКИ при появлении ошибок или переходе в ERROR

// === ВИБРОПИТАТЕЛИ ===
IF Bunker.eStateRemote = E_StateRemote.Manual THEN
	// РУЧНОЙ РЕЖИМ - Обработка импульсных команд сборки/разборки схемы вибропитателей
	// cmdBuildCircuitOn - собрать схему (включить контакторы)
	// cmdBuildCircuitOff - разобрать схему (выключить контакторы)
	IF Bunker.cmdBuildCircuitOn THEN
		xCircuitBuilt := TRUE;
		Bunker.cmdBuildCircuitOn := FALSE; // Сброс импульсной команды
	ELSIF Bunker.cmdBuildCircuitOff THEN
		xCircuitBuilt := FALSE;
		Bunker.cmdBuildCircuitOff := FALSE; // Сброс импульсной команды
	END_IF;
ELSIF Bunker.eStateRemote = E_StateRemote.Auto THEN
	// АВТОМАТИЧЕСКИЙ РЕЖИМ - Автоматическая сборка схемы при отсутствии ошибок
	// Собираем схему если:
	// 1. Нет ошибок по оборудованию бункера (моторы вибропитателей и вибраторов)
	// 2. Секция НЕ в стадии ERROR
	IF NOT fbMotorErrors.xErrorBunker AND STAGE <> E_StageWithPreStartAlarm.ERROR AND Bunker.eStateRemote = E_StateRemote.Auto THEN
		xCircuitBuilt := TRUE;
	//ELSE
		//xCircuitBuilt := FALSE;
	END_IF;
END_IF;

// Управление схемой вибраторов
IF Bunker.eVibratorStateRemote = E_StateRemote.Manual THEN
	// РУЧНОЙ РЕЖИМ - Обработка импульсных команд сборки/разборки схемы вибраторов
	// cmdBuildCircuitOnVibrator - собрать схему вибраторов (включить контакторы)
	// cmdBuildCircuitOffVibrator - разобрать схему вибраторов (выключить контакторы)
	IF Bunker.cmdBuildCircuitOnVibrator THEN
		xCircuitBuiltVibrator := TRUE;
		Bunker.cmdBuildCircuitOnVibrator := FALSE; // Сброс импульсной команды
	ELSIF Bunker.cmdBuildCircuitOffVibrator THEN
		xCircuitBuiltVibrator := FALSE;
		Bunker.cmdBuildCircuitOffVibrator := FALSE; // Сброс импульсной команды
	END_IF;
ELSIF Bunker.eVibratorStateRemote = E_StateRemote.Auto THEN
	// АВТОМАТИЧЕСКИЙ РЕЖИМ - Автоматическая сборка схемы вибраторов при отсутствии ошибок
	// Собираем схему если:
	// 1. Нет ошибок по оборудованию бункера (моторы вибропитателей и вибраторов)
	// 2. Секция НЕ в стадии ERROR
	IF NOT fbMotorErrors.xErrorBunker AND STAGE <> E_StageWithPreStartAlarm.ERROR THEN
		xCircuitBuiltVibrator := TRUE;
	//ELSE
		//xCircuitBuiltVibrator := FALSE;
	END_IF;
END_IF;

// Моторы вибропитателей - управление контакторами через состояние схемы
Bunker.MotorVibFeeder[1].qxKM_Power := xCircuitBuilt;
Bunker.MotorVibFeeder[2].qxKM_Power := xCircuitBuilt;

// Моторы вибраторов - управление контакторами через состояние схемы
Bunker.MotorVibrator[1].qxKM_Power := xCircuitBuiltVibrator;
Bunker.MotorVibrator[2].qxKM_Power := xCircuitBuiltVibrator;
Bunker.MotorVibrator[3].qxKM_Power := xCircuitBuiltVibrator;
Bunker.MotorVibrator[4].qxKM_Power := xCircuitBuiltVibrator;

// ========================================
// РУЧНОЕ УПРАВЛЕНИЕ СВЕТОФОРОМ
// ========================================

IF Bunker.eStateRemoteLighter = E_StateRemote.Manual THEN
	// Команда переключения на КРАСНЫЙ
	IF Bunker.cmdLighetSetColorRed THEN FC_Bunker_SetLightColor(Bunker:= Bunker, eColor:= E_LightColor.RED);
	// Команда переключения на ЖЕЛТЫЙ
	ELSIF Bunker.cmdLighetSetColorYellow THEN FC_Bunker_SetLightColor(Bunker:= Bunker, eColor:= E_LightColor.YELLOW);
	// Команда переключения на ЗЕЛЕНЫЙ
	ELSIF Bunker.cmdLighetSetColorGreen THEN FC_Bunker_SetLightColor(Bunker:= Bunker, eColor:= E_LightColor.GREEN);
	// Команда переключения на ВЫКЛЮЧИТЬ
	ELSIF Bunker.cmdLighetSetColorOff THEN FC_Bunker_SetLightColor(Bunker:= Bunker, eColor:= E_LightColor.OFF); END_IF;
END_IF;

// Режим управления АВТО
IF Bunker.cmdLighterSetModeAuto THEN Bunker.eStateRemoteLighter := E_StateRemote.Auto; END_IF;
// Режим управления РУЧНОЙ
IF Bunker.cmdLighterSetModeManual THEN Bunker.eStateRemoteLighter := E_StateRemote.Manual; END_IF;
// Режим управления РЕМОНТ
IF Bunker.cmdLighterSetModeRepair THEN Bunker.eStateRemoteLighter := E_StateRemote.Repair; END_IF;

// ========================================
// ПЕРЕДАЧА СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Приоритет проверки: от более критичных к менее критичным
IF STAGE = E_StageWithPreStartAlarm.ERROR THEN
	// Ошибка без активной работы
	eStageToSCADA := E_ScadaStatesDevice.ERROR;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK AND Bunker.xStateFailure THEN
	// TODO: Секция работает с аварией (требует уточнения логики)
	// Обычно при ошибке должна быть остановка, но оставляем для будущей реализации
	eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_ERROR;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK AND Bunker.xStateWarning THEN
	// Секция работает с предупреждением
	eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_WARNING;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK THEN
	// Секция работает в норме (нет ошибок и предупреждений)
	eStageToSCADA := E_ScadaStatesDevice.WORK;

ELSIF STAGE = E_StageWithPreStartAlarm.STARTING THEN
	// Секция в процессе запуска (разгон вибропитателей)
	eStageToSCADA := E_ScadaStatesDevice.STARTING;

ELSIF STAGE = E_StageWithPreStartAlarm.IDLE AND Bunker.xStateWarning THEN
	// Предупреждение без активной работы
	eStageToSCADA := E_ScadaStatesDevice.WARNING;

ELSIF STAGE = E_StageWithPreStartAlarm.IDLE AND Bunker.xStateFailure THEN
	// Секция неготова к запуску (есть ошибки)
	eStageToSCADA := E_ScadaStatesDevice.NOT_READY;

ELSE
	// Секция готова к запуску (IDLE, нет ошибок и предупреждений)
	eStageToSCADA := E_ScadaStatesDevice.READY;

END_IF;

// Передача состояний режима управления вибропитателей
Bunker.xStateRemoteAuto := Bunker.eStateRemote = E_StateRemote.Auto;
Bunker.xStateRemoteManual := Bunker.eStateRemote = E_StateRemote.Manual;
Bunker.xStateRemoteRepair := Bunker.eStateRemote = E_StateRemote.Repair;

// Передача состояний режима управления вибраторов
Bunker.xVibratorStateRemoteAuto := Bunker.eVibratorStateRemote = E_StateRemote.Auto;
Bunker.xVibratorStateRemoteManual := Bunker.eVibratorStateRemote = E_StateRemote.Manual;
Bunker.xVibratorStateRemoteRepair := Bunker.eVibratorStateRemote = E_StateRemote.Repair;

// Передача состояний режима управления светофора
Bunker.xLighterStateRemoteAuto := Bunker.eStateRemoteLighter = E_StateRemote.Auto;
Bunker.xLighterStateRemoteManual := Bunker.eStateRemoteLighter = E_StateRemote.Manual;
Bunker.xLighterStateRemoteRepair := Bunker.eStateRemoteLighter = E_StateRemote.Repair;

END_FUNCTION_BLOCK
