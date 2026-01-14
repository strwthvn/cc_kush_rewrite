FUNCTION_BLOCK FB_BunkerIO
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
END_VAR
VAR
	i : INT;
END_VAR

// ========================================
// FB_BunkerIO - Обработка I/O бункера
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Инициализация всех сигналов (кнопки ПМУ, люк)
// - Обработка дискретных сигналов с фильтрацией дребезга
// - Обработка аналоговых сигналов (VFD, температура подшипников)
// - Диагностика оборудования (токи, температура, частота)
//
// ========================================

// ========================================
// КНОПКИ ПМУ И ДАТЧИКИ
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

// ========================================
// ДВИГАТЕЛИ ВИБРАТОРОВ (4 шт)
// ========================================

FOR i := 1 TO AMOUNT_BUNKER_MOTOR_VIBRATOR BY 1 DO
	// Дискретные сигналы мотора
	Bunker.MotorVibrator[i].fbStateKM(
		ixSignal := , // Состояние контактора
		xEnableRattlingFilter := TRUE
	);

	Bunker.MotorVibrator[i].fbStateQF(
		ixSignal := , // Автомат. выключатель
		xEnableRattlingFilter := TRUE
	);

	// Дискретные сигналы VFD
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

	// Диагностика тока ЧРП
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

// ========================================
// ДВИГАТЕЛИ ВИБРОПИТАТЕЛЕЙ (2 шт)
// ========================================

FOR i := 1 TO AMOUNT_BUNKER_MOTOR_VIBFEEDER BY 1 DO
	// Дискретные сигналы мотора
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

	// Дискретные сигналы VFD
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

	// VFD Device control
	Bunker.MotorVibFeeder[i].VFD.Device(
		ixFeedback := Bunker.MotorVibFeeder[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

	// Аналоговые входы температуры подшипникового узла (2 датчика)
	Bunker.MotorVibFeeder[i].fbAnalogInput[1](
		xSimulation := SIMULATION,
		iADC_Code := Bunker.MotorVibFeeder[i].nTempBearingRawSignal[1],
		refEngValue := Bunker.MotorVibFeeder[i].rTempBearing[1],
		refSimValue := Bunker.MotorVibFeeder[i].rSimulatedTempBearing[1],
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

	Bunker.MotorVibFeeder[i].fbAnalogInput[2](
		xSimulation := SIMULATION,
		iADC_Code := Bunker.MotorVibFeeder[i].nTempBearingRawSignal[2],
		refEngValue := Bunker.MotorVibFeeder[i].rTempBearing[2],
		refSimValue := Bunker.MotorVibFeeder[i].rSimulatedTempBearing[2],
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

	// Проверки LL HH температуры подшипников (2 датчика)
	Bunker.MotorVibFeeder[i].fbRangeDiagnostic[1](
		irValue := Bunker.MotorVibFeeder[i].rTempBearing[1],
		irSetpointL := MOTOR_VIBFEEDER_TEMP_POINTS.L_Value,
		irSetpointLL := MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value,
		irSetpointH := MOTOR_VIBFEEDER_TEMP_POINTS.H_Value,
		irSetpointHH := MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value,
		ixEnable := TRUE
	);

	Bunker.MotorVibFeeder[i].fbRangeDiagnostic[2](
		irValue := Bunker.MotorVibFeeder[i].rTempBearing[2],
		irSetpointL := MOTOR_VIBFEEDER_TEMP_POINTS.L_Value,
		irSetpointLL := MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value,
		irSetpointH := MOTOR_VIBFEEDER_TEMP_POINTS.H_Value,
		irSetpointHH := MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value,
		ixEnable := TRUE
	);

	// Диагностика тока ЧРП
	Bunker.MotorVibFeeder[i].VFD.fbRangeDiagnostic(
		irValue := Bunker.MotorVibFeeder[i].VFD.wMotorCurrent.rTag,
		irSetpointL := MOTOR_VIBFEEDER_CURRENT_POINTS.L_Value,
		irSetpointLL := MOTOR_VIBFEEDER_CURRENT_POINTS.LL_Value,
		irSetpointH := MOTOR_VIBFEEDER_CURRENT_POINTS.H_Value,
		irSetpointHH := MOTOR_VIBFEEDER_CURRENT_POINTS.HH_Value,
		ixEnable := TRUE
	);

	// Аналоговый вход ЧРП (чтение текущей частоты)
	Bunker.MotorVibFeeder[i].VFD.fbAnalogInput(
		xSimulation := SIMULATION,
		iADC_Code := Bunker.MotorVibFeeder[i].VFD.nActualFrequencyADC,
		refEngValue := Bunker.MotorVibFeeder[i].VFD.rActualFrequency,
		refSimValue := Bunker.MotorVibFeeder[i].VFD.rSimulatedFrequency,
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
	// Частота берётся напрямую из qrOutFrequency (без плавного разгона через FB_FrequencyControl)
	Bunker.MotorVibFeeder[i].VFD.fbAnalogOutput(
		xEnable := Bunker.MotorVibFeeder[i].VFD.fbStateIsWorking.qxSignal,
		rEngValue := Bunker.MotorVibFeeder[i].VFD.qrOutFrequency,
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
	Bunker.MotorVibFeeder[i].VFD.nSetOutSignalToModule := Bunker.MotorVibFeeder[i].VFD.fbAnalogOutput.iDAC_Code;
END_FOR;

END_FUNCTION_BLOCK
