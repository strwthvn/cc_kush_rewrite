FUNCTION_BLOCK FB_BunkerVibFeederMotors
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
	xStart : BOOL;              // Команда запуска
	xStop : BOOL;               // Команда остановки
	xEmergencyStop : BOOL;      // Аварийная остановка
	xReset : BOOL;              // Сброс ошибок
	rTargetFrequency : REAL;    // Целевая частота (Гц)
END_VAR
VAR_OUTPUT
	eStage : E_StageActuator;   // IDLE/STARTING/WORK/STOPPING/FAULT
	rCurrentFrequency : REAL;   // Средняя частота двух моторов
	xStartingTimeout : BOOL;    // Флаг тайм-аута запуска
	xStoppingTimeout : BOOL;    // Флаг тайм-аута остановки
END_VAR
VAR
	STAGE : E_StageActuator := E_StageActuator.IDLE;

	// Таймеры контроля времени запуска/остановки
	tonTimerStarting : TON;     // Контроль времени запуска (STARTING → WORK)
	tonTimerStopping : TON;     // Контроль времени остановки (STOPPING → IDLE)
END_VAR

// ========================================
// FB_BunkerVibFeederMotors - Управление моторами вибропитателей бункера
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Управление двумя вибропитателями (7.5 кВт каждый)
// - Прямой пуск/остановка (без плавного разгона)
// - Не знает про ППЗ и верхнеуровневую логику
// - Просто выполняет команды START/STOP
//
// ВХОДЫ:
// - xStart: команда запуска моторов
// - xStop: команда остановки моторов
// - xEmergencyStop: аварийная остановка
// - xReset: сброс аварии
// - rTargetFrequency: целевая частота (Гц)
//
// ВЫХОДЫ:
// - eStage: текущая стадия (IDLE/STARTING/WORK/STOPPING/FAULT)
// - rCurrentFrequency: текущая частота моторов (среднее)
// - xStartingTimeout: флаг тайм-аута запуска
// - xStoppingTimeout: флаг тайм-аута остановки
//
// ========================================

// ========================================
// ПРИОРИТЕТНАЯ ОБРАБОТКА АВАРИЙНОЙ ОСТАНОВКИ
// ========================================

IF xEmergencyStop THEN
	// Аварийная остановка: немедленное выключение VFD
	Bunker.MotorVibFeeder[1].VFD.qxStart := FALSE;
	Bunker.MotorVibFeeder[2].VFD.qxStart := FALSE;

	// Переход в FAULT
	STAGE := E_StageActuator.FAULT;
	tonTimerStarting(IN := FALSE);
	tonTimerStopping(IN := FALSE);
END_IF

// ========================================
// ПРОВЕРКА ТАЙМ-АУТОВ ВЫПОЛНЕНИЯ КОМАНД
// ========================================

// Тайм-аут запуска: если слишком долго в STARTING → аварийная остановка
tonTimerStarting(
	IN := (STAGE = E_StageActuator.STARTING),
	PT := TIME_TIMEOUT_START_BUNKER
);

IF tonTimerStarting.Q THEN
	xStartingTimeout := TRUE;
	// Аварийная остановка: немедленное выключение VFD
	Bunker.MotorVibFeeder[1].VFD.qxStart := FALSE;
	Bunker.MotorVibFeeder[2].VFD.qxStart := FALSE;
	// Переход в FAULT
	STAGE := E_StageActuator.FAULT;
	tonTimerStarting(IN := FALSE);
END_IF

// Тайм-аут остановки: если слишком долго в STOPPING → аварийная остановка
tonTimerStopping(
	IN := (STAGE = E_StageActuator.STOPPING),
	PT := TIME_TIMEOUT_STOP_BUNKER
);

IF tonTimerStopping.Q THEN
	xStoppingTimeout := TRUE;
	// Аварийная остановка: немедленное выключение VFD
	Bunker.MotorVibFeeder[1].VFD.qxStart := FALSE;
	Bunker.MotorVibFeeder[2].VFD.qxStart := FALSE;
	// Переход в FAULT
	STAGE := E_StageActuator.FAULT;
	tonTimerStopping(IN := FALSE);
END_IF

// ========================================
// АВТОМАТ УПРАВЛЕНИЯ МОТОРАМИ
// ========================================

CASE STAGE OF
	E_StageActuator.IDLE:
		// Сброс команд
		Bunker.MotorVibFeeder[1].VFD.qxStart := FALSE;
		Bunker.MotorVibFeeder[2].VFD.qxStart := FALSE;

		// Команда запуска
		IF xStart AND NOT xEmergencyStop THEN
			STAGE := E_StageActuator.STARTING;
		END_IF

	E_StageActuator.STARTING:
		// Проверка команды остановки во время запуска
		IF xStop THEN
			// Прервать запуск и перейти к остановке
			STAGE := E_StageActuator.STOPPING;
		END_IF

		// Команда ПУСК на VFD
		Bunker.MotorVibFeeder[1].VFD.qxStart := TRUE;
		Bunker.MotorVibFeeder[2].VFD.qxStart := TRUE;

		// Проверка обратной связи VFD
		IF Bunker.MotorVibFeeder[1].VFD.fbStateIsWorking.qxSignal
		   AND Bunker.MotorVibFeeder[2].VFD.fbStateIsWorking.qxSignal
		THEN
			// Сброс таймера запуска (успешный запуск)
			tonTimerStarting(IN := FALSE);
			STAGE := E_StageActuator.WORK;
		END_IF

	E_StageActuator.WORK:
		// Нормальная работа
		// Команда остановки - переход в STOPPING
		IF xStop THEN
			STAGE := E_StageActuator.STOPPING;
		END_IF

	E_StageActuator.STOPPING:
		// Остановка VFD
		Bunker.MotorVibFeeder[1].VFD.qxStart := FALSE;
		Bunker.MotorVibFeeder[2].VFD.qxStart := FALSE;

		// Проверка остановки VFD (обратная связь)
		IF NOT Bunker.MotorVibFeeder[1].VFD.fbStateIsWorking.qxSignal
		   AND NOT Bunker.MotorVibFeeder[2].VFD.fbStateIsWorking.qxSignal
		THEN
			// Сброс таймера остановки (успешная остановка)
			tonTimerStopping(IN := FALSE);
			STAGE := E_StageActuator.IDLE;
		END_IF

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

// Установка частоты напрямую (без плавного разгона)
// В режимах STARTING и WORK частота = rTargetFrequency
// В остальных режимах (IDLE, STOPPING, FAULT) частота = 0
IF STAGE = E_StageActuator.STARTING OR STAGE = E_StageActuator.WORK THEN
	Bunker.MotorVibFeeder[1].VFD.qrOutFrequency := rTargetFrequency;
	Bunker.MotorVibFeeder[2].VFD.qrOutFrequency := rTargetFrequency;
ELSE
	Bunker.MotorVibFeeder[1].VFD.qrOutFrequency := 0.0;
	Bunker.MotorVibFeeder[2].VFD.qrOutFrequency := 0.0;
END_IF;

// ========================================
// ВЫХОДЫ
// ========================================

// Текущая стадия
eStage := STAGE;

// Текущая частота (среднее значение двух моторов)
rCurrentFrequency := (Bunker.MotorVibFeeder[1].VFD.rActualFrequency
                    + Bunker.MotorVibFeeder[2].VFD.rActualFrequency) / 2.0;

END_FUNCTION_BLOCK
