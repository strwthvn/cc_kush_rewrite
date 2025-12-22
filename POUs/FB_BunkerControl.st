FUNCTION_BLOCK FB_BunkerControl
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
	xLocalMode : BOOL; // TRUE = местный режим (ПМУ), FALSE = дистанционный режим (SCADA)
	xStart : BOOL; // Команда запуска вибропитателей (дистанционный режим)
	xStop : BOOL; // Команда остановки (дистанционный режим)
	xEmergencyStopVibFeeder : BOOL; // Аварийная остановка вибропитателей (переводит бункер в ERROR)
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
	i : INT;
	_rtStartCmd, _rtStopCmd : R_TRIG; // Детекторы фронтов для команд

	// Локальные переменные для управления в режиме МЕСТНЫЙ
	_rtStartKM, _rtStopKM : R_TRIG;
	_rtStartVFD, _rtStopVFD : R_TRIG;

	// Объединенные команды (ПМУ или SCADA в зависимости от режима)
	xStartCommand : BOOL; // Фактическая команда запуска (из ПМУ или SCADA)
	xStopCommand : BOOL; // Фактическая команда остановки (из ПМУ или SCADA)

	// ФБ управления
	fbVibratorControl : FB_VibratorControl;
	fbPneumoControl : FB_PneumoCollapseControl;

	// Таймер для автоматического отключения вибраторов
	tonVibratorEnable : TON;

	// Автомат состояний для запуска вибропитателей
	STAGE : E_StageWithPreStartAlarm := E_StageWithPreStartAlarm.IDLE;

	// Состояние схемы контакторов (TRUE = схема собрана, FALSE = схема разобрана)
	xCircuitBuilt : BOOL := FALSE;
	xCircuitBuiltVibrator : BOOL := FALSE;

	// Целевые частоты для моторов вибропитателей
	rTargetFreqVibFeeder1 : REAL := 0.0;
	rTargetFreqVibFeeder2 : REAL := 0.0;

	// Флаг активного запуска вибраторов в ручном режиме
	xVibratorManualRunActive : BOOL := FALSE;

	// Таймеры контроля выполнения команд
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
// - Режимы: Auto (таймер), Manual (выборочно), Repair (остановлены)
//
// ========================================

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
	xEnable := Bunker.MotorVibFeeder[1].VFD.fbStateIsWorking.qxSignal,
	rEngValue := Bunker.MotorVibFeeder[1].VFD.Frequency.qrCurrentFrequency,
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
	xEnable := Bunker.MotorVibFeeder[2].VFD.fbStateIsWorking.qxSignal,
	rEngValue := Bunker.MotorVibFeeder[2].VFD.Frequency.qrCurrentFrequency,
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
		xEnable := Bunker.MotorVibrator[i].VFD.fbStateIsWorking.qxSignal,
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
IF xEmergencyStopVibFeeder THEN
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

CASE STAGE OF
	E_StageWithPreStartAlarm.IDLE:
		// Сброс таймеров запуска и остановки
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);

		// Сброс целевых частот
		rTargetFreqVibFeeder1 := 0.0;
		rTargetFreqVibFeeder2 := 0.0;

		// Остановка VFD
		Bunker.MotorVibFeeder[1].VFD.qxStart := FALSE;
		Bunker.MotorVibFeeder[2].VFD.qxStart := FALSE;

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

		// Команда ПУСК на VFD (TRUE = ПУСК)
		Bunker.MotorVibFeeder[1].VFD.qxStart := TRUE;
		Bunker.MotorVibFeeder[2].VFD.qxStart := TRUE;

		// Выбор источника частоты в зависимости от режима управления
		IF Bunker.eStateRemote = E_StateRemote.Auto THEN
			// Автоматический режим - частота от ПИД
			rTargetFreqVibFeeder1 := Bunker.rMotorVibFeederCommonFrequency;
			rTargetFreqVibFeeder2 := Bunker.rMotorVibFeederCommonFrequency;
		ELSE
			// Ручной/Ремонт режим - частота от входного параметра irManualFrequency
			rTargetFreqVibFeeder1 := irManualFrequency;
			rTargetFreqVibFeeder2 := irManualFrequency;
		END_IF;

		// Переход в WORK по включению оборудования (обратная связь VFD)
		IF Bunker.MotorVibFeeder[1].VFD.fbStateIsWorking.qxSignal
		   AND Bunker.MotorVibFeeder[2].VFD.fbStateIsWorking.qxSignal
		THEN
			// Сброс таймера запуска (успешный запуск)
			fbTimerStarting(IN := FALSE);
			STAGE := E_StageWithPreStartAlarm.WORK;
		END_IF

	E_StageWithPreStartAlarm.WORK:
		// Команда ПУСК остается активной
		Bunker.MotorVibFeeder[1].VFD.qxStart := TRUE;
		Bunker.MotorVibFeeder[2].VFD.qxStart := TRUE;

		// Выбор источника частоты в зависимости от режима управления
		IF Bunker.eStateRemote = E_StateRemote.Auto THEN
			// Автоматический режим - динамическая частота от ПИД
			rTargetFreqVibFeeder1 := Bunker.rMotorVibFeederCommonFrequency;
			rTargetFreqVibFeeder2 := Bunker.rMotorVibFeederCommonFrequency;
		ELSE
			// Ручной/Ремонт режим - частота от входного параметра irManualFrequency
			rTargetFreqVibFeeder1 := irManualFrequency;
			rTargetFreqVibFeeder2 := irManualFrequency;
		END_IF;

		// Обработка команды останова
		IF xStopCommand THEN
			// Запуск таймера остановки (тайм-аут на остановку вибропитателей)
			fbTimerStopping(
				IN := TRUE,
				PT := TIME_TIMEOUT_STOP_BUNKER
			);

			// Остановка VFD
			Bunker.MotorVibFeeder[1].VFD.qxStart := FALSE;
			Bunker.MotorVibFeeder[2].VFD.qxStart := FALSE;

			// Проверка остановки VFD (обратная связь)
			IF NOT Bunker.MotorVibFeeder[1].VFD.fbStateIsWorking.qxSignal
			   AND NOT Bunker.MotorVibFeeder[2].VFD.fbStateIsWorking.qxSignal
			THEN
				// Сброс таймера остановки (успешная остановка)
				fbTimerStopping(IN := FALSE);
				STAGE := E_StageWithPreStartAlarm.IDLE;
			END_IF;
		END_IF

	E_StageWithPreStartAlarm.ERROR:
		// Состояние ошибки - аварийная остановка и ожидание сброса
		// (используется при серьезных неисправностях, не для штатной остановки)

		// Сброс таймеров
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);

		// Аварийная остановка: команда СТОП на VFD (FALSE = СТОП)
		Bunker.MotorVibFeeder[1].VFD.qxStart := FALSE;
		Bunker.MotorVibFeeder[2].VFD.qxStart := FALSE;

		// Сброс целевых частот
		rTargetFreqVibFeeder1 := 0.0;
		rTargetFreqVibFeeder2 := 0.0;

		// Разборка схемы контакторов (аварийная остановка)
		xCircuitBuilt := FALSE;

		// Контакторы управляются отдельно через импульсные команды
		// cmdBuildCircuitOn/Off (см. секцию УПРАВЛЕНИЕ КОНТАКТОРАМИ)

		// Сброс ошибки и переход в IDLE при отсутствии ошибок
		// Для выхода из ERROR требуется:
		// 1. Команда сброса (xReset)
		// 2. Снятие сигнала аварийной остановки (NOT xEmergencyStopVibFeeder)
		// 3. Отсутствие ошибок оборудования (NOT Bunker.xStateFailure)
		IF xReset AND NOT xEmergencyStopVibFeeder AND NOT Bunker.xStateFailure THEN
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
// ОБРАБОТКА ЧАСТОТЫ (после установки целевых значений в CASE)
// ========================================

// Мотор вибропитателя 1
Bunker.MotorVibFeeder[1].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqVibFeeder1,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := TRUE
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

// Мотор вибропитателя 2
Bunker.MotorVibFeeder[2].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqVibFeeder2,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := TRUE
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

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

// ========================================
// УПРАВЛЕНИЕ КОНТАКТОРАМИ
// ========================================

// Обработка импульсных команд сборки/разборки схемы
// cmdBuildCircuitOn - собрать схему (включить контакторы)
// cmdBuildCircuitOff - разобрать схему (выключить контакторы)
IF Bunker.eStateRemote = E_StateRemote.Manual THEN
	IF Bunker.cmdBuildCircuitOn THEN
		xCircuitBuilt := TRUE;
	ELSIF Bunker.cmdBuildCircuitOff THEN
		xCircuitBuilt := FALSE;
	END_IF;
END_IF;

IF Bunker.eStateRemote = E_StateRemote.Manual THEN
	IF Bunker.cmdBuildCircuitOnVibrator THEN
		xCircuitBuiltVibrator := TRUE;
	ELSIF Bunker.cmdBuildCircuitOffVibrator THEN
		xCircuitBuiltVibrator := FALSE;
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
// УПРАВЛЕНИЕ РЕЖИМАМИ ВИБРАТОРОВ
// ========================================

// Обработка команд переключения режима управления вибраторов
IF Bunker.cmdVibratorSetModeAuto THEN
	Bunker.eVibratorStateRemote := E_StateRemote.Auto;
	xVibratorManualRunActive := FALSE; // Сброс флага при смене режима
ELSIF Bunker.cmdVibratorSetModeManual THEN
	Bunker.eVibratorStateRemote := E_StateRemote.Manual;
	xVibratorManualRunActive := FALSE; // Сброс флага при смене режима
ELSIF Bunker.cmdVibratorSetModeRepair THEN
	Bunker.eVibratorStateRemote := E_StateRemote.Repair;
	xVibratorManualRunActive := FALSE; // Сброс флага при смене режима
END_IF;

// ========================================
// УПРАВЛЕНИЕ ВИБРАТОРАМИ
// ========================================

// ПРИОРИТЕТНАЯ ПРОВЕРКА АВАРИЙНОЙ ОСТАНОВКИ ВИБРАТОРОВ
// Аварийная остановка вибраторов имеет наивысший приоритет
// При получении сигнала аварийной остановки - немедленная остановка всех вибраторов
IF xEmergencyStopVibrator THEN
	// Остановка всех VFD вибраторов
	Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
	Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
	Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
	Bunker.MotorVibrator[4].VFD.qxStart := FALSE;

	// Разборка схемы контакторов вибраторов
	xCircuitBuiltVibrator := FALSE;

	// Сброс таймера и флагов
	tonVibratorEnable.IN := FALSE;
	xVibratorManualRunActive := FALSE;
END_IF;

// Обработка таймера автоматического отключения (только для автоматического режима)
tonVibratorEnable(PT := VIBRATOR_SETTINGS.TIME_ACTIVE);

// Нормальная работа вибраторов (если нет аварийной остановки)
IF NOT xEmergencyStopVibrator THEN
	// === РЕЖИМ АВТОМАТИЧЕСКИЙ - запуск от SCADA или автоматики ===
	IF Bunker.eVibratorStateRemote = E_StateRemote.Auto THEN
	// Управление запуском вибраторов
	IF Bunker.cmdStartVibrator THEN
		tonVibratorEnable.IN := TRUE;
		Bunker.MotorVibrator[1].VFD.qxStart := TRUE;
		Bunker.MotorVibrator[2].VFD.qxStart := TRUE;
		Bunker.MotorVibrator[3].VFD.qxStart := TRUE;
		Bunker.MotorVibrator[4].VFD.qxStart := TRUE;
	END_IF

	// Управление остановкой вибраторов (по команде или по таймауту)
	IF Bunker.cmdStopVibrator OR tonVibratorEnable.Q THEN
		tonVibratorEnable.IN := FALSE;
		Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[4].VFD.qxStart := FALSE;
	END_IF

// === РЕЖИМ РУЧНОЙ - индивидуальное управление через выбор + старт/стоп ===
ELSIF Bunker.eVibratorStateRemote = E_StateRemote.Manual THEN
	// Команда СТАРТ активирует флаг запуска
	IF Bunker.cmdStartVibrator THEN
		xVibratorManualRunActive := TRUE;
	END_IF

	// Команда СТОП останавливает ВСЕ вибраторы и сбрасывает флаг
	IF Bunker.cmdStopVibrator THEN
		xVibratorManualRunActive := FALSE;
		Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[4].VFD.qxStart := FALSE;
	END_IF

	// Если флаг запуска активен - управляем вибраторами через галочки выбора
	IF xVibratorManualRunActive THEN
		// Каждый вибратор работает только если он выбран (галочка установлена)
		Bunker.MotorVibrator[1].VFD.qxStart := Bunker.cmdAddVib1;
		Bunker.MotorVibrator[2].VFD.qxStart := Bunker.cmdAddVib2;
		Bunker.MotorVibrator[3].VFD.qxStart := Bunker.cmdAddVib3;
		Bunker.MotorVibrator[4].VFD.qxStart := Bunker.cmdAddVib4;
	END_IF

	// Установка частоты для вибраторов в ручном режиме
	FOR i := 1 TO AMOUNT_BUNKER_MOTOR_VIBRATOR BY 1 DO
		Bunker.MotorVibrator[i].VFD.qrOutFrequency := irManualFrequencyVibrator;
	END_FOR;

	// === РЕЖИМ РЕМОНТ - все вибраторы остановлены ===
	ELSIF Bunker.eVibratorStateRemote = E_StateRemote.Repair THEN
		xVibratorManualRunActive := FALSE;
		Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
		Bunker.MotorVibrator[4].VFD.qxStart := FALSE;
	END_IF;
END_IF; // Конец IF NOT xEmergencyStopVibrator

// ========================================
// УПРАВЛЕНИЕ СВЕТОФОРОМ
// ========================================
// Управление выходами светофора происходит извне через вызовы отдельных функций

// ========================================
// РАСЧЁТ ОШИБОК ОБОРУДОВАНИЯ
// ========================================
// Ошибки рассчитываются через отдельные функции FC_Get_ErrorBunker и т.д.

END_FUNCTION_BLOCK