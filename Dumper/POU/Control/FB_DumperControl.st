FUNCTION_BLOCK FB_DumperControl
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
	xLocalMode : BOOL; // TRUE = местный режим (ПМУ), FALSE = дистанционный режим (SCADA)
	xStart : BOOL; // Команда запуска отвалообразователя (дистанционный режим)
	xStop : BOOL; // Команда остановки (дистанционный режим)
	xEmergencyStop : BOOL; // Аварийная остановка
	xReset : BOOL; // Сброс в начальное состояние
	xDisableAutoEmergencyStop : BOOL; // Отключение автоматических аварийных остановок по датчикам безопасности
END_VAR
VAR_OUTPUT
	eStage : E_StageWithPreStartAlarm; // Текущая стадия
	eStageToSCADA : E_ScadaStatesDevice; // Передача состояния скаде
END_VAR
VAR
	// I/O обработка
	fbDumperIO : FB_DumperIO;

	// Аппаратное управление
	fbConveyorMotors : FB_DumperConveyorMotors; // Управление моторами конвейера
	fbRotationMotors : FB_DumperRotationMotors; // Управление моторами поворота
	fbSensors : FB_DumperSensors; // Обработка датчиков безопасности
	fbMotorErrors : FB_DumperMotorErrors; // Проверка ошибок моторов

	// Состояния
	STAGE : E_StageWithPreStartAlarm := E_StageWithPreStartAlarm.IDLE;

	// Объединенные команды (ПМУ или SCADA в зависимости от режима)
	xStartCommand : BOOL; // Фактическая команда запуска (из ПМУ или SCADA)
	xStopCommand : BOOL; // Фактическая команда остановки (из ПМУ или SCADA)

	// Команды для аппаратных блоков
	xStartConveyor : BOOL; // Команда запуска конвейера
	xStopConveyor : BOOL;  // Команда остановки конвейера
	xTurnLeft : BOOL;      // Команда поворота влево
	xTurnRight : BOOL;     // Команда поворота вправо
	xStopRotation : BOOL;  // Команда остановки поворота

	// Состояние схемы контакторов (TRUE = схема собрана, FALSE = схема разобрана)
	xCircuitBuilt : BOOL := FALSE;
	xCircuitBuiltRotation : BOOL := FALSE;

	// Таймеры контроля выполнения команд
	fbTimerStarting : TON; // Тайм-аут запуска (STARTING → WORK)
	fbTimerStopping : TON; // Тайм-аут остановки (WORK → IDLE)

	simInit : BOOL;
END_VAR

// ========================================
// FB_DumperControl - Управление отвалообразователем
// ========================================
//
// РЕЖИМЫ УПРАВЛЕНИЯ:
//
// 1. МЕСТНЫЙ РЕЖИМ (xLocalMode = TRUE):
//    - Команды берутся с кнопок ПМУ (Dumper.fbBtnStart, fbBtnStop)
//    - Конвейер: ПУСК/СТОП по фронтам кнопок
//    - Поворот: работает пока кнопка ЗАЖАТА (fbBtnTurnLeft/Right)
//    - Автоматически устанавливает eStateRemote = Manual
//
// 2. ДИСТАНЦИОННЫЙ РЕЖИМ (xLocalMode = FALSE):
//    - Команды берутся из входов ФБ (xStart, xStop)
//    - Конвейер: ПУСК/СТОП по входам ФБ
//    - Поворот: импульсные команды через Dumper.cmdTurnLeft/Right/Stop
//    - Режим устанавливается через SCADA (Manual/Remote/Auto)
//
// УПРАВЛЕНИЕ КОНВЕЙЕРОМ:
// - ПУСК: включение конвейеров отвалообразователя
// - СТОП: плавная остановка с последовательным выключением VFD и тормозов
//
// УПРАВЛЕНИЕ ПОВОРОТОМ:
// - Местный: поворот пока кнопка зажата (отпустили - остановка)
// - Дистанционный: импульсные команды от SCADA
// - Блокировка по концевикам (fbEndSwitchLeft/Right):
//   * Если концевик сработал (qxSignal = FALSE), команда поворота в эту сторону игнорируется
//   * Поворот автоматически останавливается при достижении концевика
//
// ========================================

// ========================================
// ОБРАБОТКА I/O (все сигналы и устройства)
// ========================================

fbDumperIO(Dumper := Dumper);

// ========================================
// АППАРАТНОЕ УПРАВЛЕНИЕ МОТОРАМИ КОНВЕЙЕРА
// ========================================

fbConveyorMotors(
	Dumper := Dumper,
	xStart := xStartConveyor,
	xStop := xStopConveyor,
	xEmergencyStop := xEmergencyStop OR NOT Dumper.fbBtnEmergencyStop.qxSignal,
	rTargetFrequency := MOTOR_FREQUENCY_DUMPER_CONVEYOR
);

// ========================================
// АППАРАТНОЕ УПРАВЛЕНИЕ МОТОРАМИ ПОВОРОТА
// ========================================

fbRotationMotors(
	Dumper := Dumper,
	xTurnLeft := xTurnLeft,
	xTurnRight := xTurnRight,
	xStop := xStopRotation,
	xEmergencyStop := xEmergencyStop OR NOT Dumper.fbBtnEmergencyStop.qxSignal,
	rTargetFrequency := MOTOR_FREQUENCY_DUMPER_ROTATION
);

// ========================================
// ОБРАБОТКА ДАТЧИКОВ БЕЗОПАСНОСТИ
// ========================================

fbSensors(
	Dumper := Dumper,
	xReset := xReset
);

// ========================================
// ПРОВЕРКА ОШИБОК МОТОРОВ
// ========================================

fbMotorErrors(Dumper := Dumper);

// ========================================
// ПРЕДПУСКОВАЯ СИГНАЛИЗАЦИЯ
// ========================================

Dumper.fbPreStartAlarm(
	ixStart := STAGE = PRESTART_ALARM,
	ixStop := xStopCommand OR xReset,
	itFirstSignal := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL,
	itPauseAfterFirst := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE,
	itSecondSignal := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL,
	itPauseAfterSecond := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE,
	qxAlarmPower => Dumper.xHLA
);

// Световая сигнализация во время активной работы поворота
// xHLA включается как при предпусковой сигнализации, так и при повороте
Dumper.xHLA := Dumper.fbPreStartAlarm.qxAlarmPower OR (fbRotationMotors.eStage = E_StageActuator.WORK);

Dumper.xStateEnable := STAGE = E_StageWithPreStartAlarm.WORK;
Dumper.xStateStarting := STAGE = E_StageWithPreStartAlarm.STARTING OR STAGE = PRESTART_ALARM;

// ========================================
// ОПРЕДЕЛЕНИЕ СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Проверка ошибок оборудования
IF fbSensors.xErrorSafetySensors OR fbMotorErrors.xErrorMotors THEN
	Dumper.xStateFailure := TRUE;
END_IF;

// Проверка предупреждений:
// 1. Датчики безопасности - уровень Warning
// 2. Контроль тока моторов - уровень L или H
Dumper.xStateWarning := fbSensors.xWarningSafetySensors
                     OR Dumper.MotorConveyor[1].VFD.fbRangeDiagnostic.qxWarningActive
                     OR Dumper.MotorConveyor[2].VFD.fbRangeDiagnostic.qxWarningActive
                     OR Dumper.MotorRotation[1].VFD.fbRangeDiagnostic.qxWarningActive
                     OR Dumper.MotorRotation[2].VFD.fbRangeDiagnostic.qxWarningActive;

// ========================================
// ОБРАБОТКА ОСТАНОВКИ И СБРОСА
// ========================================

// Сброс в начальное состояние
IF xReset THEN
	Dumper.xStateFailure := FALSE;
END_IF

// Штатная остановка - запускается при получении команды xStop
// Обрабатывается через подстадии в режиме WORK

// ========================================
// ВЫБОР ИСТОЧНИКА КОМАНД (ПМУ ИЛИ SCADA)
// ========================================

// В местном режиме (xLocalMode = TRUE) - команды берутся с ПМУ (кнопки)
// В дистанционном режиме (xLocalMode = FALSE) - команды берутся из SCADA (входы ФБ)
IF xLocalMode THEN
	// Местный режим - команды с ПМУ
	xStartCommand := Dumper.fbBtnStart.qxRisingEdge; // ПУСК по фронту кнопки
	xStopCommand := Dumper.fbBtnStop.qxRisingEdge;   // СТОП по фронту кнопки
ELSE
	// Дистанционный режим - команды из SCADA
	xStartCommand := xStart;
	xStopCommand := xStop;
END_IF;

// ========================================
// АВТОМАТ ПУСКА ОТВАЛООБРАЗОВАТЕЛЯ
// ========================================

// ПРИОРИТЕТНАЯ ПРОВЕРКА АВАРИЙНОЙ ОСТАНОВКИ
// Аварийная остановка имеет наивысший приоритет и срабатывает в любой стадии
// 1. Внешний сигнал аварийной остановки (от SCADA или системы)
// 2. Кнопка аварийной остановки на ПМУ (NC контакт: FALSE = кнопка нажата)
IF xEmergencyStop OR NOT Dumper.fbBtnEmergencyStop.qxSignal THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// КРИТИЧЕСКИЕ ОШИБКИ ДАТЧИКОВ БЕЗОПАСНОСТИ
// При срабатывании датчиков безопасности немедленная аварийная остановка,
// если секция НЕ в IDLE (т.е. находится в процессе работы или запуска)
// Блокируется через вход xDisableAutoEmergencyStop
IF fbSensors.xErrorSafetySensors
   AND STAGE <> E_StageWithPreStartAlarm.IDLE
   AND NOT xDisableAutoEmergencyStop
THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// ПРОВЕРКА ТАЙМ-АУТОВ ВЫПОЛНЕНИЯ КОМАНД
// Тайм-аут запуска: не удалось запустить секцию за установленное время
IF fbTimerStarting.Q THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// Тайм-аут остановки: не удалось остановить секцию за установленное время
IF fbTimerStopping.Q THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

CASE STAGE OF
	E_StageWithPreStartAlarm.IDLE:
		// Сброс команд управления конвейером
		xStartConveyor := FALSE;
		xStopConveyor := FALSE;

		// Сброс таймеров
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);

		// Команда запуска верхнего уровня
		IF xStartCommand THEN
			STAGE := PRESTART_ALARM;
		END_IF;

	PRESTART_ALARM:
		// Проверка команды остановки во время предпусковой сигнализации
		IF xStopCommand THEN
			// Прервать предпусковую сигнализацию и вернуться в IDLE
			STAGE := E_StageWithPreStartAlarm.IDLE;
		ELSIF Dumper.fbPreStartAlarm.qxComplete THEN
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

		// Таймер ожидания полного запуска секции
		fbTimerStarting(
			IN := TRUE,
			PT := TIME_AFTER_START_DUMPER
		);

		// Проверка состояния аппаратного блока конвейера
		IF fbConveyorMotors.eStage = E_StageActuator.WORK THEN
			// Конвейер запущен, переходим в WORK
			STAGE := E_StageWithPreStartAlarm.WORK;
			fbTimerStarting(IN := FALSE); // Сброс таймера
		END_IF;

	E_StageWithPreStartAlarm.WORK:
		// Нормальная работа
		fbTimerStopping(IN := FALSE);

		// Команда остановки
		IF xStopCommand THEN
			// Начать штатную остановку
			xStartConveyor := FALSE;
			xStopConveyor := TRUE;

			// Запуск таймера остановки
			fbTimerStopping(
				IN := TRUE,
				PT := TIME_TIMEOUT_STOP_DUMPER
			);
		END_IF;

		// Проверка завершения остановки
		IF xStopConveyor AND fbConveyorMotors.eStage = E_StageActuator.IDLE THEN
			// Конвейер остановлен, переходим в IDLE
			fbTimerStopping(IN := FALSE);
			STAGE := E_StageWithPreStartAlarm.IDLE;
		END_IF;

	E_StageWithPreStartAlarm.ERROR:
		// Состояние ошибки - аварийная остановка и ожидание сброса
		// (используется при серьезных неисправностях, не для штатной остановки)

		// Аварийная остановка конвейера (обрабатывается аппаратным блоком через xEmergencyStop)
		xStartConveyor := FALSE;
		xStopConveyor := FALSE; // Аварийная остановка через xEmergencyStop

		// Аварийная остановка моторов поворота (обрабатывается аппаратным блоком через xEmergencyStop)
		xTurnLeft := FALSE;
		xTurnRight := FALSE;
		xStopRotation := FALSE;

		// Разборка схем контакторов (аварийная остановка)
		IF Dumper.eStateRemote = E_StateRemote.Auto THEN
			xCircuitBuilt := FALSE;
			xCircuitBuiltRotation := FALSE;
		END_IF;

		// Сброс таймеров
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);
		// Контакторы управляются отдельно через импульсные команды
		// cmdBuildCircuitOn/Off (см. секцию УПРАВЛЕНИЕ КОНТАКТОРАМИ)

		// Сброс ошибки и переход в IDLE при отсутствии ошибок
		// Для выхода из ERROR требуется:
		// 1. Команда сброса (xReset)
		// 2. Снятие сигнала аварийной остановки (NOT xEmergencyStop)
		// 3. Кнопка аварийной остановки отпущена (NC контакт: TRUE = кнопка отпущена)
		// 4. Отсутствие ошибок оборудования (NOT Dumper.xStateFailure)
		IF xReset AND NOT xEmergencyStop AND Dumper.fbBtnEmergencyStop.qxSignal AND NOT Dumper.xStateFailure THEN
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

IF Dumper.eStateRemote = E_StateRemote.Manual THEN
	// РУЧНОЙ РЕЖИМ - Обработка импульсных команд сборки/разборки схемы конвейера
	// cmdBuildCircuitOn - собрать схему (включить контакторы)
	// cmdBuildCircuitOff - разобрать схему (выключить контакторы)
	IF Dumper.cmdBuildCircuitOn THEN
		xCircuitBuilt := TRUE;
		Dumper.cmdBuildCircuitOn := FALSE; // Сброс импульсной команды
	ELSIF Dumper.cmdBuildCircuitOff THEN
		xCircuitBuilt := FALSE;
		Dumper.cmdBuildCircuitOff := FALSE; // Сброс импульсной команды
	END_IF;
ELSIF Dumper.eStateRemote = E_StateRemote.Auto THEN
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
Dumper.MotorConveyor[1].qxKM_Power := xCircuitBuilt;
Dumper.MotorConveyor[2].qxKM_Power := xCircuitBuilt;

IF Dumper.eStateRemote = E_StateRemote.Manual THEN
	// РУЧНОЙ РЕЖИМ - Обработка импульсных команд сборки/разборки схемы поворота
	// cmdBuildCircuitOnRotation - собрать схему поворота (включить контакторы)
	// cmdBuildCircuitOffRotation - разобрать схему поворота (выключить контакторы)
	IF Dumper.cmdBuildCircuitOnRotation THEN
		xCircuitBuiltRotation := TRUE;
		Dumper.cmdBuildCircuitOnRotation := FALSE; // Сброс импульсной команды
	ELSIF Dumper.cmdBuildCircuitOffRotation THEN
		xCircuitBuiltRotation := FALSE;
		Dumper.cmdBuildCircuitOffRotation := FALSE; // Сброс импульсной команды
	END_IF;
ELSIF Dumper.eStateRemote = E_StateRemote.Auto THEN
	// АВТОМАТИЧЕСКИЙ РЕЖИМ - Автоматическая сборка схемы поворота при отсутствии ошибок
	// Собираем схему если:
	// 1. Нет ошибок по датчикам безопасности
	// 2. Секция НЕ в стадии ERROR
	IF NOT fbSensors.xErrorSafetySensors AND STAGE <> E_StageWithPreStartAlarm.ERROR THEN
		xCircuitBuiltRotation := TRUE;
	ELSE
		xCircuitBuiltRotation := FALSE;
	END_IF;
END_IF;

// Моторы поворота - управление контакторами через состояние схемы
Dumper.MotorRotation[1].qxKM_Power := xCircuitBuiltRotation;
Dumper.MotorRotation[2].qxKM_Power := xCircuitBuiltRotation;

// ========================================
// УПРАВЛЕНИЕ МОТОРАМИ ПОВОРОТА
// ========================================

// Обработка команд поворота в зависимости от режима управления
// Поворот может работать независимо от состояния конвейера (в любой стадии)

IF xLocalMode THEN
	// ========== МЕСТНЫЙ РЕЖИМ (ПМУ) ==========
	// В местном режиме: поворот работает ПОКА ЗАЖАТА КНОПКА

	// Команды поворота с кнопок ПМУ (уровень, не edge)
	xTurnLeft := Dumper.fbBtnTurnLeft.qxSignal;
	xTurnRight := Dumper.fbBtnTurnRight.qxSignal;

	// Остановка при отпускании кнопки (обрабатывается внутри FB_DumperRotationMotors)
	xStopRotation := FALSE;

ELSE
	// ========== ДИСТАНЦИОННЫЙ РЕЖИМ (SCADA) ==========
	// В дистанционном режиме: импульсные команды от АСУТП

	// Обработка импульсной команды поворота влево
	IF Dumper.cmdTurnLeft THEN
		xTurnLeft := TRUE;
		Dumper.cmdTurnLeft := FALSE; // Сброс импульсной команды
	END_IF;

	// Обработка импульсной команды поворота вправо
	IF Dumper.cmdTurnRight THEN
		xTurnRight := TRUE;
		Dumper.cmdTurnRight := FALSE; // Сброс импульсной команды
	END_IF;

	// Обработка команды остановки поворота
	IF Dumper.cmdStopRotation THEN
		xStopRotation := TRUE;
		xTurnLeft := FALSE;
		xTurnRight := FALSE;
		Dumper.cmdStopRotation := FALSE; // Сброс импульсной команды
	END_IF;

	// Сброс команды остановки после выполнения
	IF xStopRotation AND fbRotationMotors.eStage = E_StageActuator.IDLE THEN
		xStopRotation := FALSE;
	END_IF;
END_IF;

// ========================================
// ОБНОВЛЕНИЕ РЕЖИМА УПРАВЛЕНИЯ
// ========================================

// Если установлен местный режим (xLocalMode = TRUE), то переводим в Manual
// Manual может работать как дистанционно (от SCADA), так и местно (от ПМУ)
IF xLocalMode THEN
	Dumper.eStateRemote := E_StateRemote.Manual;
END_IF;

// ========================================
// ПЕРЕДАЧА СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Приоритет проверки: от более критичных к менее критичным
IF STAGE = E_StageWithPreStartAlarm.ERROR THEN
	// Ошибка без активной работы
	eStageToSCADA := E_ScadaStatesDevice.ERROR;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK AND Dumper.xStateFailure THEN
	// TODO: Секция работает с аварией (требует уточнения логики)
	// Обычно при ошибке должна быть остановка, но оставляем для будущей реализации
	eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_ERROR;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK AND Dumper.xStateWarning THEN
	// Секция работает с предупреждением
	eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_WARNING;

ELSIF STAGE = E_StageWithPreStartAlarm.WORK THEN
	// Секция работает в норме (нет ошибок и предупреждений)
	eStageToSCADA := E_ScadaStatesDevice.WORK;

ELSIF Dumper.xStateStarting THEN
	// Секция в процессе запуска (предпусковая сигнализация или разгон)
	eStageToSCADA := E_ScadaStatesDevice.STARTING;

ELSIF STAGE = E_StageWithPreStartAlarm.IDLE AND Dumper.xStateWarning THEN
	// Предупреждение без активной работы
	eStageToSCADA := E_ScadaStatesDevice.WARNING;

ELSIF STAGE = E_StageWithPreStartAlarm.IDLE AND Dumper.xStateFailure THEN
	// Секция неготова к запуску (есть ошибки)
	eStageToSCADA := E_ScadaStatesDevice.NOT_READY;

ELSE
	// Секция готова к запуску (IDLE, нет ошибок и предупреждений)
	eStageToSCADA := E_ScadaStatesDevice.READY;

END_IF;

// Передача состояний режима управления
Dumper.xStateRemoteAuto := Dumper.eStateRemote = E_StateRemote.Auto;
Dumper.xStateRemoteManual := Dumper.eStateRemote = E_StateRemote.Manual;
Dumper.xStateRemoteRepair := Dumper.eStateRemote = E_StateRemote.Repair;

END_FUNCTION_BLOCK