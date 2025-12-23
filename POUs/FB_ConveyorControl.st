FUNCTION_BLOCK FB_ConveyorControl
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
	xLocalMode : BOOL; // TRUE = местный режим (ПМУ), FALSE = дистанционный режим (SCADA)
	xStart : BOOL; // Команда запуска конвейера (дистанционный режим)
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

	// Подстадии запуска
	nStartingSubstage : INT := 0;
	// 0 - RELEASE_BRAKE, 1 - WAIT_BRAKE_FEEDBACK, 2 - START_VFD, 3 - RAMPING

	// Подстадии остановки
	nStoppingSubstage : INT := 0;
	// 0 - Нормальная работа
	// 1 - SET_FREQUENCY_ZERO: Установка частоты 0 на аналоговый выход
	// 2 - WAIT_FREQUENCY_ZERO: Ожидание подтверждения частоты 0 с аналогового входа
	// 3 - STOP_VFD: Остановка VFD (снятие команды пуска)
	// 4 - WAIT_VFD_STOP: Ожидание остановки VFD (обратная связь)
	// 5 - ACTIVATE_BRAKE: Активация тормозов
	// 6 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормозов

	// Целевые частоты для моторов
	rTargetFreqConv1 : REAL := 0.0;
	rTargetFreqConv2 : REAL := 0.0;

	// Переменные синхронизации моторов конвейера
	xVFDsReady : BOOL; // Оба ЧРП конвейера готовы и запущены
	xFrequenciesSynchronized : BOOL; // Частоты синхронизированы в пределах допуска
	xConditionToProceed : BOOL; // Общее условие для продолжения разгона

	// Состояние схемы контакторов
	xCircuitBuilt : BOOL := FALSE;

	// Таймеры контроля выполнения команд
	fbTimerStarting : TON; // Тайм-аут запуска (STARTING → WORK)
	fbTimerStopping : TON; // Тайм-аут остановки (WORK → IDLE)

	simInit : BOOL;
	i : INT;
END_VAR

// ========================================
// FB_ConveyorControl - Управление сборным конвейером
// ========================================
//
// РЕЖИМЫ УПРАВЛЕНИЯ:
//
// 1. МЕСТНЫЙ РЕЖИМ (xLocalMode = TRUE):
//    - Команды берутся с кнопок ПМУ (Conveyor.fbBtnStart, fbBtnStop)
//    - ПУСК/СТОП по фронтам кнопок
//    - Автоматически устанавливает eStateRemote = Manual
//
// 2. ДИСТАНЦИОННЫЙ РЕЖИМ (xLocalMode = FALSE):
//    - Команды берутся из входов ФБ (xStart, xStop)
//    - Режим устанавливается через SCADA (Manual/Remote/Auto)
//
// УПРАВЛЕНИЕ КОНВЕЙЕРОМ:
// - ПУСК: включение конвейеров с предпусковой сигнализацией
// - СТОП: плавная остановка с последовательным выключением VFD и тормозов
//
// ========================================

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
	ixStop := xStopCommand OR xReset,
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
IF FC_Conveyor_GetErrorCommon(Conveyor := Conveyor) OR fbTimerStarting.Q THEN
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
	Conveyor.xStateFailure := FALSE;
END_IF

// ========================================
// ВЫБОР ИСТОЧНИКА КОМАНД (ПМУ ИЛИ SCADA)
// ========================================

// В местном режиме (xLocalMode = TRUE) - команды берутся с ПМУ (кнопки)
// В дистанционном режиме (xLocalMode = FALSE) - команды берутся из SCADA (входы ФБ)
IF xLocalMode THEN
	// Местный режим - команды с ПМУ
	xStartCommand := Conveyor.fbBtnStart.qxRisingEdge; // ПУСК по фронту кнопки
	xStopCommand := Conveyor.fbBtnStop.qxRisingEdge;   // СТОП по фронту кнопки
ELSE
	// Дистанционный режим - команды из SCADA
	xStartCommand := xStart;
	xStopCommand := xStop;
END_IF;

// ========================================
// АВТОМАТ ПУСКА КОНВЕЙЕРА
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
IF FC_Conveyor_GetErrorSensors(Conveyor := Conveyor)
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

		// Сброс таймеров запуска и остановки
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);

		IF xStartCommand THEN
			STAGE := PRESTART_ALARM;
		END_IF;

	E_StageWithPreStartAlarm.PRESTART_ALARM:
		// Проверка команды остановки во время предпусковой сигнализации
		IF xStopCommand THEN
			// Прервать предпусковую сигнализацию и вернуться в IDLE
			STAGE := E_StageWithPreStartAlarm.IDLE;
		ELSIF Conveyor.fbPreStartAlarm.qxComplete THEN
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
			PT := TIME_AFTER_START_CONVEYOR
		);
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
						fbTimerStarting(IN := FALSE); // Сброс таймера
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
					fbTimerStarting(IN := FALSE); // Сброс таймера
				END_IF;
		END_CASE;

	E_StageWithPreStartAlarm.WORK:
		CASE nStoppingSubstage OF
			0: // Нормальная работа
				// Сброс таймера остановки
				fbTimerStopping(IN := FALSE);

				// Обновление целевой частоты конвейера в ручном режиме
				IF Conveyor.eStateRemote = E_StateRemote.Manual THEN
					rTargetFreqConv1 := MOTOR_FREQUENCY_CONVEYOR;
					rTargetFreqConv2 := MOTOR_FREQUENCY_CONVEYOR;
				END_IF;

				// Проверка команды остановки
				IF xStopCommand THEN
					nStoppingSubstage := 1;
				END_IF;

			1: // SET_FREQUENCY_ZERO - Установка частоты 0 на аналоговый выход
				// Запуск таймера остановки (тайм-аут на остановку секции)
				fbTimerStopping(
					IN := TRUE,
					PT := TIME_TIMEOUT_STOP_CONVEYOR
				);

				// Установить целевую частоту 0
				// (FB_FrequencyControl автоматически выберет плавную или прямую остановку через irStep)
				rTargetFreqConv1 := 0.0;
				rTargetFreqConv2 := 0.0;

				// Команды пуска VFD остаются активными (TRUE = ПУСК)
				// VFD продолжают работать, но частота снижается
				Conveyor.MotorConveyor[1].VFD.qxStart := TRUE;
				Conveyor.MotorConveyor[2].VFD.qxStart := TRUE;

				// Переход к следующей подстадии
				nStoppingSubstage := 2;

			2: // WAIT_FREQUENCY_ZERO - Ожидание подтверждения частоты 0 с аналогового входа
				// Ждём, пока фактическая частота (с аналогового входа) не снизится до 0 (+/- 2 Гц)
				IF Conveyor.MotorConveyor[1].VFD.rActualFrequency <= 2.0
					AND Conveyor.MotorConveyor[2].VFD.rActualFrequency <= 2.0
				THEN
					// Частота подтверждена на 0, переходим к остановке VFD
					nStoppingSubstage := 3;
				END_IF;

			3: // STOP_VFD - Остановка VFD (снятие команды пуска)
				// Отключить команду пуска на VFD (FALSE = СТОП)
				Conveyor.MotorConveyor[1].VFD.qxStart := FALSE;
				Conveyor.MotorConveyor[2].VFD.qxStart := FALSE;

				// Переход к ожиданию обратной связи VFD
				nStoppingSubstage := 4;

			4: // WAIT_VFD_STOP - Ожидание остановки VFD (обратная связь)
				// Проверить обратную связь VFD о выключении
				IF NOT Conveyor.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND NOT Conveyor.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					// VFD выключены, переход к активации тормозов
					nStoppingSubstage := 5;
				END_IF;

			5: // ACTIVATE_BRAKE - Активация тормозов
				// Снять сигнал с тормоза (поставить на тормоз: FALSE = активен)
				Conveyor.qxBreakerConveyor := FALSE;

				// Переход к завершению остановки
				nStoppingSubstage := 6;

			6: // WAIT_BRAKE_FEEDBACK - Переход в IDLE
				// Сброс таймера остановки (успешная остановка)
				fbTimerStopping(IN := FALSE);

				STAGE := E_StageWithPreStartAlarm.IDLE;
				nStoppingSubstage := 0;
		END_CASE;

	E_StageWithPreStartAlarm.ERROR:
		// Состояние ошибки - аварийная остановка и ожидание сброса
		// (используется при серьезных неисправностях, не для штатной остановки)

		// Аварийная остановка: команда СТОП на VFD (FALSE = СТОП)
		Conveyor.MotorConveyor[1].VFD.qxStart := FALSE;
		Conveyor.MotorConveyor[2].VFD.qxStart := FALSE;

		// Сброс целевых частот
		rTargetFreqConv1 := 0.0;
		rTargetFreqConv2 := 0.0;

		// Активировать тормоз
		Conveyor.qxBreakerConveyor := FALSE;

		// Разборка схемы контакторов (аварийная остановка)
		xCircuitBuilt := FALSE;

		// Сброс подстадий для следующего запуска
		nStartingSubstage := 0;
		nStoppingSubstage := 0;

		// Сброс таймеров
		fbTimerStarting(IN := FALSE);
		fbTimerStopping(IN := FALSE);

		// Контакторы управляются отдельно через импульсные команды
		// cmdBuildCircuitOn/Off (см. секцию УПРАВЛЕНИЕ КОНТАКТОРАМИ)

		// Сброс ошибки и переход в IDLE при отсутствии ошибок
		// Для выхода из ERROR требуется:
		// 1. Команда сброса (xReset)
		// 2. Снятие сигнала аварийной остановки (NOT xEmergencyStop)
		// 3. Отсутствие ошибок оборудования (NOT Conveyor.xStateFailure)
		IF xReset AND NOT xEmergencyStop AND NOT Conveyor.xStateFailure THEN
			STAGE := E_StageWithPreStartAlarm.IDLE;
		END_IF
END_CASE;

// Вывод текущей стадии
eStage := STAGE;

// ========================================
// ОБНОВЛЕНИЕ РЕЖИМА УПРАВЛЕНИЯ
// ========================================

// Если установлен местный режим (xLocalMode = TRUE), то переводим в Manual
// Manual может работать как дистанционно (от SCADA), так и местно (от ПМУ)
IF xLocalMode THEN
	Conveyor.eStateRemote := E_StateRemote.Manual;
END_IF;

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
Conveyor.xStateRemoteAuto := Conveyor.eStateRemote = E_StateRemote.Auto;
Conveyor.xStateRemoteManual := Conveyor.eStateRemote = E_StateRemote.Manual;
Conveyor.xStateRemoteRepair := Conveyor.eStateRemote = E_StateRemote.Repair;

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
// Только в ручном режиме
IF Conveyor.eStateRemote = E_StateRemote.Manual THEN
	IF Conveyor.cmdBuildCircuitOn THEN
		xCircuitBuilt := TRUE;
	ELSIF Conveyor.cmdBuildCircuitOff THEN
		xCircuitBuilt := FALSE;
	END_IF;
END_IF;

// Моторы конвейера - управление контакторами через состояние схемы
Conveyor.MotorConveyor[1].qxKM_Power := xCircuitBuilt;
Conveyor.MotorConveyor[2].qxKM_Power := xCircuitBuilt;

END_FUNCTION_BLOCK