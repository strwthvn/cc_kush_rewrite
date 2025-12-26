FUNCTION_BLOCK FB_Simulation
VAR_INPUT
	xEnable : BOOL; // Включение симуляции
	xReset : BOOL; // Сброс всех переменных (симуляция отсутствия ошибок)
	Dumper : REFERENCE TO ST_Dumper; // Структура отвалообразователя
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated; // Структура сборного конвейера
	Bunker : REFERENCE TO ARRAY[1..3] OF ST_Bunker; // Массив бункеров
	Common : ST_CommonSignals; // Общие сигналы
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

	// === Симуляция веса бункеров ===
	// Средняя частота вибропитателей каждого бункера
	_rAvgFrequencyVibFeeder : ARRAY[1..3] OF REAL;

	// Скорость расхода веса бункера (кг/с) в зависимости от частоты вибропитателей
	_rWeightDischargeRate : ARRAY[1..3] OF REAL;

	// Скорость заполнения веса бункера (кг/с) в зависимости от светофора
	_rWeightFillRate : ARRAY[1..3] OF REAL;

	// Таймер для периодического заполнения по приоритету
	_tonFillTimer : ARRAY[1..3] OF TON;
	_xFillTimerActive : ARRAY[1..3] OF BOOL;

	// Параметры заполнения (настраиваются через входные параметры)
	_rFillRateGreen : REAL := 0.8; // Скорость заполнения на зелёном (кг/с) - плавное заполнение
	_rFillRateYellow : REAL := 0.3; // Скорость заполнения на жёлтом (кг/с) - медленное заполнение
	_tFillPeriod : TIME := T#8S; // Период заполнения (раз в N секунд) - реже
	_tFillDuration : TIME := T#3S; // Длительность одного заполнения - дольше

	// Константа расхода: частота 50 Гц → 0.5 кг/с расход (замедлено)
	_rDischargeCoeff : REAL := 0.01; // 50 Гц * 0.01 = 0.5 кг/с

	// === Симуляция веса под бункерами ===

	// Скорость накопления веса (кг/с) для каждого бункера
	_rWeightAccumulationRate : ARRAY[1..3] OF REAL;

	// Накопленный вес от каждого бункера (независимо)
	_rLocalWeightUnderBunker : ARRAY[1..3] OF REAL;

	// === Случайные возмущения для бункеров ===
	// Параметры генератора псевдослучайных чисел (Linear Congruential Generator)
	_nRandomSeed : ARRAY[1..3] OF DINT := [12345, 67890, 24680]; // Начальные значения

	// Случайное смещение для каждого бункера (-1.0 до +1.0)
	_rRandomOffset : ARRAY[1..3] OF REAL;

	// Линейный дрейф (медленное изменение характеристик материала)
	_rDriftOffset : ARRAY[1..3] OF REAL;
	_rDriftSpeed : ARRAY[1..3] OF REAL := [0.0003, -0.00025, 0.00035]; // Скорость дрейфа за цикл

	// Временные переменные
	_rNoise : REAL; // Шум ±3%
	_rDrift : REAL; // Дрейф ±8%

	// === Таймеры отвалообразователя ===
	// Таймеры обратной связи контакторов (KM)
	tonKM_Conv1, tonKM_Conv2 : TON;
	tonKM_Rot1, tonKM_Rot2 : TON;

	// Таймеры обратной связи ЧРП (IsWorking)
	tonVFD_Conv1, tonVFD_Conv2 : TON;
	tonVFD_Rot1, tonVFD_Rot2 : TON;

	// Таймеры обратной связи тормозов отвалообразователя
	tonBreaker_DumperConv, tonBreaker_DumperRot : TON;

	// === Таймеры сборного конвейера ===
	// Таймеры обратной связи контакторов (KM)
	tonKM_PrefConv1, tonKM_PrefConv2 : TON;

	// Таймеры обратной связи ЧРП (IsWorking)
	tonVFD_PrefConv1, tonVFD_PrefConv2 : TON;

	// Таймер обратной связи тормоза сборного конвейера
	tonBreaker_PrefConv : TON;

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
	// ИНИЦИАЛИЗАЦИЯ ОБЩИЕ СИГНАЛЫ
	// ========================================
	
	// Сигнал ПМУ - режим управления 1 - дистанция, 0 - местный
	Common.fbRemoteModeBtn.ixSignal := TRUE; 

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

	// Контроль схода ленты - предупреждение (ZQ) - инвертированный сигнал (NC)
	Dumper.fbZQWarning[1].ixSignal := TRUE;
	Dumper.fbZQWarning[2].ixSignal := TRUE;
	Dumper.fbZQWarning[3].ixSignal := TRUE;
	Dumper.fbZQWarning[4].ixSignal := TRUE;

	// Кнопка аварийной остановки - инвертированный сигнал (NC)
	Dumper.fbBtnEmergencyStop.ixSignal := TRUE;

	// Концевые выключатели - инвертированный сигнал (NC)
	Dumper.fbEndSwitchLeft.ixSignal := TRUE;
	Dumper.fbEndSwitchRight.ixSignal := TRUE;

	// Контроль заштыбовки - норма = 1
	Dumper.fbGS1.ixSignal := TRUE;

	// Контроль продольного разрыва ленты - норма = 1
	Dumper.fbYS1.ixSignal := TRUE;

	// Тормоза - в начале активны (NOT released)
	Dumper.fbBreakerConveyor.ixSignal := FALSE;
	Dumper.fbBreakerRotation.ixSignal := FALSE;

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

	// Контроль схода ленты - предупреждение (ZQ) - инвертированный сигнал (NC)
	Conveyor.fbZQWarning[1].ixSignal := TRUE;
	Conveyor.fbZQWarning[2].ixSignal := TRUE;
	Conveyor.fbZQWarning[3].ixSignal := TRUE;
	Conveyor.fbZQWarning[4].ixSignal := TRUE;

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

		// Сброс веса под бункером
		Bunker[b].rWeightUnderBunker := 0.0;
		_rLocalWeightUnderBunker[b] := 0.0;

		// Сброс дрейфа
		_rDriftOffset[b] := 0.0;
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
	// В режиме симуляции: DAC код от модуля AO → ADC код модуля AI
	Dumper.MotorConveyor[1].VFD.nActualFrequencyADC := Dumper.MotorConveyor[1].VFD.nSetOutSignalToModule;
	Dumper.MotorConveyor[2].VFD.nActualFrequencyADC := Dumper.MotorConveyor[2].VFD.nSetOutSignalToModule;

	// Симуляция частоты ЧРП моторов поворота отвалообразователя
	// В режиме симуляции: DAC код от модуля AO → ADC код модуля AI
	Dumper.MotorRotation[1].VFD.nActualFrequencyADC := Dumper.MotorRotation[1].VFD.nSetOutSignalToModule;
	Dumper.MotorRotation[2].VFD.nActualFrequencyADC := Dumper.MotorRotation[2].VFD.nSetOutSignalToModule;

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
	// Учитываем как прямое, так и реверсивное вращение
	tonVFD_Rot1(IN := (Dumper.MotorRotation[1].VFD.qxStart OR Dumper.MotorRotation[1].qxVFDReverseStart), PT := tFeedbackDelay);
	Dumper.MotorRotation[1].VFD.fbStateIsWorking.ixSignal := tonVFD_Rot1.Q;

	tonVFD_Rot2(IN := (Dumper.MotorRotation[2].VFD.qxStart OR Dumper.MotorRotation[2].qxVFDReverseStart), PT := tFeedbackDelay);
	Dumper.MotorRotation[2].VFD.fbStateIsWorking.ixSignal := tonVFD_Rot2.Q;

	// Обратная связь тормозов отвалообразователя
	// Тормоз отпущен (TRUE) когда на выходе активен сигнал
	// Тормоз активен (FALSE) когда выход отключен
	tonBreaker_DumperConv(IN := Dumper.qxBreakerConveyor, PT := tFeedbackDelay);
	Dumper.fbBreakerConveyor.ixSignal := tonBreaker_DumperConv.Q;

	tonBreaker_DumperRot(IN := Dumper.qxBreakerRotation, PT := tFeedbackDelay);
	Dumper.fbBreakerRotation.ixSignal := tonBreaker_DumperRot.Q;

	// ========================================
	// СИМУЛЯЦИЯ СБОРНОГО КОНВЕЙЕРА
	// ========================================

	// Симуляция частоты ЧРП моторов конвейера
	// В режиме симуляции: DAC код от модуля AO → ADC код модуля AI
	Conveyor.MotorConveyor[1].VFD.nActualFrequencyADC := Conveyor.MotorConveyor[1].VFD.nSetOutSignalToModule;
	Conveyor.MotorConveyor[2].VFD.nActualFrequencyADC := Conveyor.MotorConveyor[2].VFD.nSetOutSignalToModule;

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

	// Обратная связь тормоза сборного конвейера
	tonBreaker_PrefConv(IN := Conveyor.qxBreakerConveyor, PT := tFeedbackDelay);
	Conveyor.fbBreakerConveyor.ixSignal := tonBreaker_PrefConv.Q;

	// ========================================
	// СИМУЛЯЦИЯ БУНКЕРОВ
	// ========================================

	FOR b := 1 TO 3 BY 1 DO
		// --- Вибропитатели (MotorVibFeeder[1..2]) ---
		FOR m := 1 TO 2 BY 1 DO
			// Симуляция частоты ЧРП вибропитателя
			// В режиме симуляции: DAC код от модуля AO → ADC код модуля AI
			Bunker[b].MotorVibFeeder[m].VFD.nActualFrequencyADC := Bunker[b].MotorVibFeeder[m].VFD.nSetOutSignalToModule;

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
			// В режиме симуляции: DAC код от модуля AO → ADC код модуля AI
			Bunker[b].MotorVibrator[m].VFD.nActualFrequencyADC := Bunker[b].MotorVibrator[m].VFD.nSetOutSignalToModule;

			// Обратная связь контактора вибратора
			tonKM_Vibrator[b, m](IN := Bunker[b].MotorVibrator[m].qxKM_Power, PT := tFeedbackDelay);
			Bunker[b].MotorVibrator[m].fbStateKM.ixSignal := tonKM_Vibrator[b, m].Q;

			// Обратная связь работы ЧРП вибратора
			tonVFD_Vibrator[b, m](IN := Bunker[b].MotorVibrator[m].VFD.qxStart, PT := tFeedbackDelay);
			Bunker[b].MotorVibrator[m].VFD.fbStateIsWorking.ixSignal := tonVFD_Vibrator[b, m].Q;
		END_FOR;
	END_FOR;

	// ========================================
	// СИМУЛЯЦИЯ ВЕСА ПОД БУНКЕРАМИ
	// ========================================

	// Симуляция с случайными возмущениями для тестирования ПИД-регулятора
	FOR b := 1 TO 3 BY 1 DO
		// Средняя выходная частота двух вибропитателей бункера
		// Используем rActualFrequency - актуальная частота от модуля AI (после полного цикла AO → AI)
		_rAvgFrequencyVibFeeder[b] :=
			(Bunker[b].MotorVibFeeder[1].VFD.rActualFrequency
		   + Bunker[b].MotorVibFeeder[2].VFD.rActualFrequency) / 2.0;

		// --- Генерация случайного шума (Linear Congruential Generator) ---
		// LCG формула: seed = (a * seed + c) mod m
		// Параметры: a = 1103515245, c = 12345, m = 2^31
		_nRandomSeed[b] := (1103515245 * _nRandomSeed[b] + 12345) MOD 2147483647;

		// Преобразование seed в диапазон [-1.0 ... +1.0]
		_rRandomOffset[b] := (DINT_TO_REAL(_nRandomSeed[b]) / 2147483647.0) * 2.0 - 1.0;

		// Шум ±3% от базового значения
		_rNoise := _rRandomOffset[b] * 0.03;

		// --- Медленный линейный дрейф (имитация изменения свойств материала) ---
		// Дрейф накапливается с течением времени, но ограничен диапазоном ±8%
		_rDriftOffset[b] := _rDriftOffset[b] + _rDriftSpeed[b];

		// Ограничение дрейфа в диапазоне [-0.08 ... +0.08]
		IF _rDriftOffset[b] > 0.08 THEN
			_rDriftOffset[b] := 0.08;
			_rDriftSpeed[b] := -ABS(_rDriftSpeed[b]); // Реверс направления
		ELSIF _rDriftOffset[b] < -0.08 THEN
			_rDriftOffset[b] := -0.08;
			_rDriftSpeed[b] := ABS(_rDriftSpeed[b]); // Реверс направления
		END_IF;

		_rDrift := _rDriftOffset[b];

		// --- Расчет веса с возмущениями ---
		// Базовая линейная зависимость: частота 50 Гц -> 100 кг
		// + Шум ±3%
		// + Дрейф ±8%
		_rLocalWeightUnderBunker[b] := (_rAvgFrequencyVibFeeder[b] / 50.0) * 100.0
		                             * (1.0 + _rNoise + _rDrift);

		// Ограничение минимального значения (вес не может быть отрицательным)
		IF _rLocalWeightUnderBunker[b] < 0.0 THEN
			_rLocalWeightUnderBunker[b] := 0.0;
		END_IF;
	END_FOR;

	// --- Формирование кумулятивных весов согласно движению конвейера ---
	// Конвейер движется: Бункер 3 → Бункер 2 → Бункер 1 → дальше
	//
	// rWeightUnderBunker[3] = вес только от бункера 3
	// rWeightUnderBunker[2] = вес от бункера 3 + вес от бункера 2
	// rWeightUnderBunker[1] = вес от бункера 3 + вес от бункера 2 + вес от бункера 1

	Bunker[3].rWeightUnderBunker := _rLocalWeightUnderBunker[3];

	Bunker[2].rWeightUnderBunker := _rLocalWeightUnderBunker[3]
	                              + _rLocalWeightUnderBunker[2];

	Bunker[1].rWeightUnderBunker := _rLocalWeightUnderBunker[3]
	                              + _rLocalWeightUnderBunker[2]
	                              + _rLocalWeightUnderBunker[1];

	// ========================================
	// СИМУЛЯЦИЯ ВЕСА БУНКЕРОВ (РАСХОД И ЗАПОЛНЕНИЕ)
	// ========================================

	IF SIMULATION_BUNKER_WEIGHT THEN
		FOR b := 1 TO 3 BY 1 DO
		// ========================================
		// 1. РАСХОД ВЕСА (пропорционален частоте вибропитателей)
		// ========================================

		// Средняя частота вибропитателей
		_rAvgFrequencyVibFeeder[b] :=
			(Bunker[b].MotorVibFeeder[1].VFD.rActualFrequency
		   + Bunker[b].MotorVibFeeder[2].VFD.rActualFrequency) / 2.0;

		// Скорость расхода (кг/с): частота * коэффициент
		// Пример: 50 Гц * 0.02 = 1.0 кг/с
		_rWeightDischargeRate[b] := _rAvgFrequencyVibFeeder[b] * _rDischargeCoeff;

		// Применение расхода к весу бункера (за один цикл ПЛК ~10-50 мс)
		// Предполагаем цикл ПЛК = 50 мс = 0.05 с
		Bunker[b].rWeight := Bunker[b].rWeight - (_rWeightDischargeRate[b] * 0.05);

		// Ограничение минимального веса (не может быть отрицательным)
		IF Bunker[b].rWeight < 0.0 THEN
			Bunker[b].rWeight := 0.0;
		END_IF;

		// ========================================
		// 2. ЗАПОЛНЕНИЕ ВЕСА (зависит от цвета светофора)
		// ========================================

		// Определение скорости заполнения в зависимости от цвета светофора
		CASE Bunker[b].eLightColor OF
			E_LightColor.GREEN:
				// Зелёный - максимальная скорость заполнения (приоритет)
				_rWeightFillRate[b] := _rFillRateGreen;

			E_LightColor.YELLOW:
				// Жёлтый - умеренная скорость заполнения
				_rWeightFillRate[b] := _rFillRateYellow;

			E_LightColor.RED, E_LightColor.OFF:
				// Красный или выключен - заполнение отсутствует
				_rWeightFillRate[b] := 0.0;
		END_CASE;

		// ========================================
		// 3. ПЕРИОДИЧЕСКОЕ ЗАПОЛНЕНИЕ (раз в N секунд)
		// ========================================

		// Таймер периода ожидания между заполнениями
		_tonFillTimer[b](
			IN := NOT _xFillTimerActive[b] AND (_rWeightFillRate[b] > 0.0),
			PT := _tFillPeriod
		);

		// Когда таймер ожидания истёк - запускаем процесс заполнения
		IF _tonFillTimer[b].Q THEN
			_xFillTimerActive[b] := TRUE;
			_tonFillTimer[b].IN := FALSE; // Сброс таймера ожидания
		END_IF;

		// Таймер длительности заполнения
		IF _xFillTimerActive[b] THEN
			// Применение заполнения к весу бункера (за один цикл ПЛК)
			Bunker[b].rWeight := Bunker[b].rWeight + (_rWeightFillRate[b] * 0.05);

			// Ограничение максимального веса (100 кг = 100%)
			IF Bunker[b].rWeight > 100.0 THEN
				Bunker[b].rWeight := 100.0;
			END_IF;

			// Проверка длительности заполнения
			_tonFillTimer[b](IN := TRUE, PT := _tFillDuration);

			// Когда заполнение завершено - сбросить флаг
			IF _tonFillTimer[b].Q THEN
				_xFillTimerActive[b] := FALSE;
				_tonFillTimer[b].IN := FALSE; // Сброс таймера заполнения
			END_IF;
		END_IF;

		// ========================================
		// 4. ПРИОРИТЕТ ЗЕЛЁНОГО СВЕТОФОРА
		// ========================================
		// Если хотя бы один бункер горит зелёным (критический режим),
		// то только он получает заполнение, а остальные ждут

		// Проверка: есть ли бункеры с зелёным светофором в критическом режиме?
		// (вес <= BUNKER_WEIGHT_LIGHT_RED_SPECIAL)
		IF (Bunker[1].eLightColor = E_LightColor.GREEN AND Bunker[1].rWeight <= BUNKER_WEIGHT_LIGHT_RED_SPECIAL)
		OR (Bunker[2].eLightColor = E_LightColor.GREEN AND Bunker[2].rWeight <= BUNKER_WEIGHT_LIGHT_RED_SPECIAL)
		OR (Bunker[3].eLightColor = E_LightColor.GREEN AND Bunker[3].rWeight <= BUNKER_WEIGHT_LIGHT_RED_SPECIAL)
		THEN
			// Есть критический бункер с зелёным светофором
			// Отменяем заполнение для всех НЕ критических бункеров
			IF Bunker[b].eLightColor <> E_LightColor.GREEN OR Bunker[b].rWeight > BUNKER_WEIGHT_LIGHT_RED_SPECIAL THEN
				_rWeightFillRate[b] := 0.0;
				_xFillTimerActive[b] := FALSE;
			END_IF;
		END_IF;
		END_FOR;
	END_IF; // IF SIMULATION_BUNKER_WEIGHT THEN

END_IF; // IF _xInitRequired THEN

END_FUNCTION_BLOCK