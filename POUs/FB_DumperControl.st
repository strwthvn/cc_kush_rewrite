FUNCTION_BLOCK FB_DumperControl
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
	xStart : BOOL; // Команда запуска отвалообразователя
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

	// Целевые частоты для моторов
	rTargetFreqConv1 : REAL := 0.0;
	rTargetFreqConv2 : REAL := 0.0;
	rTargetFreqRot1 : REAL := 0.0;
	rTargetFreqRot2 : REAL := 0.0;

	// Переменные синхронизации моторов конвейера
	xVFDsReady : BOOL; // Оба ЧРП конвейера готовы и запущены
	xFrequenciesSynchronized : BOOL; // Частоты синхронизированы в пределах допуска
	xConditionToProceed : BOOL; // Общее условие для продолжения разгона

	simInit : BOOL;
	i : INT;
END_VAR

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

// ПМУ режим управления (0 - Местный, 1 - Дистанционный)
Dumper.fbBtnRemoteMode(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

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

	Dumper.MotorConveyor[i].qxKM_Power := Dumper.MotorConveyor[i].Device.qxPower;

	// ЧРП
	Dumper.MotorConveyor[i].VFD.Device(
		ixFeedback := Dumper.MotorConveyor[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

	Dumper.MotorConveyor[i].VFD.qxStart := Dumper.MotorConveyor[i].VFD.Device.qxPower;

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

	Dumper.MotorRotation[i].qxKM_Power := Dumper.MotorRotation[i].Device.qxPower;

	// ЧРП
	Dumper.MotorRotation[i].VFD.Device(
		ixFeedback := Dumper.MotorRotation[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

	Dumper.MotorRotation[i].VFD.qxStart := Dumper.MotorRotation[i].VFD.Device.qxPower;

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
		refEngValue := Dumper.MotorRotation[i].VFD.Frequency.qrCurrentFrequency,
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
		rEngValue := Dumper.MotorRotation[i].VFD.qrOutFrequency,
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
	ixStop := xStop OR xReset,
	itFirstSignal := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL,
	itPauseAfterFirst := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE,
	itSecondSignal := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL,
	itPauseAfterSecond := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE,
	qxAlarmPower => Dumper.xHLA
);

Dumper.xStateEnable := STAGE = E_StageWithPreStartAlarm.WORK;
Dumper.xStateStarting := STAGE = E_StageWithPreStartAlarm.STARTING OR STAGE = PRESTART_ALARM;

// ========================================
// ОПРЕДЕЛЕНИЕ СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Проверка ошибок оборудования
Dumper.xStateFailure := FC_Dumper_GetErrorCommon(Dumper := Dumper);

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
	STAGE := E_StageWithPreStartAlarm.IDLE;
	// Сброс команд запуска
	Dumper.MotorConveyor[1].Device.xStartCommand := FALSE;
	Dumper.MotorConveyor[2].Device.xStartCommand := FALSE;
	Dumper.MotorConveyor[1].VFD.Device.xStartCommand := FALSE;
	Dumper.MotorConveyor[2].VFD.Device.xStartCommand := FALSE;
	// Сброс целевых частот
	rTargetFreqConv1 := 0.0;
	rTargetFreqConv2 := 0.0;
	rTargetFreqRot1 := 0.0;
	rTargetFreqRot2 := 0.0;
END_IF

// Аварийная остановка - переход в ERROR
IF xStop AND STAGE <> E_StageWithPreStartAlarm.IDLE THEN
	STAGE := E_StageWithPreStartAlarm.ERROR;
	// Сброс команд запуска
	Dumper.MotorConveyor[1].Device.xStartCommand := FALSE;
	Dumper.MotorConveyor[2].Device.xStartCommand := FALSE;
	Dumper.MotorConveyor[1].VFD.Device.xStartCommand := FALSE;
	Dumper.MotorConveyor[2].VFD.Device.xStartCommand := FALSE;
	// Сброс целевых частот
	rTargetFreqConv1 := 0.0;
	rTargetFreqConv2 := 0.0;
	rTargetFreqRot1 := 0.0;
	rTargetFreqRot2 := 0.0;
END_IF

// ========================================
// АВТОМАТ ПУСКА ОТВАЛООБРАЗОВАТЕЛЯ
// ========================================

CASE STAGE OF
	E_StageWithPreStartAlarm.IDLE:
		// Сброс целевой частоты
		rTargetFreqConv1 := 0.0;
		rTargetFreqConv2 := 0.0;
		rTargetFreqRot1 := 0.0;
		rTargetFreqRot2 := 0.0;

		IF xStart THEN
			STAGE := PRESTART_ALARM;
		END_IF;

	PRESTART_ALARM:
		IF Dumper.fbPreStartAlarm.qxComplete THEN
			STAGE := E_StageWithPreStartAlarm.STARTING;
		END_IF;

	E_StageWithPreStartAlarm.STARTING:
		// Команда ПУСК на контакторы
		Dumper.MotorConveyor[1].Device.xStartCommand := TRUE;
		Dumper.MotorConveyor[2].Device.xStartCommand := TRUE;

		// Команда ПУСК на частотный преобразователь
		Dumper.MotorConveyor[1].VFD.Device.xStartCommand := Dumper.MotorConveyor[1].Device.qxActive;
		Dumper.MotorConveyor[2].VFD.Device.xStartCommand := Dumper.MotorConveyor[2].Device.qxActive;

		// Задание целевой частоты (переменные будут переданы в FB_FrequencyControl выше)
		rTargetFreqConv1 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
		rTargetFreqConv2 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;

		// Переход в режим WORK при достижении целевой частоты
		IF Dumper.MotorConveyor[1].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
			AND Dumper.MotorConveyor[2].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
		THEN
			STAGE := E_StageWithPreStartAlarm.WORK;
		END_IF;

	E_StageWithPreStartAlarm.WORK:
		// Нормальная работа

	E_StageWithPreStartAlarm.ERROR:
		// Состояние ошибки - ожидание сброса
		// Все команды запуска уже сброшены выше
END_CASE;

// ========================================
// ПРОВЕРКА СИНХРОНИЗАЦИИ МОТОРОВ КОНВЕЙЕРА
// ========================================

// Проверка что оба ЧРП конвейера готовы и запущены
xVFDsReady := Dumper.MotorConveyor[1].VFD.Device.qxActive
           AND Dumper.MotorConveyor[2].VFD.Device.qxActive;

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
	irStep := VFD_FREQUENCY_STEP,
	rTargetFrequency := rTargetFreqConv1,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := xConditionToProceed // Синхронизация с мотором 2
);
Dumper.MotorConveyor[1].VFD.qrOutFrequency := Dumper.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency;

Dumper.MotorConveyor[2].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	irStep := VFD_FREQUENCY_STEP,
	rTargetFrequency := rTargetFreqConv2,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := xConditionToProceed // Синхронизация с мотором 1
);
Dumper.MotorConveyor[2].VFD.qrOutFrequency := Dumper.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency;

// Моторы поворота
Dumper.MotorRotation[1].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	irStep := VFD_FREQUENCY_STEP,
	rTargetFrequency := rTargetFreqRot1,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := TRUE
);
Dumper.MotorRotation[1].VFD.qrOutFrequency := Dumper.MotorRotation[1].VFD.Frequency.qrCurrentFrequency;

Dumper.MotorRotation[2].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	irStep := VFD_FREQUENCY_STEP,
	rTargetFrequency := rTargetFreqRot2,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := TRUE
);
Dumper.MotorRotation[2].VFD.qrOutFrequency := Dumper.MotorRotation[2].VFD.Frequency.qrCurrentFrequency;

// Вывод текущей стадии
eStage := STAGE;

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

END_FUNCTION_BLOCK