FUNCTION_BLOCK FB_VibratorControl
VAR_INPUT
	MotorVibrator : REFERENCE TO ARRAY [1..4] OF ST_Motor; // Массив моторов вибраторов
	Bunker : REFERENCE TO ST_Bunker; // Ссылка на бункер для доступа к режиму управления
	xEnable : BOOL; // Разрешение работы блока (TRUE - автоматический режим)
	xManualStart : BOOL; // Сигнал ручного запуска моторов
	rWorkingFrequency : REAL := 50.0; // Частота работы мотора в автоматическом режиме (Гц)
	irManualFrequency : REAL := 30.0; // Частота работы мотора в ручном режиме (Гц)
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
// ПРИМЕЧАНИЕ: Управление контакторами перенесено в FB_BunkerControl
// ========================================
// Здесь управляем только VFD (частотой и командами ПУСК/СТОП)

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

	// Ручной запуск моторов (контакторы управляются в FB_BunkerControl)
	FOR i := 1 TO 4 BY 1 DO
		// Проверяем, включен ли вибратор через cmdAddVib
		CASE i OF
			1: IF Bunker.cmdAddVib1 THEN
				MotorVibrator[i].VFD.qxStart := TRUE;
				// Выбор частоты в зависимости от режима управления бункера
				IF Bunker.eStateRemote = E_StateRemote.Manual THEN
					MotorVibrator[i].VFD.qrOutFrequency := irManualFrequency;
				ELSE
					MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
				END_IF;
			ELSE
				MotorVibrator[i].VFD.qxStart := FALSE;
				MotorVibrator[i].VFD.qrOutFrequency := 0.0;
			END_IF;

			2: IF Bunker.cmdAddVib2 THEN
				MotorVibrator[i].VFD.qxStart := TRUE;
				IF Bunker.eStateRemote = E_StateRemote.Manual THEN
					MotorVibrator[i].VFD.qrOutFrequency := irManualFrequency;
				ELSE
					MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
				END_IF;
			ELSE
				MotorVibrator[i].VFD.qxStart := FALSE;
				MotorVibrator[i].VFD.qrOutFrequency := 0.0;
			END_IF;

			3: IF Bunker.cmdAddVib3 THEN
				MotorVibrator[i].VFD.qxStart := TRUE;
				IF Bunker.eStateRemote = E_StateRemote.Manual THEN
					MotorVibrator[i].VFD.qrOutFrequency := irManualFrequency;
				ELSE
					MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
				END_IF;
			ELSE
				MotorVibrator[i].VFD.qxStart := FALSE;
				MotorVibrator[i].VFD.qrOutFrequency := 0.0;
			END_IF;

			4: IF Bunker.cmdAddVib4 THEN
				MotorVibrator[i].VFD.qxStart := TRUE;
				IF Bunker.eStateRemote = E_StateRemote.Manual THEN
					MotorVibrator[i].VFD.qrOutFrequency := irManualFrequency;
				ELSE
					MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
				END_IF;
			ELSE
				MotorVibrator[i].VFD.qxStart := FALSE;
				MotorVibrator[i].VFD.qrOutFrequency := 0.0;
			END_IF;
		END_CASE;
	END_FOR

ELSE
	// ========================================
	// АВТОМАТИЧЕСКИЙ РЕЖИМ УПРАВЛЕНИЯ
	// ========================================

	IF xEnable THEN
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

				// Запуск выбранных моторов
				FOR i := 1 TO 4 BY 1 DO
					// Проверяем, включен ли вибратор через cmdAddVib
					CASE i OF
						1: IF Bunker.cmdAddVib1 THEN
							MotorVibrator[i].VFD.qxStart := TRUE;
							IF Bunker.eStateRemote = E_StateRemote.Manual THEN
								MotorVibrator[i].VFD.qrOutFrequency := irManualFrequency;
							ELSE
								MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
							END_IF;
						ELSE
							MotorVibrator[i].VFD.qxStart := FALSE;
							MotorVibrator[i].VFD.qrOutFrequency := 0.0;
						END_IF;

						2: IF Bunker.cmdAddVib2 THEN
							MotorVibrator[i].VFD.qxStart := TRUE;
							IF Bunker.eStateRemote = E_StateRemote.Manual THEN
								MotorVibrator[i].VFD.qrOutFrequency := irManualFrequency;
							ELSE
								MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
							END_IF;
						ELSE
							MotorVibrator[i].VFD.qxStart := FALSE;
							MotorVibrator[i].VFD.qrOutFrequency := 0.0;
						END_IF;

						3: IF Bunker.cmdAddVib3 THEN
							MotorVibrator[i].VFD.qxStart := TRUE;
							IF Bunker.eStateRemote = E_StateRemote.Manual THEN
								MotorVibrator[i].VFD.qrOutFrequency := irManualFrequency;
							ELSE
								MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
							END_IF;
						ELSE
							MotorVibrator[i].VFD.qxStart := FALSE;
							MotorVibrator[i].VFD.qrOutFrequency := 0.0;
						END_IF;

						4: IF Bunker.cmdAddVib4 THEN
							MotorVibrator[i].VFD.qxStart := TRUE;
							IF Bunker.eStateRemote = E_StateRemote.Manual THEN
								MotorVibrator[i].VFD.qrOutFrequency := irManualFrequency;
							ELSE
								MotorVibrator[i].VFD.qrOutFrequency := rWorkingFrequency;
							END_IF;
						ELSE
							MotorVibrator[i].VFD.qxStart := FALSE;
							MotorVibrator[i].VFD.qrOutFrequency := 0.0;
						END_IF;
					END_CASE;
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

				// Остановка всех ЧРП
				FOR i := 1 TO 4 BY 1 DO
					MotorVibrator[i].VFD.qxStart := FALSE;
					MotorVibrator[i].VFD.qrOutFrequency := 0.0;
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

				// Остановка всех ЧРП
				FOR i := 1 TO 4 BY 1 DO
					MotorVibrator[i].VFD.qxStart := FALSE;
					MotorVibrator[i].VFD.qrOutFrequency := 0.0;
				END_FOR

				// Переход в IDLE после паузы и сброс счётчика
				IF tonPauseFB.Q THEN
					tonPauseFB(IN := FALSE);
					nCurrentCycle := 0;
					eState := E_VibratorState.IDLE;
				END_IF
		END_CASE

	ELSE
		// xEnable = FALSE И xManualStart = FALSE - полная остановка
		FOR i := 1 TO 4 BY 1 DO
			MotorVibrator[i].VFD.qxStart := FALSE;
			MotorVibrator[i].VFD.qrOutFrequency := 0.0;
		END_FOR

		// Сброс состояния
		eState := E_VibratorState.IDLE;
		nCurrentCycle := 0;
		tonActiveWork(IN := FALSE);
		tonPauseVibrator(IN := FALSE);
		tonPauseFB(IN := FALSE);
	END_IF
END_IF

// ========================================
// ФОРМИРОВАНИЕ ВЫХОДОВ
// ========================================

// Проверка работы хотя бы одного мотора (по обратной связи VFD)
xAnyMotorActive := FALSE;
FOR i := 1 TO 4 BY 1 DO
	IF MotorVibrator[i].VFD.fbStateIsWorking.qxSignal THEN
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