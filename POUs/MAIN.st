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

	// Вспомогательные переменные
	i : INT; // Счётчик для циклов
	awModbusRegisters : ARRAY [0..99] OF WORD; // Массив Modbus регистров

	// Временные переменные для расчёта пропорций бункеров
	rWeight1, rWeight2, rWeight3 : REAL; // Индивидуальный вес каждого бункера
	rTotalWeightActive : REAL; // Суммарный вес активных бункеров

	// Начальные частоты вибропитателей (рассчитываются в INIT)
	rInitialFrequency_1 : REAL := 0.0; // Начальная частота бункера 1, Гц
	rInitialFrequency_2 : REAL := 0.0; // Начальная частота бункера 2, Гц
	rInitialFrequency_3 : REAL := 0.0; // Начальная частота бункера 3, Гц

	// Временная переменная для конвертации TIME из Modbus (секунды)
	rTempTime : REAL;
	
	ton_AutoTimer : TON; // Таймер автоматического режима

	nBunkerStartStep : INT := 0; // Подшаг последовательного запуска бункеров (0=бункер3, 1=задержка, 2=бункер2, 3=задержка, 4=бункер1, 5=готово)

	xAutoStopping : BOOL; // Процесс остановки
	xAutoEmergencyStopping : BOOL; // Процесс аварийной остановки
	nStopSubstage : INT := 0; // Подшаг последовательной остановки (0=бункер1, 1=задержка, 2=бункер2, 3=задержка, 4=бункер3, 5=задержка, 6=конвейер, 7=задержка, 8=отвалообразователь, 9=готово)
END_VAR

stCommonSignals.qx6KM1 := TRUE;

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
	irManualFrequencyVibrator := BUNKER_1_FREQ_VIBRATOR,
	eStage => eBunkerStage[1],
	eStageToSCADA => eBunkerStageToSCADA[1]
);

fbBunker[2](
	Bunker := stBunker[2],
	xStart := xStartBunker[2],
	xStop := fbEmergencyStopProcess.qxStateStopProcess OR xManualStopBunker[2],
	xReset := stCommands.cmdResetAll.qxSignal,
	irManualFrequency := BUNKER_2_FREQ_VIBFEEDER,
	irManualFrequencyVibrator := BUNKER_2_FREQ_VIBRATOR,
	eStage => eBunkerStage[2],
	eStageToSCADA => eBunkerStageToSCADA[2]
);

fbBunker[3](
	Bunker := stBunker[3],
	xStart := xStartBunker[3],
	xStop := fbEmergencyStopProcess.qxStateStopProcess OR xManualStopBunker[3],
	xReset := stCommands.cmdResetAll.qxSignal,
	irManualFrequency := BUNKER_3_FREQ_VIBFEEDER,
	irManualFrequencyVibrator := BUNKER_3_FREQ_VIBRATOR,
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
		xManualStopDumper := FALSE;
		xStartDumper := TRUE;
END_IF;

// Остановка отвалообразователя в ручном режиме
IF 	stDumper.eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
	AND stDumper.cmdStopConveyor // Команда на остановку в ручном режиме
	AND	(eDumperStage = E_StageWithPreStartAlarm.WORK // В статусе работы
		OR eDumperStage = E_StageWithPreStartAlarm.STARTING 
		OR eDumperStage = E_StageWithPreStartAlarm.PRESTART_ALARM) // В процессе запуска
	THEN
		xStartDumper := FALSE;
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
		xManualStopConveyor := FALSE;
END_IF;

// Остановка сборочного конвейера в ручном режиме
IF 	stConveyor.eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
	AND stConveyor.cmdStopConveyor // Команда на остановку в ручном режиме
	AND	(eConveyorStage = E_StageWithPreStartAlarm.WORK // В статусе работы
		OR eConveyorStage = E_StageWithPreStartAlarm.STARTING 
		OR eConveyorStage = E_StageWithPreStartAlarm.PRESTART_ALARM) // В процессе запуска
	THEN
		xStartConveyor := FALSE;
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
			xManualStopBunker[i] := FALSE;
			xStartBunker[i] := TRUE;
	END_IF;
IF (eBunkerStage[i] = E_StageWithPreStartAlarm.STARTING OR eBunkerStage[i] = E_StageWithPreStartAlarm.PRESTART_ALARM) AND xStartBunker[i] THEN xStartBunker[i] := FALSE; END_IF;

	// Остановка бункера в ручном режиме
	IF 	stBunker[i].eStateRemote = E_StateRemote.Manual // Находится в режиме Manual
		AND stBunker[i].cmdStopFeeder // Команда на остановку в ручном режиме
		THEN
			xStartBunker[i] := FALSE;
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
ton_AutoTimer(PT:=T#10S);

// Проверка готовности системы к автоматическому пуску
xStateErrorCheckReady :=
	NOT xAutoStopping AND NOT xAutoEmergencyStopping
	AND stBunker[1].eStateRemote = E_StateRemote.Auto
	AND stBunker[2].eStateRemote = E_StateRemote.Auto
	AND stBunker[3].eStateRemote = E_StateRemote.Auto
	AND stDumper.eStateRemote = E_StateRemote.Auto
	AND stConveyor.eStateRemote = E_StateRemote.Auto
	AND NOT stBunker[1].xStateFailure
	AND NOT stBunker[2].xStateFailure
	AND NOT stBunker[3].xStateFailure
	AND NOT stDumper.xStateFailure
	AND NOT stConveyor.xStateFailure
	AND BUNKER_WORK_PRECENT_1 + BUNKER_WORK_PRECENT_2 + BUNKER_WORK_PRECENT_3 = 100;

CASE AUTO_STEP OF

	IDLE: // Стадия ожидания задания

	IF stCommands.cmdStartCommon.qxSignal AND xStateErrorCheckReady THEN
		AUTO_STEP := INIT;
	END_IF;

	INIT : // Первоначальный расчёт работы вибропитателей
		// Расчёт начальных частот на основе заданных пропорций
		// Формула: FreqBase_i = TargetSum * (Proportion_i / 100)

		rInitialFrequency_1 := BUNKER_VIBFEEDER_FREQUENCY_TARGET_SUM * (BUNKER_WORK_PRECENT_1 / 100.0);
		rInitialFrequency_2 := BUNKER_VIBFEEDER_FREQUENCY_TARGET_SUM * (BUNKER_WORK_PRECENT_2 / 100.0);
		rInitialFrequency_3 := BUNKER_VIBFEEDER_FREQUENCY_TARGET_SUM * (BUNKER_WORK_PRECENT_3 / 100.0);

		// Установка начальных частот в структуры бункеров
		stBunker[1].rMotorVibFeederCommonFrequency := rInitialFrequency_1;
		stBunker[2].rMotorVibFeederCommonFrequency := rInitialFrequency_2;
		stBunker[3].rMotorVibFeederCommonFrequency := rInitialFrequency_3;

		// Переход к запуску отвалообразователя
		AUTO_STEP := START_DUMPER;

	START_DUMPER :
		IF eDumperStage <> E_StageWithPreStartAlarm.WORK THEN // Если отвалообразователь не запущен
				xStartDumper := TRUE; // Команда запуска отвалообразователя
		ELSE
			ton_AutoTimer.IN := TRUE;
			IF ton_AutoTimer.Q THEN			
				xStartDumper := FALSE;
				ton_AutoTimer.IN := FALSE;
				AUTO_STEP := START_CONV; // Отвалообразователь запущен, переход к следующему шагу
			END_IF;
		END_IF;

	START_CONV:
		IF eConveyorStage <> E_StageWithPreStartAlarm.WORK THEN // Если отвалообразователь не запущен
			xStartConveyor := TRUE; // Команда запуска отвалообразователя
		ELSE
			ton_AutoTimer.IN := TRUE;
			IF ton_AutoTimer.Q THEN
				ton_AutoTimer.IN := FALSE;
				xStartConveyor := FALSE;
				AUTO_STEP := START_VIBFEEDER; // Отвалообразователь запущен, переход к следующему шагу
			END_IF;
		END_IF;

	START_VIBFEEDER:
		// Последовательный запуск бункеров с задержкой: 3 → задержка → 2 → задержка → 1
		CASE nBunkerStartStep OF
			0: // Шаг 0: Запуск бункера 3
				IF stBunker[3].eStateRemote = E_StateRemote.Auto AND BUNKER_WORK_PRECENT_3 > 0 THEN
					xStartBunker[3] := TRUE;
					IF eBunkerStage[3] = E_StageWithPreStartAlarm.WORK THEN
						xStartBunker[3] := FALSE;
						nBunkerStartStep := 1; // Бункер 3 запущен → задержка
					END_IF;
				ELSE
					nBunkerStartStep := 2; // Бункер 3 пропущен → переход к бункеру 2 без задержки
				END_IF;

			1: // Шаг 1: Задержка после бункера 3
				ton_AutoTimer.IN := TRUE;
				IF ton_AutoTimer.Q THEN
					ton_AutoTimer.IN := FALSE;
					nBunkerStartStep := 2; // Переход к бункеру 2
				END_IF;

			2: // Шаг 2: Запуск бункера 2
				IF stBunker[2].eStateRemote = E_StateRemote.Auto AND BUNKER_WORK_PRECENT_2 > 0 THEN
					xStartBunker[2] := TRUE;
					IF eBunkerStage[2] = E_StageWithPreStartAlarm.WORK THEN
						xStartBunker[2] := FALSE;
						nBunkerStartStep := 3; // Бункер 2 запущен → задержка
					END_IF;
				ELSE
					nBunkerStartStep := 4; // Бункер 2 пропущен → переход к бункеру 1 без задержки
				END_IF;

			3: // Шаг 3: Задержка после бункера 2
				ton_AutoTimer.IN := TRUE;
				IF ton_AutoTimer.Q THEN
					ton_AutoTimer.IN := FALSE;
					nBunkerStartStep := 4; // Переход к бункеру 1
				END_IF;

			4: // Шаг 4: Запуск бункера 1
				IF stBunker[1].eStateRemote = E_StateRemote.Auto AND BUNKER_WORK_PRECENT_1 > 0 THEN
					xStartBunker[1] := TRUE;
					IF eBunkerStage[1] = E_StageWithPreStartAlarm.WORK THEN
						xStartBunker[1] := FALSE;
						nBunkerStartStep := 5; // Бункер 1 запущен → завершение
					END_IF;
				ELSE
					nBunkerStartStep := 5; // Бункер 1 пропущен → завершение
				END_IF;

			5: // Шаг 5: Все бункеры запущены
				nBunkerStartStep := 0; // Сброс для следующего цикла
				AUTO_STEP := WORK; // Переход к работе
		END_CASE;
		
	WORK:
		// Нормальная работа
		xStateAutoWorking := TRUE;

		xStartBunker[1] := FALSE;
		xStartBunker[2] := FALSE;
		xStartBunker[3] := FALSE;
		xStartConveyor := FALSE;
		xStartDumper := FALSE;

		// === ОПРЕДЕЛЕНИЕ ТИПА ОСТАНОВКИ ===

		// Аварийная остановка (приоритет)
		IF stCommands.cmdEmergencyStopCommon.qxSignal
		OR (
			NOT (eConveyorStage = E_StageWithPreStartAlarm.WORK AND eDumperStage = E_StageWithPreStartAlarm.WORK)
			AND (eBunkerStage[1] = E_StageWithPreStartAlarm.WORK
			OR eBunkerStage[2] = E_StageWithPreStartAlarm.WORK
			OR eBunkerStage[3] = E_StageWithPreStartAlarm.WORK)
			)
		OR (eConveyorStage = E_StageWithPreStartAlarm.WORK AND NOT eDumperStage = E_StageWithPreStartAlarm.WORK)
		THEN
			xAutoEmergencyStopping := TRUE;
		END_IF

		// Обычная остановка
		IF stCommands.cmdStopCommon.qxSignal AND NOT xAutoEmergencyStopping THEN
			xAutoStopping := TRUE;
		END_IF

		// === АВАРИЙНАЯ ОСТАНОВКА (останавливаем всё сразу) ===
		IF xAutoEmergencyStopping THEN
			xManualStopBunker[1] := TRUE;
			xManualStopBunker[2] := TRUE;
			xManualStopBunker[3] := TRUE;
			xManualStopConveyor := TRUE;
			xManualStopDumper := TRUE;

			// Ожидание остановки всего оборудования
			IF eBunkerStage[1] <> E_StageWithPreStartAlarm.WORK
			AND eBunkerStage[2] <> E_StageWithPreStartAlarm.WORK
			AND eBunkerStage[3] <> E_StageWithPreStartAlarm.WORK
			AND eConveyorStage <> E_StageWithPreStartAlarm.WORK
			AND eDumperStage <> E_StageWithPreStartAlarm.WORK
			THEN
				// Сброс всех команд
				xManualStopBunker[1] := FALSE;
				xManualStopBunker[2] := FALSE;
				xManualStopBunker[3] := FALSE;
				xManualStopConveyor := FALSE;
				xManualStopDumper := FALSE;
				xAutoEmergencyStopping := FALSE;
				nStopSubstage := 0;
				xStateAutoWorking := FALSE;
				AUTO_STEP := ERROR;
			END_IF

		// === ОБЫЧНАЯ ОСТАНОВКА (последовательная, обратная от запуска) ===
		ELSIF xAutoStopping THEN
			CASE nStopSubstage OF
				0: // Шаг 0: Остановка бункера 1
					IF BUNKER_WORK_PRECENT_1 > 0 THEN
						xManualStopBunker[1] := TRUE;
						IF eBunkerStage[1] <> E_StageWithPreStartAlarm.WORK THEN
							xManualStopBunker[1] := FALSE;
							nStopSubstage := 1; // Бункер 1 остановлен → задержка
						END_IF
					ELSE
						nStopSubstage := 2; // Бункер 1 не используется → переход к бункеру 2 без задержки
					END_IF

				1: // Шаг 1: Задержка после бункера 1
					ton_AutoTimer.IN := TRUE;
					IF ton_AutoTimer.Q THEN
						ton_AutoTimer.IN := FALSE;
						nStopSubstage := 2; // Переход к бункеру 2
					END_IF

				2: // Шаг 2: Остановка бункера 2
					IF BUNKER_WORK_PRECENT_2 > 0 THEN
						xManualStopBunker[2] := TRUE;
						IF eBunkerStage[2] <> E_StageWithPreStartAlarm.WORK THEN
							xManualStopBunker[2] := FALSE;
							nStopSubstage := 3; // Бункер 2 остановлен → задержка
						END_IF
					ELSE
						nStopSubstage := 4; // Бункер 2 не используется → переход к бункеру 3 без задержки
					END_IF

				3: // Шаг 3: Задержка после бункера 2
					ton_AutoTimer.IN := TRUE;
					IF ton_AutoTimer.Q THEN
						ton_AutoTimer.IN := FALSE;
						nStopSubstage := 4; // Переход к бункеру 3
					END_IF

				4: // Шаг 4: Остановка бункера 3
					IF BUNKER_WORK_PRECENT_3 > 0 THEN
						xManualStopBunker[3] := TRUE;
						IF eBunkerStage[3] <> E_StageWithPreStartAlarm.WORK THEN
							xManualStopBunker[3] := FALSE;
							nStopSubstage := 5; // Бункер 3 остановлен → задержка
						END_IF
					ELSE
						nStopSubstage := 6; // Бункер 3 не используется → переход к конвейеру без задержки
					END_IF

				5: // Шаг 5: Задержка после бункера 3
					ton_AutoTimer.IN := TRUE;
					IF ton_AutoTimer.Q THEN
						ton_AutoTimer.IN := FALSE;
						nStopSubstage := 6; // Переход к конвейеру
					END_IF

				6: // Шаг 6: Остановка конвейера
					xManualStopConveyor := TRUE;
					IF eConveyorStage <> E_StageWithPreStartAlarm.WORK THEN
						xManualStopConveyor := FALSE;
						nStopSubstage := 7; // Конвейер остановлен → задержка
					END_IF

				7: // Шаг 7: Задержка после конвейера
					ton_AutoTimer.IN := TRUE;
					IF ton_AutoTimer.Q THEN
						ton_AutoTimer.IN := FALSE;
						nStopSubstage := 8; // Переход к отвалообразователю
					END_IF

				8: // Шаг 8: Остановка отвалообразователя
					xManualStopDumper := TRUE;
					IF eDumperStage <> E_StageWithPreStartAlarm.WORK THEN
						xManualStopDumper := FALSE;
						nStopSubstage := 9; // Отвалообразователь остановлен → завершение
					END_IF

				9: // Шаг 9: Завершение остановки
					ton_AutoTimer.IN := FALSE;
					xAutoStopping := FALSE;
					xStateAutoWorking := FALSE;
					nStopSubstage := 0; // Сброс для следующего цикла
					AUTO_STEP := IDLE; // Возврат в IDLE
			END_CASE
		END_IF
		

		IF BUNKER_ENABLE_PROPORTION_MONITORING THEN

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

		// Переход в IDLE при сбросе ошибки
		IF stCommands.cmdResetAll.qxRisingEdge AND xStateErrorCheckReady THEN
			AUTO_STEP := IDLE;
		END_IF;

END_CASE;

IF BUNKER_ENABLE_PID THEN

	fbProportionPid(
		xEnable:= AUTO_STEP = WORK,
		xReset:= stCommands.cmdResetAll.qxRisingEdge,

		rProportionTarget_1:= BUNKER_WORK_PRECENT_1,
		rProportionTarget_2:= BUNKER_WORK_PRECENT_2,
		rProportionTarget_3:= BUNKER_WORK_PRECENT_3,

		rProportionActual_1:= stBunker[1].rProportionActual,
		rProportionActual_2:= stBunker[2].rProportionActual,
		rProportionActual_3:= stBunker[3].rProportionActual,

		rFrequencyBase_1:= rInitialFrequency_1,
		rFrequencyBase_2:= rInitialFrequency_2,
		rFrequencyBase_3:= rInitialFrequency_3,

		rFrequency_Min:= 5,
		rFrequency_Max:= 50,
		rFrequency_TargetSum:= BUNKER_VIBFEEDER_FREQUENCY_TARGET_SUM,
		rDeltaTime:= 0.5
	);


	// Передача частоты ПИД регулятора 
	stBunker[1].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_1;
	stBunker[2].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_2;
	stBunker[3].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_3;

END_IF;

(* fbEmergencyStopProcess(
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

// ========================================
// MODBUS РЕГИСТРЫ
// ========================================

FC_ModbusToSCADA(
	stBunker:= stBunker, 
	stDumper:= stDumper, 
	stConveyor:= stConveyor, 
	stCommonSignals:= stCommonSignals, 
	stCommands:= stCommands, 
	eBunkerStageToSCADA:= eBunkerStageToSCADA, 
	eConveyorStageToSCADA:= eConveyorStageToSCADA, 
	eDumperStageToSCADA:= eDumperStageToSCADA);

END_PROGRAM