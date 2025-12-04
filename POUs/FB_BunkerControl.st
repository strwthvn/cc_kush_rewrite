FUNCTION_BLOCK FB_BunkerControl
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
	xStart : BOOL; // Команда запуска вибропитателей
	xStop : BOOL; // Команда останова (аварийная)
	xReset : BOOL; // Сброс ошибок
END_VAR
VAR_OUTPUT
	eStage : E_StageWithPreStartAlarm; // Текущая стадия запуска вибропитателей
	eStageToSCADA : E_ScadaStatesDevice; // Передача состояния скаде
END_VAR
VAR
	i : INT;
	_rtStartCmd, _rtStopCmd : R_TRIG; // Детекторы фронтов для команд

	// Локальные переменные для управления в режиме МЕСТНЫЙ
	_rtStartKM, _rtStopKM : R_TRIG;
	_rtStartVFD, _rtStopVFD : R_TRIG;

	// ФБ управления
	fbVibratorControl : FB_VibratorControl;
	fbPneumoControl : FB_PneumoCollapseControl;

	// Автомат состояний для запуска вибропитателей
	STAGE : E_StageWithPreStartAlarm := E_StageWithPreStartAlarm.IDLE;

END_VAR

// ========================================
// ИНИЦИАЛИЗАЦИЯ СИГНАЛОВ С ФИЛЬТРАЦИЕЙ ДРЕБЕЗГА
// ========================================

// Положение люка - с фильтрацией дребезга
Bunker.fbStateHatch(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// ПМУ - СТАРТ - с фильтрацией дребезга
Bunker.fbBtnStart(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// ПМУ - СТОП - с фильтрацией дребезга
Bunker.fbBtnStop(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// ПМУ - Аварийная остановка - с фильтрацией дребезга
Bunker.fbBtnEmergencyStop(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

// Двигатели вибраторов
FOR i := 1 TO AMOUNT_BUNKER_MOTOR_VIBRATOR BY 1 DO
	Bunker.MotorVibrator[i].fbStateKM(
		ixSignal := , // Состояние контактора
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibrator[i].fbStateQF(
		ixSignal := , // Автомат. выключатель
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibrator[i].VFD.fbStateFailure(
		ixSignal := , // ЧРП - ошибка
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibrator[i].VFD.fbStateRdyToStart(
		ixSignal := , // ЧРП - Готовность
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibrator[i].VFD.fbStateIsWorking(
		ixSignal := , // ЧРП - Работа
		xEnableRattlingFilter := TRUE
	);
END_FOR;

// Двигатели вибропитателей
FOR i := 1 TO AMOUNT_BUNKER_MOTOR_VIBFEEDER BY 1 DO
	Bunker.MotorVibFeeder[i].fbStateKM(
		ixSignal := , // Состояние контактора
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibFeeder[i].fbStatorOverheat(
		ixSignal := , // Перегрев статора
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibFeeder[i].fbStateQF(
		ixSignal := , // Автомат. выключатель
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibFeeder[i].VFD.fbStateFailure(
		ixSignal := , // ЧРП - ошибка
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibFeeder[i].VFD.fbStateRdyToStart(
		ixSignal := , // ЧРП - Готовность
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibFeeder[i].VFD.fbStateIsWorking(
		ixSignal := , // ЧРП - Работа
		xEnableRattlingFilter := TRUE
	);

	// Device control для контакторов
	Bunker.MotorVibFeeder[i].Device(
		ixFeedback := Bunker.MotorVibFeeder[i].fbStateKM.qxSignal,
		xEnableFeedback := TRUE
	);
	Bunker.MotorVibFeeder[i].qxKM_Power := Bunker.MotorVibFeeder[i].Device.qxPower;

	// Device control для ЧРП
	Bunker.MotorVibFeeder[i].VFD.Device(
		ixFeedback := Bunker.MotorVibFeeder[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);
	Bunker.MotorVibFeeder[i].VFD.qxStart := Bunker.MotorVibFeeder[i].VFD.Device.qxPower;
END_FOR;

// ========================================
// ОБРАБОТКА ДИАГНОСТИКИ ДИАПАЗОНОВ
// ========================================

// Аналоговые входы температуры подшипникового узла мотора вибропитателя 1
Bunker.MotorVibFeeder[1].fbAnalogInput[1](
	xSimulation := SIMULATION,
	iADC_Code := Bunker.MotorVibFeeder[1].nTempBearingRawSignal[1],
	refEngValue := Bunker.MotorVibFeeder[1].rTempBearing[1],
	refSimValue := Bunker.MotorVibFeeder[1].rSimulatedTempBearing[1],
	rAlarm_LL := VFD_CURRENT_ALARM_LL,
	rAlarm_L := VFD_CURRENT_ALARM_L,
	rAlarm_H := VFD_CURRENT_ALARM_H,
	rAlarm_HH := VFD_CURRENT_ALARM_HH,
	iADC_Max := VFD_ADC_MAX,
	iADC_Min := VFD_ADC_MIN,
	rEngValue_Max := TEMP_BEARING_MAX,
	rEngValue_Min := TEMP_BEARING_MIN,
	rCurrent_Max := VFD_CURRENT_MAX,
	rCurrent_Min := VFD_CURRENT_MIN
);

Bunker.MotorVibFeeder[1].fbAnalogInput[2](
	xSimulation := SIMULATION,
	iADC_Code := Bunker.MotorVibFeeder[1].nTempBearingRawSignal[2],
	refEngValue := Bunker.MotorVibFeeder[1].rTempBearing[2],
	refSimValue := Bunker.MotorVibFeeder[1].rSimulatedTempBearing[2],
	rAlarm_LL := VFD_CURRENT_ALARM_LL,
	rAlarm_L := VFD_CURRENT_ALARM_L,
	rAlarm_H := VFD_CURRENT_ALARM_H,
	rAlarm_HH := VFD_CURRENT_ALARM_HH,
	iADC_Max := VFD_ADC_MAX,
	iADC_Min := VFD_ADC_MIN,
	rEngValue_Max := TEMP_BEARING_MAX,
	rEngValue_Min := TEMP_BEARING_MIN,
	rCurrent_Max := VFD_CURRENT_MAX,
	rCurrent_Min := VFD_CURRENT_MIN
);

// Проверки LL HH мотора вибропитателя 1
Bunker.MotorVibFeeder[1].fbRangeDiagnostic[1](
	irValue := Bunker.MotorVibFeeder[1].rTempBearing[1],
	irSetpointL := MOTOR_VIBFEEDER_TEMP_POINTS.L_Value,
	irSetpointLL := MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value,
	irSetpointH := MOTOR_VIBFEEDER_TEMP_POINTS.H_Value,
	irSetpointHH := MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value,
	ixEnable := TRUE
);

Bunker.MotorVibFeeder[1].fbRangeDiagnostic[2](
	irValue := Bunker.MotorVibFeeder[1].rTempBearing[2],
	irSetpointL := MOTOR_VIBFEEDER_TEMP_POINTS.L_Value,
	irSetpointLL := MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value,
	irSetpointH := MOTOR_VIBFEEDER_TEMP_POINTS.H_Value,
	irSetpointHH := MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value,
	ixEnable := TRUE
);

Bunker.MotorVibFeeder[1].VFD.fbRangeDiagnostic(
	irValue := Bunker.MotorVibFeeder[1].VFD.wMotorCurrent.rTag,
	irSetpointL := MOTOR_VIBFEEDER_CURRENT_POINTS.L_Value,
	irSetpointLL := MOTOR_VIBFEEDER_CURRENT_POINTS.LL_Value,
	irSetpointH := MOTOR_VIBFEEDER_CURRENT_POINTS.H_Value,
	irSetpointHH := MOTOR_VIBFEEDER_CURRENT_POINTS.HH_Value,
	ixEnable := TRUE
);

// Аналоговый вход ЧРП (чтение текущей частоты)
Bunker.MotorVibFeeder[1].VFD.fbAnalogInput(
	xSimulation := SIMULATION,
	iADC_Code := Bunker.MotorVibFeeder[1].VFD.nActualFrequencyADC,
	refEngValue := Bunker.MotorVibFeeder[1].VFD.rActualFrequency,
	refSimValue := Bunker.MotorVibFeeder[1].VFD.rSimulatedFrequency,
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
Bunker.MotorVibFeeder[1].VFD.fbAnalogOutput(
	xEnable := Bunker.MotorVibFeeder[1].VFD.Device.qxActive,
	rEngValue := Bunker.MotorVibFeeder[1].VFD.qrOutFrequency,
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
Bunker.MotorVibFeeder[1].VFD.nSetOutSignalToModule := Bunker.MotorVibFeeder[1].VFD.fbAnalogOutput.iDAC_Code;

// Аналоговые входы температуры подшипникового узла мотора вибропитателя 2
Bunker.MotorVibFeeder[2].fbAnalogInput[1](
	xSimulation := SIMULATION,
	iADC_Code := Bunker.MotorVibFeeder[2].nTempBearingRawSignal[1],
	refEngValue := Bunker.MotorVibFeeder[2].rTempBearing[1],
	refSimValue := Bunker.MotorVibFeeder[2].rSimulatedTempBearing[1],
	rAlarm_LL := VFD_CURRENT_ALARM_LL,
	rAlarm_L := VFD_CURRENT_ALARM_L,
	rAlarm_H := VFD_CURRENT_ALARM_H,
	rAlarm_HH := VFD_CURRENT_ALARM_HH,
	iADC_Max := VFD_ADC_MAX,
	iADC_Min := VFD_ADC_MIN,
	rEngValue_Max := TEMP_BEARING_MAX,
	rEngValue_Min := TEMP_BEARING_MIN,
	rCurrent_Max := VFD_CURRENT_MAX,
	rCurrent_Min := VFD_CURRENT_MIN
);

Bunker.MotorVibFeeder[2].fbAnalogInput[2](
	xSimulation := SIMULATION,
	iADC_Code := Bunker.MotorVibFeeder[2].nTempBearingRawSignal[2],
	refEngValue := Bunker.MotorVibFeeder[2].rTempBearing[2],
	refSimValue := Bunker.MotorVibFeeder[2].rSimulatedTempBearing[2],
	rAlarm_LL := VFD_CURRENT_ALARM_LL,
	rAlarm_L := VFD_CURRENT_ALARM_L,
	rAlarm_H := VFD_CURRENT_ALARM_H,
	rAlarm_HH := VFD_CURRENT_ALARM_HH,
	iADC_Max := VFD_ADC_MAX,
	iADC_Min := VFD_ADC_MIN,
	rEngValue_Max := TEMP_BEARING_MAX,
	rEngValue_Min := TEMP_BEARING_MIN,
	rCurrent_Max := VFD_CURRENT_MAX,
	rCurrent_Min := VFD_CURRENT_MIN
);

// Проверки LL HH мотора вибропитателя 2
Bunker.MotorVibFeeder[2].fbRangeDiagnostic[1](
	irValue := Bunker.MotorVibFeeder[2].rTempBearing[1],
	irSetpointL := MOTOR_VIBFEEDER_TEMP_POINTS.L_Value,
	irSetpointLL := MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value,
	irSetpointH := MOTOR_VIBFEEDER_TEMP_POINTS.H_Value,
	irSetpointHH := MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value,
	ixEnable := TRUE
);

Bunker.MotorVibFeeder[2].fbRangeDiagnostic[2](
	irValue := Bunker.MotorVibFeeder[2].rTempBearing[2],
	irSetpointL := MOTOR_VIBFEEDER_TEMP_POINTS.L_Value,
	irSetpointLL := MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value,
	irSetpointH := MOTOR_VIBFEEDER_TEMP_POINTS.H_Value,
	irSetpointHH := MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value,
	ixEnable := TRUE
);

Bunker.MotorVibFeeder[2].VFD.fbRangeDiagnostic(
	irValue := Bunker.MotorVibFeeder[2].VFD.wMotorCurrent.rTag,
	irSetpointL := MOTOR_VIBFEEDER_CURRENT_POINTS.L_Value,
	irSetpointLL := MOTOR_VIBFEEDER_CURRENT_POINTS.LL_Value,
	irSetpointH := MOTOR_VIBFEEDER_CURRENT_POINTS.H_Value,
	irSetpointHH := MOTOR_VIBFEEDER_CURRENT_POINTS.HH_Value,
	ixEnable := TRUE
);

// Аналоговый вход ЧРП (чтение текущей частоты)
Bunker.MotorVibFeeder[2].VFD.fbAnalogInput(
	xSimulation := SIMULATION,
	iADC_Code := Bunker.MotorVibFeeder[2].VFD.nActualFrequencyADC,
	refEngValue := Bunker.MotorVibFeeder[2].VFD.rActualFrequency,
	refSimValue := Bunker.MotorVibFeeder[2].VFD.rSimulatedFrequency,
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
Bunker.MotorVibFeeder[2].VFD.fbAnalogOutput(
	xEnable := Bunker.MotorVibFeeder[2].VFD.Device.qxActive,
	rEngValue := Bunker.MotorVibFeeder[2].VFD.qrOutFrequency,
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
Bunker.MotorVibFeeder[2].VFD.nSetOutSignalToModule := Bunker.MotorVibFeeder[2].VFD.fbAnalogOutput.iDAC_Code;

// Проверки LL HH моторов вибратора
FOR i := 1 TO AMOUNT_BUNKER_MOTOR_VIBRATOR BY 1 DO
	Bunker.MotorVibrator[i].VFD.fbRangeDiagnostic(
		irValue := Bunker.MotorVibrator[i].VFD.wMotorCurrent.rTag,
		irSetpointL := MOTOR_VIBRATOR_CURRENT_POINTS.L_Value,
		irSetpointLL := MOTOR_VIBRATOR_CURRENT_POINTS.LL_Value,
		irSetpointH := MOTOR_VIBRATOR_CURRENT_POINTS.H_Value,
		irSetpointHH := MOTOR_VIBRATOR_CURRENT_POINTS.HH_Value,
		ixEnable := TRUE
	);

	// Аналоговый вход ЧРП (чтение текущей частоты)
	Bunker.MotorVibrator[i].VFD.fbAnalogInput(
		xSimulation := SIMULATION,
		iADC_Code := Bunker.MotorVibrator[i].VFD.nActualFrequencyADC,
		refEngValue := Bunker.MotorVibrator[i].VFD.rActualFrequency,
		refSimValue := Bunker.MotorVibrator[i].VFD.rSimulatedFrequency,
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
	Bunker.MotorVibrator[i].VFD.fbAnalogOutput(
		xEnable := Bunker.MotorVibrator[i].VFD.Device.qxActive,
		rEngValue := Bunker.MotorVibrator[i].VFD.qrOutFrequency,
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
	Bunker.MotorVibrator[i].VFD.nSetOutSignalToModule := Bunker.MotorVibrator[i].VFD.fbAnalogOutput.iDAC_Code;
END_FOR;

fbVibratorControl(
	MotorVibrator:= Bunker.MotorVibrator, 
	xEnable:= xStateAutoWorking, 
	xManualStart:= , 
	rWorkingFrequency:= 50 * EFFICIENCY_LIMIT_RATE, 
	tActiveTime:= VIBRATOR_SETTINGS.TIME_ACTIVE, 
	tPauseVibrator:= VIBRATOR_SETTINGS.TIME_PAUSE_VIBRATOR, 
	tPauseFB:= VIBRATOR_SETTINGS.TIME_PAUSE_FB, 
	nCycleCount:= VIBRATOR_SETTINGS.COUNT_CYCLE, 
	xMotorsWorking=> , 
	tTimeToNext=> );

fbPneumoControl(
	xEnable:= ,
	xManualStart:= ,
	tActiveTime:= VIBRATOR_SETTINGS.TIME_ACTIVE,
	tPauseCycle:= VIBRATOR_SETTINGS.TIME_PAUSE_VIBRATOR,
	tPauseFB:= VIBRATOR_SETTINGS.TIME_PAUSE_FB,
	nCycleCount:= VIBRATOR_SETTINGS.COUNT_CYCLE,
	xPneumoActive=> ,
	tTimeToNext=> );


// ========================================
// ОПРЕДЕЛЕНИЕ СОСТОЯНИЙ ДЛЯ SCADA
// ========================================

// Проверка ошибок вибропитателей (без вибраторов и пневмообрушения)
Bunker.xStateFailure := FC_Bunker_GetErrorMotorVibFeeder(Bunker := Bunker)
					 OR FC_Bunker_GetErrorBunker(Bunker := Bunker);

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
// АВТОМАТ СОСТОЯНИЙ ЗАПУСКА ВИБРОПИТАТЕЛЕЙ
// ========================================

CASE STAGE OF
	E_StageWithPreStartAlarm.IDLE:
		// Сброс частот
		Bunker.MotorVibFeeder[1].VFD.qrOutFrequency := 0.0;
		Bunker.MotorVibFeeder[2].VFD.qrOutFrequency := 0.0;

		// Переход в STARTING при получении команды запуска
		IF xStart THEN
			STAGE := E_StageWithPreStartAlarm.STARTING;
		END_IF

	E_StageWithPreStartAlarm.STARTING:
		// Команда контакторам
		Bunker.MotorVibFeeder[1].Device.xStartCommand := TRUE;
		Bunker.MotorVibFeeder[2].Device.xStartCommand := TRUE;

		// Команда ЧРП после включения контакторов
		Bunker.MotorVibFeeder[1].VFD.Device.xStartCommand :=
			Bunker.MotorVibFeeder[1].Device.qxActive;
		Bunker.MotorVibFeeder[2].VFD.Device.xStartCommand :=
			Bunker.MotorVibFeeder[2].Device.qxActive;

		// Прямое задание стартовой частоты
		Bunker.MotorVibFeeder[1].VFD.qrOutFrequency := BUNKER_VIBFEEDER_START_FREQUENCY;
		Bunker.MotorVibFeeder[2].VFD.qrOutFrequency := BUNKER_VIBFEEDER_START_FREQUENCY;

		// Переход в WORK по включению оборудования
		IF Bunker.MotorVibFeeder[1].Device.qxActive
		   AND Bunker.MotorVibFeeder[2].Device.qxActive
		   AND Bunker.MotorVibFeeder[1].VFD.Device.qxActive
		   AND Bunker.MotorVibFeeder[2].VFD.Device.qxActive
		THEN
			STAGE := E_StageWithPreStartAlarm.WORK;
		END_IF

	E_StageWithPreStartAlarm.WORK:
		// Управление от PID-контроллера (активируется в MAIN.st при AUTO_STEP = WORK)
		Bunker.MotorVibFeeder[1].VFD.qrOutFrequency := Bunker.rMotorVibFeederCommonFrequency;
		Bunker.MotorVibFeeder[2].VFD.qrOutFrequency := Bunker.rMotorVibFeederCommonFrequency;

		// Обработка команды останова
		IF xStop THEN
			Bunker.MotorVibFeeder[1].Device.xStopCommand := TRUE;
			Bunker.MotorVibFeeder[2].Device.xStopCommand := TRUE;
			Bunker.MotorVibFeeder[1].VFD.Device.xStopCommand := TRUE;
			Bunker.MotorVibFeeder[2].VFD.Device.xStopCommand := TRUE;
			STAGE := E_StageWithPreStartAlarm.IDLE;
		END_IF

	E_StageWithPreStartAlarm.ERROR:
		// Сброс частот
		Bunker.MotorVibFeeder[1].VFD.qrOutFrequency := 0.0;
		Bunker.MotorVibFeeder[2].VFD.qrOutFrequency := 0.0;

		// Команды останова
		Bunker.MotorVibFeeder[1].Device.xStopCommand := TRUE;
		Bunker.MotorVibFeeder[2].Device.xStopCommand := TRUE;

		// Переход в IDLE при сбросе ошибки
		IF xReset AND NOT FC_Bunker_GetErrorMotorVibFeeder(Bunker := Bunker) THEN
			STAGE := E_StageWithPreStartAlarm.IDLE;
		END_IF

END_CASE;

// Выходной параметр - текущая стадия
eStage := STAGE;

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

// ========================================
// УПРАВЛЕНИЕ СВЕТОФОРОМ
// ========================================
// Управление выходами светофора происходит извне через вызовы отдельных функций

// ========================================
// РАСЧЁТ ОШИБОК ОБОРУДОВАНИЯ
// ========================================
// Ошибки рассчитываются через отдельные функции FC_Get_ErrorBunker и т.д.

END_FUNCTION_BLOCK