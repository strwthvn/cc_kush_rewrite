 FUNCTION_BLOCK FB_Simulation
VAR_INPUT
	xEnable : BOOL; // Включение симуляции
	xReset : BOOL; // Сброс всех переменных (симуляция отсутствия ошибок)
	Dumper : REFERENCE TO ST_Dumper; // Структура отвалообразователя
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated; // Структура сборного конвейера
	Bunker : REFERENCE TO ARRAY[1..3] OF ST_Bunker; // Массив бункеров
	tFeedbackDelay : TIME := T#500MS; // Задержка обратной связи
END_VAR
VAR
	// Детекция переднего фронта
	rtEnable : R_TRIG;
	rtReset : R_TRIG;

	// Флаг инициализации
	_xInitRequired : BOOL;

	// Индексы для циклов
	b, m : INT;

	// === Таймеры отвалообразователя ===
	// Таймеры обратной связи контакторов (KM)
	tonKM_Conv1, tonKM_Conv2 : TON;
	tonKM_Rot1, tonKM_Rot2 : TON;

	// Таймеры обратной связи ЧРП (IsWorking)
	tonVFD_Conv1, tonVFD_Conv2 : TON;
	tonVFD_Rot1, tonVFD_Rot2 : TON;

	// === Таймеры сборного конвейера ===
	// Таймеры обратной связи контакторов (KM)
	tonKM_PrefConv1, tonKM_PrefConv2 : TON;

	// Таймеры обратной связи ЧРП (IsWorking)
	tonVFD_PrefConv1, tonVFD_PrefConv2 : TON;

	// === Таймеры бункеров ===
	// Таймеры обратной связи вибропитателей [бункер 1..3][мотор 1..2]
	tonKM_VibFeeder : ARRAY[1..3, 1..2] OF TON;
	tonVFD_VibFeeder : ARRAY[1..3, 1..2] OF TON;

	// Таймеры обратной связи вибраторов [бункер 1..3][мотор 1..4]
	tonKM_Vibrator : ARRAY[1..3, 1..4] OF TON;
	tonVFD_Vibrator : ARRAY[1..3, 1..4] OF TON;
END_VAR

// Детекция фронтов
rtEnable(CLK := xEnable);
rtReset(CLK := xReset);

// Инициализация по переднему фронту Enable или Reset
_xInitRequired := rtEnable.Q OR rtReset.Q;

IF _xInitRequired THEN
	// ========================================
	// ИНИЦИАЛИЗАЦИЯ СИМУЛЯЦИИ ОТВАЛООБРАЗОВАТЕЛЯ
	// Установка всех сигналов в состояние "нет ошибок"
	// ========================================

	// Моторы конвейера - ЧРП готовность
	Dumper.MotorConveyor[1].VFD.fbStateRdyToStart.ixSignal := TRUE;
	Dumper.MotorConveyor[2].VFD.fbStateRdyToStart.ixSignal := TRUE;

	// Моторы поворота - ЧРП готовность
	Dumper.MotorRotation[1].VFD.fbStateRdyToStart.ixSignal := TRUE;
	Dumper.MotorRotation[2].VFD.fbStateRdyToStart.ixSignal := TRUE;

	// Автоматические выключатели (QF)
	Dumper.MotorConveyor[1].fbStateQF.ixSignal := TRUE;
	Dumper.MotorConveyor[2].fbStateQF.ixSignal := TRUE;
	Dumper.MotorRotation[1].fbStateQF.ixSignal := TRUE;
	Dumper.MotorRotation[2].fbStateQF.ixSignal := TRUE;

	// ЧРП ошибки - инвертированный сигнал (NC)
	Dumper.MotorConveyor[1].VFD.fbStateFailure.ixSignal := TRUE;
	Dumper.MotorConveyor[2].VFD.fbStateFailure.ixSignal := TRUE;
	Dumper.MotorRotation[1].VFD.fbStateFailure.ixSignal := TRUE;
	Dumper.MotorRotation[2].VFD.fbStateFailure.ixSignal := TRUE;

	// Перегрев статора - инвертированный сигнал (NC)
	Dumper.MotorConveyor[1].fbStatorOverheat.ixSignal := TRUE;
	Dumper.MotorConveyor[2].fbStatorOverheat.ixSignal := TRUE;
	Dumper.MotorRotation[1].fbStatorOverheat.ixSignal := TRUE;
	Dumper.MotorRotation[2].fbStatorOverheat.ixSignal := TRUE;

	// Кабель-тросовые выключатели (HQ)
	Dumper.fbHQ_IsOk[1].ixSignal := TRUE;
	Dumper.fbHQ_IsOk[2].ixSignal := TRUE;
	Dumper.fbHQ_IsOk[3].ixSignal := TRUE;
	Dumper.fbHQ_IsOk[4].ixSignal := TRUE;

	// Контроль ограждения барабана (SQ)
	Dumper.fbSQ_IsOk[1].ixSignal := TRUE;
	Dumper.fbSQ_IsOk[2].ixSignal := TRUE;

	// Контроль схода ленты - тревога (ZQ) - инвертированный сигнал (NC)
	Dumper.fbZQAlarm[1].ixSignal := TRUE;
	Dumper.fbZQAlarm[2].ixSignal := TRUE;
	Dumper.fbZQAlarm[3].ixSignal := TRUE;
	Dumper.fbZQAlarm[4].ixSignal := TRUE;

	// Кнопка аварийной остановки - инвертированный сигнал (NC)
	Dumper.fbBtnEmergencyStop.ixSignal := TRUE;

	// Концевые выключатели - инвертированный сигнал (NC)
	Dumper.fbEndSwitchLeft.ixSignal := TRUE;
	Dumper.fbEndSwitchRight.ixSignal := TRUE;

	// Контроль заштыбовки - норма = 1
	Dumper.fbGS1.ixSignal := TRUE;

	// Контроль продольного разрыва ленты - норма = 1
	Dumper.fbYS1.ixSignal := TRUE;

	// ========================================
	// ИНИЦИАЛИЗАЦИЯ СИМУЛЯЦИИ СБОРНОГО КОНВЕЙЕРА
	// Установка всех сигналов в состояние "нет ошибок"
	// ========================================

	// Моторы конвейера - ЧРП готовность
	Conveyor.MotorConveyor[1].VFD.fbStateRdyToStart.ixSignal := TRUE;
	Conveyor.MotorConveyor[2].VFD.fbStateRdyToStart.ixSignal := TRUE;

	// Автоматические выключатели (QF)
	Conveyor.MotorConveyor[1].fbStateQF.ixSignal := TRUE;
	Conveyor.MotorConveyor[2].fbStateQF.ixSignal := TRUE;

	// ЧРП ошибки - инвертированный сигнал (NC)
	Conveyor.MotorConveyor[1].VFD.fbStateFailure.ixSignal := TRUE;
	Conveyor.MotorConveyor[2].VFD.fbStateFailure.ixSignal := TRUE;

	// Перегрев статора - инвертированный сигнал (NC)
	Conveyor.MotorConveyor[1].fbStatorOverheat.ixSignal := TRUE;
	Conveyor.MotorConveyor[2].fbStatorOverheat.ixSignal := TRUE;

	// Кабель-тросовые выключатели (HQ)
	Conveyor.fbHQ_IsOk[1].ixSignal := TRUE;
	Conveyor.fbHQ_IsOk[2].ixSignal := TRUE;
	Conveyor.fbHQ_IsOk[3].ixSignal := TRUE;
	Conveyor.fbHQ_IsOk[4].ixSignal := TRUE;

	// Контроль ограждения барабана (SQ)
	Conveyor.fbSQ_IsOk[1].ixSignal := TRUE;
	Conveyor.fbSQ_IsOk[2].ixSignal := TRUE;

	// Контроль схода ленты - тревога (ZQ) - инвертированный сигнал (NC)
	Conveyor.fbZQAlarm[1].ixSignal := TRUE;
	Conveyor.fbZQAlarm[2].ixSignal := TRUE;
	Conveyor.fbZQAlarm[3].ixSignal := TRUE;
	Conveyor.fbZQAlarm[4].ixSignal := TRUE;

	// Кнопка аварийной остановки - инвертированный сигнал (NC)
	Conveyor.fbBtnEmergencyStop.ixSignal := TRUE;

	// Контроль заштыбовки - норма = 1
	Conveyor.fbGS1.ixSignal := TRUE;

	// Контроль продольного разрыва ленты - норма = 1
	Conveyor.fbYS1.ixSignal := TRUE;

	// Металлодетектор - норма = 0 (металл не обнаружен)
	Conveyor.fbYE1.ixSignal := FALSE;

	// ========================================
	// ИНИЦИАЛИЗАЦИЯ СИМУЛЯЦИИ БУНКЕРОВ
	// Установка всех сигналов в состояние "нет ошибок"
	// ========================================

	FOR b := 1 TO 3 BY 1 DO
		// Вибропитатели (MotorVibFeeder[1..2])
		FOR m := 1 TO 2 BY 1 DO
			// ЧРП готовность
			Bunker[b].MotorVibFeeder[m].VFD.fbStateRdyToStart.ixSignal := TRUE;

			// Автоматический выключатель (QF)
			Bunker[b].MotorVibFeeder[m].fbStateQF.ixSignal := TRUE;

			// ЧРП ошибка - инвертированный сигнал (NC)
			Bunker[b].MotorVibFeeder[m].VFD.fbStateFailure.ixSignal := TRUE;

			// Перегрев статора - инвертированный сигнал (NC)
			Bunker[b].MotorVibFeeder[m].fbStatorOverheat.ixSignal := TRUE;
		END_FOR;

		// Вибраторы (MotorVibrator[1..4])
		FOR m := 1 TO 4 BY 1 DO
			// ЧРП готовность
			Bunker[b].MotorVibrator[m].VFD.fbStateRdyToStart.ixSignal := TRUE;

			// Автоматический выключатель (QF)
			Bunker[b].MotorVibrator[m].fbStateQF.ixSignal := TRUE;

			// ЧРП ошибка - инвертированный сигнал (NC)
			Bunker[b].MotorVibrator[m].VFD.fbStateFailure.ixSignal := TRUE;
		END_FOR;

		// Люк бункера - закрыт (норма = 1)
		Bunker[b].fbStateHatch.ixSignal := TRUE;

		// Кнопка аварийной остановки - инвертированный сигнал (NC)
		Bunker[b].fbBtnEmergencyStop.ixSignal := TRUE;

		// Начальный вес бункера (симуляция заполненного бункера)
		Bunker[b].rWeight := 100.0;
	END_FOR;
END_IF;

// ========================================
// ПРОЦЕСС СИМУЛЯЦИИ
// ========================================

IF xEnable THEN
	// ========================================
	// СИМУЛЯЦИЯ ОТВАЛООБРАЗОВАТЕЛЯ
	// ========================================

	// Симуляция частоты ЧРП моторов конвейера отвалообразователя
	Dumper.MotorConveyor[1].VFD.fbSimFreq(
		xProceed := Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal,
		irTarget := Dumper.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency,
		irStep := 0.2,
		irInputModule => Dumper.MotorConveyor[1].VFD.rActualFrequency
	);

	Dumper.MotorConveyor[2].VFD.fbSimFreq(
		xProceed := Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal,
		irTarget := Dumper.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency,
		irStep := 0.2,
		irInputModule => Dumper.MotorConveyor[2].VFD.rActualFrequency
	);

	// Симуляция частоты ЧРП моторов поворота отвалообразователя
	Dumper.MotorRotation[1].VFD.fbSimFreq(
		xProceed := Dumper.MotorRotation[1].VFD.fbStateIsWorking.qxSignal,
		irTarget := Dumper.MotorRotation[1].VFD.Frequency.qrCurrentFrequency,
		irStep := 0.2,
		irInputModule => Dumper.MotorRotation[1].VFD.rActualFrequency
	);

	Dumper.MotorRotation[2].VFD.fbSimFreq(
		xProceed := Dumper.MotorRotation[2].VFD.fbStateIsWorking.qxSignal,
		irTarget := Dumper.MotorRotation[2].VFD.Frequency.qrCurrentFrequency,
		irStep := 0.2,
		irInputModule => Dumper.MotorRotation[2].VFD.rActualFrequency
	);

	// ========================================
	// СИМУЛЯЦИЯ ОБРАТНОЙ СВЯЗИ ОТВАЛООБРАЗОВАТЕЛЯ
	// ========================================

	// Обратная связь контакторов моторов конвейера отвалообразователя
	tonKM_Conv1(IN := Dumper.MotorConveyor[1].qxKM_Power, PT := tFeedbackDelay);
	Dumper.MotorConveyor[1].fbStateKM.ixSignal := tonKM_Conv1.Q;

	tonKM_Conv2(IN := Dumper.MotorConveyor[2].qxKM_Power, PT := tFeedbackDelay);
	Dumper.MotorConveyor[2].fbStateKM.ixSignal := tonKM_Conv2.Q;

	// Обратная связь контакторов моторов поворота отвалообразователя
	tonKM_Rot1(IN := Dumper.MotorRotation[1].qxKM_Power, PT := tFeedbackDelay);
	Dumper.MotorRotation[1].fbStateKM.ixSignal := tonKM_Rot1.Q;

	tonKM_Rot2(IN := Dumper.MotorRotation[2].qxKM_Power, PT := tFeedbackDelay);
	Dumper.MotorRotation[2].fbStateKM.ixSignal := tonKM_Rot2.Q;

	// Обратная связь работы ЧРП моторов конвейера отвалообразователя
	tonVFD_Conv1(IN := Dumper.MotorConveyor[1].VFD.qxStart, PT := tFeedbackDelay);
	Dumper.MotorConveyor[1].VFD.fbStateIsWorking.ixSignal := tonVFD_Conv1.Q;

	tonVFD_Conv2(IN := Dumper.MotorConveyor[2].VFD.qxStart, PT := tFeedbackDelay);
	Dumper.MotorConveyor[2].VFD.fbStateIsWorking.ixSignal := tonVFD_Conv2.Q;

	// Обратная связь работы ЧРП моторов поворота отвалообразователя
	tonVFD_Rot1(IN := Dumper.MotorRotation[1].VFD.qxStart, PT := tFeedbackDelay);
	Dumper.MotorRotation[1].VFD.fbStateIsWorking.ixSignal := tonVFD_Rot1.Q;

	tonVFD_Rot2(IN := Dumper.MotorRotation[2].VFD.qxStart, PT := tFeedbackDelay);
	Dumper.MotorRotation[2].VFD.fbStateIsWorking.ixSignal := tonVFD_Rot2.Q;

	// ========================================
	// СИМУЛЯЦИЯ СБОРНОГО КОНВЕЙЕРА
	// ========================================

	// Симуляция частоты ЧРП моторов конвейера
	Conveyor.MotorConveyor[1].VFD.fbSimFreq(
		xProceed := Conveyor.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal,
		irTarget := Conveyor.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency,
		irStep := 0.2,
		irInputModule => Conveyor.MotorConveyor[1].VFD.rActualFrequency
	);

	Conveyor.MotorConveyor[2].VFD.fbSimFreq(
		xProceed := Conveyor.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal,
		irTarget := Conveyor.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency,
		irStep := 0.2,
		irInputModule => Conveyor.MotorConveyor[2].VFD.rActualFrequency
	);

	// ========================================
	// СИМУЛЯЦИЯ ОБРАТНОЙ СВЯЗИ СБОРНОГО КОНВЕЙЕРА
	// ========================================

	// Обратная связь контакторов моторов конвейера
	tonKM_PrefConv1(IN := Conveyor.MotorConveyor[1].qxKM_Power, PT := tFeedbackDelay);
	Conveyor.MotorConveyor[1].fbStateKM.ixSignal := tonKM_PrefConv1.Q;

	tonKM_PrefConv2(IN := Conveyor.MotorConveyor[2].qxKM_Power, PT := tFeedbackDelay);
	Conveyor.MotorConveyor[2].fbStateKM.ixSignal := tonKM_PrefConv2.Q;

	// Обратная связь работы ЧРП моторов конвейера
	tonVFD_PrefConv1(IN := Conveyor.MotorConveyor[1].VFD.qxStart, PT := tFeedbackDelay);
	Conveyor.MotorConveyor[1].VFD.fbStateIsWorking.ixSignal := tonVFD_PrefConv1.Q;

	tonVFD_PrefConv2(IN := Conveyor.MotorConveyor[2].VFD.qxStart, PT := tFeedbackDelay);
	Conveyor.MotorConveyor[2].VFD.fbStateIsWorking.ixSignal := tonVFD_PrefConv2.Q;

	// ========================================
	// СИМУЛЯЦИЯ БУНКЕРОВ
	// ========================================

	FOR b := 1 TO 3 BY 1 DO
		// --- Вибропитатели (MotorVibFeeder[1..2]) ---
		FOR m := 1 TO 2 BY 1 DO
			// Симуляция частоты ЧРП вибропитателя
			Bunker[b].MotorVibFeeder[m].VFD.fbSimFreq(
				xProceed := Bunker[b].MotorVibFeeder[m].VFD.fbStateIsWorking.qxSignal,
				irTarget := Bunker[b].MotorVibFeeder[m].VFD.Frequency.qrCurrentFrequency,
				irStep := 0.2,
				irInputModule => Bunker[b].MotorVibFeeder[m].VFD.rActualFrequency
			);

			// Обратная связь контактора вибропитателя
			tonKM_VibFeeder[b, m](IN := Bunker[b].MotorVibFeeder[m].qxKM_Power, PT := tFeedbackDelay);
			Bunker[b].MotorVibFeeder[m].fbStateKM.ixSignal := tonKM_VibFeeder[b, m].Q;

			// Обратная связь работы ЧРП вибропитателя
			tonVFD_VibFeeder[b, m](IN := Bunker[b].MotorVibFeeder[m].VFD.qxStart, PT := tFeedbackDelay);
			Bunker[b].MotorVibFeeder[m].VFD.fbStateIsWorking.ixSignal := tonVFD_VibFeeder[b, m].Q;
		END_FOR;

		// --- Вибраторы (MotorVibrator[1..4]) ---
		FOR m := 1 TO 4 BY 1 DO
			// Симуляция частоты ЧРП вибратора
			Bunker[b].MotorVibrator[m].VFD.fbSimFreq(
				xProceed := Bunker[b].MotorVibrator[m].VFD.fbStateIsWorking.qxSignal,
				irTarget := Bunker[b].MotorVibrator[m].VFD.Frequency.qrCurrentFrequency,
				irStep := 0.2,
				irInputModule => Bunker[b].MotorVibrator[m].VFD.rActualFrequency
			);

			// Обратная связь контактора вибратора
			tonKM_Vibrator[b, m](IN := Bunker[b].MotorVibrator[m].qxKM_Power, PT := tFeedbackDelay);
			Bunker[b].MotorVibrator[m].fbStateKM.ixSignal := tonKM_Vibrator[b, m].Q;

			// Обратная связь работы ЧРП вибратора
			tonVFD_Vibrator[b, m](IN := Bunker[b].MotorVibrator[m].VFD.qxStart, PT := tFeedbackDelay);
			Bunker[b].MotorVibrator[m].VFD.fbStateIsWorking.ixSignal := tonVFD_Vibrator[b, m].Q;
		END_FOR;
	END_FOR;
END_IF;

END_FUNCTION_BLOCK