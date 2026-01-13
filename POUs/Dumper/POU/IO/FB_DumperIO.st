FUNCTION_BLOCK FB_DumperIO
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
END_VAR
VAR
	i : INT;
END_VAR

// ========================================
// FB_DumperIO - Обработка I/O отвалообразователя
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Инициализация всех сигналов (кнопки ПМУ, датчики безопасности)
// - Обработка дискретных сигналов с фильтрацией дребезга
// - Обработка аналоговых сигналов (VFD)
// - Диагностика оборудования (токи, частоты)
//
// ========================================

// ========================================
// КНОПКИ ПМУ (Пульт Местного Управления)
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

// ПМУ - Поворот влево/вправо
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

// ========================================
// КОНЦЕВЫЕ ВЫКЛЮЧАТЕЛИ ПОВОРОТА
// ========================================

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

// ========================================
// ОБРАТНАЯ СВЯЗЬ ТОРМОЗОВ
// ========================================

Dumper.fbBreakerConveyor(
	ixSignal := , // Физ. сигнал
	xEnableRattlingFilter := TRUE
);

Dumper.fbBreakerRotation(
	ixSignal := , // Физ. сигнал
	xEnableRattlingFilter := TRUE
);

// ========================================
// ДВИГАТЕЛИ КОНВЕЙЕРА (2 шт)
// ========================================

FOR i := 1 TO 2 BY 1 DO
	// Дискретные сигналы мотора
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

	// Дискретные сигналы VFD
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

	// ЧРП Device
	Dumper.MotorConveyor[i].VFD.Device(
		ixFeedback := Dumper.MotorConveyor[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

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
	// xEnable: включаем аналоговый выход когда есть команда на запуск ИЛИ VFD уже работает
	// Это позволяет задать частоту ДО того, как VFD запустится
	Dumper.MotorConveyor[i].VFD.fbAnalogOutput(
		xEnable := Dumper.MotorConveyor[i].VFD.qxStart OR Dumper.MotorConveyor[i].VFD.Device.qxActive,
		rEngValue := Dumper.MotorConveyor[i].VFD.qrOutFrequency,
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

// ========================================
// ДВИГАТЕЛИ ПОВОРОТА (2 шт)
// ========================================

FOR i := 1 TO 2 BY 1 DO
	// Дискретные сигналы мотора
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

	// Дискретные сигналы VFD
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

	// ЧРП Device
	Dumper.MotorRotation[i].VFD.Device(
		ixFeedback := Dumper.MotorRotation[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

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
	// xEnable: включаем аналоговый выход когда есть команда на запуск ИЛИ VFD уже работает
	// Это позволяет задать частоту ДО того, как VFD запустится
	Dumper.MotorRotation[i].VFD.fbAnalogOutput(
		xEnable := Dumper.MotorRotation[i].VFD.qxStart OR Dumper.MotorRotation[i].VFD.Device.qxActive,
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

// ========================================
// ДАТЧИКИ БЕЗОПАСНОСТИ
// ========================================

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

END_FUNCTION_BLOCK
