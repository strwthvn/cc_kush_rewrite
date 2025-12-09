FUNCTION_BLOCK FB_ConveyorControl
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
	xStart : BOOL; // Команда запуска конвейера
	xStop : BOOL; // Команда остановки (аварийная остановка)
	xReset : BOOL; // Сброс в начальное состояние
END_VAR
VAR_OUTPUT
	eStage : E_StageWithPreStartAlarm; // Текущая стадия
	eStageToSCADA : E_ScadaStatesDevice; // Передача состояния скаде
END_VAR
VAR
	// Состояния
	STAGE : E_StageWithPreStartAlarm := E_StageWithPreStartAlarm.IDLE;

	// Подстадии запуска
	nStartingSubstage : INT := 0;
	// 0 - RELEASE_BRAKE, 1 - WAIT_BRAKE_FEEDBACK, 2 - START_VFD, 3 - RAMPING

	// Подстадии остановки
	nStoppingSubstage : INT := 0;
	// 0 - Normal work, 1 - STOP_VFD, 2 - WAIT_VFD_STOP, 3 - ACTIVATE_BRAKE, 4 - WAIT_BRAKE_FEEDBACK

	// Целевые частоты для моторов
	rTargetFreqConv1 : REAL := 0.0;
	rTargetFreqConv2 : REAL := 0.0;

	// Переменные синхронизации моторов конвейера
	xVFDsReady : BOOL; // Оба ЧРП конвейера готовы и запущены
	xFrequenciesSynchronized : BOOL; // Частоты синхронизированы в пределах допуска
	xConditionToProceed : BOOL; // Общее условие для продолжения разгона

	// Состояние схемы контакторов
	xCircuitBuilt : BOOL := FALSE;

	simInit : BOOL;
	i : INT;
END_VAR

// ========================================
// ИНИЦИАЛИЗАЦИЯ СИГНАЛОВ
// ========================================

// ПМУ - СТАРТ
Conveyor.fbBtnStart(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// ПМУ - СТОП
Conveyor.fbBtnStop(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// ПМУ - Аварийная остановка
Conveyor.fbBtnEmergencyStop(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// Двигатели конвейера
FOR i := 1 TO 2 BY 1 DO
	Conveyor.MotorConveyor[i].fbStateKM(
		ixSignal := , // Состояние контактора
		xEnableRattlingFilter := TRUE
	);

	Conveyor.MotorConveyor[i].fbStatorOverheat(
		ixSignal := , // Перегрев статора
		xEnableRattlingFilter := TRUE
	);

	Conveyor.MotorConveyor[i].fbStateQF(
		ixSignal := , // Автомат. выключатель
		xEnableRattlingFilter := TRUE
	);

	Conveyor.MotorConveyor[i].VFD.fbStateFailure(
		ixSignal := , // ЧРП - ошибка
		xEnableRattlingFilter := TRUE
	);

	Conveyor.MotorConveyor[i].VFD.fbStateRdyToStart(
		ixSignal := , // ЧРП - Готовность
		xEnableRattlingFilter := TRUE
	);

	Conveyor.MotorConveyor[i].VFD.fbStateIsWorking(
		ixSignal := , // ЧРП - Работа
		xEnableRattlingFilter := TRUE
	);

	// Инициализация устройств
	Conveyor.MotorConveyor[i].Device(
		ixFeedback := Conveyor.MotorConveyor[i].fbStateKM.qxSignal,
		xEnableFeedback := TRUE
	);
	// Контакторы управляются в секции "УПРАВЛЕНИЕ КОНТАКТОРАМИ" через cmdBuildCircuitOn/Off

	// ЧРП
	Conveyor.MotorConveyor[i].VFD.Device(
		ixFeedback := Conveyor.MotorConveyor[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);
	// VFD.qxStart теперь управляется напрямую в алгоритме (TRUE = ПУСК, FALSE = СТОП)

	// Диагностика тока
	Conveyor.MotorConveyor[i].VFD.fbRangeDiagnostic(
		irValue := Conveyor.MotorConveyor[i].VFD.wMotorCurrent.rTag,
		irSetpointL := MOTOR_CONVEYOR_CURRENT_POINTS.L_Value,
		irSetpointLL := MOTOR_CONVEYOR_CURRENT_POINTS.LL_Value,
		irSetpointH := MOTOR_CONVEYOR_CURRENT_POINTS.H_Value,
		irSetpointHH := MOTOR_CONVEYOR_CURRENT_POINTS.HH_Value,
		ixEnable := TRUE
	);
	// Аналоговый вход ЧРП (чтение текущей частоты)
	Conveyor.MotorConveyor[i].VFD.fbAnalogInput(
		xSimulation := SIMULATION,
		iADC_Code := Conveyor.MotorConveyor[i].VFD.nActualFrequencyADC,
		refEngValue := Conveyor.MotorConveyor[i].VFD.rActualFrequency,
		refSimValue := Conveyor.MotorConveyor[i].VFD.rSimulatedFrequency,
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
	Conveyor.MotorConveyor[i].VFD.fbAnalogOutput(
		xEnable := Conveyor.MotorConveyor[i].VFD.fbStateIsWorking.qxSignal,
		rEngValue := Conveyor.MotorConveyor[i].VFD.Frequency.qrCurrentFrequency,
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
	Conveyor.MotorConveyor[i].VFD.nSetOutSignalToModule := Conveyor.MotorConveyor[i].VFD.fbAnalogOutput.iDAC_Code;
END_FOR;

// Датчики безопасности
FOR i := 1 TO 4 BY 1 DO
	Conveyor.fbZQAlarm[i](
		ixSignal := ,
		xEnableRattlingFilter := TRUE
	);

	Conveyor.fbZQWarning[i](
		ixSignal := ,
		xEnableRattlingFilter := TRUE
	);

	Conveyor.fbHQ_IsOk[i](
		ixSignal := ,
		xEnableRattlingFilter := TRUE
	);
END_FOR;

FOR i := 1 TO 2 BY 1 DO
	Conveyor.fbSQ_IsOk[i](
		ixSignal := ,
		xEnableRattlingFilter := TRUE
	);

	Conveyor.fbQR[i](
		ixSignal := ,
		xEnableRattlingFilter := FALSE // Только edge detection
	);
END_FOR;

Conveyor.fbGS1(
	ixSignal := ,
	xEnableRattlingFilter := TRUE
);

Conveyor.fbYS1(
	ixSignal := ,
	xEnableRattlingFilter := TRUE
);

Conveyor.fbYE1(
	ixSignal := ,
	xEnableRattlingFilter := TRUE
);

// Обратная связь тормоза конвейера
Conveyor.fbBreakerConveyor(
	ixSignal := , // Обратная связь реле тормоза
	xEnableRattlingFilter := TRUE
);

// ========================================
// ПРЕДПУСКОВАЯ СИГНАЛИЗАЦИЯ
// ========================================

Conveyor.fbPreStartAlarm(
	ixStart := STAGE = PRESTART_ALARM,
	ixStop := xStop OR xReset,
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
IF FC_Conveyor_GetErrorCommon(Conveyor := Conveyor) THEN
	Conveyor.xStateFailure := TRUE;
END_IF;


// Проверка предупреждений:
// 1. Датчики схода ленты ZQ - уровень Warning
// 2. Контроль тока моторов - уровень L или H
Conveyor.xStateWarning := NOT Conveyor.fbZQWarning[1].qxSignal
                       OR NOT Conveyor.fbZQWarning[2].qxSignal
                       OR NOT Conveyor.fbZQWarning[3].qxSignal
                       OR NOT Conveyor.fbZQWarning[4].qxSignal
                       OR Conveyor.MotorConveyor[1].VFD.fbRangeDiagnostic.qxWarningActive
                       OR Conveyor.MotorConveyor[2].VFD.fbRangeDiagnostic.qxWarningActive;

// ========================================
// ОБРАБОТКА ОСТАНОВКИ И СБРОСА
// ========================================

// Сброс в начальное состояние
IF xReset THEN
	xStateFailure := FALSE;
END_IF

// ========================================
// АВТОМАТ ПУСКА КОНВЕЙЕРА
// ========================================

CASE STAGE OF
	E_StageWithPreStartAlarm.IDLE:
		// Установка тормозов в активное состояние (FALSE = тормоз активен)
		Conveyor.qxBreakerConveyor := FALSE;

		// Сброс целевой частоты
		rTargetFreqConv1 := 0.0;
		rTargetFreqConv2 := 0.0;

		// Сброс подстадий
		nStartingSubstage := 0;
		nStoppingSubstage := 0;

		IF xStart THEN
			STAGE := PRESTART_ALARM;
		END_IF;

	E_StageWithPreStartAlarm.PRESTART_ALARM:
		IF Conveyor.fbPreStartAlarm.qxComplete THEN
			STAGE := E_StageWithPreStartAlarm.STARTING;
		END_IF;

	E_StageWithPreStartAlarm.STARTING:
		CASE nStartingSubstage OF
			0: // RELEASE_BRAKE - Отпускание тормозов
				// Отпускаем тормоз конвейера (TRUE = тормоз отпущен)
				Conveyor.qxBreakerConveyor := TRUE;
				nStartingSubstage := 1;

			1: // WAIT_BRAKE_FEEDBACK - Ожидание обратной связи тормоза
				IF Conveyor.fbBreakerConveyor.qxSignal THEN
					nStartingSubstage := 2;
				END_IF;

			2: // START_VFD - Запуск VFD
				// Команда ПУСК на ЧРП (TRUE = ПУСК)
				Conveyor.MotorConveyor[1].VFD.qxStart := TRUE;
				Conveyor.MotorConveyor[2].VFD.qxStart := TRUE;

				// Задание целевой частоты
				rTargetFreqConv1 := MOTOR_FREQUENCY_CONVEYOR;
				rTargetFreqConv2 := MOTOR_FREQUENCY_CONVEYOR;

				// Ждем запуска ЧРП
				IF Conveyor.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND Conveyor.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					IF VFD_SMOOTH_SET_FREQUENCY THEN
						nStartingSubstage := 3; // Плавный разгон
					ELSE
						STAGE := E_StageWithPreStartAlarm.WORK; // Прямой пуск
						nStartingSubstage := 0;
					END_IF;
				END_IF;

			3: // RAMPING - Разгон частоты до рабочей
				// Продолжаем удерживать команду ПУСК на ЧРП
				Conveyor.MotorConveyor[1].VFD.qxStart := TRUE;
				Conveyor.MotorConveyor[2].VFD.qxStart := TRUE;

				// Задание целевой частоты
				rTargetFreqConv1 := MOTOR_FREQUENCY_CONVEYOR;
				rTargetFreqConv2 := MOTOR_FREQUENCY_CONVEYOR;

				// Переход в режим WORK при достижении целевой частоты
				IF Conveyor.MotorConveyor[1].VFD.rActualFrequency >= MOTOR_FREQUENCY_CONVEYOR - VFD_FREQUENCY_INACCURANCY
					AND Conveyor.MotorConveyor[2].VFD.rActualFrequency >= MOTOR_FREQUENCY_CONVEYOR - VFD_FREQUENCY_INACCURANCY
				THEN
					STAGE := E_StageWithPreStartAlarm.WORK;
					nStartingSubstage := 0;
				END_IF;
		END_CASE;

	E_StageWithPreStartAlarm.WORK:
		CASE nStoppingSubstage OF
			0: // Нормальная работа
				// Проверка команды остановки
				IF xStop THEN
					nStoppingSubstage := 1;
				END_IF;

			1: // STOP_VFD - Остановка VFD
				// Задаем частоту 0
				rTargetFreqConv1 := 0.0;
				rTargetFreqConv2 := 0.0;

				IF VFD_SMOOTH_SET_FREQUENCY THEN
					// Плавная остановка: ждем снижения частоты до нуля
					IF Conveyor.MotorConveyor[1].VFD.rActualFrequency <= VFD_FREQUENCY_INACCURANCY
						AND Conveyor.MotorConveyor[2].VFD.rActualFrequency <= VFD_FREQUENCY_INACCURANCY
					THEN
						// Частоты снижены до нуля, снимаем команду ПУСК с ЧРП (FALSE = СТОП)
						Conveyor.MotorConveyor[1].VFD.qxStart := FALSE;
						Conveyor.MotorConveyor[2].VFD.qxStart := FALSE;
						nStoppingSubstage := 2;
					END_IF;
				ELSE
					// Прямая остановка: сразу снимаем команду ПУСК с ЧРП (FALSE = СТОП)
					Conveyor.MotorConveyor[1].VFD.qxStart := FALSE;
					Conveyor.MotorConveyor[2].VFD.qxStart := FALSE;
					nStoppingSubstage := 2;
				END_IF;

			2: // WAIT_VFD_STOP - Ожидание остановки VFD
				// Ждем подтверждения остановки ЧРП
				IF NOT Conveyor.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND NOT Conveyor.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					nStoppingSubstage := 3;
				END_IF;

			3: // ACTIVATE_BRAKE - Активация тормозов
				// Активируем тормоз конвейера (FALSE = тормоз активен)
				Conveyor.qxBreakerConveyor := FALSE;
				nStoppingSubstage := 4;

			4: // Переход в IDLE

				STAGE := E_StageWithPreStartAlarm.IDLE;
				nStoppingSubstage := 0;
		END_CASE;

	E_StageWithPreStartAlarm.ERROR:
		// Аварийная остановка - снимаем команды с VFD и активируем тормоза
		Conveyor.MotorConveyor[1].VFD.qxStart := FALSE;
		Conveyor.MotorConveyor[2].VFD.qxStart := FALSE;

		// Активируем тормоз конвейера (FALSE = тормоз активен)
		Conveyor.qxBreakerConveyor := FALSE;

		// Сброс целевых частот
		rTargetFreqConv1 := 0.0;
		rTargetFreqConv2 := 0.0;
END_CASE;

// Вывод текущей стадии
eStage := STAGE;

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
Conveyor.xStateRemoteAuto := Conveyor.eStateRemote := E_StateRemote.Auto;
Conveyor.xStateRemoteManual := Conveyor.eStateRemote := E_StateRemote.Manual;
Conveyor.xStateRemoteRepair := Conveyor.eStateRemote := E_StateRemote.Repair;

// ========================================
// ПРОВЕРКА СИНХРОНИЗАЦИИ МОТОРОВ КОНВЕЙЕРА
// ========================================

// Проверка что оба ЧРП конвейера готовы и запущены
xVFDsReady := Conveyor.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
           AND Conveyor.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal;

// Проверка синхронизации текущих частот (разница не превышает допуск)
xFrequenciesSynchronized := ABS(Conveyor.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency
                              - Conveyor.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency)
                              <= VFD_FREQUENCY_SYNC_TOLERANCE;

// Общее условие для продолжения плавного разгона
// Разгон продолжается только если оба ЧРП запущены И частоты синхронизированы
xConditionToProceed := xVFDsReady AND xFrequenciesSynchronized;

// ========================================
// ОБРАБОТКА ЧАСТОТЫ (после установки целевых значений в CASE)
// ========================================

// Моторы конвейера
Conveyor.MotorConveyor[1].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - малый шаг, иначе - большой шаг (мгновенно)
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqConv1,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := xConditionToProceed // Синхронизация с мотором 2
);

Conveyor.MotorConveyor[2].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - малый шаг, иначе - большой шаг (мгновенно)
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqConv2,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := xConditionToProceed // Синхронизация с мотором 1
);

// ========================================
// УПРАВЛЕНИЕ КОНТАКТОРАМИ
// ========================================

// Обработка импульсных команд сборки/разборки схемы
IF Conveyor.cmdBuildCircuitOn THEN
	xCircuitBuilt := TRUE;
ELSIF Conveyor.cmdBuildCircuitOff THEN
	xCircuitBuilt := FALSE;
END_IF;

// Моторы конвейера - управление контакторами через состояние схемы
Conveyor.MotorConveyor[1].qxKM_Power := xCircuitBuilt;
Conveyor.MotorConveyor[2].qxKM_Power := xCircuitBuilt;

END_FUNCTION_BLOCK