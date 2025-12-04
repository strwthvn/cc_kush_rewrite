FUNCTION_BLOCK FB_PneumoCollapseControl
VAR_INPUT
	xEnable : BOOL; // Разрешение работы блока (TRUE - автоматический режим)
	xManualStart : BOOL; // Сигнал ручного запуска системы
	tActiveTime : TIME := T#3S; // Время активной работы пневмообрушения
	tPauseCycle : TIME := T#5S; // Время паузы между циклами
	tPauseFB : TIME := T#30S; // Время паузы ФБ между подходами
	nCycleCount : INT := 3; // Количество срабатываний в одном подходе
END_VAR
VAR_OUTPUT
	xPneumoActive : BOOL; // Сигнал управления системой пневмообрушения
	tTimeToNext : TIME; // Время до следующего срабатывания
END_VAR
VAR
	// Внутренние состояния
	eState : E_VibratorState := E_VibratorState.IDLE; // Текущее состояние автоматического цикла
	nCurrentCycle : INT := 0; // Текущий счётчик срабатываний

	// Таймеры
	tonActiveWork : TON; // Таймер активной работы
	tonPauseCycle : TON; // Таймер паузы между циклами
	tonPauseFB : TON; // Таймер паузы ФБ

	// Вспомогательные переменные
	_xManualStartPrev : BOOL; // Предыдущее состояние ручного пуска
	_rtManualStart : R_TRIG; // Детектор фронта ручного пуска
END_VAR

// ========================================
// ДЕТЕКТОР ФРОНТА РУЧНОГО ПУСКА
// ========================================
_rtManualStart(CLK := xManualStart);

// ========================================
// РУЧНОЙ РЕЖИМ УПРАВЛЕНИЯ
// ========================================
IF xManualStart THEN
	// Остановить все таймеры автоматического цикла
	tonActiveWork(IN := FALSE);
	tonPauseCycle(IN := FALSE);
	tonPauseFB(IN := FALSE);

	// Сбросить состояние в IDLE при ручном управлении
	IF NOT _xManualStartPrev THEN
		eState := E_VibratorState.IDLE;
		nCurrentCycle := 0;
	END_IF

	// Ручной запуск системы пневмообрушения
	xPneumoActive := TRUE;

ELSE
	// ========================================
	// АВТОМАТИЧЕСКИЙ РЕЖИМ УПРАВЛЕНИЯ
	// ========================================

	IF NOT xEnable THEN
		// Если Enable выключен - остановить систему и сбросить состояние
		xPneumoActive := FALSE;

		// Сброс состояния
		eState := E_VibratorState.IDLE;
		nCurrentCycle := 0;
		tonActiveWork(IN := FALSE);
		tonPauseCycle(IN := FALSE);
		tonPauseFB(IN := FALSE);

	ELSE
		// Автоматический цикл работы
		CASE eState OF
			E_VibratorState.IDLE:
				// Ожидание старта автоматического цикла
				nCurrentCycle := 0;
				tonActiveWork(IN := FALSE);
				tonPauseCycle(IN := FALSE);
				tonPauseFB(IN := FALSE);
				xPneumoActive := FALSE;

				// Автоматический старт при наличии Enable
				eState := E_VibratorState.ACTIVE_WORK;

			E_VibratorState.ACTIVE_WORK:
				// Активная работа системы пневмообрушения
				tonActiveWork(IN := TRUE, PT := tActiveTime);
				tonPauseCycle(IN := FALSE);
				tonPauseFB(IN := FALSE);

				// Включение системы
				xPneumoActive := TRUE;

				// Переход в паузу после окончания времени активной работы
				IF tonActiveWork.Q THEN
					tonActiveWork(IN := FALSE);
					nCurrentCycle := nCurrentCycle + 1;

					IF nCurrentCycle >= nCycleCount THEN
						// Достигнуто максимальное количество циклов - переход в паузу ФБ
						eState := E_VibratorState.PAUSE_FB;
					ELSE
						// Ещё не достигнуто - переход в паузу между циклами
						eState := E_VibratorState.PAUSE_VIBRATOR;
					END_IF
				END_IF

			E_VibratorState.PAUSE_VIBRATOR:
				// Пауза между циклами
				tonActiveWork(IN := FALSE);
				tonPauseCycle(IN := TRUE, PT := tPauseCycle);
				tonPauseFB(IN := FALSE);

				// Остановка системы
				xPneumoActive := FALSE;

				// Переход обратно в активную работу после паузы
				IF tonPauseCycle.Q THEN
					tonPauseCycle(IN := FALSE);
					eState := E_VibratorState.ACTIVE_WORK;
				END_IF

			E_VibratorState.PAUSE_FB:
				// Пауза между подходами (после достижения nCycleCount)
				tonActiveWork(IN := FALSE);
				tonPauseCycle(IN := FALSE);
				tonPauseFB(IN := TRUE, PT := tPauseFB);

				// Остановка системы
				xPneumoActive := FALSE;

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
// РАСЧЁТ ВРЕМЕНИ ДО СЛЕДУЮЩЕГО СРАБАТЫВАНИЯ
// ========================================
CASE eState OF
	E_VibratorState.IDLE:
		tTimeToNext := T#0S;

	E_VibratorState.ACTIVE_WORK:
		tTimeToNext := tActiveTime - tonActiveWork.ET;

	E_VibratorState.PAUSE_VIBRATOR:
		tTimeToNext := tPauseCycle - tonPauseCycle.ET;

	E_VibratorState.PAUSE_FB:
		tTimeToNext := tPauseFB - tonPauseFB.ET;
END_CASE

// Сохранение предыдущего состояния ручного пуска
_xManualStartPrev := xManualStart;

END_FUNCTION_BLOCK