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

	// Подстадии запуска (для последовательного включения тормозов и VFD)
	nStartingSubstage : INT := 0;
	// 0 - RELEASE_BRAKE: Отпускание тормозов
	// 1 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормозов
	// 2 - START_VFD: Запуск VFD
	// 3 - RAMPING: Разгон частоты до рабочей

	// Подстадии остановки (для последовательного выключения VFD и тормозов)
	nStoppingSubstage : INT := 0;
	// 0 - Нормальная работа
	// 1 - STOP_VFD: Остановка VFD
	// 2 - WAIT_VFD_STOP: Ожидание остановки VFD
	// 3 - ACTIVATE_BRAKE: Активация тормозов
	// 4 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормозов

	// Состояние схемы контакторов (TRUE = схема собрана, FALSE = схема разобрана)
	xCircuitBuilt : BOOL := FALSE;

	// Таймер ожидания полного запуска секции
	fbTimerStarting : TON;

	// == Управление поворотом ==
	xRotationLeftActive : BOOL; // Поворот влево активен
	xRotationRightActive : BOOL; // Поворот вправо активен
	nRotationSubstage : INT := 0; // Подстадии поворота
	// 0 - IDLE: Нет активного поворота
	// 1 - RELEASE_BRAKE: Отпускание тормоза поворота
	// 2 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормоза
	// 3 - START_VFD: Запуск VFD поворота
	// 4 - WORKING: Моторы поворота работают

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

// Сигналы тормозоов (Обратная связь)
Dumper.fbBreakerConveyor(
	ixSignal := , // Физ. сигнал
	xEnableRattlingFilter := TRUE);

Dumper.fbBreakerRotation(
	ixSignal := , // Физ. сигнал
	xEnableRattlingFilter := TRUE);

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

	// ЧРП
	Dumper.MotorConveyor[i].VFD.Device(
		ixFeedback := Dumper.MotorConveyor[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

	// VFD.qxStart теперь управляется напрямую в алгоритме (TRUE = ПУСК, FALSE = СТОП)

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

	// ЧРП
	Dumper.MotorRotation[i].VFD.Device(
		ixFeedback := Dumper.MotorRotation[i].VFD.fbStateIsWorking.qxSignal,
		xEnableFeedback := TRUE
	);

	// VFD.qxStart теперь управляется напрямую в алгоритме (TRUE = ПУСК, FALSE = СТОП)

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
	Dumper.MotorRotation[i].VFD.fbAnalogOutput(
		xEnable := Dumper.MotorRotation[i].VFD.Device.qxActive,
		rEngValue := Dumper.MotorRotation[i].VFD.Frequency.qrCurrentFrequency,
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

IF FC_Dumper_GetErrorCommon(Dumper := Dumper) OR fbTimerStarting.Q THEN
	Dumper.xStateFailure := TRUE;
END_IF;



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
	Dumper.xStateFailure := FALSE;
END_IF

// Штатная остановка - запускается при получении команды xStop
// Обрабатывается через подстадии в режиме WORK

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

		// Сброс подстадий запуска и остановки
		nStartingSubstage := 0;
		nStoppingSubstage := 0;

		// Сброс таймера запуска
		fbTimerStarting(IN := FALSE);

		// Тормоза активны (удерживают механизм)
		Dumper.qxBreakerConveyor := FALSE;
		Dumper.qxBreakerRotation := FALSE;

		IF xStart THEN
			STAGE := PRESTART_ALARM;
		END_IF;

	PRESTART_ALARM:
		// Проверка команды остановки во время предпусковой сигнализации
		IF xStop THEN
			// Прервать предпусковую сигнализацию и вернуться в IDLE
			STAGE := E_StageWithPreStartAlarm.IDLE;
		ELSIF Dumper.fbPreStartAlarm.qxComplete THEN
			STAGE := E_StageWithPreStartAlarm.STARTING;
		END_IF;

	E_StageWithPreStartAlarm.STARTING:
		// Проверка команды остановки во время запуска
		IF xStop THEN
			// Прервать запуск и перейти к процедуре остановки
			STAGE := E_StageWithPreStartAlarm.WORK;
			nStartingSubstage := 0;
			nStoppingSubstage := 1; // Начать процедуру остановки
			fbTimerStarting(IN := FALSE); // Сброс таймера
		END_IF;

		// Таймер ожидания полного запуска секции
		fbTimerStarting(
			IN := TRUE,
			PT := TIME_AFTER_START_DUMPER
		);

		// Последовательный запуск: Тормоза → Обратная связь → VFD → Разгон
		CASE nStartingSubstage OF
			0: // RELEASE_BRAKE - Отпускание тормозов
				// Включить сигнал тормоза (1 = тормоз отпущен)
				Dumper.qxBreakerConveyor := TRUE;
				Dumper.qxBreakerRotation := TRUE;

				// Переход к следующей подстадии
				nStartingSubstage := 1;

			1: // WAIT_BRAKE_FEEDBACK - Ожидание обратной связи тормозов
				// Получить обратную связь реле тормоза
				IF Dumper.fbBreakerConveyor.qxSignal THEN
					// Обратная связь получена, переходим к запуску VFD
					nStartingSubstage := 2;
				END_IF;

			2: // START_VFD - Запуск VFD (контакторы управляются отдельно через cmdBuildCircuitOn/Off)
				// Команда ПУСК на частотный преобразователь (TRUE = ПУСК)
				Dumper.MotorConveyor[1].VFD.qxStart := TRUE;
				Dumper.MotorConveyor[2].VFD.qxStart := TRUE;

				// Установка целевой частоты
				// (FB_FrequencyControl автоматически выберет плавный или прямой пуск через irStep)
				rTargetFreqConv1 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
				rTargetFreqConv2 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;

				// Если оба VFD запущены (обратная связь), переходим к следующей подстадии
				IF Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					IF VFD_SMOOTH_SET_FREQUENCY THEN
						// Плавный пуск: переходим к разгону
						nStartingSubstage := 3;
					ELSE
						// Прямой пуск: сразу в режим WORK (частота уже установлена через большой шаг)
						STAGE := E_StageWithPreStartAlarm.WORK;
						nStartingSubstage := 0;
						fbTimerStarting(IN := FALSE); // Сброс таймера
					END_IF;
				END_IF;

			3: // RAMPING - Разгон частоты до рабочей
				// Команды запуска VFD остаются активными (TRUE = ПУСК)
				Dumper.MotorConveyor[1].VFD.qxStart := TRUE;
				Dumper.MotorConveyor[2].VFD.qxStart := TRUE;

				// Задание целевой частоты (передается в FB_FrequencyControl)
				rTargetFreqConv1 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
				rTargetFreqConv2 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;

				// Переход в режим WORK при достижении целевой частоты
				// Используется регулирование частоты с синхронизацией
				IF Dumper.MotorConveyor[1].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
					AND Dumper.MotorConveyor[2].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
				THEN
					STAGE := E_StageWithPreStartAlarm.WORK;
					nStartingSubstage := 0; // Сброс для следующего запуска
					fbTimerStarting(IN := FALSE); // Сброс таймера
				END_IF;
		END_CASE;

	E_StageWithPreStartAlarm.WORK:
		// Нормальная работа или штатная остановка через подстадии
		CASE nStoppingSubstage OF
			0: // Нормальная работа
				IF xStop THEN
					// Начать штатную остановку
					nStoppingSubstage := 1;
				END_IF;

			1: // STOP_VFD - Остановка VFD
				// Установить целевую частоту 0
				// (FB_FrequencyControl автоматически выберет плавную или прямую остановку через irStep)
				rTargetFreqConv1 := 0.0;
				rTargetFreqConv2 := 0.0;
				rTargetFreqRot1 := 0.0;
				rTargetFreqRot2 := 0.0;

				IF VFD_SMOOTH_SET_FREQUENCY THEN
					// Плавная остановка: ждем снижения частоты до 0, затем отключаем VFD
					IF Dumper.MotorConveyor[1].VFD.rActualFrequency <= VFD_FREQUENCY_INACCURANCY
						AND Dumper.MotorConveyor[2].VFD.rActualFrequency <= VFD_FREQUENCY_INACCURANCY
					THEN
						// Частота достигла 0, отключаем VFD
						Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
						Dumper.MotorConveyor[2].VFD.qxStart := FALSE;
						nStoppingSubstage := 2;
					END_IF;
				ELSE
					// Прямая остановка: сразу отключаем VFD (частота мгновенно стала 0 через большой шаг)
					Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
					Dumper.MotorConveyor[2].VFD.qxStart := FALSE;
					nStoppingSubstage := 2;
				END_IF;

			2: // WAIT_VFD_STOP - Ожидание остановки VFD
				// Проверить обратную связь VFD о выключении
				IF NOT Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND NOT Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					// VFD выключены, переход к активации тормозов
					nStoppingSubstage := 3;
				END_IF;

			3: // ACTIVATE_BRAKE - Активация тормозов
				// Снять сигнал с тормоза (поставить на тормоз: FALSE = активен)
				Dumper.qxBreakerConveyor := FALSE;
				Dumper.qxBreakerRotation := FALSE;

				// Переход к ожиданию обратной связи тормозов
				nStoppingSubstage := 4;

			4: // Переход в IDLE

				STAGE := E_StageWithPreStartAlarm.IDLE;
				nStoppingSubstage := 0;
		END_CASE;

	E_StageWithPreStartAlarm.ERROR:
		// Состояние ошибки - аварийная остановка и ожидание сброса
		// (используется при серьезных неисправностях, не для штатной остановки)

		// Аварийная остановка: команда СТОП на VFD (FALSE = СТОП)
		Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
		Dumper.MotorConveyor[2].VFD.qxStart := FALSE;

		// Сброс целевых частот
		rTargetFreqConv1 := 0.0;
		rTargetFreqConv2 := 0.0;
		rTargetFreqRot1 := 0.0;
		rTargetFreqRot2 := 0.0;

		// Активировать тормоза
		Dumper.qxBreakerConveyor := FALSE;
		Dumper.qxBreakerRotation := FALSE;

		// Сброс подстадий для следующего запуска
		nStartingSubstage := 0;
		nStoppingSubstage := 0;

		// Сброс таймера запуска
		fbTimerStarting(IN := FALSE);

		// Контакторы управляются отдельно через импульсные команды
		// cmdBuildCircuitOn/Off (см. секцию УПРАВЛЕНИЕ КОНТАКТОРАМИ)
END_CASE;

// ========================================
// ПРОВЕРКА СИНХРОНИЗАЦИИ МОТОРОВ КОНВЕЙЕРА
// ========================================

// Проверка что оба ЧРП конвейера готовы и запущены (обратная связь)
xVFDsReady := Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
           AND Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal;

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
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqConv1,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := xConditionToProceed // Синхронизация с мотором 2
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

Dumper.MotorConveyor[2].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqConv2,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := xConditionToProceed // Синхронизация с мотором 1
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

// Моторы поворота
Dumper.MotorRotation[1].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqRot1,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := TRUE
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

Dumper.MotorRotation[2].VFD.Frequency(
	irMaxFrequency := VFD_FREQUENCY_MAX,
	// Если плавный пуск - используем шаг, иначе - большой шаг для мгновенной установки
	irStep := SEL(VFD_SMOOTH_SET_FREQUENCY, VFD_FREQ_MAX_RANGE, VFD_FREQUENCY_STEP),
	rTargetFrequency := rTargetFreqRot2,
	xPulse := PULSE_RTRIG.Q,
	xConditionToProceed := TRUE
);
// qrCurrentFrequency передается напрямую в fbAnalogOutput.rEngValue

// Вывод текущей стадии
eStage := STAGE;

// ========================================
// УПРАВЛЕНИЕ КОНТАКТОРАМИ
// ========================================

// Обработка импульсных команд сборки/разборки схемы
// cmdBuildCircuitOn - собрать схему (включить контакторы)
// cmdBuildCircuitOff - разобрать схему (выключить контакторы)
IF Dumper.eStateRemote = E_StateRemote.Manual THEN
	IF Dumper.cmdBuildCircuitOn THEN
		xCircuitBuilt := TRUE;
	ELSIF Dumper.cmdBuildCircuitOff THEN
		xCircuitBuilt := FALSE;
	END_IF;
END_IF;
// Моторы конвейера - управление контакторами через состояние схемы
Dumper.MotorConveyor[1].qxKM_Power := xCircuitBuilt;
Dumper.MotorConveyor[2].qxKM_Power := xCircuitBuilt;

// ========================================
// УПРАВЛЕНИЕ МОТОРАМИ ПОВОРОТА
// ========================================

// Обработка импульсных команд поворота (из ПМУ и АСУТП)
// Команды поворота могут быть активны в любом режиме работы

// Обработка команды поворота влево
IF (Dumper.fbBtnTurnLeft.qxRisingEdge OR Dumper.cmdTurnLeft) AND nRotationSubstage = 0 THEN
	// Можем начать поворот влево только если:
	// 1. Не упёрлись в левый концевик
	// 2. Нет активного поворота (nRotationSubstage = 0)
	// 3. Нет команды остановки поворота
	IF NOT Dumper.fbEndSwitchLeft.qxSignal AND NOT Dumper.cmdStopRotation THEN
		xRotationLeftActive := TRUE;
		xRotationRightActive := FALSE;
		nRotationSubstage := 1; // Начать последовательность запуска
	END_IF;
	// Сброс импульсной команды
	Dumper.cmdTurnLeft := FALSE;
END_IF;

// Обработка команды поворота вправо
IF (Dumper.fbBtnTurnRight.qxRisingEdge OR Dumper.cmdTurnRight) AND nRotationSubstage = 0 THEN
	// Можем начать поворот вправо только если:
	// 1. Не упёрлись в правый концевик
	// 2. Нет активного поворота (nRotationSubstage = 0)
	// 3. Нет команды остановки поворота
	IF NOT Dumper.fbEndSwitchRight.qxSignal AND NOT Dumper.cmdStopRotation THEN
		xRotationRightActive := TRUE;
		xRotationLeftActive := FALSE;
		nRotationSubstage := 1; // Начать последовательность запуска
	END_IF;
	// Сброс импульсной команды
	Dumper.cmdTurnRight := FALSE;
END_IF;

// Автоматическая остановка при достижении концевых выключателей
IF Dumper.fbEndSwitchLeft.qxSignal AND xRotationLeftActive THEN
	// Упёрлись в левый концевик - останавливаем поворот влево
	nRotationSubstage := 0;
	xRotationLeftActive := FALSE;
END_IF;

IF Dumper.fbEndSwitchRight.qxSignal AND xRotationRightActive THEN
	// Упёрлись в правый концевик - останавливаем поворот вправо
	nRotationSubstage := 0;
	xRotationRightActive := FALSE;
END_IF;

// Остановка по команде
IF Dumper.cmdStopRotation AND (xRotationLeftActive OR xRotationRightActive) THEN
	nRotationSubstage := 0;
	xRotationLeftActive := FALSE;
	xRotationRightActive := FALSE;
	// Сброс импульсной команды остановки
	Dumper.cmdStopRotation := FALSE;
END_IF;

// Автомат управления поворотом с подстадиями
CASE nRotationSubstage OF
	0: // IDLE - Нет активного поворота
		// Остановка VFD
		Dumper.MotorRotation[1].VFD.qxStart := FALSE;
		Dumper.MotorRotation[2].VFD.qxStart := FALSE;
		Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
		Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;

		// Активация тормоза поворота
		Dumper.qxBreakerRotation := FALSE;

		// Сброс целевой частоты
		rTargetFreqRot1 := 0.0;
		rTargetFreqRot2 := 0.0;

	1: // RELEASE_BRAKE - Отпускание тормоза поворота
		// Отпустить тормоз (1 = тормоз отпущен)
		Dumper.qxBreakerRotation := TRUE;

		// Переход к следующей подстадии
		nRotationSubstage := 2;

	2: // WAIT_BRAKE_FEEDBACK - Ожидание обратной связи тормоза
		// Ждём обратную связь реле тормоза
		IF Dumper.fbBreakerRotation.qxSignal THEN
			// Обратная связь получена, переходим к запуску VFD
			nRotationSubstage := 3;
		END_IF;

	3: // START_VFD - Запуск VFD поворота
		IF xRotationLeftActive THEN
			// Поворот влево - запуск в режиме реверса
			Dumper.MotorRotation[1].VFD.qxStart := TRUE;
			Dumper.MotorRotation[2].VFD.qxStart := TRUE;
			Dumper.MotorRotation[1].qxVFDReverseStart := TRUE;
			Dumper.MotorRotation[2].qxVFDReverseStart := TRUE;

		ELSIF xRotationRightActive THEN
			// Поворот вправо - запуск в прямом направлении
			Dumper.MotorRotation[1].VFD.qxStart := TRUE;
			Dumper.MotorRotation[2].VFD.qxStart := TRUE;
			Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
			Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;
		END_IF;

		// Установка целевой частоты
		rTargetFreqRot1 := MOTOR_FREQUENCY_DUMPER_ROTATION;
		rTargetFreqRot2 := MOTOR_FREQUENCY_DUMPER_ROTATION;

		// Проверка запуска VFD (обратная связь)
		IF Dumper.MotorRotation[1].VFD.fbStateIsWorking.qxSignal
			AND Dumper.MotorRotation[2].VFD.fbStateIsWorking.qxSignal
		THEN
			// VFD запущены, переходим в режим работы
			nRotationSubstage := 4;
		END_IF;

	4: // WORKING - Моторы поворота работают
		// Поддержка целевой частоты
		rTargetFreqRot1 := MOTOR_FREQUENCY_DUMPER_ROTATION;
		rTargetFreqRot2 := MOTOR_FREQUENCY_DUMPER_ROTATION;
END_CASE;

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

// Передача состояний режима управления
Dumper.xStateRemoteAuto := Dumper.eStateRemote = E_StateRemote.Auto;
Dumper.xStateRemoteManual := Dumper.eStateRemote = E_StateRemote.Manual;
Dumper.xStateRemoteRepair := Dumper.eStateRemote = E_StateRemote.Repair;

END_FUNCTION_BLOCK