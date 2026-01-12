FUNCTION_BLOCK FB_ConveyorIO
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
END_VAR
VAR
	i : INT;
END_VAR

// ========================================
// FB_ConveyorIO - Обработка I/O сборного конвейера
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

// ========================================
// ОБРАТНАЯ СВЯЗЬ ТОРМОЗА
// ========================================

Conveyor.fbBreakerConveyor(
	ixSignal := , // Физ. сигнал обратной связи реле тормоза
	xEnableRattlingFilter := TRUE
);

// ========================================
// ДВИГАТЕЛИ КОНВЕЙЕРА (2 шт)
// ========================================

FOR i := 1 TO 2 BY 1 DO
	// Дискретные сигналы мотора
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

	// Дискретные сигналы VFD
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

	// ЧРП Device
	Conveyor.MotorConveyor[i].VFD.Device(
		ixFeedback := Conveyor.MotorConveyor[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

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
		xEnable := Conveyor.MotorConveyor[i].VFD.Device.qxActive,
		rEngValue := Conveyor.MotorConveyor[i].VFD.qrOutFrequency,
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

// ========================================
// ДАТЧИКИ БЕЗОПАСНОСТИ
// ========================================

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

END_FUNCTION_BLOCK
