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
	// Состояния
	STAGE : E_StageWithPreStartAlarm := E_StageWithPreStartAlarm.IDLE;

	// Объединенные команды (ПМУ или SCADA в зависимости от режима)
	xStartCommand : BOOL; // Фактическая команда запуска (из ПМУ или SCADA)
	xStopCommand : BOOL; // Фактическая команда остановки (из ПМУ или SCADA)

	// Целевые частоты для моторов
	rTargetFreqConv1 : REAL := 0.0;
	rTargetFreqConv2 : REAL := 0.0;
	rTargetFreqRot1 : REAL := 0.0;
	rTargetFreqRot2 : REAL := 0.0;

	// Переменные синхронизации моторов конвейера
	xVFDsReady : BOOL; // Оба ЧРП конвейера готовы и запущены
	xFrequenciesSynchronized : BOOL; // Частоты синхронизированы в пределах допуска
	xConditionToProceed : BOOL; // Общее условие для продолжения разгона

	// Подстадии запуска (для последовательного включения тормозов и VFD)
	nStartingSubstage : INT := 0;
	// 0 - RELEASE_BRAKE: Отпускание тормозов
	// 1 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормозов
	// 2 - START_VFD: Запуск VFD
	// 3 - RAMPING: Разгон частоты до рабочей

	// Подстадии остановки (для последовательного выключения VFD и тормозов)
	nStoppingSubstage : INT := 0;
	// 0 - Нормальная работа
	// 1 - STOP_VFD: Остановка VFD
	// 2 - WAIT_VFD_STOP: Ожидание остановки VFD
	// 3 - ACTIVATE_BRAKE: Активация тормозов
	// 4 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормозов

	// Состояние схемы контакторов (TRUE = схема собрана, FALSE = схема разобрана)
	xCircuitBuilt : BOOL := FALSE;
	xCircuitBuiltRotation : BOOL := FALSE;

	// Таймеры контроля выполнения команд
	fbTimerStarting : TON; // Тайм-аут запуска (STARTING → WORK)
	fbTimerStopping : TON; // Тайм-аут остановки (WORK → IDLE)
	fbTimerRotation : TON; // Тайм-аут выполнения команд поворота

	// == Управление поворотом ==
	xRotationLeftActive : BOOL; // Поворот влево активен
	xRotationRightActive : BOOL; // Поворот вправо активен
	nRotationSubstage : INT := 0; // Подстадии поворота
	// 0 - IDLE: Нет активного поворота
	// 1 - RELEASE_BRAKE: Отпускание тормоза поворота
	// 2 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормоза
	// 3 - START_VFD: Запуск VFD поворота
	// 4 - WORKING: Моторы поворота работают
	// 5 - STOP_VFD: Остановка VFD поворота
	// 6 - WAIT_VFD_STOP: Ожидание остановки VFD
	// 7 - ACTIVATE_BRAKE: Активация тормоза

	simInit : BOOL;
	i : INT;
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
// ИНИЦИАЛИЗАЦИЯ СИГНАЛОВ
// ========================================

// ПМУ - СТАРТ
Dumper.fbBtnStart(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// ПМУ - СТОП
Dumper.fbBtnStop(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// ПМУ - Аварийная остановка
Dumper.fbBtnEmergencyStop(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// ПМУ Поворот влево/вправо
Dumper.fbBtnTurnLeft(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

Dumper.fbBtnTurnRight(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

Dumper.fbEndSwitchLeft(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

Dumper.fbEndSwitchRight(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// Сигналы тормозоов (Обратная связь)
Dumper.fbBreakerConveyor(
	ixSignal := , // Физ. сигнал
	xEnableRattlingFilter := TRUE);

Dumper.fbBreakerRotation(
	ixSignal := , // Физ. сигнал
	xEnableRattlingFilter := TRUE);

// Двигатели конвейера
FOR i := 1 TO 2 BY 1 DO
	Dumper.MotorConveyor[i].fbStateKM(
		ixSignal := , // Состояние контактора
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorConveyor[i].fbStatorOverheat(
		ixSignal := , // Перегрев статора
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorConveyor[i].fbStateQF(
		ixSignal := , // Автомат. выключатель
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorConveyor[i].VFD.fbStateFailure(
		ixSignal := , // ЧРП - ошибка
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorConveyor[i].VFD.fbStateRdyToStart(
		ixSignal := , // ЧРП - Готовность
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorConveyor[i].VFD.fbStateIsWorking(
		ixSignal := , // ЧРП - Работа
		xEnableRattlingFilter := TRUE
	);

	// Инициализация устройств
	Dumper.MotorConveyor[i].Device(
		ixFeedback := Dumper.MotorConveyor[i].fbStateKM.qxSignal,
		xEnableFeedback := TRUE
	);

	// ЧРП
	Dumper.MotorConveyor[i].VFD.Device(
		ixFeedback := Dumper.MotorConveyor[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

	// VFD.qxStart теперь управляется напрямую в алгоритме (TRUE = ПУСК, FALSE = СТОП)

	// Диагностика тока
	Dumper.MotorConveyor[i].VFD.fbRangeDiagnostic(
		irValue := Dumper.MotorConveyor[i].VFD.wMotorCurrent.rTag,
		irSetpointL := MOTOR_CONVEYOR_CURRENT_POINTS.L_Value,
		irSetpointLL := MOTOR_CONVEYOR_CURRENT_POINTS.LL_Value,
		irSetpointH := MOTOR_CONVEYOR_CURRENT_POINTS.H_Value,
		irSetpointHH := MOTOR_CONVEYOR_CURRENT_POINTS.HH_Value,
		ixEnable := TRUE
	);

	// Аналоговый вход ЧРП (чтение текущей частоты)
	Dumper.MotorConveyor[i].VFD.fbAnalogInput(
		xSimulation := SIMULATION,
		iADC_Code := Dumper.MotorConveyor[i].VFD.nActualFrequencyADC,
		refEngValue := Dumper.MotorConveyor[i].VFD.rActualFrequency,
		refSimValue := Dumper.MotorConveyor[i].VFD.rSimulatedFrequency,
		rAlarm_LL := VFD_CURRENT_ALARM_LL,
		rAlarm_L := VFD_CURRENT_ALARM_L,
		rAlarm_H := VFD_CURRENT_ALARM_H,
		rAlarm_HH := VFD_CURRENT_ALARM_HH,
		iADC_Max := VFD_ADC_MAX,
		iADC_Min := VFD_ADC_MIN,
		rEngValue_Max := VFD_FREQ_MAX_RANGE,
		rEngValue_Min := VFD_FREQ_MIN,
		rCurrent_Max := VFD_CURRENT_MAX,
		rCurrent_Min := VFD_CURRENT_MIN
	);

	// Аналоговый выход ЧРП (задание частоты)
	Dumper.MotorConveyor[i].VFD.fbAnalogOutput(
		xEnable := Dumper.MotorConveyor[i].VFD.Device.qxActive,
		rEngValue := Dumper.MotorConveyor[i].VFD.Frequency.qrCurrentFrequency,
		rEngValue_Max := VFD_FREQ_MAX_RANGE,
		rEngValue_Min := VFD_FREQ_MIN,
		rCurrent_Max := VFD_CURRENT_MAX,
		rCurrent_Min := VFD_CURRENT_MIN,
		iDAC_Max := VFD_ADC_MAX,
		iDAC_Min := VFD_ADC_MIN,
		rAlarm_LL := VFD_CURRENT_ALARM_LL,
		rAlarm_L := VFD_CURRENT_ALARM_L,
		rAlarm_H := VFD_CURRENT_ALARM_H,
		rAlarm_HH := VFD_CURRENT_ALARM_HH,
		xEnableClamp := TRUE
	);
	Dumper.MotorConveyor[i].VFD.nSetOutSignalToModule := Dumper.MotorConveyor[i].VFD.fbAnalogOutput.iDAC_Code;
END_FOR;

// Двигатели поворота
FOR i := 1 TO 2 BY 1 DO
	Dumper.MotorRotation[i].fbStateKM(
		ixSignal := , // Состояние контактора
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorRotation[i].fbStatorOverheat(
		ixSignal := , // Перегрев статора
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorRotation[i].fbStateQF(
		ixSignal := , // Автомат. выключатель
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorRotation[i].VFD.fbStateFailure(
		ixSignal := , // ЧРП - ошибка
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorRotation[i].VFD.fbStateRdyToStart(
		ixSignal := , // ЧРП - Готовность
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorRotation[i].VFD.fbStateIsWorking(
		ixSignal := , // ЧРП - Работа
		xEnableRattlingFilter := TRUE
	);

	Dumper.MotorRotation[i].fbRotationStatus(
		ixSignal := , // Статус вращения
		xEnableRattlingFilter := TRUE
	);

	// Инициализация устройств
	Dumper.MotorRotation[i].Device(
		ixFeedback := Dumper.MotorRotation[i].fbStateKM.qxSignal,
		xEnableFeedback := TRUE
	);

	// ЧРП
	Dumper.MotorRotation[i].VFD.Device(
		ixFeedback := Dumper.MotorRotation[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

	// VFD.qxStart теперь управляется напрямую в алгоритме (TRUE = ПУСК, FALSE = СТОП)

	// Диагностика тока
	Dumper.MotorRotation[i].VFD.fbRangeDiagnostic(
		irValue := Dumper.MotorRotation[i].VFD.wMotorCurrent.rTag,
		irSetpointL := MOTOR_ROTATION_CURRENT_POINTS.L_Value,
		irSetpointLL := MOTOR_ROTATION_CURRENT_POINTS.LL_Value,
		irSetpointH := MOTOR_ROTATION_CURRENT_POINTS.H_Value,
		irSetpointHH := MOTOR_ROTATION_CURRENT_POINTS.HH_Value,
		ixEnable := TRUE
	);

	// Аналоговый вход ЧРП (чтение текущей частоты)
	Dumper.MotorRotation[i].VFD.fbAnalogInput(
		xSimulation := SIMULATION,
		iADC_Code := Dumper.MotorRotation[i].VFD.nActualFrequencyADC,
		refEngValue := Dumper.MotorRotation[i].VFD.rActualFrequency,
		refSimValue := Dumper.MotorRotation[i].VFD.rSimulatedFrequency,
		rAlarm_LL := VFD_CURRENT_ALARM_LL,
		rAlarm_L := VFD_CURRENT_ALARM_L,
		rAlarm_H := VFD_CURRENT_ALARM_H,
		rAlarm_HH := VFD_CURRENT_ALARM_HH,
		iADC_Max := VFD_ADC_MAX,
		iADC_Min := VFD_ADC_MIN,
		rEngValue_Max := VFD_FREQ_MAX_RANGE,
		rEngValue_Min := VFD_FREQ_MIN,
		rCurrent_Max := VFD_CURRENT_MAX,
		rCurrent_Min := VFD_CURRENT_MIN
	);

	// Аналоговый выход ЧРП (задание частоты)
	Dumper.MotorRotation[i].VFD.fbAnalogOutput(
		xEnable := Dumper.MotorRotation[i].VFD.Device.qxActive,
		rEngValue := Dumper.MotorRotation[i].VFD.Frequency.qrCurrentFrequency,
		rEngValue_Max := VFD_FREQ_MAX_RANGE,
		rEngValue_Min := VFD_FREQ_MIN,
		rCurrent_Max := VFD_CURRENT_MAX,
		rCurrent_Min := VFD_CURRENT_MIN,
		iDAC_Max := VFD_ADC_MAX,
		iDAC_Min := VFD_ADC_MIN,
		rAlarm_LL := VFD_CURRENT_ALARM_LL,
		rAlarm_L := VFD_CURRENT_ALARM_L,
		rAlarm_H := VFD_CURRENT_ALARM_H,
		rAlarm_HH := VFD_CURRENT_ALARM_HH,
		xEnableClamp := TRUE
	);
	Dumper.MotorRotation[i].VFD.nSetOutSignalToModule := Dumper.MotorRotation[i].VFD.fbAnalogOutput.iDAC_Code;
END_FOR;

// Датчики безопасности
FOR i := 1 TO 4 BY 1 DO
	Dumper.fbZQAlarm[i](
		ixSignal := ,
		xEnableRattlingFilter := TRUE
	);

	Dumper.fbZQWarning[i](
		ixSignal := ,
		xEnableRattlingFilter := TRUE
	);

	Dumper.fbHQ_IsOk[i](
		ixSignal := ,
		xEnableRattlingFilter := TRUE
	);
END_FOR;

FOR i := 1 TO 2 BY 1 DO
	Dumper.fbSQ_IsOk[i](
		ixSignal := ,
		xEnableRattlingFilter := TRUE
	);

	Dumper.fbQR[i](
		ixSignal := ,
		xEnableRattlingFilter := FALSE // Только edge detection
	);
END_FOR;

Dumper.fbGS1(
	ixSignal := ,
	xEnableRattlingFilter := TRUE
);

Dumper.fbYS1(
	ixSignal := ,
	xEnableRattlingFilter := TRUE
);

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
Dumper.xHLA := Dumper.fbPreStartAlarm.qxAlarmPower OR (nRotationSubstage = 4);

Dumper.xStateEnable := STAGE = E_StageWithPreStartAlarm.WORK;
Dumper.xStateStarting := STAGE = E_StageWithPreStartAlarm.STARTING OR STAGE = PRESTART_ALARM;

// ========================================
// ОПРЕДЕЛЕНИЕ СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Проверка ошибок оборудования
IF FC_Dumper_GetErrorCommon(Dumper := Dumper) THEN
	Dumper.xStateFailure := TRUE;
END_IF;



// Проверка предупреждений:
// 1. Датчики схода ленты ZQ - уровень Warning
// 2. Контроль тока моторов - уровень L или H
Dumper.xStateWarning := NOT Dumper.fbZQWarning[1].qxSignal
                     OR NOT Dumper.fbZQWarning[2].qxSignal
                     OR NOT Dumper.fbZQWarning[3].qxSignal
                     OR NOT Dumper.fbZQWarning[4].qxSignal
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
IF xEmergencyStop THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
END_IF;

// КРИТИЧЕСКИЕ ОШИБКИ ДАТЧИКОВ БЕЗОПАСНОСТИ
// При срабатывании датчиков безопасности немедленная аварийная остановка,
// если секция НЕ в IDLE (т.е. находится в процессе работы или запуска)
// Блокируется через вход xDisableAutoEmergencyStop
IF FC_Dumper_GetErrorSensors(Dumper := Dumper)
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

// Тайм-аут поворота: не удалось выполнить команду поворота за установленное время
IF fbTimerRotation.Q THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
	nRotationSubstage := 0; // Сброс подстадии поворота
END_IF;

CASE STAGE OF
	E_StageWithPreStartAlarm.IDLE:
		// Сброс целевой частоты
		rTargetFreqConv1 := 0.0;
		rTargetFreqConv2 := 0.0;
		rTargetFreqRot1 := 0.0;
		rTargetFreqRot2 := 0.0;

		// Сброс подстадий запуска и остановки
		nStartingSubstage := 0;
		nStoppingSubstage := 0;

		// Сброс таймеров запуска и остановки
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);

		// Тормоза активны (удерживают механизм)
		Dumper.qxBreakerConveyor := FALSE;
		Dumper.qxBreakerRotation := FALSE;

		IF xStartCommand THEN
			STAGE := PRESTART_ALARM;
		END_IF;

	PRESTART_ALARM:
		// Проверка команды остановки во время предпусковой сигнализации
		IF xStopCommand THEN
			// Прервать предпусковую сигнализацию и вернуться в IDLE
			STAGE := E_StageWithPreStartAlarm.IDLE;
		ELSIF Dumper.fbPreStartAlarm.qxComplete THEN
			STAGE := E_StageWithPreStartAlarm.STARTING;
		END_IF;

	E_StageWithPreStartAlarm.STARTING:
		// Проверка команды остановки во время запуска
		IF xStopCommand THEN
			// Прервать запуск и перейти к процедуре остановки
			STAGE := E_StageWithPreStartAlarm.WORK;
			nStartingSubstage := 0;
			nStoppingSubstage := 1; // Начать процедуру остановки
			fbTimerStarting(IN := FALSE); // Сброс таймера
		END_IF;

		// Таймер ожидания полного запуска секции
		fbTimerStarting(
			IN := TRUE,
			PT := TIME_AFTER_START_DUMPER
		);

		// Последовательный запуск: Тормоза → Обратная связь → VFD → Разгон
		CASE nStartingSubstage OF
			0: // RELEASE_BRAKE - Отпускание тормозов
				// Включить сигнал тормоза (1 = тормоз отпущен)
				Dumper.qxBreakerConveyor := TRUE;
				Dumper.qxBreakerRotation := TRUE;

				// Переход к следующей подстадии
				nStartingSubstage := 1;

			1: // WAIT_BRAKE_FEEDBACK - Ожидание обратной связи тормозов
				// Получить обратную связь реле тормоза
				IF Dumper.fbBreakerConveyor.qxSignal THEN
					// Обратная связь получена, переходим к запуску VFD
					nStartingSubstage := 2;
				END_IF;

			2: // START_VFD - Запуск VFD (контакторы управляются отдельно через cmdBuildCircuitOn/Off)
				// Команда ПУСК на частотный преобразователь (TRUE = ПУСК)
				Dumper.MotorConveyor[1].VFD.qxStart := TRUE;
				Dumper.MotorConveyor[2].VFD.qxStart := TRUE;

				// Установка целевой частоты
				// (FB_FrequencyControl автоматически выберет плавный или прямой пуск через irStep)
				rTargetFreqConv1 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
				rTargetFreqConv2 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;

				// Если оба VFD запущены (обратная связь), переходим к следующей подстадии
				IF Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					IF VFD_SMOOTH_SET_FREQUENCY THEN
						// Плавный пуск: переходим к разгону
						nStartingSubstage := 3;
					ELSE
						// Прямой пуск: сразу в режим WORK (частота уже установлена через большой шаг)
						STAGE := E_StageWithPreStartAlarm.WORK;
						nStartingSubstage := 0;
						fbTimerStarting(IN := FALSE); // Сброс таймера
					END_IF;
				END_IF;

			3: // RAMPING - Разгон частоты до рабочей
				// Команды запуска VFD остаются активными (TRUE = ПУСК)
				Dumper.MotorConveyor[1].VFD.qxStart := TRUE;
				Dumper.MotorConveyor[2].VFD.qxStart := TRUE;

				// Задание целевой частоты (передается в FB_FrequencyControl)
				rTargetFreqConv1 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
				rTargetFreqConv2 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;

				// Переход в режим WORK при достижении целевой частоты
				// Используется регулирование частоты с синхронизацией
				IF Dumper.MotorConveyor[1].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
					AND Dumper.MotorConveyor[2].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
				THEN
					STAGE := E_StageWithPreStartAlarm.WORK;
					nStartingSubstage := 0; // Сброс для следующего запуска
					fbTimerStarting(IN := FALSE); // Сброс таймера
				END_IF;
		END_CASE;

	E_StageWithPreStartAlarm.WORK:
		// Нормальная работа или штатная остановка через подстадии
		CASE nStoppingSubstage OF
			0: // Нормальная работа
				// Сброс таймера остановки
				fbTimerStopping(IN := FALSE);

				// Обновление целевой частоты конвейера в ручном режиме
				IF Dumper.eStateRemote = E_StateRemote.Manual THEN
					rTargetFreqConv1 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
					rTargetFreqConv2 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
				END_IF;

				IF xStopCommand THEN
					// Начать штатную остановку
					nStoppingSubstage := 1;
				END_IF;

			1: // STOP_VFD - Остановка VFD
				// Запуск таймера остановки (тайм-аут на остановку секции)
				fbTimerStopping(
					IN := TRUE,
					PT := TIME_TIMEOUT_STOP_DUMPER
				);
				// Установить целевую частоту 0
				// (FB_FrequencyControl автоматически выберет плавную или прямую остановку через irStep)
				rTargetFreqConv1 := 0.0;
				rTargetFreqConv2 := 0.0;
				rTargetFreqRot1 := 0.0;
				rTargetFreqRot2 := 0.0;

				IF VFD_SMOOTH_SET_FREQUENCY THEN
					// Плавная остановка: ждем снижения частоты до 0, затем отключаем VFD
					IF Dumper.MotorConveyor[1].VFD.rActualFrequency <= VFD_FREQUENCY_INACCURANCY
						AND Dumper.MotorConveyor[2].VFD.rActualFrequency <= VFD_FREQUENCY_INACCURANCY
					THEN
						// Частота достигла 0, отключаем VFD
						Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
						Dumper.MotorConveyor[2].VFD.qxStart := FALSE;
						nStoppingSubstage := 2;
					END_IF;
				ELSE
					// Прямая остановка: сразу отключаем VFD (частота мгновенно стала 0 через большой шаг)
					Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
					Dumper.MotorConveyor[2].VFD.qxStart := FALSE;
					nStoppingSubstage := 2;
				END_IF;

			2: // WAIT_VFD_STOP - Ожидание остановки VFD
				// Проверить обратную связь VFD о выключении
				IF NOT Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND NOT Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					// VFD выключены, переход к активации тормозов
					nStoppingSubstage := 3;
				END_IF;

			3: // ACTIVATE_BRAKE - Активация тормозов
				// Снять сигнал с тормоза (поставить на тормоз: FALSE = активен)
				Dumper.qxBreakerConveyor := FALSE;
				Dumper.qxBreakerRotation := FALSE;

				// Переход к ожиданию обратной связи тормозов
				nStoppingSubstage := 4;

			4: // Переход в IDLE
				// Сброс таймера остановки (успешная остановка)
				fbTimerStopping(IN := FALSE);

				STAGE := E_StageWithPreStartAlarm.IDLE;
				nStoppingSubstage := 0;
		END_CASE;

	E_StageWithPreStartAlarm.ERROR:
		// Состояние ошибки - аварийная остановка и ожидание сброса
		// (используется при серьезных неисправностях, не для штатной остановки)

		// Аварийная остановка: команда СТОП на VFD (FALSE = СТОП)
		Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
		Dumper.MotorConveyor[2].VFD.qxStart := FALSE;
		Dumper.MotorRotation[1].VFD.qxStart := FALSE;
		Dumper.MotorRotation[2].VFD.qxStart := FALSE;
		Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
		Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;

		// Сброс целевых частот
		rTargetFreqConv1 := 0.0;
		rTargetFreqConv2 := 0.0;
		rTargetFreqRot1 := 0.0;
		rTargetFreqRot2 := 0.0;

		// Активировать тормоза
		Dumper.qxBreakerConveyor := FALSE;
		Dumper.qxBreakerRotation := FALSE;

		// Разборка схем контакторов (аварийная остановка)
		xCircuitBuilt := FALSE;
		xCircuitBuiltRotation := FALSE;

		// Сброс подстадий для следующего запуска
		nStartingSubstage := 0;
		nStoppingSubstage := 0;
		nRotationSubstage := 0;

		// Сброс таймеров
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);
		fbTimerRotation(IN := FALSE);

		// Контакторы управляются отдельно через импульсные команды
		// cmdBuildCircuitOn/Off (см. секцию УПРАВЛЕНИЕ КОНТАКТОРАМИ)

		// Сброс ошибки и переход в IDLE при отсутствии ошибок
		// Для выхода из ERROR требуется:
		// 1. Команда сброса (xReset)
		// 2. Снятие сигнала аварийной остановки (NOT xEmergencyStop)
		// 3. Отсутствие ошибок оборудования (NOT Dumper.xStateFailure)
		IF xReset AND NOT xEmergencyStop AND NOT Dumper.xStateFailure THEN
			STAGE := E_StageWithPreStartAlarm.IDLE;
		END_IF
END_CASE;

// ========================================
// ПРОВЕРКА СИНХРОНИЗАЦИИ МОТОРОВ КОНВЕЙЕРА
// ========================================

// Проверка что оба ЧРП конвейера готовы и запущены (обратная связь)
xVFDsReady := Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
           AND Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal;

// Проверка синхронизации текущих частот (разница не превышает допуск)
xFrequenciesSynchronized := ABS(Dumper.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency
                              - Dumper.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency)
                              <= VFD_FREQUENCY_SYNC_TOLERANCE;

// Общее условие для продолжения плавного разгона
// Разгон продолжается только если оба ЧРП запущены И частоты синхронизированы
xConditionToProceed := xVFDsReady AND xFrequenciesSynchronized;

// ========================================
// ОБРАБОТКА ЧАСТОТЫ (после установки целевых значений в CASE)
// ========================================

// Моторы конвейера
Dumper.MotorConveyor[1].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqConv1,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := xConditionToProceed // Синхронизация с мотором 2
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

Dumper.MotorConveyor[2].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqConv2,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := xConditionToProceed // Синхронизация с мотором 1
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

// Моторы поворота
Dumper.MotorRotation[1].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqRot1,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := TRUE
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

Dumper.MotorRotation[2].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqRot2,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := TRUE
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

// Вывод текущей стадии
eStage := STAGE;

// ========================================
// УПРАВЛЕНИЕ КОНТАКТОРАМИ
// ========================================

// Обработка импульсных команд сборки/разборки схемы конвейера
// cmdBuildCircuitOn - собрать схему (включить контакторы)
// cmdBuildCircuitOff - разобрать схему (выключить контакторы)
IF Dumper.eStateRemote = E_StateRemote.Manual THEN
	IF Dumper.cmdBuildCircuitOn THEN
		xCircuitBuilt := TRUE;
		Dumper.cmdBuildCircuitOn := FALSE; // Сброс импульсной команды
	ELSIF Dumper.cmdBuildCircuitOff THEN
		xCircuitBuilt := FALSE;
		Dumper.cmdBuildCircuitOff := FALSE; // Сброс импульсной команды
	END_IF;
END_IF;
// Моторы конвейера - управление контакторами через состояние схемы
Dumper.MotorConveyor[1].qxKM_Power := xCircuitBuilt;
Dumper.MotorConveyor[2].qxKM_Power := xCircuitBuilt;

// Обработка импульсных команд сборки/разборки схемы поворота
// cmdBuildCircuitOnRotation - собрать схему поворота (включить контакторы)
// cmdBuildCircuitOffRotation - разобрать схему поворота (выключить контакторы)
IF Dumper.eStateRemote = E_StateRemote.Manual THEN
	IF Dumper.cmdBuildCircuitOnRotation THEN
		xCircuitBuiltRotation := TRUE;
		Dumper.cmdBuildCircuitOnRotation := FALSE; // Сброс импульсной команды
	ELSIF Dumper.cmdBuildCircuitOffRotation THEN
		xCircuitBuiltRotation := FALSE;
		Dumper.cmdBuildCircuitOffRotation := FALSE; // Сброс импульсной команды
	END_IF;
END_IF;
// Моторы поворота - управление контакторами через состояние схемы
Dumper.MotorRotation[1].qxKM_Power := xCircuitBuiltRotation;
Dumper.MotorRotation[2].qxKM_Power := xCircuitBuiltRotation;

// ========================================
// УПРАВЛЕНИЕ МОТОРАМИ ПОВОРОТА
// ========================================

// Обработка команд поворота в зависимости от режима управления

IF xLocalMode THEN
	// ========== МЕСТНЫЙ РЕЖИМ (ПМУ) ==========
	// В местном режиме: поворот работает ПОКА ЗАЖАТА КНОПКА

	// ПУСК поворота влево - при зажатой кнопке и отсутствии активного поворота
	IF Dumper.fbBtnTurnLeft.qxSignal AND nRotationSubstage = 0 THEN
		// Можем начать поворот влево только если:
		// 1. Левый концевик НЕ сработал (qxSignal = TRUE означает концевик в норме, не нажат)
		// 2. Нет активного поворота
		IF Dumper.fbEndSwitchLeft.qxSignal THEN
			xRotationLeftActive := TRUE;
			xRotationRightActive := FALSE;
			nRotationSubstage := 1; // Начать последовательность запуска
		END_IF;
		// Если концевик сработал (qxSignal = FALSE), команда игнорируется
	END_IF;

	// ПУСК поворота вправо - при зажатой кнопке и отсутствии активного поворота
	IF Dumper.fbBtnTurnRight.qxSignal AND nRotationSubstage = 0 THEN
		// Можем начать поворот вправо только если:
		// 1. Правый концевик НЕ сработал (qxSignal = TRUE означает концевик в норме, не нажат)
		// 2. Нет активного поворота
		IF Dumper.fbEndSwitchRight.qxSignal THEN
			xRotationRightActive := TRUE;
			xRotationLeftActive := FALSE;
			nRotationSubstage := 1; // Начать последовательность запуска
		END_IF;
		// Если концевик сработал (qxSignal = FALSE), команда игнорируется
	END_IF;

	// ОСТАНОВКА поворота - когда кнопка отпущена или достигнут концевик
	IF nRotationSubstage >= 1 AND nRotationSubstage <= 4 THEN
		// Условия остановки:
		// 1. Кнопка отпущена (для левого поворота - кнопка влево отпущена, для правого - кнопка вправо)
		// 2. Достигнут концевик
		IF (xRotationLeftActive AND (NOT Dumper.fbBtnTurnLeft.qxSignal OR NOT Dumper.fbEndSwitchLeft.qxSignal))
			OR (xRotationRightActive AND (NOT Dumper.fbBtnTurnRight.qxSignal OR NOT Dumper.fbEndSwitchRight.qxSignal))
		THEN
			// Начать последовательность остановки
			nRotationSubstage := 5;
		END_IF;
	END_IF;

ELSE
	// ========== ДИСТАНЦИОННЫЙ РЕЖИМ (SCADA) ==========
	// В дистанционном режиме: импульсные команды от АСУТП

	// Обработка команды поворота влево
	IF Dumper.cmdTurnLeft AND nRotationSubstage = 0 THEN
		// Можем начать поворот влево только если:
		// 1. Левый концевик НЕ сработал (qxSignal = TRUE означает концевик в норме, не нажат)
		// 2. Нет активного поворота
		IF Dumper.fbEndSwitchLeft.qxSignal THEN
			xRotationLeftActive := TRUE;
			xRotationRightActive := FALSE;
			nRotationSubstage := 1; // Начать последовательность запуска
		END_IF;
		// Если концевик сработал (qxSignal = FALSE), команда игнорируется
	END_IF;

	// Обработка команды поворота вправо
	IF Dumper.cmdTurnRight AND nRotationSubstage = 0 THEN
		// Можем начать поворот вправо только если:
		// 1. Правый концевик НЕ сработал (qxSignal = TRUE означает концевик в норме, не нажат)
		// 2. Нет активного поворота
		IF Dumper.fbEndSwitchRight.qxSignal THEN
			xRotationRightActive := TRUE;
			xRotationLeftActive := FALSE;
			nRotationSubstage := 1; // Начать последовательность запуска
		END_IF;
		// Если концевик сработал (qxSignal = FALSE), команда игнорируется
	END_IF;

	// Условия остановки поворота:
	// 1. Достигнут концевик
	// 2. Импульсная команда остановки (cmdStopRotation)
	IF nRotationSubstage >= 1 AND nRotationSubstage <= 4 THEN
		// Проверка условий остановки
		IF (xRotationLeftActive AND NOT Dumper.fbEndSwitchLeft.qxSignal)
			OR (xRotationRightActive AND NOT Dumper.fbEndSwitchRight.qxSignal)
			OR Dumper.cmdStopRotation
		THEN
			// Начать последовательность остановки
			nRotationSubstage := 5;
		END_IF;
	END_IF;

	// Сброс импульсных команд от АСУТП
	IF Dumper.cmdTurnLeft THEN
		Dumper.cmdTurnLeft := FALSE;
	END_IF;
	IF Dumper.cmdTurnRight THEN
		Dumper.cmdTurnRight := FALSE;
	END_IF;
	IF Dumper.cmdStopRotation THEN
		Dumper.cmdStopRotation := FALSE;
	END_IF;
END_IF;

// Автомат управления поворотом с подстадиями
CASE nRotationSubstage OF
	0: // IDLE - Нет активного поворота
		// Сброс таймера поворота
		fbTimerRotation(IN := FALSE);

		// Остановка VFD
		Dumper.MotorRotation[1].VFD.qxStart := FALSE;
		Dumper.MotorRotation[2].VFD.qxStart := FALSE;
		Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
		Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;

		// Активация тормоза поворота
		Dumper.qxBreakerRotation := FALSE;

		// Сброс целевой частоты
		rTargetFreqRot1 := 0.0;
		rTargetFreqRot2 := 0.0;

		// Сброс флагов поворота
		xRotationLeftActive := FALSE;
		xRotationRightActive := FALSE;

	1: // RELEASE_BRAKE - Отпускание тормоза поворота
		// Запуск таймера поворота (тайм-аут на выполнение команды поворота)
		fbTimerRotation(
			IN := TRUE,
			PT := TIME_TIMEOUT_ROTATION_DUMPER
		);

		// Отпустить тормоз (1 = тормоз отпущен)
		Dumper.qxBreakerRotation := TRUE;

		// Переход к следующей подстадии
		nRotationSubstage := 2;

	2: // WAIT_BRAKE_FEEDBACK - Ожидание обратной связи тормоза
		// Ждём обратную связь реле тормоза
		IF Dumper.fbBreakerRotation.qxSignal THEN
			// Обратная связь получена, переходим к запуску VFD
			nRotationSubstage := 3;
		END_IF;

	3: // START_VFD - Запуск VFD поворота
		IF xRotationLeftActive THEN
			// Поворот влево - запуск в прямом направлении
			Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
			Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;
			Dumper.MotorRotation[1].VFD.qxStart := TRUE;
			Dumper.MotorRotation[2].VFD.qxStart := TRUE;


		ELSIF xRotationRightActive THEN
			// Поворот вправо - запуск в режиме реверса
			Dumper.MotorRotation[1].VFD.qxStart := FALSE;
			Dumper.MotorRotation[2].VFD.qxStart := FALSE;
			Dumper.MotorRotation[1].qxVFDReverseStart := TRUE;
			Dumper.MotorRotation[2].qxVFDReverseStart := TRUE;
		END_IF;

		// Установка целевой частоты
		rTargetFreqRot1 := MOTOR_FREQUENCY_DUMPER_ROTATION;
		rTargetFreqRot2 := MOTOR_FREQUENCY_DUMPER_ROTATION;

		// Проверка запуска VFD (обратная связь)
		IF Dumper.MotorRotation[1].VFD.fbStateIsWorking.qxSignal
			AND Dumper.MotorRotation[2].VFD.fbStateIsWorking.qxSignal
		THEN
			// VFD запущены, переходим в режим работы
			nRotationSubstage := 4;
		END_IF;

	4: // WORKING - Моторы поворота работают
		// Поддержка целевой частоты
		rTargetFreqRot1 := MOTOR_FREQUENCY_DUMPER_ROTATION;
		rTargetFreqRot2 := MOTOR_FREQUENCY_DUMPER_ROTATION;

	5: // STOP_VFD - Остановка VFD поворота
		// Установить целевую частоту 0
		rTargetFreqRot1 := 0.0;
		rTargetFreqRot2 := 0.0;

		IF VFD_SMOOTH_SET_FREQUENCY THEN
			// Плавная остановка: ждем снижения частоты до 0, затем отключаем VFD
			IF Dumper.MotorRotation[1].VFD.rActualFrequency <= VFD_FREQUENCY_INACCURANCY
				AND Dumper.MotorRotation[2].VFD.rActualFrequency <= VFD_FREQUENCY_INACCURANCY
			THEN
				// Частота достигла 0, отключаем VFD
				Dumper.MotorRotation[1].VFD.qxStart := FALSE;
				Dumper.MotorRotation[2].VFD.qxStart := FALSE;
				Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
				Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;
				nRotationSubstage := 6;
			END_IF;
		ELSE
			// Прямая остановка: сразу отключаем VFD
			Dumper.MotorRotation[1].VFD.qxStart := FALSE;
			Dumper.MotorRotation[2].VFD.qxStart := FALSE;
			Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
			Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;
			nRotationSubstage := 6;
		END_IF;

	6: // WAIT_VFD_STOP - Ожидание остановки VFD
		// Проверить обратную связь VFD о выключении
		IF NOT Dumper.MotorRotation[1].VFD.fbStateIsWorking.qxSignal
			AND NOT Dumper.MotorRotation[2].VFD.fbStateIsWorking.qxSignal
		THEN
			// VFD выключены, переход к активации тормоза
			nRotationSubstage := 7;
		END_IF;

	7: // ACTIVATE_BRAKE - Активация тормоза
		// Снять сигнал с тормоза (поставить на тормоз: FALSE = активен)
		Dumper.qxBreakerRotation := FALSE;

		// Сброс таймера поворота (успешное выполнение команды)
		fbTimerRotation(IN := FALSE);

		// Переход в IDLE
		nRotationSubstage := 0;
END_CASE;

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