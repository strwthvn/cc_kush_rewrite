FUNCTION_BLOCK FB_BunkerVibratorMotors
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
	xEmergencyStop : BOOL;              // Аварийная остановка
	xReset : BOOL;                      // Сброс ошибок
	eVibratorMode : E_StateRemote;      // Auto/Manual/Repair
	xManualStart : BOOL;                // СТАРТ в ручном режиме
	xManualStop : BOOL;                 // СТОП в ручном режиме
	xSelectedVibrators : ARRAY[1..4] OF BOOL;  // Выбор вибраторов (галочки)
	rTargetFrequency : REAL;            // Целевая частота
	stVibratorSettings : ST_BunkerVibratorSettings; // Параметры цикла
	xEnableAutoMode : BOOL;             // Разрешение автоматического режима (только в WORK вибропитателей)
END_VAR
VAR_OUTPUT
	eStage : E_StageActuator;           // IDLE/STARTING/WORK/STOPPING/FAULT
	xVibratorAutoActive : BOOL;         // Флаг активной работы (Auto)
	xVibratorManualRunActive : BOOL;    // Флаг активной работы (Manual)
END_VAR
VAR
	STAGE : E_StageActuator := E_StageActuator.IDLE;  // Текущая стадия
	tonVibratorActive : TON;            // Таймер активной работы (Auto)
	tonVibratorPause : TON;             // Таймер паузы (Auto)
	i : INT;
END_VAR

// ========================================
// FB_BunkerVibratorMotors - Управление вибраторами бункера
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Управление 4 вибраторами (0.62 кВт каждый)
// - 3 режима: Auto (цикл), Manual (выборочное управление), Repair (остановка)
// - Auto режим: ACTIVE (работа) ↔ PAUSE (пауза) циклически
// - Manual режим: индивидуальный выбор через галочки + СТАРТ/СТОП
// - Не знает про вибропитатели и верхнеуровневую логику
//
// ВХОДЫ:
// - xEmergencyStop: аварийная остановка
// - xReset: сброс ошибок
// - eVibratorMode: режим управления (Auto/Manual/Repair)
// - xManualStart: команда СТАРТ в ручном режиме
// - xManualStop: команда СТОП в ручном режиме
// - xSelectedVibrators[1..4]: выбор вибраторов (галочки)
// - rTargetFrequency: целевая частота (Гц)
// - stVibratorSettings: параметры цикла (TIME_ACTIVE, TIME_PAUSE_VIBRATOR и т.д.)
// - xEnableAutoMode: разрешение автоматического режима (TRUE только в WORK вибропитателей)
//
// ВЫХОДЫ:
// - eStage: текущая стадия (IDLE/STARTING/WORK/STOPPING/FAULT)
// - xVibratorAutoActive: флаг активной работы в авто режиме
// - xVibratorManualRunActive: флаг активной работы в ручном режиме
//
// ========================================

// ========================================
// ПРИОРИТЕТНАЯ ОБРАБОТКА АВАРИЙНОЙ ОСТАНОВКИ
// ========================================

IF xEmergencyStop THEN
	// Остановка всех VFD вибраторов
	Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
	Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
	Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
	Bunker.MotorVibrator[4].VFD.qxStart := FALSE;

	// Сброс таймеров и флагов
	tonVibratorActive(IN := FALSE);
	tonVibratorPause(IN := FALSE);
	xVibratorManualRunActive := FALSE;
	xVibratorAutoActive := FALSE;

	// Переход в FAULT
	STAGE := E_StageActuator.FAULT;
END_IF

// ========================================
// НОРМАЛЬНАЯ РАБОТА ВИБРАТОРОВ
// ========================================

IF NOT xEmergencyStop THEN
	CASE eVibratorMode OF
		// ========================================
		// РЕЖИМ АВТОМАТИЧЕСКИЙ - циклическая работа по таймеру
		// ========================================
		E_StateRemote.Auto:
			// Автоматический режим работает только при разрешении (в WORK вибропитателей)
			IF xEnableAutoMode THEN
				// Установка частоты для вибраторов в автоматическом режиме
				FOR i := 1 TO AMOUNT_BUNKER_MOTOR_VIBRATOR BY 1 DO
					Bunker.MotorVibrator[i].VFD.qrOutFrequency := rTargetFrequency;
				END_FOR;

				// Таймеры автоматического цикла
				tonVibratorActive(PT := stVibratorSettings.TIME_ACTIVE);
				tonVibratorPause(PT := stVibratorSettings.TIME_PAUSE_VIBRATOR);

				// Логика автоматического цикла (ACTIVE ↔ PAUSE)
				IF NOT xVibratorAutoActive THEN
					// Состояние PAUSE - ждем окончания паузы
					IF tonVibratorPause.Q THEN
						// Пауза завершена - переход в ACTIVE
						tonVibratorPause(IN := FALSE);
						tonVibratorActive(IN := TRUE);
						xVibratorAutoActive := TRUE;

						// Запуск всех вибраторов
						Bunker.MotorVibrator[1].VFD.qxStart := TRUE;
						Bunker.MotorVibrator[2].VFD.qxStart := TRUE;
						Bunker.MotorVibrator[3].VFD.qxStart := TRUE;
						Bunker.MotorVibrator[4].VFD.qxStart := TRUE;

						// Переход в WORK
						STAGE := E_StageActuator.WORK;
					ELSIF NOT tonVibratorPause.IN THEN
						// Первый запуск - сразу в ACTIVE
						tonVibratorActive(IN := TRUE);
						xVibratorAutoActive := TRUE;

						// Запуск всех вибраторов
						Bunker.MotorVibrator[1].VFD.qxStart := TRUE;
						Bunker.MotorVibrator[2].VFD.qxStart := TRUE;
						Bunker.MotorVibrator[3].VFD.qxStart := TRUE;
						Bunker.MotorVibrator[4].VFD.qxStart := TRUE;

						// Переход в WORK
						STAGE := E_StageActuator.WORK;
					ELSE
						// Пауза активна - IDLE
						STAGE := E_StageActuator.IDLE;
					END_IF;
				ELSE
					// Состояние ACTIVE - ждем окончания активной работы
					IF tonVibratorActive.Q THEN
						// Активная работа завершена - переход в PAUSE
						tonVibratorActive(IN := FALSE);
						tonVibratorPause(IN := TRUE);
						xVibratorAutoActive := FALSE;

						// Остановка всех вибраторов
						Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
						Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
						Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
						Bunker.MotorVibrator[4].VFD.qxStart := FALSE;

						// Переход в IDLE (пауза)
						STAGE := E_StageActuator.IDLE;
					ELSE
						// Активная работа - WORK
						STAGE := E_StageActuator.WORK;
					END_IF;
				END_IF;
			ELSE
				// Вне WORK вибропитателей - остановка автоматического цикла
				tonVibratorActive(IN := FALSE);
				tonVibratorPause(IN := FALSE);
				xVibratorAutoActive := FALSE;

				// Остановка всех вибраторов
				Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
				Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
				Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
				Bunker.MotorVibrator[4].VFD.qxStart := FALSE;

				// Переход в IDLE
				STAGE := E_StageActuator.IDLE;
			END_IF;

		// ========================================
		// РЕЖИМ РУЧНОЙ - индивидуальное управление через выбор + старт/стоп
		// ========================================
		E_StateRemote.Manual:
			// Команда СТАРТ активирует флаг запуска
			IF xManualStart THEN
				xVibratorManualRunActive := TRUE;
			END_IF

			// Команда СТОП останавливает ВСЕ вибраторы и сбрасывает флаг
			IF xManualStop THEN
				xVibratorManualRunActive := FALSE;
				Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
				Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
				Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
				Bunker.MotorVibrator[4].VFD.qxStart := FALSE;
			END_IF

			// Если флаг запуска активен - управляем вибраторами через галочки выбора
			IF xVibratorManualRunActive THEN
				// Каждый вибратор работает только если он выбран (галочка установлена)
				Bunker.MotorVibrator[1].VFD.qxStart := xSelectedVibrators[1];
				Bunker.MotorVibrator[2].VFD.qxStart := xSelectedVibrators[2];
				Bunker.MotorVibrator[3].VFD.qxStart := xSelectedVibrators[3];
				Bunker.MotorVibrator[4].VFD.qxStart := xSelectedVibrators[4];

				// Проверка: хотя бы один вибратор выбран → WORK
				IF xSelectedVibrators[1] OR xSelectedVibrators[2] OR xSelectedVibrators[3] OR xSelectedVibrators[4] THEN
					STAGE := E_StageActuator.WORK;
				ELSE
					STAGE := E_StageActuator.IDLE;
				END_IF;
			ELSE
				// Флаг запуска неактивен - IDLE
				STAGE := E_StageActuator.IDLE;
			END_IF

			// Установка частоты для вибраторов в ручном режиме
			FOR i := 1 TO AMOUNT_BUNKER_MOTOR_VIBRATOR BY 1 DO
				Bunker.MotorVibrator[i].VFD.qrOutFrequency := rTargetFrequency;
			END_FOR;

		// ========================================
		// РЕЖИМ РЕМОНТ - все вибраторы остановлены
		// ========================================
		E_StateRemote.Repair:
			xVibratorManualRunActive := FALSE;
			xVibratorAutoActive := FALSE;
			Bunker.MotorVibrator[1].VFD.qxStart := FALSE;
			Bunker.MotorVibrator[2].VFD.qxStart := FALSE;
			Bunker.MotorVibrator[3].VFD.qxStart := FALSE;
			Bunker.MotorVibrator[4].VFD.qxStart := FALSE;

			// Режим ремонт - IDLE
			STAGE := E_StageActuator.IDLE;
	END_CASE
END_IF; // Конец IF NOT xEmergencyStop

// ========================================
// ВЫХОД ИЗ FAULT ПО КОМАНДЕ СБРОСА
// ========================================

IF STAGE = E_StageActuator.FAULT AND xReset THEN
	STAGE := E_StageActuator.IDLE;
END_IF

// ========================================
// ВЫХОДЫ
// ========================================

eStage := STAGE;

END_FUNCTION_BLOCK
