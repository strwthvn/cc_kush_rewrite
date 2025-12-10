PROGRAM MAIN
VAR
	fbSimulation : FB_Simulation;
	fbEmergencyStopProcess : FB_EmergencyStopProcess;

	fbBunker : ARRAY [1..3] OF FB_BunkerControl;
	stBunker : ARRAY [1..3] OF ST_Bunker;

	fbDumper : FB_DumperControl;
	stDumper : ST_Dumper;
	xStartDumper : BOOL := FALSE; // Команда запуска отвалообразователя
	xManualStopDumper : BOOL; // Ручная остановка отвалообразователя
	eDumperStage : E_StageWithPreStartAlarm; // Стадия отвалообразователя
	eDumperStageToSCADA : E_ScadaStatesDevice; // Состояние для SCADA отвалообразователя

	fbProportionPid : FB_ProportionPID;

	fbConveyor : FB_ConveyorControl;
	stConveyor : ST_ConveyorPrefabricated;
	xStartConveyor : BOOL := FALSE; // Команда запуска конвейера
	xManualStopConveyor : BOOL; // Команда остановки сборного конвейера
	eConveyorStage : E_StageWithPreStartAlarm; // Стадия конвейера
	eConveyorStageToSCADA : E_ScadaStatesDevice; // Состояние для SCADA конвейера

	xStartBunker : ARRAY[1..3] OF BOOL := [FALSE, FALSE, FALSE]; // Команды запуска бункеров
	xManualStopBunker : ARRAY[1..3] OF BOOL; // Команды остановки бункеров
	eBunkerStage : ARRAY[1..3] OF E_StageWithPreStartAlarm; // Стадии бункеров
	eBunkerStageToSCADA : ARRAY[1..3] OF E_ScadaStatesDevice; // Состояния для SCADA бункеров

	stCommonSignals : ST_CommonSignals;
	stCommands : ST_Commands;

	// Системные переменные
	xStateEmergencyStop : BOOL := FALSE; // Флаг аварийного останова
	xStateErrorCheckReady : BOOL := FALSE; // Готовность к пуску (отсутствие ошибок)
	xStateErrorAcceptIdle : BOOL := FALSE; // Ошибка задания пропорции
	ICUR_PRECENT : REAL := 0.0; // КИУМ в процентах

	// Шаги автоматического алгоритма
	AUTO_STEP : (
		IDLE, 				// Ожидание задания пропорции
		INIT,				// Расчёт производительности
		START_DUMPER,		// Запуск отвалообразователя
		START_CONV,			// Запуск конвейера
		START_VIBFEEDER,	// Запуск вибропитателей
		WORK,				// Работа отвалообразователя, доступ к дополнительным функциям
		END_REPORT,			// Завершение работы, формирование отчёта
		ERROR				// Состояние ошибки
		) := IDLE; // Начальное положение

	ton_waitAfterStartDumper : TON; // Таймер ожидания после пуска отвалообразователя

	// Вспомогательные переменные
	i : INT; // Счётчик для циклов
	awModbusRegisters : ARRAY [0..99] OF WORD; // Массив Modbus регистров

	// Временные переменные для расчёта пропорций бункеров
	rWeight1, rWeight2, rWeight3 : REAL; // Индивидуальный вес каждого бункера
	rTotalWeightActive : REAL; // Суммарный вес активных бункеров

	// Временная переменная для конвертации TIME из Modbus (секунды)
	rTempTime : REAL;
END_VAR

// == ИНИЦИАЛИЗАЦИЯ ==
// Инициализация общих сигналов
stCommonSignals.fbEmergencyStopBtn(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := FALSE // Базовый сигнал без фильтра
);

stCommonSignals.fbRemoteModeBtn(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

stCommonSignals.fbRealyCurrentControl(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE,
	tStabilityTime := T#100MS
);

stCommonSignals.fbQF1(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE
);

stCommonSignals.fb9QF1(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE
);

stCommonSignals.fb10QF1(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE
);

stCommonSignals.fb11QF1(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := TRUE
);

// Инициализация команд
stCommands.cmdResetAll(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := FALSE // Только edge detection
);

stCommands.cmdStartCommon(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := FALSE // Только edge detection
);

stCommands.cmdStopCommon(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := FALSE // Только edge detection
);

stCommands.cmdEmergencyStopCommon(
	ixSignal := , // Подключить физический вход
	xEnableRattlingFilter := FALSE // Только edge detection
);

// Постоянный внутренний импульс-сигнал
PULSE(ENABLE:= TRUE, TIMELOW:= T#200MS, TIMEHIGH := T#200MS);
PULSE_RTRIG(CLK:= PULSE.OUT);

// Конвертация сигнала светофора бункера в WORD
FOR i := 1 TO 3 DO
	stBunker[i].wLightColor := TO_WORD(stBunker[i].eLightColor);
END_FOR

// == ОБРАБОТКА ФУНКЦИОНАЛЬНЫХ БЛОКОВ ==
// Бункеры
fbBunker[1](
	Bunker := stBunker[1],
	xStart := xStartBunker[1],
	xStop := fbEmergencyStopProcess.qxStateStopProcess OR xManualStopBunker[1],
	xReset := stCommands.cmdResetAll.qxSignal,
	irManualFrequency := BUNKER_1_FREQ_VIBFEEDER,
	eStage => eBunkerStage[1],
	eStageToSCADA => eBunkerStageToSCADA[1]
);

fbBunker[2](
	Bunker := stBunker[2],
	xStart := xStartBunker[2],
	xStop := fbEmergencyStopProcess.qxStateStopProcess OR xManualStopBunker[2],
	xReset := stCommands.cmdResetAll.qxSignal,
	irManualFrequency := BUNKER_2_FREQ_VIBFEEDER,
	eStage => eBunkerStage[2],
	eStageToSCADA => eBunkerStageToSCADA[2]
);

fbBunker[3](
	Bunker := stBunker[3],
	xStart := xStartBunker[3],
	xStop := fbEmergencyStopProcess.qxStateStopProcess OR xManualStopBunker[3],
	xReset := stCommands.cmdResetAll.qxSignal,
	irManualFrequency := BUNKER_3_FREQ_VIBFEEDER,
	eStage => eBunkerStage[3],
	eStageToSCADA => eBunkerStageToSCADA[3]
);

// Отвалообразователь
fbDumper(
	Dumper := stDumper,
	xStart := xStartDumper,
	xStop := fbEmergencyStopProcess.qxStateStopProcess OR xManualStopDumper,
	xReset := stCommands.cmdResetAll.qxSignal,
	eStage => eDumperStage,
	eStageToSCADA => eDumperStageToSCADA
);

// Конвейер
fbConveyor(
	Conveyor := stConveyor,
	xStart := xStartConveyor,
	xStop := fbEmergencyStopProcess.qxStateStopProcess OR xManualStopConveyor,
	xReset := stCommands.cmdResetAll.qxSignal,
	eStage => eConveyorStage,
	eStageToSCADA => eConveyorStageToSCADA
);

// Обновление состояния Emergency Stop
xStateEmergencyStop := stCommonSignals.fbEmergencyStopBtn.qxSignal
	OR stCommands.cmdEmergencyStopCommon.qxRisingEdge;

// Вызов всех ошибок в переменную готовности
xStateErrorCheckReady := NOT FC_Get_ErrorCommon(
	Bunker1 := stBunker[1],
	Bunker2 := stBunker[2],
	Bunker3 := stBunker[3],
	Conveyor := stConveyor,
	Dumper := stDumper
);

// ========================================
// СИМУЛЯЦИЯ
// ========================================

fbSimulation(
	xEnable := SIMULATION,
	xReset := ,
	Dumper := stDumper,
	Conveyor := stConveyor,
	Bunker := stBunker
);

// == РУЧНОЙ РЕЖИМ - ДИСТАНЦИЯ ==

// ОТВАЛООБРАЗОВАТЕЛЬ

// Запуск отвалообразователя в ручном режиме
IF 	stDumper.cmdSetModeManual OR stCommands.cmdSetToManual THEN stDumper.eStateRemote := E_StateRemote.Manual; END_IF;
IF 	stDumper.cmdSetModeAuto OR stCommands.cmdSetToAuto THEN stDumper.eStateRemote := E_StateRemote.Auto; END_IF;

IF 	stDumper.eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
	AND stDumper.cmdStartConveyor // Команда на запуск в ручном режиме
	AND eDumperStage <> E_StageWithPreStartAlarm.WORK // Не находится в статусе работы
	AND eDumperStage <> E_StageWithPreStartAlarm.STARTING AND eDumperStage <> E_StageWithPreStartAlarm.PRESTART_ALARM // Не в процессе запуска
	//AND NOT FC_Dumper_GetErrorCommon(Dumper:=stDumper) // Не имеет ошибок
	THEN
		xStartDumper := TRUE;
END_IF;
IF eDumperStage = E_StageWithPreStartAlarm.STARTING AND xStartDumper THEN xStartDumper := FALSE; END_IF;

// Остановка отвалообразователя в ручном режиме
IF 	stDumper.eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
	AND stDumper.cmdStopConveyor // Команда на остановку в ручном режиме
	AND	(eDumperStage = E_StageWithPreStartAlarm.WORK // В статусе работы
		OR eDumperStage = E_StageWithPreStartAlarm.STARTING 
		OR eDumperStage = E_StageWithPreStartAlarm.PRESTART_ALARM) // В процессе запуска
	THEN
		xManualStopDumper := TRUE;
END_IF;
IF eDumperStage <> E_StageWithPreStartAlarm.WORK AND xManualStopDumper THEN xManualStopDumper := FALSE; END_IF;

// СБОРНЫЙ КОНВЕЙЕР

// Запуск сборочного конвейера в ручном режиме
IF 	stConveyor.cmdSetModeManual OR stCommands.cmdSetToManual THEN stConveyor.eStateRemote := E_StateRemote.Manual; END_IF;
IF 	stConveyor.cmdSetModeAuto OR stCommands.cmdSetToAuto THEN stConveyor.eStateRemote := E_StateRemote.Auto; END_IF;

IF 	stConveyor.eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
	AND stConveyor.cmdStartConveyor // Команда на запуск в ручном режиме
	AND eConveyorStage <> E_StageWithPreStartAlarm.WORK // Не находится в статусе работы
	AND eConveyorStage <> E_StageWithPreStartAlarm.STARTING AND eConveyorStage <> E_StageWithPreStartAlarm.PRESTART_ALARM // Не в процессе запуска
	//AND NOT FC_Conveyor_GetErrorCommon(Conveyor:=stConveyor) // Не имеет ошибок
	THEN
		xStartConveyor := TRUE;
END_IF;
IF eConveyorStage = E_StageWithPreStartAlarm.STARTING AND xStartConveyor THEN xStartConveyor := FALSE; END_IF;

// Остановка сборочного конвейера в ручном режиме
IF 	stConveyor.eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
	AND stConveyor.cmdStopConveyor // Команда на остановку в ручном режиме
	AND	(eConveyorStage = E_StageWithPreStartAlarm.WORK // В статусе работы
		OR eConveyorStage = E_StageWithPreStartAlarm.STARTING 
		OR eConveyorStage = E_StageWithPreStartAlarm.PRESTART_ALARM) // В процессе запуска
	THEN
		xManualStopConveyor := TRUE;
END_IF;
IF eConveyorStage <> E_StageWithPreStartAlarm.WORK AND xManualStopConveyor THEN xManualStopConveyor := FALSE; END_IF;

// БУНКЕР

FOR i := 1 TO 3 DO
	// Запуск бункера в ручном режиме
	IF 	stBunker[i].cmdSetModeManual OR stCommands.cmdSetToManual THEN stBunker[i].eStateRemote := E_StateRemote.Manual; END_IF;
	IF 	stBunker[i].cmdSetModeAuto OR stCommands.cmdSetToAuto THEN stBunker[i].eStateRemote := E_StateRemote.Auto; END_IF;
	
	IF 	stBunker[i].eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
		AND stBunker[i].cmdStartFeeder // Команда на запуск в ручном режиме
		AND eBunkerStage[i] <> E_StageWithPreStartAlarm.WORK // Не находится в статусе работы
		AND eBunkerStage[i] <> E_StageWithPreStartAlarm.STARTING AND eBunkerStage[i] <> E_StageWithPreStartAlarm.PRESTART_ALARM // Не в процессе запуска
		//AND NOT FC_Bunker_GetErrorBunker(Bunker:=stBunker[i]) // Не имеет ошибок
		THEN
			xStartBunker[i] := TRUE;
	END_IF;
	IF eBunkerStage[i] = E_StageWithPreStartAlarm.STARTING AND xStartBunker[i] THEN xStartBunker[i] := FALSE; END_IF;

	// Остановка бункера в ручном режиме
	IF 	stBunker[i].eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
		AND stBunker[i].cmdStartFeeder // Команда на остановку в ручном режиме
		AND	(eBunkerStage[i] = E_StageWithPreStartAlarm.WORK // В статусе работы
			OR eBunkerStage[i] = E_StageWithPreStartAlarm.STARTING 
			OR eBunkerStage[i] = E_StageWithPreStartAlarm.PRESTART_ALARM) // В процессе запуска
		THEN
			xManualStopBunker[i] := TRUE;
	END_IF;
	IF eBunkerStage[i] <> E_StageWithPreStartAlarm.WORK AND xManualStopBunker[i] THEN xManualStopBunker[i] := FALSE; END_IF;
END_FOR;

// Процессы аварийных остановок в ручном режиме 
	// F FC_Dumper_GetErrorCommon(Dumper:=stDumper) THEN FC_Dumper_EmergencyStop(Dumper:=stDumper); END_IF;
	// F FC_Conveyor_GetErrorCommon(Conveyor:=stConveyor) THEN FC_Conveyor_EmergencyStop(Conveyor:=stConveyor); END_IF;
	//FOR i := 1 TO 3 DO 
		// IF FC_Bunker_GetErrorBunker(Bunker:=stBunker[i]) THEN FC_Bunker_EmergencyStop(Bunker:=stBunker[i]); END_IF;
	//END_FOR

// == АВТОМАТИЧЕСКИЙ РЕЖИМ ==
CASE AUTO_STEP OF

	IDLE: // Стадия ожидания задания

		// Удачная проверка
		IF stCommands.cmdStartCommon.qxRisingEdge // Получение команды оператора на ПУСК
		AND BUNKER_WORK_PRECENT_1 + BUNKER_WORK_PRECENT_2 + BUNKER_WORK_PRECENT_3 = 100 // Сумма всех коэффицентов равна 100
		AND xStateErrorCheckReady // Статус готовности к пуску (отсутствие ошибок)
		// Дополнительная проверка: не более одного бункера с нулевой пропорцией
		AND NOT ((BUNKER_WORK_PRECENT_1 = 0 AND BUNKER_WORK_PRECENT_2 = 0)
			OR (BUNKER_WORK_PRECENT_1 = 0 AND BUNKER_WORK_PRECENT_3 = 0)
			OR (BUNKER_WORK_PRECENT_2 = 0 AND BUNKER_WORK_PRECENT_3 = 0))
		THEN
			xStateErrorAcceptIdle := FALSE;
			AUTO_STEP := INIT;

		// Неудачная проверка
		ELSIF stCommands.cmdStartCommon.qxRisingEdge // Получение команды оператора на подтверждение задания шихты
		AND NOT (BUNKER_WORK_PRECENT_1 + BUNKER_WORK_PRECENT_2 + BUNKER_WORK_PRECENT_3 = 100 // Сумма всех коэффицентов НЕ равна 100
			AND NOT ((BUNKER_WORK_PRECENT_1 = 0 AND BUNKER_WORK_PRECENT_2 = 0)
				OR (BUNKER_WORK_PRECENT_1 = 0 AND BUNKER_WORK_PRECENT_3 = 0)
				OR (BUNKER_WORK_PRECENT_2 = 0 AND BUNKER_WORK_PRECENT_3 = 0))) // Или более одного бункера с нулевой пропорцией
		THEN
			xStateErrorAcceptIdle := TRUE; // Флаг ошибки задания
		END_IF;

	INIT : // Первоначальный расчёт работы вибропитателей
		// АЛГОРИТМ расчёта производительности
		// TODO: Добавить расчёт производительности вибропитателей
		AUTO_STEP := START_DUMPER;

	START_DUMPER :
		IF eDumperStage <> E_StageWithPreStartAlarm.WORK THEN // Если отвалообразователь не запущен
			xStartDumper := TRUE; // Команда запуска отвалообразователя
		ELSE
			xStartDumper := FALSE; // Сброс команды
			AUTO_STEP := START_CONV; // Отвалообразователь запущен, переход к следующему шагу
		END_IF;

	START_CONV:
		IF eConveyorStage <> E_StageWithPreStartAlarm.WORK THEN // Если конвейер не запущен
			xStartConveyor := TRUE; // Команда запуска конвейера
		ELSE
			xStartConveyor := FALSE; // Сброс команды
			AUTO_STEP := START_VIBFEEDER; // Конвейер запущен, переход к следующему шагу
		END_IF;

	START_VIBFEEDER:
		// Последовательный запуск бункеров: 1 → 2 → 3 (пропускаем бункеры с нулевой пропорцией)
		IF BUNKER_WORK_PRECENT_1 > 0 AND eBunkerStage[1] <> E_StageWithPreStartAlarm.WORK THEN
			// Запускаем бункер 1 (если пропорция > 0)
			xStartBunker[1] := TRUE;
		ELSIF BUNKER_WORK_PRECENT_2 > 0 AND eBunkerStage[2] <> E_StageWithPreStartAlarm.WORK THEN
			// Бункер 1 запущен или пропущен, запускаем бункер 2 (если пропорция > 0)
			xStartBunker[1] := FALSE;
			xStartBunker[2] := TRUE;
		ELSIF BUNKER_WORK_PRECENT_3 > 0 AND eBunkerStage[3] <> E_StageWithPreStartAlarm.WORK THEN
			// Бункеры 1 и 2 запущены или пропущены, запускаем бункер 3 (если пропорция > 0)
			xStartBunker[2] := FALSE;
			xStartBunker[3] := TRUE;
		ELSE
			// Все активные бункеры запущены
			xStartBunker[1] := FALSE;
			xStartBunker[2] := FALSE;
			xStartBunker[3] := FALSE;
			AUTO_STEP := WORK; // Переход в работу, PID активируется
		END_IF;

	WORK:
		// Нормальная работа
		xStateAutoWorking := TRUE;

		// === Расчёт актуальных пропорций бункеров ===
		// 1. Извлечь вес каждого бункера из кумулятивных показаний
		rWeight3 := stBunker[3].rWeightUnderBunker;
		rWeight2 := stBunker[2].rWeightUnderBunker - stBunker[3].rWeightUnderBunker;
		rWeight1 := stBunker[1].rWeightUnderBunker - stBunker[2].rWeightUnderBunker;

		// 2. Зажать отрицательные значения (ошибки датчиков)
		IF rWeight1 < 0.0 THEN rWeight1 := 0.0; END_IF
		IF rWeight2 < 0.0 THEN rWeight2 := 0.0; END_IF
		IF rWeight3 < 0.0 THEN rWeight3 := 0.0; END_IF

		// 3. Суммировать вес только активных бункеров
		rTotalWeightActive := 0.0;
		IF BUNKER_WORK_PRECENT_1 > 0.0 THEN
			rTotalWeightActive := rTotalWeightActive + rWeight1;
		END_IF
		IF BUNKER_WORK_PRECENT_2 > 0.0 THEN
			rTotalWeightActive := rTotalWeightActive + rWeight2;
		END_IF
		IF BUNKER_WORK_PRECENT_3 > 0.0 THEN
			rTotalWeightActive := rTotalWeightActive + rWeight3;
		END_IF

		// 4. Рассчитать пропорции
		IF rTotalWeightActive > 0.5 THEN  // Защита от деления на ноль
			// Активные бункеры
			IF BUNKER_WORK_PRECENT_1 > 0.0 THEN
				stBunker[1].rProportionActual := rWeight1 / rTotalWeightActive;
			ELSE
				stBunker[1].rProportionActual := 0.0;
			END_IF

			IF BUNKER_WORK_PRECENT_2 > 0.0 THEN
				stBunker[2].rProportionActual := rWeight2 / rTotalWeightActive;
			ELSE
				stBunker[2].rProportionActual := 0.0;
			END_IF

			IF BUNKER_WORK_PRECENT_3 > 0.0 THEN
				stBunker[3].rProportionActual := rWeight3 / rTotalWeightActive;
			ELSE
				stBunker[3].rProportionActual := 0.0;
			END_IF
		ELSE
			// Недостаточный вес - обнулить все пропорции
			stBunker[1].rProportionActual := 0.0;
			stBunker[2].rProportionActual := 0.0;
			stBunker[3].rProportionActual := 0.0;
		END_IF;

		// Обработка команд останова
		IF stCommands.cmdStopCommon.qxRisingEdge OR xStateEmergencyStop THEN
			xStartDumper := FALSE;
			xStartConveyor := FALSE;
			xStartBunker[1] := FALSE;
			xStartBunker[2] := FALSE;
			xStartBunker[3] := FALSE;
			AUTO_STEP := END_REPORT;
		END_IF;

	END_REPORT:
		// Формирование отчёта
		// TODO: Добавить формирование отчёта
		IF eDumperStage = E_StageWithPreStartAlarm.IDLE
		   AND eConveyorStage = E_StageWithPreStartAlarm.IDLE
		   AND (BUNKER_WORK_PRECENT_1 = 0 OR eBunkerStage[1] = E_StageWithPreStartAlarm.IDLE)
		   AND (BUNKER_WORK_PRECENT_2 = 0 OR eBunkerStage[2] = E_StageWithPreStartAlarm.IDLE)
		   AND (BUNKER_WORK_PRECENT_3 = 0 OR eBunkerStage[3] = E_StageWithPreStartAlarm.IDLE)
		THEN
			AUTO_STEP := IDLE; // Возврат в ожидание
		END_IF;

	ERROR:
		// Обработка ошибок
		// Сброс всех команд запуска
		xStartDumper := FALSE;
		xStartConveyor := FALSE;
		xStartBunker[1] := FALSE;
		xStartBunker[2] := FALSE;
		xStartBunker[3] := FALSE;

		// Переход в IDLE при сбросе ошибки
		IF stCommands.cmdResetAll.qxRisingEdge AND xStateErrorCheckReady THEN
			AUTO_STEP := IDLE;
		END_IF;

END_CASE;

fbProportionPid(
	xEnable:= AUTO_STEP = WORK, 
	xReset:= stCommands.cmdResetAll.qxRisingEdge, 
	
	rProportionTarget_1:= BUNKER_WORK_PRECENT_1, 
	rProportionTarget_2:= BUNKER_WORK_PRECENT_2, 
	rProportionTarget_3:= BUNKER_WORK_PRECENT_3, 
	
	rProportionActual_1:= stBunker[1].rProportionActual, 
	rProportionActual_2:= stBunker[1].rProportionActual, 
	rProportionActual_3:= stBunker[1].rProportionActual,
	
	rFrequency_Min:= 5, 
	rFrequency_Max:= 50, 
	rFrequency_TargetSum:= 90, 
	rDeltaTime:= 0.5, 
);


// Передача частоты ПИД регулятора 
stBunker[1].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_1;
stBunker[2].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_2;
stBunker[3].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_3;


(*fbEmergencyStopProcess(
	ixEnable:= stCommands.cmdEmergencyStopCommon.qxSignal 
		OR ( FC_Get_ErrorCommon(
			Bunker1:= stBunker[1], 
			Bunker2:= stBunker[2], 
			Bunker3:= stBunker[3], 
			Conveyor:= stConveyor, 
			Dumper:= stDumper,)
	
			AND (AUTO_STEP = START_DUMPER OR AUTO_STEP = START_CONV OR AUTO_STEP = START_VIBFEEDER OR AUTO_STEP = WORK)),
			
	ixReset:= stCommands.cmdResetAll.qxSignal,
	Bunker:= stBunker, 
	Dumper:= stDumper, 
	Conveyor:= stConveyor, 
	
	qxStateStopProcess=> , 
	qxStateEmergencyStop=> , 
	qnCurrentStage=> );*)

// Переход в ERROR при возникновении ошибок
IF fbEmergencyStopProcess.qxStateStopProcess THEN
	AUTO_STEP := ERROR;
	xStateAutoWorking := FALSE;
END_IF;

// Возврат состояния после команды RESET
IF stCommands.cmdResetAll.qxRisingEdge THEN
	AUTO_STEP := IDLE;
END_IF

// ========================================
// MODBUS РЕГИСТРЫ
// ========================================

// === HOLDING РЕГИСТРЫ (SCADA → PLC) - Чтение уставок ===

// Общие системные переменные и уставки (0-29)
// Регистры 0-1: BOOL флаги команд
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 0, xValue => stCommands.cmdStartCommon.ixSignal);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 1, xValue => stCommands.cmdStopCommon.ixSignal);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 2, xValue => stCommands.cmdEmergencyStopCommon.ixSignal);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 3, xValue => stCommands.cmdResetAll.ixSignal);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 4, xValue => stCommands.cmdSetToAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 5, xValue => stCommands.cmdSetToManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 6, xValue => stCommands.cmdSetToRepair);

// Уставки ЧРП (30-59)
// Регистры 30-31: BOOL флаги ЧРП
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 30, iBitIndex := 0, xValue => VFD_SMOOTH_SET_FREQUENCY);

FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 32, rValue => VFD_FREQUENCY_MAX);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 34, rValue => VFD_FREQUENCY_STEP);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 36, rValue => VFD_FREQUENCY_INACCURANCY);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 38, rValue => VFD_FREQUENCY_SYNC_TOLERANCE);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 40, rValue => MOTOR_FREQUENCY_CONVEYOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 42, rValue => MOTOR_FREQUENCY_DUMPER_CONVEYOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 44, rValue => MOTOR_FREQUENCY_DUMPER_ROTATION);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 46, rValue => CONVEYOR_DEAFULT_SPEED);

// Уставки бункеров (60-89)
// Регистры 60-61: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 62, rValue => BUNKER_WORK_PRECENT_1);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 64, rValue => BUNKER_WORK_PRECENT_2);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 66, rValue => BUNKER_WORK_PRECENT_3);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 68, rValue => BUNKER_MINIMAL_WEIGHT);

// Уставки аварийных значений - Температура (90-119)
// Регистры 90-91: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 92, rValue => MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 94, rValue => MOTOR_VIBFEEDER_TEMP_POINTS.L_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 96, rValue => MOTOR_VIBFEEDER_TEMP_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 98, rValue => MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value);

// Уставки аварийных значений - Ток (120-149)
// Регистры 120-121: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 122, rValue => MOTOR_VIBFEEDER_CURRENT_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 124, rValue => MOTOR_VIBFEEDER_CURRENT_POINTS.L_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 126, rValue => MOTOR_VIBFEEDER_CURRENT_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 128, rValue => MOTOR_VIBFEEDER_CURRENT_POINTS.HH_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 130, rValue => MOTOR_VIBRATOR_CURRENT_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 132, rValue => MOTOR_VIBRATOR_CURRENT_POINTS.L_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 134, rValue => MOTOR_VIBRATOR_CURRENT_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 136, rValue => MOTOR_VIBRATOR_CURRENT_POINTS.HH_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 138, rValue => MOTOR_CONVEYOR_CURRENT_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 140, rValue => MOTOR_CONVEYOR_CURRENT_POINTS.L_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 142, rValue => MOTOR_CONVEYOR_CURRENT_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 144, rValue => MOTOR_CONVEYOR_CURRENT_POINTS.HH_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 146, rValue => MOTOR_ROTATION_CURRENT_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 148, rValue => MOTOR_ROTATION_CURRENT_POINTS.L_Value);

// Уставки времени (150-179)
// Регистры 150-151: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 152, rValue => MOTOR_ROTATION_CURRENT_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 154, rValue => MOTOR_ROTATION_CURRENT_POINTS.HH_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 156, rValue => rTempTime);
VIBRATOR_SETTINGS.TIME_ACTIVE := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 158, rValue => rTempTime);
VIBRATOR_SETTINGS.TIME_PAUSE_VIBRATOR := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 160, rValue => rTempTime);
VIBRATOR_SETTINGS.TIME_PAUSE_FB := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 162, rValue => rTempTime);
PNEUMO_SETTINGS.TIME_ACTIVE := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 164, rValue => rTempTime);
PNEUMO_SETTINGS.TIME_PAUSE_VIBRATOR := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 166, rValue => rTempTime);
PNEUMO_SETTINGS.TIME_PAUSE_FB := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 168, rValue => rTempTime);
TIME_WAITING_FEEDBACK := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 170, rValue => rTempTime);
PNEUMATIC_COLLAPSE_TIME := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 172, rValue => rTempTime);
DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 174, rValue => rTempTime);
DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 176, rValue => rTempTime);
DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 178, rValue => rTempTime);
DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE := REAL_TO_TIME(rTempTime * 1000);

// Уставки времени (продолжение) (180-209)
// Регистры 180-181: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 182, rValue => rTempTime);
CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 184, rValue => rTempTime);
CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 186, rValue => rTempTime);
CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 188, rValue => rTempTime);
CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE := REAL_TO_TIME(rTempTime * 1000);

// Команды - Отвалообразователь (210-239)
// Регистры 210-211: BOOL флаги управления отвалообразователем
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 0, xValue => stDumper.cmdStartConveyor);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 1, xValue => stDumper.cmdStopConveyor);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 2, xValue => stDumper.cmdEmergencyStop);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 3, xValue => stDumper.cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 8, xValue => stDumper.cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 9, xValue => stDumper.cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 10, xValue => stDumper.cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 11, xValue => stDumper.cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 12, xValue => stDumper.cmdBuildCircuitOff);


FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 0, xValue => stDumper.cmdTurnLeft);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 1, xValue => stDumper.cmdTurnRight);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 2, xValue => stDumper.cmdStopRotation);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 11, xValue => stDumper.cmdBuildCircuitOnRotation);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 12, xValue => stDumper.cmdBuildCircuitOffRotation);

// Настройка - Отвалообразователь (210-239)
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 212, iBitIndex := 0, xValue => DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.OPTION_ENABLE);

// Команды - Конвейер (240-269)
// Регистры 240-241: BOOL флаги управления конвейером
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 0, xValue => stConveyor.cmdStartConveyor);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 1, xValue => stConveyor.cmdStopConveyor);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 2, xValue => stConveyor.cmdEmergencyStop);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 3, xValue => stConveyor.cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 8, xValue => stConveyor.cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 9, xValue => stConveyor.cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 10, xValue => stConveyor.cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 11, xValue => stConveyor.cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 12, xValue => stConveyor.cmdBuildCircuitOff);

// Настройка - Конвейер (240-269)
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 242, iBitIndex := 0, xValue => CONVEYOR_PRESTART_ALARM_SETTINGS.OPTION_ENABLE);

// Команды - Бункер 1 (270-299)
// Регистры 270-271: BOOL флаги управления бункером 1
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 0, xValue => stBunker[1].cmdStartFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 1, xValue => stBunker[1].cmdStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 2, xValue => stBunker[1].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 3, xValue => stBunker[1].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 4, xValue => stBunker[1].cmdAddVib1);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 5, xValue => stBunker[1].cmdAddVib2);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 6, xValue => stBunker[1].cmdAddVib3);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 7, xValue => stBunker[1].cmdAddVib4);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 8, xValue => stBunker[1].cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 9, xValue => stBunker[1].cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 10, xValue => stBunker[1].cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 11, xValue => stBunker[1].cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 12, xValue => stBunker[1].cmdBuildCircuitOff);

FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 278, rValue => BUNKER_1_FREQ_VIBRATOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 282, rValue => BUNKER_1_FREQ_VIBFEEDER);

// Команды - Бункер 2 (300-329)
// Регистры 300-301: BOOL флаги управления бункером 2
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 0, xValue => stBunker[2].cmdStartFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 1, xValue => stBunker[2].cmdStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 2, xValue => stBunker[2].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 3, xValue => stBunker[2].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 4, xValue => stBunker[2].cmdAddVib1);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 5, xValue => stBunker[2].cmdAddVib2);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 6, xValue => stBunker[2].cmdAddVib3);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 7, xValue => stBunker[2].cmdAddVib4);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 8, xValue => stBunker[2].cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 9, xValue => stBunker[2].cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 10, xValue => stBunker[2].cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 11, xValue => stBunker[2].cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 12, xValue => stBunker[2].cmdBuildCircuitOff);

FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 308, rValue => BUNKER_2_FREQ_VIBRATOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 312, rValue => BUNKER_2_FREQ_VIBFEEDER);

// Команды - Бункер 3 (330-359)
// Регистры 330-331: BOOL флаги управления бункером 3
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 0, xValue => stBunker[3].cmdStartFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 1, xValue => stBunker[3].cmdStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 2, xValue => stBunker[3].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 3, xValue => stBunker[3].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 4, xValue => stBunker[3].cmdAddVib1);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 5, xValue => stBunker[3].cmdAddVib2);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 6, xValue => stBunker[3].cmdAddVib3);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 7, xValue => stBunker[3].cmdAddVib4);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 8, xValue => stBunker[3].cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 9, xValue => stBunker[3].cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 10, xValue => stBunker[3].cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 11, xValue => stBunker[3].cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 12, xValue => stBunker[3].cmdBuildCircuitOff);

FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 338, rValue => BUNKER_3_FREQ_VIBRATOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 342, rValue => BUNKER_3_FREQ_VIBFEEDER);

// === INPUT РЕГИСТРЫ (PLC → SCADA) - Запись данных мониторинга ===

// Общие системные статусы (0-29)
// Регистры 0-1: BOOL флаги статусов системы
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 0, xValue := xStateAutoWorking);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 1, xValue := xStateEmergencyStop);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 2, xValue := xStateErrorCheckReady);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 3, xValue := xStateErrorAcceptIdle);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 4, xValue := stCommonSignals.fbEmergencyStopBtn.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 5, xValue := stCommonSignals.fbRemoteModeBtn.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 6, xValue := stCommonSignals.fbRealyCurrentControl.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 7, xValue := stCommonSignals.fbQF1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 8, xValue := stCommonSignals.fb9QF1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 9, xValue := stCommonSignals.fb10QF1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 10, xValue := stCommonSignals.fb11QF1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 11, xValue := stCommonSignals.qx6KM1);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 12, xValue := SIMULATION);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 2, rValue := ICUR_PRECENT);

// Бункер 1 (30-89)
// Регистры 30-31: BOOL флаги статусов бункера 1
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 0, xValue := stBunker[1].xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 1, xValue := stBunker[1].xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 2, xValue := stBunker[1].fbStateHatch.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 3, xValue := stBunker[1].qxLightRed);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 4, xValue := stBunker[1].qxLightYellow);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 5, xValue := stBunker[1].qxLightGreen);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 6, xValue := stBunker[1].fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 7, xValue := stBunker[1].fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 8, xValue := stBunker[1].fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 12, xValue := stBunker[1].xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 13, xValue := stBunker[1].xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 14, xValue := stBunker[1].xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 32, rValue := stBunker[1].rWeight);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 34, rValue := stBunker[1].rProportionActual);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 36, rValue := stBunker[1].rMotorVibFeederCommonFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 38, rValue := stBunker[1].cmdDumpingPrecent);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 40, rValue := stBunker[1].MotorVibrator[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 42, rValue := stBunker[1].MotorVibrator[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 44, rValue := stBunker[1].MotorVibrator[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 46, rValue := stBunker[1].MotorVibrator[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 48, rValue := stBunker[1].MotorVibrator[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 50, rValue := stBunker[1].MotorVibrator[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 52, rValue := stBunker[1].MotorVibrator[3].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 54, rValue := stBunker[1].MotorVibrator[3].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 56, rValue := stBunker[1].MotorVibrator[3].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 58, rValue := stBunker[1].MotorVibrator[4].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 60, rValue := stBunker[1].MotorVibrator[4].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 62, rValue := stBunker[1].MotorVibrator[4].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 64, rValue := stBunker[1].MotorVibFeeder[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 66, rValue := stBunker[1].MotorVibFeeder[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 68, rValue := stBunker[1].MotorVibFeeder[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 70, rValue := stBunker[1].MotorVibFeeder[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 72, rValue := stBunker[1].MotorVibFeeder[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 74, rValue := stBunker[1].MotorVibFeeder[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 76, rValue := stBunker[1].MotorVibFeeder[1].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 78, rValue := stBunker[1].MotorVibFeeder[1].rTempBearing[2]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 80, rValue := stBunker[1].MotorVibFeeder[2].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 82, rValue := stBunker[1].MotorVibFeeder[2].rTempBearing[2]);

GLOBAL.awModbusInputRegisters[84] := TO_WORD(eBunkerStageToSCADA[1]);

// Бункер 2 (90-149)
// Регистры 90-91: BOOL флаги статусов бункера 2
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 0, xValue := stBunker[2].xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 1, xValue := stBunker[2].xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 2, xValue := stBunker[2].fbStateHatch.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 3, xValue := stBunker[2].qxLightRed);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 4, xValue := stBunker[2].qxLightYellow);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 5, xValue := stBunker[2].qxLightGreen);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 6, xValue := stBunker[2].fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 7, xValue := stBunker[2].fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 8, xValue := stBunker[2].fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 12, xValue := stBunker[2].xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 13, xValue := stBunker[2].xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 14, xValue := stBunker[2].xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 92, rValue := stBunker[2].rWeight);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 94, rValue := stBunker[2].rProportionActual);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 96, rValue := stBunker[2].rMotorVibFeederCommonFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 98, rValue := stBunker[2].cmdDumpingPrecent);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 100, rValue := stBunker[2].MotorVibrator[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 102, rValue := stBunker[2].MotorVibrator[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 104, rValue := stBunker[2].MotorVibrator[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 106, rValue := stBunker[2].MotorVibrator[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 108, rValue := stBunker[2].MotorVibrator[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 110, rValue := stBunker[2].MotorVibrator[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 112, rValue := stBunker[2].MotorVibrator[3].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 114, rValue := stBunker[2].MotorVibrator[3].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 116, rValue := stBunker[2].MotorVibrator[3].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 118, rValue := stBunker[2].MotorVibrator[4].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 120, rValue := stBunker[2].MotorVibrator[4].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 122, rValue := stBunker[2].MotorVibrator[4].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 124, rValue := stBunker[2].MotorVibFeeder[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 126, rValue := stBunker[2].MotorVibFeeder[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 128, rValue := stBunker[2].MotorVibFeeder[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 130, rValue := stBunker[2].MotorVibFeeder[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 132, rValue := stBunker[2].MotorVibFeeder[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 134, rValue := stBunker[2].MotorVibFeeder[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 136, rValue := stBunker[2].MotorVibFeeder[1].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 138, rValue := stBunker[2].MotorVibFeeder[1].rTempBearing[2]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 140, rValue := stBunker[2].MotorVibFeeder[2].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 142, rValue := stBunker[2].MotorVibFeeder[2].rTempBearing[2]);

GLOBAL.awModbusInputRegisters[144] := TO_WORD(eBunkerStageToSCADA[2]);

// Бункер 3 (150-209)
// Регистры 150-151: BOOL флаги статусов бункера 3
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 0, xValue := stBunker[3].xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 1, xValue := stBunker[3].xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 2, xValue := stBunker[3].fbStateHatch.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 3, xValue := stBunker[3].qxLightRed);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 4, xValue := stBunker[3].qxLightYellow);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 5, xValue := stBunker[3].qxLightGreen);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 6, xValue := stBunker[3].fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 7, xValue := stBunker[3].fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 8, xValue := stBunker[3].fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 12, xValue := stBunker[3].xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 13, xValue := stBunker[3].xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 14, xValue := stBunker[3].xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 152, rValue := stBunker[3].rWeight);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 154, rValue := stBunker[3].rProportionActual);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 156, rValue := stBunker[3].rMotorVibFeederCommonFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 158, rValue := stBunker[3].cmdDumpingPrecent);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 160, rValue := stBunker[3].MotorVibrator[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 162, rValue := stBunker[3].MotorVibrator[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 164, rValue := stBunker[3].MotorVibrator[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 166, rValue := stBunker[3].MotorVibrator[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 168, rValue := stBunker[3].MotorVibrator[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 170, rValue := stBunker[3].MotorVibrator[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 172, rValue := stBunker[3].MotorVibrator[3].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 174, rValue := stBunker[3].MotorVibrator[3].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 176, rValue := stBunker[3].MotorVibrator[3].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 178, rValue := stBunker[3].MotorVibrator[4].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 180, rValue := stBunker[3].MotorVibrator[4].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 182, rValue := stBunker[3].MotorVibrator[4].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 184, rValue := stBunker[3].MotorVibFeeder[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 186, rValue := stBunker[3].MotorVibFeeder[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 188, rValue := stBunker[3].MotorVibFeeder[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 190, rValue := stBunker[3].MotorVibFeeder[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 192, rValue := stBunker[3].MotorVibFeeder[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 194, rValue := stBunker[3].MotorVibFeeder[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 196, rValue := stBunker[3].MotorVibFeeder[1].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 198, rValue := stBunker[3].MotorVibFeeder[1].rTempBearing[2]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 200, rValue := stBunker[3].MotorVibFeeder[2].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 202, rValue := stBunker[3].MotorVibFeeder[2].rTempBearing[2]);

GLOBAL.awModbusInputRegisters[204] := TO_WORD(eBunkerStageToSCADA[3]);

// Отвалообразователь - Конвейер (210-239)
// Регистры 210-211: BOOL флаги статусов отвалообразователя
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 0, xValue := stDumper.xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 1, xValue := stDumper.xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 2, xValue := stDumper.xStateEnable);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 3, xValue := stDumper.xStateStarting);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 4, xValue := stDumper.fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 5, xValue := stDumper.fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 6, xValue := stDumper.fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 7, xValue := stDumper.fbBtnRemoteMode.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 8, xValue := stDumper.xHLA);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 9, xValue := stDumper.xSoundAlarm);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 10, xValue := stDumper.fbZQAlarm[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 11, xValue := stDumper.fbZQAlarm[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 12, xValue := stDumper.fbZQAlarm[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 13, xValue := stDumper.fbZQAlarm[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 14, xValue := stDumper.fbZQWarning[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 15, xValue := stDumper.fbZQWarning[2].qxSignal);

// Регистр 211: дополнительные сигналы обратной связи отвалообразователя
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 0, xValue := stDumper.fbZQWarning[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 1, xValue := stDumper.fbZQWarning[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 2, xValue := stDumper.fbHQ_IsOk[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 3, xValue := stDumper.fbHQ_IsOk[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 4, xValue := stDumper.fbHQ_IsOk[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 5, xValue := stDumper.fbHQ_IsOk[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 6, xValue := stDumper.fbSQ_IsOk[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 7, xValue := stDumper.fbSQ_IsOk[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 8, xValue := stDumper.fbGS1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 9, xValue := stDumper.fbQR[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 10, xValue := stDumper.fbQR[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 11, xValue := stDumper.fbYS1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 12, xValue := stDumper.xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 13, xValue := stDumper.xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 14, xValue := stDumper.xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 212, rValue := stDumper.MotorConveyor[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 214, rValue := stDumper.MotorConveyor[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 216, rValue := stDumper.MotorConveyor[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 218, rValue := stDumper.MotorConveyor[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 220, rValue := stDumper.MotorConveyor[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 222, rValue := stDumper.MotorConveyor[2].VFD.wMotorCurrent.rTag);

GLOBAL.awModbusInputRegisters[230] := TO_WORD(eDumperStageToSCADA);

// Отвалообразователь - Поворот (240-269)
// Регистры 240-241: BOOL флаги управления поворотом
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 240, iBitIndex := 0, xValue := stDumper.fbBtnTurnLeft.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 240, iBitIndex := 1, xValue := stDumper.fbBtnTurnRight.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 240, iBitIndex := 2, xValue := stDumper.fbEndSwitchRight.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 240, iBitIndex := 3, xValue := stDumper.fbEndSwitchLeft.qxSignal);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 242, rValue := stDumper.MotorRotation[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 244, rValue := stDumper.MotorRotation[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 246, rValue := stDumper.MotorRotation[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 248, rValue := stDumper.MotorRotation[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 250, rValue := stDumper.MotorRotation[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 252, rValue := stDumper.MotorRotation[2].VFD.wMotorCurrent.rTag);

// Конвейер (270-299)
// Регистры 270-271: BOOL флаги статусов конвейера
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 0, xValue := stConveyor.xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 1, xValue := stConveyor.xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 2, xValue := stConveyor.xStateEnable);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 3, xValue := stConveyor.xStateStarting);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 4, xValue := stConveyor.fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 5, xValue := stConveyor.fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 6, xValue := stConveyor.fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 7, xValue := stConveyor.xHLA);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 8, xValue := stConveyor.xSoundAlarm);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 9, xValue := stConveyor.fbYE1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 10, xValue := stConveyor.fbZQAlarm[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 11, xValue := stConveyor.fbZQAlarm[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 12, xValue := stConveyor.fbZQAlarm[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 13, xValue := stConveyor.fbZQAlarm[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 14, xValue := stConveyor.fbZQWarning[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 15, xValue := stConveyor.fbZQWarning[2].qxSignal);

// Регистр 271: дополнительные сигналы обратной связи конвейера
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 0, xValue := stConveyor.fbZQWarning[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 1, xValue := stConveyor.fbZQWarning[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 2, xValue := stConveyor.fbHQ_IsOk[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 3, xValue := stConveyor.fbHQ_IsOk[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 4, xValue := stConveyor.fbHQ_IsOk[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 5, xValue := stConveyor.fbHQ_IsOk[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 6, xValue := stConveyor.fbSQ_IsOk[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 7, xValue := stConveyor.fbSQ_IsOk[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 8, xValue := stConveyor.fbGS1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 9, xValue := stConveyor.fbQR[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 10, xValue := stConveyor.fbQR[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 11, xValue := stConveyor.fbYS1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 12, xValue := stConveyor.xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 13, xValue := stConveyor.xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 14, xValue := stConveyor.xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 272, rValue := stConveyor.MotorConveyor[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 274, rValue := stConveyor.MotorConveyor[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 276, rValue := stConveyor.MotorConveyor[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 278, rValue := stConveyor.MotorConveyor[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 280, rValue := stConveyor.MotorConveyor[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 282, rValue := stConveyor.MotorConveyor[2].VFD.wMotorCurrent.rTag);

GLOBAL.awModbusInputRegisters[290] := TO_WORD(eConveyorStageToSCADA);
END_PROGRAM