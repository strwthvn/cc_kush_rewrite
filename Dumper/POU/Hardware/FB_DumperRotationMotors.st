FUNCTION_BLOCK FB_DumperRotationMotors
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
	xTurnLeft : BOOL;           // Команда поворота влево
	xTurnRight : BOOL;          // Команда поворота вправо
	xStop : BOOL;               // Команда остановки поворота
	xEmergencyStop : BOOL;      // Аварийная остановка
	rTargetFrequency : REAL;    // Целевая частота моторов
END_VAR
VAR_OUTPUT
	eStage : E_StageActuator;   // Текущая стадия
	rCurrentFrequency : REAL;   // Текущая частота моторов (среднее значение)
	xRotatingLeft : BOOL;       // Активен поворот влево
	xRotatingRight : BOOL;      // Активен поворот вправо
END_VAR
VAR
	STAGE : E_StageActuator := E_StageActuator.IDLE;

	// Направление поворота
	xLeftActive : BOOL := FALSE;  // Поворот влево активен
	xRightActive : BOOL := FALSE; // Поворот вправо активен

	// Подстадии запуска
	nStartingSubstage : INT := 0;
	// 0 - IDLE
	// 1 - RELEASE_BRAKE: Отпускание тормоза поворота
	// 2 - WAIT_BRAKE_FEEDBACK: Ожидание обратной связи тормоза
	// 3 - START_VFD: Запуск VFD поворота

	// Подстадии остановки
	nStoppingSubstage : INT := 0;
	// 0 - Нормальная работа
	// 1 - STOP_VFD: Остановка VFD
	// 2 - WAIT_VFD_STOP: Ожидание остановки VFD
	// 3 - ACTIVATE_BRAKE: Активация тормоза

	// Таймер задержки включения тормоза
	tonTimerEnableBrake : TON;

	// Флаг запуска таймера (защита от зацикливания)
	xBrakeTimerStarted : BOOL := FALSE;
END_VAR

// ========================================
// FB_DumperRotationMotors - Управление моторами поворота отвалообразователя
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Управление двумя моторами поворота (3 кВт каждый)
// - Поддержка реверса (влево/вправо)
// - Блокировка по концевым выключателям
// - Последовательная остановка (VFD → тормоз)
// - Не знает про верхнеуровневую логику
// - Просто выполняет команды TURN_LEFT/TURN_RIGHT/STOP
//
// ВХОДЫ:
// - xTurnLeft: команда поворота влево
// - xTurnRight: команда поворота вправо
// - xStop: команда остановки
// - xEmergencyStop: аварийная остановка
// - rTargetFrequency: целевая частота (Гц)
//
// ВЫХОДЫ:
// - eStage: текущая стадия (IDLE/STARTING/WORK)
// - rCurrentFrequency: текущая частота моторов
// - xRotatingLeft: флаг активного поворота влево
// - xRotatingRight: флаг активного поворота вправо
//
// ========================================

// ========================================
// ПРИОРИТЕТНАЯ ОБРАБОТКА АВАРИЙНОЙ ОСТАНОВКИ
// ========================================

IF xEmergencyStop THEN
	// Аварийная остановка: немедленное выключение VFD
	Dumper.MotorRotation[1].VFD.qxStart := FALSE;
	Dumper.MotorRotation[2].VFD.qxStart := FALSE;
	Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
	Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;

	// Активация тормоза
	Dumper.qxBreakerRotation := FALSE;

	// Сброс направления
	xLeftActive := FALSE;
	xRightActive := FALSE;

	// Переход в IDLE
	STAGE := E_StageActuator.IDLE;
	nStartingSubstage := 0;
	nStoppingSubstage := 0;
	tonTimerEnableBrake(IN := FALSE);
	xBrakeTimerStarted := FALSE;
END_IF

// ========================================
// АВТОМАТ УПРАВЛЕНИЯ МОТОРАМИ ПОВОРОТА
// ========================================

CASE STAGE OF
	E_StageActuator.IDLE:
		// Сброс подстадий
		nStartingSubstage := 0;
		nStoppingSubstage := 0;

		// Сброс флага таймера тормоза
		xBrakeTimerStarted := FALSE;

		// Тормоз активен
		Dumper.qxBreakerRotation := FALSE;

		// Остановка VFD
		Dumper.MotorRotation[1].VFD.qxStart := FALSE;
		Dumper.MotorRotation[2].VFD.qxStart := FALSE;
		Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
		Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;

		// Сброс флагов направления
		xLeftActive := FALSE;
		xRightActive := FALSE;

		// Команда поворота влево
		IF xTurnLeft AND NOT xEmergencyStop AND NOT xTurnRight THEN
			// Проверка концевого выключателя влево
			// qxSignal = TRUE означает концевик в норме (не нажат)
			IF Dumper.fbEndSwitchLeft.qxSignal THEN
				xLeftActive := TRUE;
				xRightActive := FALSE;
				STAGE := E_StageActuator.STARTING;
			END_IF
		END_IF

		// Команда поворота вправо
		IF xTurnRight AND NOT xEmergencyStop AND NOT xTurnLeft THEN
			// Проверка концевого выключателя вправо
			IF Dumper.fbEndSwitchRight.qxSignal THEN
				xRightActive := TRUE;
				xLeftActive := FALSE;
				STAGE := E_StageActuator.STARTING;
			END_IF
		END_IF

	E_StageActuator.STARTING:
		// Проверка команды остановки во время запуска
		IF xStop THEN
			// Прервать запуск и перейти к остановке
			STAGE := E_StageActuator.WORK;
			nStartingSubstage := 0;
			nStoppingSubstage := 1; // Начать процедуру остановки
		END_IF

		// Проверка достижения концевого выключателя
		IF (xLeftActive AND NOT Dumper.fbEndSwitchLeft.qxSignal)
			OR (xRightActive AND NOT Dumper.fbEndSwitchRight.qxSignal)
		THEN
			// Концевик достигнут, начать остановку
			STAGE := E_StageActuator.WORK;
			nStartingSubstage := 0;
			nStoppingSubstage := 1;
		END_IF

		// Последовательный запуск: Тормоз → VFD → Разгон
		CASE nStartingSubstage OF
			0: // IDLE
				nStartingSubstage := 1;

			1: // RELEASE_BRAKE - Отпускание тормоза
				// Отпустить тормоз (1 = тормоз отпущен)
				Dumper.qxBreakerRotation := TRUE;

				// Переход к следующей подстадии
				nStartingSubstage := 2;

			2: // WAIT_BRAKE_FEEDBACK - Ожидание обратной связи тормоза
				// Получить обратную связь реле тормоза
				IF Dumper.fbBreakerRotation.qxSignal THEN
					// Обратная связь получена, переходим к запуску VFD
					nStartingSubstage := 3;
				END_IF

			3: // START_VFD - Запуск VFD
				// Установка направления и запуск VFD
				IF xLeftActive THEN
					// Поворот влево - прямое направление
					Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
					Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;
					Dumper.MotorRotation[1].VFD.qxStart := TRUE;
					Dumper.MotorRotation[2].VFD.qxStart := TRUE;
				ELSIF xRightActive THEN
					// Поворот вправо - реверс
					Dumper.MotorRotation[1].VFD.qxStart := FALSE;
					Dumper.MotorRotation[2].VFD.qxStart := FALSE;
					Dumper.MotorRotation[1].qxVFDReverseStart := TRUE;
					Dumper.MotorRotation[2].qxVFDReverseStart := TRUE;
				END_IF

				// Проверка запуска VFD (обратная связь)
				IF Dumper.MotorRotation[1].VFD.fbStateIsWorking.qxSignal
					AND Dumper.MotorRotation[2].VFD.fbStateIsWorking.qxSignal
				THEN
					// VFD запущены, переходим в режим работы
					STAGE := E_StageActuator.WORK;
					nStartingSubstage := 0;
				END_IF
		END_CASE;

	E_StageActuator.WORK:
		// Нормальная работа или штатная остановка через подстадии
		CASE nStoppingSubstage OF
			0: // Нормальная работа
				// Проверка команды остановки
				IF xStop THEN
					nStoppingSubstage := 1;
				END_IF

				// Проверка достижения концевого выключателя
				IF (xLeftActive AND NOT Dumper.fbEndSwitchLeft.qxSignal)
					OR (xRightActive AND NOT Dumper.fbEndSwitchRight.qxSignal)
				THEN
					// Концевик достигнут, автоматическая остановка
					nStoppingSubstage := 1;
				END_IF

			1: // STOP_VFD - Остановка VFD
				// Отключить команду пуска на VFD
				Dumper.MotorRotation[1].VFD.qxStart := FALSE;
				Dumper.MotorRotation[2].VFD.qxStart := FALSE;
				Dumper.MotorRotation[1].qxVFDReverseStart := FALSE;
				Dumper.MotorRotation[2].qxVFDReverseStart := FALSE;

				nStoppingSubstage := 2;

			2: // WAIT_VFD_STOP - Ожидание остановки VFD
				// Проверить обратную связь VFD о выключении
				IF NOT Dumper.MotorRotation[1].VFD.fbStateIsWorking.qxSignal
					AND NOT Dumper.MotorRotation[2].VFD.fbStateIsWorking.qxSignal
				THEN
					nStoppingSubstage := 3;
				END_IF

			3: // ACTIVATE_BRAKE - Активация тормоза с задержкой
				// Включение таймера на задержку тормоза (один раз)
				IF NOT xBrakeTimerStarted THEN
					xBrakeTimerStarted := TRUE;
				END_IF

				tonTimerEnableBrake(IN := xBrakeTimerStarted, PT := T#3S);

				IF tonTimerEnableBrake.Q THEN
					// Снять сигнал с тормоза (FALSE = активен)
					Dumper.qxBreakerRotation := FALSE;
					tonTimerEnableBrake(IN := FALSE);
					xBrakeTimerStarted := FALSE;

					// Сброс флагов направления
					xLeftActive := FALSE;
					xRightActive := FALSE;

					// Переход в IDLE
					STAGE := E_StageActuator.IDLE;
					nStoppingSubstage := 0;
				END_IF
		END_CASE;
END_CASE;

// ========================================
// ЗАДАНИЕ ЧАСТОТЫ МОТОРОВ
// ========================================

// Установка частоты напрямую в аналоговый выход VFD
// В режиме IDLE и при остановке частота = 0
// В режиме WORK частота = rTargetFrequency
IF STAGE = E_StageActuator.WORK THEN
	Dumper.MotorRotation[1].VFD.qrOutFrequency := rTargetFrequency;
	Dumper.MotorRotation[2].VFD.qrOutFrequency := rTargetFrequency;
ELSE
	Dumper.MotorRotation[1].VFD.qrOutFrequency := 0.0;
	Dumper.MotorRotation[2].VFD.qrOutFrequency := 0.0;
END_IF;

// ========================================
// ВЫХОДЫ
// ========================================

// Текущая стадия
eStage := STAGE;

// Текущая частота (среднее значение двух моторов)
rCurrentFrequency := (Dumper.MotorRotation[1].VFD.rActualFrequency
                    + Dumper.MotorRotation[2].VFD.rActualFrequency) / 2.0;

// Флаги активного поворота
xRotatingLeft := xLeftActive;
xRotatingRight := xRightActive;

END_FUNCTION_BLOCK
