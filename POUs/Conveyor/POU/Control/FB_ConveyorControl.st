FUNCTION_BLOCK FB_ConveyorControl
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
	xLocalMode : BOOL; // TRUE = местный режим (ПМУ), FALSE = дистанционный режим (SCADA)
	xStart : BOOL; // Команда запуска конвейера (дистанционный режим)
	xStop : BOOL; // Команда остановки (дистанционный режим)
	xEmergencyStop : BOOL; // Аварийная остановка
	xReset : BOOL; // Сброс в начальное состояние
END_VAR
VAR_OUTPUT
	eStage : E_StageWithPreStartAlarm; // Текущая стадия
	eStageToSCADA : E_ScadaStatesDevice; // Передача состояния скаде
END_VAR
VAR
	// I/O обработка
	fbConveyorIO : FB_ConveyorIO;

	// Аппаратное управление
	fbConveyorMotors : FB_ConveyorMotors; // Управление моторами конвейера
	fbSensors : FB_ConveyorSensors; // Обработка датчиков безопасности
	fbMotorErrors : FB_ConveyorMotorErrors; // Проверка ошибок моторов

	// Состояния
	STAGE : E_StageWithPreStartAlarm := E_StageWithPreStartAlarm.IDLE;

	// Объединенные команды (ПМУ или SCADA в зависимости от режима)
	xStartCommand : BOOL; // Фактическая команда запуска (из ПМУ или SCADA)
	xStopCommand : BOOL; // Фактическая команда остановки (из ПМУ или SCADA)

	// Команды для аппаратных блоков
	xStartConveyor : BOOL; // Команда запуска конвейера
	xStopConveyor : BOOL;  // Команда остановки конвейера

	// Состояние схемы контакторов (TRUE = схема собрана, FALSE = схема разобрана)
	xCircuitBuilt : BOOL := FALSE;

	simInit : BOOL;
END_VAR

// ========================================
// FB_ConveyorControl - Управление сборным конвейером
// ========================================
//
// РЕЖИМЫ УПРАВЛЕНИЯ:
//
// 1. МЕСТНЫЙ РЕЖИМ (xLocalMode = TRUE):
//    - Команды берутся с кнопок ПМУ (Conveyor.fbBtnStart, fbBtnStop)
//    - ПУСК/СТОП по фронтам кнопок
//    - Автоматически устанавливает eStateRemote = Manual
//
// 2. ДИСТАНЦИОННЫЙ РЕЖИМ (xLocalMode = FALSE):
//    - Команды берутся из входов ФБ (xStart, xStop)
//    - Режим устанавливается через SCADA (Manual/Remote/Auto)
//
// УПРАВЛЕНИЕ КОНВЕЙЕРОМ:
// - ПУСК: включение конвейеров с предпусковой сигнализацией
// - СТОП: плавная остановка с последовательным выключением VFD и тормозов
//
// ========================================

// ========================================
// ОБРАБОТКА I/O (все сигналы и устройства)
// ========================================

fbConveyorIO(Conveyor := Conveyor);

// ========================================
// АППАРАТНОЕ УПРАВЛЕНИЕ МОТОРАМИ КОНВЕЙЕРА
// ========================================

fbConveyorMotors(
	Conveyor := Conveyor,
	xStart := xStartConveyor,
	xStop := xStopConveyor,
	xEmergencyStop := xEmergencyStop OR NOT Conveyor.fbBtnEmergencyStop.qxSignal,
	xReset := xReset,
	rTargetFrequency := MOTOR_FREQUENCY_CONVEYOR
);

// ========================================
// ОБРАБОТКА ДАТЧИКОВ БЕЗОПАСНОСТИ
// ========================================

fbSensors(
	Conveyor := Conveyor,
	xReset := xReset
);

// ========================================
// ПРОВЕРКА ОШИБОК МОТОРОВ
// ========================================

fbMotorErrors(
	Conveyor := Conveyor,
	xReset := xReset
);

// ========================================
// ПРЕДПУСКОВАЯ СИГНАЛИЗАЦИЯ
// ========================================

Conveyor.fbPreStartAlarm(
	ixStart := STAGE = PRESTART_ALARM,
	ixStop := xStopCommand OR xReset,
	itFirstSignal := CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL,
	itPauseAfterFirst := CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE,
	itSecondSignal := CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL,
	itPauseAfterSecond := CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE,
	qxAlarmPower => Conveyor.xHLA
);

Conveyor.xStateEnable := STAGE = E_StageWithPreStartAlarm.WORK;
Conveyor.xStateStarting := STAGE = E_StageWithPreStartAlarm.STARTING OR STAGE = PRESTART_ALARM;

// ========================================
// ОПРЕДЕЛЕНИЕ СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Проверка ошибок оборудования
IF fbSensors.xErrorSafetySensors OR fbMotorErrors.xErrorMotors THEN
	Conveyor.xStateFailure := TRUE;
END_IF;

// Проверка предупреждений:
// 1. Датчики безопасности - уровень Warning
// 2. Контроль тока моторов - уровень L или H
Conveyor.xStateWarning := fbSensors.xWarningSafetySensors
                       OR Conveyor.MotorConveyor[1].VFD.fbRangeDiagnostic.qxWarningActive
                       OR Conveyor.MotorConveyor[2].VFD.fbRangeDiagnostic.qxWarningActive;

// ========================================
// ОБРАБОТКА ОСТАНОВКИ И СБРОСА
// ========================================

// Сброс в начальное состояние
IF xReset THEN
	Conveyor.xStateFailure := FALSE;
END_IF

// ========================================
// ВЫБОР ИСТОЧНИКА КОМАНД (ПМУ ИЛИ SCADA)
// ========================================

// В местном режиме (xLocalMode = TRUE) - команды берутся с ПМУ (кнопки)
// В дистанционном режиме (xLocalMode = FALSE) - команды берутся из SCADA (входы ФБ)
IF xLocalMode THEN
	// Местный режим - команды с ПМУ
	xStartCommand := Conveyor.fbBtnStart.qxRisingEdge; // ПУСК по фронту кнопки
	xStopCommand := Conveyor.fbBtnStop.qxRisingEdge;   // СТОП по фронту кнопки
ELSE
	// Дистанционный режим - команды из SCADA
	xStartCommand := xStart;
	xStopCommand := xStop;
END_IF;

// ========================================
// АВТОМАТ ПУСКА КОНВЕЙЕРА
// ========================================

// ПРИОРИТЕТНАЯ ПРОВЕРКА АВАРИЙНОЙ ОСТАНОВКИ
// Аварийная остановка имеет наивысший приоритет и срабатывает в любой стадии
// 1. Внешний сигнал аварийной остановки (от FB_EmergencyStopCollector)
//    - включает все настраиваемые источники (датчики, зависимости, и т.д.)
// 2. Кнопка аварийной остановки на ПМУ (NC контакт: FALSE = кнопка нажата) - ГАРАНТИРОВАННАЯ
//
// ПРИМЕЧАНИЕ: Проверка датчиков безопасности (fbSensors.xErrorSafetySensors) теперь
// централизована в FB_EmergencyStopCollector и передаётся через вход xEmergencyStop.
// Настройка источников аварийной остановки выполняется через опции ENABLE_GLOBAL_ESTOP_*
// в GLOBAL.st (например, ENABLE_GLOBAL_ESTOP_ZQ, ENABLE_GLOBAL_ESTOP_HQ и т.д.).
IF xEmergencyStop OR NOT Conveyor.fbBtnEmergencyStop.qxSignal THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// ПРОВЕРКА ТАЙМ-АУТОВ ВЫПОЛНЕНИЯ КОМАНД (флаги из аппаратных блоков)
// Тайм-аут запуска моторов конвейера
IF fbConveyorMotors.xStartingTimeout THEN
	Conveyor.xStateFailure := TRUE;
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// Тайм-аут остановки моторов конвейера
IF fbConveyorMotors.xStoppingTimeout THEN
	Conveyor.xStateFailure := TRUE;
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

CASE STAGE OF
	E_StageWithPreStartAlarm.IDLE:
		// Сброс команд управления конвейером
		xStartConveyor := FALSE;
		xStopConveyor := FALSE;

		// Команда запуска верхнего уровня
		IF xStartCommand THEN
			STAGE := PRESTART_ALARM;
		END_IF;

	PRESTART_ALARM:
		// Проверка команды остановки во время предпусковой сигнализации
		IF xStopCommand THEN
			// Прервать предпусковую сигнализацию и вернуться в IDLE
			STAGE := E_StageWithPreStartAlarm.IDLE;
		ELSIF Conveyor.fbPreStartAlarm.qxComplete THEN
			// ППЗ завершена, запускаем конвейер
			xStartConveyor := TRUE;
			STAGE := E_StageWithPreStartAlarm.STARTING;
		END_IF;

	E_StageWithPreStartAlarm.STARTING:
		// Проверка команды остановки во время запуска
		IF xStopCommand THEN
			// Прервать запуск и остановить конвейер
			xStartConveyor := FALSE;
			xStopConveyor := TRUE;
			STAGE := E_StageWithPreStartAlarm.WORK; // Переход в WORK для обработки остановки
		END_IF;

		// Проверка состояния аппаратного блока конвейера
		// Тайм-аут запуска контролируется в fbConveyorMotors
		IF fbConveyorMotors.eStage = E_StageActuator.WORK THEN
			// Конвейер запущен, переходим в WORK
			STAGE := E_StageWithPreStartAlarm.WORK;
		END_IF;

	E_StageWithPreStartAlarm.WORK:
		// Нормальная работа

		// Команда остановки
		IF xStopCommand THEN
			// Начать штатную остановку
			xStartConveyor := FALSE;
			xStopConveyor := TRUE;
		END_IF;

		// Проверка завершения остановки
		// Тайм-аут остановки контролируется в fbConveyorMotors
		IF xStopConveyor AND fbConveyorMotors.eStage = E_StageActuator.IDLE THEN
			// Конвейер остановлен, переходим в IDLE
			STAGE := E_StageWithPreStartAlarm.IDLE;
		END_IF;

	E_StageWithPreStartAlarm.ERROR:
		// Состояние ошибки - аварийная остановка и ожидание сброса
		// (используется при серьезных неисправностях, не для штатной остановки)

		// Аварийная остановка конвейера (обрабатывается аппаратным блоком через xEmergencyStop)
		xStartConveyor := FALSE;
		xStopConveyor := FALSE; // Аварийная остановка через xEmergencyStop

		// Разборка схемы контакторов (аварийная остановка)
		IF Conveyor.eStateRemote = E_StateRemote.Auto THEN
			xCircuitBuilt := FALSE;
		END_IF;

		// Сброс ошибки и переход в IDLE при отсутствии ошибок
		// Для выхода из ERROR требуется:
		// 1. Команда сброса (xReset)
		// 2. Снятие сигнала аварийной остановки (NOT xEmergencyStop)
		// 3. Кнопка аварийной остановки отпущена (NC контакт: TRUE = кнопка отпущена)
		// 4. Отсутствие ошибок оборудования (NOT Conveyor.xStateFailure)
		IF xReset AND NOT xEmergencyStop AND Conveyor.fbBtnEmergencyStop.qxSignal AND NOT Conveyor.xStateFailure THEN
			STAGE := E_StageWithPreStartAlarm.IDLE;
		END_IF
END_CASE;

// Вывод текущей стадии
eStage := STAGE;

// ========================================
// УПРАВЛЕНИЕ КОНТАКТОРАМИ
// ========================================

// РУЧНОЙ РЕЖИМ (Manual):
// - Схема управляется ТОЛЬКО импульсными командами cmdBuildCircuitOn/Off
// - Автоматическая сборка/разборка схемы ОТКЛЮЧЕНА
//
// АВТОМАТИЧЕСКИЙ РЕЖИМ (Auto/Remote):
// - Схема собирается АВТОМАТИЧЕСКИ при отсутствии ошибок секции:
//   * Нет ошибок по датчикам безопасности (fbSensors.xErrorSafetySensors = FALSE)
//   * Секция НЕ в стадии ERROR
// - Схема разбирается АВТОМАТИЧЕСКИ при появлении ошибок или переходе в ERROR

IF Conveyor.eStateRemote = E_StateRemote.Manual THEN
	// РУЧНОЙ РЕЖИМ - Обработка импульсных команд сборки/разборки схемы
	// cmdBuildCircuitOn - собрать схему (включить контакторы)
	// cmdBuildCircuitOff - разобрать схему (выключить контакторы)
	IF Conveyor.cmdBuildCircuitOn THEN
		xCircuitBuilt := TRUE;
		Conveyor.cmdBuildCircuitOn := FALSE; // Сброс импульсной команды
	ELSIF Conveyor.cmdBuildCircuitOff THEN
		xCircuitBuilt := FALSE;
		Conveyor.cmdBuildCircuitOff := FALSE; // Сброс импульсной команды
	END_IF;
ELSIF Conveyor.eStateRemote = E_StateRemote.Auto THEN
	// АВТОМАТИЧЕСКИЙ РЕЖИМ - Автоматическая сборка схемы при отсутствии ошибок
	// Собираем схему если:
	// 1. Нет ошибок по датчикам безопасности
	// 2. Секция НЕ в стадии ERROR
	IF NOT fbSensors.xErrorSafetySensors AND STAGE <> E_StageWithPreStartAlarm.ERROR THEN
		xCircuitBuilt := TRUE;
	ELSE
		xCircuitBuilt := FALSE;
	END_IF;
END_IF;

// Моторы конвейера - управление контакторами через состояние схемы
Conveyor.MotorConveyor[1].qxKM_Power := xCircuitBuilt;
Conveyor.MotorConveyor[2].qxKM_Power := xCircuitBuilt;

// ========================================
// ОБНОВЛЕНИЕ РЕЖИМА УПРАВЛЕНИЯ
// ========================================

// Если установлен местный режим (xLocalMode = TRUE), то переводим в Manual
// Manual может работать как дистанционно (от SCADA), так и местно (от ПМУ)
IF xLocalMode THEN
	Conveyor.eStateRemote := E_StateRemote.Manual;
END_IF;

// ========================================
// ПЕРЕДАЧА СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Приоритет проверки: от более критичных к менее критичным
IF STAGE = E_StageWithPreStartAlarm.ERROR THEN
	// Ошибка без активной работы
	eStageToSCADA := E_ScadaStatesDevice.ERROR;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK AND Conveyor.xStateFailure THEN
	// TODO: Секция работает с аварией (требует уточнения логики)
	// Обычно при ошибке должна быть остановка, но оставляем для будущей реализации
	eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_ERROR;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK AND Conveyor.xStateWarning THEN
	// Секция работает с предупреждением
	eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_WARNING;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK THEN
	// Секция работает в норме (нет ошибок и предупреждений)
	eStageToSCADA := E_ScadaStatesDevice.WORK;

ELSIF Conveyor.xStateStarting THEN
	// Секция в процессе запуска (предпусковая сигнализация или разгон)
	eStageToSCADA := E_ScadaStatesDevice.STARTING;

ELSIF STAGE = E_StageWithPreStartAlarm.IDLE AND Conveyor.xStateWarning THEN
	// Предупреждение без активной работы
	eStageToSCADA := E_ScadaStatesDevice.WARNING;

ELSIF STAGE = E_StageWithPreStartAlarm.IDLE AND Conveyor.xStateFailure THEN
	// Секция неготова к запуску (есть ошибки)
	eStageToSCADA := E_ScadaStatesDevice.NOT_READY;

ELSE
	// Секция готова к запуску (IDLE, нет ошибок и предупреждений)
	eStageToSCADA := E_ScadaStatesDevice.READY;

END_IF;

// Передача состояний режима управления
Conveyor.xStateRemoteAuto := Conveyor.eStateRemote = E_StateRemote.Auto;
Conveyor.xStateRemoteManual := Conveyor.eStateRemote = E_StateRemote.Manual;
Conveyor.xStateRemoteRepair := Conveyor.eStateRemote = E_StateRemote.Repair;

END_FUNCTION_BLOCK
