FUNCTION_BLOCK FB_DumperConveyorMotors
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
	xStart : BOOL;              // Команда запуска
	xStop : BOOL;               // Команда остановки
	xEmergencyStop : BOOL;      // Аварийная остановка (импульсная)
	xReset : BOOL;              // Сброс аварии (импульсная)
	rTargetFrequency : REAL;    // Целевая частота моторов
END_VAR
VAR_OUTPUT
	eStage : E_StageActuator;   // Текущая стадия
	rCurrentFrequency : REAL;   // Текущая частота моторов (среднее значение)
	xStartingTimeout : BOOL;    // Флаг тайм-аута запуска (STARTING слишком долго)
	xStoppingTimeout : BOOL;    // Флаг тайм-аута остановки (STOPPING слишком долго)
END_VAR
VAR
	STAGE : E_StageActuator := E_StageActuator.IDLE;

	// Подстадии запуска
	nStartingSubstage : INT := 0;
	// 0 - RELEASE_BRAKE: Отпускание тормоза
	// 1 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормоза
	// 2 - START_VFD: Запуск VFD

	// Подстадии остановки
	nStoppingSubstage : INT := 0;
	// 0 - Нормальная работа
	// 1 - STOP_VFD: Остановка VFD
	// 2 - WAIT_VFD_STOP: Ожидание остановки VFD
	// 3 - ACTIVATE_BRAKE: Активация тормоза
	// 4 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормоза

	// Таймер задержки включения тормоза
	tonTimerEnableBrake : TON;

	// Таймер контроля времени запуска (STARTING → WORK)
	tonTimerStarting : TON;

	// Таймер контроля времени остановки (STOPPING → IDLE)
	tonTimerStopping : TON;

	// Флаг запуска таймера (защита от зацикливания)
	xBrakeTimerStarted : BOOL := FALSE;
END_VAR

// ========================================
// FB_DumperConveyorMotors - Управление моторами конвейера отвалообразователя
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Управление двумя моторами конвейера (22 кВт каждый)
// - Прямой пуск (без плавного разгона)
// - Последовательная остановка (VFD → тормоз)
// - Не знает про ППЗ и верхнеуровневую логику
// - Просто выполняет команды START/STOP
//
// ВХОДЫ:
// - xStart: команда запуска моторов
// - xStop: команда остановки моторов
// - xEmergencyStop: аварийная остановка (импульсная)
// - xReset: сброс аварии (импульсная)
// - rTargetFrequency: целевая частота (Гц)
//
// ВЫХОДЫ:
// - eStage: текущая стадия (IDLE/STARTING/WORK/STOPPING/FAULT)
// - rCurrentFrequency: текущая частота моторов
//
// ========================================

// ========================================
// ПРИОРИТЕТНАЯ ОБРАБОТКА АВАРИЙНОЙ ОСТАНОВКИ
// ========================================

IF xEmergencyStop THEN
	// Аварийная остановка: немедленное выключение VFD
	Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
	Dumper.MotorConveyor[2].VFD.qxStart := FALSE;

	// Активация тормоза
	Dumper.qxBreakerConveyor := FALSE;

	// Переход в FAULT
	STAGE := E_StageActuator.FAULT;
	nStartingSubstage := 0;
	nStoppingSubstage := 0;
	tonTimerEnableBrake(IN := FALSE);
	tonTimerStarting(IN := FALSE);
	tonTimerStopping(IN := FALSE);
	xBrakeTimerStarted := FALSE;
END_IF

// Тайм-аут запуска: если слишком долго в STARTING → аварийная остановка
tonTimerStarting(
	IN := (STAGE = E_StageActuator.STARTING),
	PT := TIME_TIMEOUT_START_DUMPER_CONVEYOR
);

IF tonTimerStarting.Q THEN
	xStartingTimeout := TRUE;
	// Аварийная остановка: немедленное выключение VFD
	Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
	Dumper.MotorConveyor[2].VFD.qxStart := FALSE;
	// Активация тормоза
	Dumper.qxBreakerConveyor := FALSE;
	// Переход в FAULT
	STAGE := E_StageActuator.FAULT;
	nStartingSubstage := 0;
	tonTimerStarting(IN := FALSE);
END_IF

// Тайм-аут остановки: если слишком долго в STOPPING → аварийная остановка
tonTimerStopping(
	IN := (STAGE = E_StageActuator.STOPPING),
	PT := TIME_TIMEOUT_STOP_DUMPER_CONVEYOR
);

IF tonTimerStopping.Q THEN
	xStoppingTimeout := TRUE;
	// Аварийная остановка: немедленное выключение VFD
	Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
	Dumper.MotorConveyor[2].VFD.qxStart := FALSE;
	// Активация тормоза
	Dumper.qxBreakerConveyor := FALSE;
	// Переход в FAULT
	STAGE := E_StageActuator.FAULT;
	nStoppingSubstage := 0;
	tonTimerStopping(IN := FALSE);
END_IF

// ========================================
// АВТОМАТ УПРАВЛЕНИЯ МОТОРАМИ
// ========================================

CASE STAGE OF
	E_StageActuator.IDLE:
		// Сброс подстадий
		nStartingSubstage := 0;
		nStoppingSubstage := 0;

		// Сброс флага таймера тормоза
		xBrakeTimerStarted := FALSE;

		// Тормоз активен (удерживает механизм)
		Dumper.qxBreakerConveyor := FALSE;

		// Команда запуска
		IF xStart AND NOT xEmergencyStop THEN
			STAGE := E_StageActuator.STARTING;
		END_IF

	E_StageActuator.STARTING:
		// Проверка команды остановки во время запуска
		IF xStop THEN
			// Прервать запуск и перейти к остановке
			STAGE := E_StageActuator.STOPPING;
			nStartingSubstage := 0;
			nStoppingSubstage := 1; // Начать процедуру остановки
		END_IF

		// Последовательный запуск: Тормоз → VFD → Разгон
		CASE nStartingSubstage OF
			0: // RELEASE_BRAKE - Отпускание тормоза
				// Отпустить тормоз (1 = тормоз отпущен)
				Dumper.qxBreakerConveyor := TRUE;

				// Переход к следующей подстадии
				nStartingSubstage := 1;

			1: // WAIT_BRAKE_FEEDBACK - Ожидание обратной связи тормоза
				// Получить обратную связь реле тормоза
				IF Dumper.fbBreakerConveyor.qxSignal THEN
					// Обратная связь получена, переходим к запуску VFD
					nStartingSubstage := 2;
				END_IF

			2: // START_VFD - Запуск VFD
				// Команда ПУСК на частотный преобразователь
				Dumper.MotorConveyor[1].VFD.qxStart := TRUE;
				Dumper.MotorConveyor[2].VFD.qxStart := TRUE;

				// Если оба VFD запущены (обратная связь)
				IF Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					// Переход в режим WORK
					STAGE := E_StageActuator.WORK;
					nStartingSubstage := 0;
				END_IF
		END_CASE;

	E_StageActuator.WORK:
		// Нормальная работа
		// Команда остановки - переход в STOPPING
		IF xStop THEN
			STAGE := E_StageActuator.STOPPING;
			nStoppingSubstage := 0;
		END_IF

	E_StageActuator.STOPPING:
		// Штатная остановка через подстадии
		CASE nStoppingSubstage OF
			0: // STOP_VFD - Остановка VFD
				// Отключить команду пуска на VFD
				Dumper.MotorConveyor[1].VFD.qxStart := FALSE;
				Dumper.MotorConveyor[2].VFD.qxStart := FALSE;

				nStoppingSubstage := 1;

			1: // WAIT_VFD_STOP - Ожидание остановки VFD
				// Проверить обратную связь VFD о выключении
				IF NOT Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal
					AND NOT Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal
				THEN
					nStoppingSubstage := 2;
				END_IF

			2: // ACTIVATE_BRAKE - Активация тормоза с задержкой
				// Включение таймера на задержку тормоза (один раз)
				IF NOT xBrakeTimerStarted THEN
					xBrakeTimerStarted := TRUE;
				END_IF

				tonTimerEnableBrake(IN := xBrakeTimerStarted, PT := T#5S);

				IF tonTimerEnableBrake.Q THEN
					// Снять сигнал с тормоза (FALSE = активен)
					Dumper.qxBreakerConveyor := FALSE;
					tonTimerEnableBrake(IN := FALSE);
					xBrakeTimerStarted := FALSE;
					nStoppingSubstage := 3;
				END_IF

			3: // Переход в IDLE
				STAGE := E_StageActuator.IDLE;
				nStoppingSubstage := 0;
		END_CASE;

	E_StageActuator.FAULT:
		// Состояние аварии - ожидание сброса
		// Выход из FAULT по команде xReset
		IF xReset THEN
			STAGE := E_StageActuator.IDLE;
			xStartingTimeout := FALSE; // Сброс флага тайм-аута запуска
			xStoppingTimeout := FALSE; // Сброс флага тайм-аута остановки
		END_IF
END_CASE;

// ========================================
// ЗАДАНИЕ ЧАСТОТЫ МОТОРОВ
// ========================================

// Установка частоты напрямую в аналоговый выход VFD
// В режиме WORK частота = rTargetFrequency
// В остальных режимах (IDLE, STOPPING, FAULT) частота = 0
IF STAGE = E_StageActuator.WORK THEN
	Dumper.MotorConveyor[1].VFD.qrOutFrequency := rTargetFrequency;
	Dumper.MotorConveyor[2].VFD.qrOutFrequency := rTargetFrequency;
ELSE
	Dumper.MotorConveyor[1].VFD.qrOutFrequency := 0.0;
	Dumper.MotorConveyor[2].VFD.qrOutFrequency := 0.0;
END_IF;

// ========================================
// ВЫХОДЫ
// ========================================

// Текущая стадия
eStage := STAGE;

// Текущая частота (среднее значение двух моторов)
rCurrentFrequency := (Dumper.MotorConveyor[1].VFD.rActualFrequency
                    + Dumper.MotorConveyor[2].VFD.rActualFrequency) / 2.0;

END_FUNCTION_BLOCK
