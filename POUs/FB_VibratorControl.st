FUNCTION_BLOCK FB_VibratorControl
VAR_INPUT
	MotorVibrator : REFERENCE TO ARRAY [1..4] OF ST_Motor; // Массив моторов вибраторов
	xEnable : BOOL; // Разрешение работы блока (TRUE - автоматический режим)
	xManualStart : BOOL; // Сигнал ручного запуска моторов
	rWorkingFrequency : REAL := 50.0; // Частота работы мотора (Гц)
	tActiveTime : TIME := T#10S; // Время активной работы вибратора
	tPauseVibrator : TIME := T#5S; // Время паузы вибратора между циклами
	tPauseFB : TIME := T#30S; // Время паузы ФБ между подходами
	nCycleCount : INT := 3; // Количество срабатываний в одном подходе
END_VAR
VAR_OUTPUT
	xMotorsWorking : BOOL; // Моторы в работе (TRUE если хотя бы один мотор работает)
	tTimeToNext : TIME; // Время до следующего срабатывания мотора
END_VAR
VAR
	// Внутренние состояния
	eState : E_VibratorState := E_VibratorState.IDLE; // Текущее состояние автоматического цикла
	nCurrentCycle : INT := 0; // Текущий счётчик срабатываний

	// Таймеры
	tonActiveWork : TON; // Таймер активной работы
	tonPauseVibrator : TON; // Таймер паузы вибратора
	tonPauseFB : TON; // Таймер паузы ФБ

	// Вспомогательные переменные
	i : INT; // Счётчик для циклов
	xAnyMotorActive : BOOL; // Хотя бы один мотор активен
	_xManualStartPrev : BOOL; // Предыдущее состояние ручного пуска
	_rtManualStart : R_TRIG; // Детектор фронта ручного пуска
END_VAR

// ========================================
// ДЕТЕКТОР ФРОНТА РУЧНОГО ПУСКА
// ========================================
_rtManualStart(CLK := xManualStart);

// ========================================
// УПРАВЛЕНИЕ КОНТАКТОРАМИ МОТОРОВ
// ========================================
// Контакторы включены при наличии Enable ИЛИ при ручном запуске
FOR i := 1 TO 4 BY 1 DO
	// Условия для запуска (QF включен, нет ошибок)
	MotorVibrator[i].Device.xStartCondition := MotorVibrator[i].fbStateQF.qxSignal;
	MotorVibrator[i].Device.xStopCondition := TRUE;

	// Команда запуска контактора
	IF xEnable OR xManualStart THEN
		// Enable = TRUE: контакторы всегда включены
		// Enable = FALSE + ManualStart = TRUE: контакторы включаются для ручного запуска
		MotorVibrator[i].Device.xStartCommand := TRUE;
		MotorVibrator[i].Device.xStopCommand := FALSE;
	ELSE
		// Enable = FALSE + ManualStart = FALSE: контакторы выключены
		MotorVibrator[i].Device.xStartCommand := FALSE;
		MotorVibrator[i].Device.xStopCommand := TRUE;
	END_IF

	// Применение выходов контактора
	MotorVibrator[i].qxKM_Power := MotorVibrator[i].Device.qxPower;

	// Условия для ЧРП
	MotorVibrator[i].VFD.Device.xStartCondition := MotorVibrator[i].VFD.fbStateRdyToStart.qxSignal
	                                             AND NOT MotorVibrator[i].VFD.fbStateFailure.qxSignal;
	MotorVibrator[i].VFD.Device.xStopCondition := TRUE;
END_FOR

// ========================================
// РУЧНОЙ РЕЖИМ УПРАВЛЕНИЯ
// ========================================
IF xManualStart THEN
	// Остановить все таймеры автоматического цикла
	tonActiveWork(IN := FALSE);
	tonPauseVibrator(IN := FALSE);
	tonPauseFB(IN := FALSE);

	// Сбросить состояние в IDLE при ручном управлении
	IF NOT _xManualStartPrev THEN
		eState := E_VibratorState.IDLE;
		nCurrentCycle := 0;
	END_IF

	// Ручной запуск моторов (контакторы уже управляются выше)
	// При ручном запуске даём ПУСК на ЧРП после того как контактор активен
	FOR i := 1 TO 4 BY 1 DO
		// ПУСК на ЧРП когда контактор активен (Device.qxActive)
		MotorVibrator[i].VFD.Device.xStartCommand := MotorVibrator[i].Device.qxActive;
		MotorVibrator[i].VFD.Device.xStopCommand := FALSE;

		// Прямая установка частоты
		MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
		MotorVibrator[i].VFD.qxStart := MotorVibrator[i].VFD.Device.qxPower;
	END_FOR

ELSE
	// ========================================
	// АВТОМАТИЧЕСКИЙ РЕЖИМ УПРАВЛЕНИЯ
	// ========================================

	IF NOT xEnable THEN
		// Если Enable выключен - остановить все ЧРП и сбросить состояние
		// (контакторы уже управляются выше)
		FOR i := 1 TO 4 BY 1 DO
			MotorVibrator[i].VFD.Device.xStartCommand := FALSE;
			MotorVibrator[i].VFD.Device.xStopCommand := TRUE;
			MotorVibrator[i].VFD.qrOutFrequency := 0.0;
			MotorVibrator[i].VFD.qxStart := MotorVibrator[i].VFD.Device.qxPower;
		END_FOR

		// Сброс состояния
		eState := E_VibratorState.IDLE;
		nCurrentCycle := 0;
		tonActiveWork(IN := FALSE);
		tonPauseVibrator(IN := FALSE);
		tonPauseFB(IN := FALSE);

	ELSE
		// Автоматический цикл работы
		CASE eState OF
			E_VibratorState.IDLE:
				// Ожидание старта автоматического цикла
				nCurrentCycle := 0;
				tonActiveWork(IN := FALSE);
				tonPauseVibrator(IN := FALSE);
				tonPauseFB(IN := FALSE);

				// Автоматический старт при наличии Enable
				eState := E_VibratorState.ACTIVE_WORK;

			E_VibratorState.ACTIVE_WORK:
				// Активная работа вибраторов
				tonActiveWork(IN := TRUE, PT := tActiveTime);
				tonPauseVibrator(IN := FALSE);
				tonPauseFB(IN := FALSE);

				// Запуск всех моторов (контакторы уже включены, т.к. Enable = TRUE)
				FOR i := 1 TO 4 BY 1 DO
					// ПУСК на ЧРП когда контактор активен
					MotorVibrator[i].VFD.Device.xStartCommand := MotorVibrator[i].Device.qxActive;
					MotorVibrator[i].VFD.Device.xStopCommand := FALSE;

					// Прямая установка частоты (без плавного разгона)
					MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
					MotorVibrator[i].VFD.qxStart := MotorVibrator[i].VFD.Device.qxPower;
				END_FOR

				// Переход в паузу после окончания времени активной работы
				IF tonActiveWork.Q THEN
					tonActiveWork(IN := FALSE);
					nCurrentCycle := nCurrentCycle + 1;

					IF nCurrentCycle >= nCycleCount THEN
						// Достигнуто максимальное количество циклов - переход в паузу ФБ
						eState := E_VibratorState.PAUSE_FB;
					ELSE
						// Ещё не достигнуто - переход в паузу вибратора
						eState := E_VibratorState.PAUSE_VIBRATOR;
					END_IF
				END_IF

			E_VibratorState.PAUSE_VIBRATOR:
				// Пауза между циклами вибратора
				tonActiveWork(IN := FALSE);
				tonPauseVibrator(IN := TRUE, PT := tPauseVibrator);
				tonPauseFB(IN := FALSE);

				// Остановка всех ЧРП (контакторы остаются включёнными, т.к. Enable = TRUE)
				FOR i := 1 TO 4 BY 1 DO
					MotorVibrator[i].VFD.Device.xStartCommand := FALSE;
					MotorVibrator[i].VFD.Device.xStopCommand := TRUE;
					MotorVibrator[i].VFD.qrOutFrequency := 0.0;
					MotorVibrator[i].VFD.qxStart := MotorVibrator[i].VFD.Device.qxPower;
				END_FOR

				// Переход обратно в активную работу после паузы
				IF tonPauseVibrator.Q THEN
					tonPauseVibrator(IN := FALSE);
					eState := E_VibratorState.ACTIVE_WORK;
				END_IF

			E_VibratorState.PAUSE_FB:
				// Пауза между подходами (после достижения nCycleCount)
				tonActiveWork(IN := FALSE);
				tonPauseVibrator(IN := FALSE);
				tonPauseFB(IN := TRUE, PT := tPauseFB);

				// Остановка всех ЧРП (контакторы остаются включёнными, т.к. Enable = TRUE)
				FOR i := 1 TO 4 BY 1 DO
					MotorVibrator[i].VFD.Device.xStartCommand := FALSE;
					MotorVibrator[i].VFD.Device.xStopCommand := TRUE;
					MotorVibrator[i].VFD.qrOutFrequency := 0.0;
					MotorVibrator[i].VFD.qxStart := MotorVibrator[i].VFD.Device.qxPower;
				END_FOR

				// Переход в IDLE после паузы и сброс счётчика
				IF tonPauseFB.Q THEN
					tonPauseFB(IN := FALSE);
					nCurrentCycle := 0;
					eState := E_VibratorState.IDLE;
				END_IF
		END_CASE
	END_IF
END_IF

// ========================================
// ФОРМИРОВАНИЕ ВЫХОДОВ
// ========================================

// Проверка работы хотя бы одного мотора
xAnyMotorActive := FALSE;
FOR i := 1 TO 4 BY 1 DO
	IF MotorVibrator[i].VFD.Device.qxActive THEN
		xAnyMotorActive := TRUE;
	END_IF
END_FOR
xMotorsWorking := xAnyMotorActive;

// Расчёт времени до следующего срабатывания
CASE eState OF
	E_VibratorState.IDLE:
		tTimeToNext := T#0S;

	E_VibratorState.ACTIVE_WORK:
		tTimeToNext := tActiveTime - tonActiveWork.ET;

	E_VibratorState.PAUSE_VIBRATOR:
		tTimeToNext := tPauseVibrator - tonPauseVibrator.ET;

	E_VibratorState.PAUSE_FB:
		tTimeToNext := tPauseFB - tonPauseFB.ET;
END_CASE

// Сохранение предыдущего состояния ручного пуска
_xManualStartPrev := xManualStart;

END_FUNCTION_BLOCK