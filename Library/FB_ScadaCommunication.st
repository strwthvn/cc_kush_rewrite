FUNCTION_BLOCK FB_ScadaCommunication
(*
	Функциональный блок контроля связи со SCADA

	Принцип работы:
	- SCADA отправляет пульсирующий сигнал (периодически меняется 0 → 1 → 0)
	- ФБ отслеживает изменения сигнала
	- Если изменения происходят регулярно → связь есть
	- Если сигнал "завис" (нет изменений дольше таймаута) → связи нет

	Применение:
	fbScadaComm(
		ixHeartbeatSignal := SCADA_Heartbeat,
		itTimeout := T#5S,
		xReset := ResetButton
	);

	IF fbScadaComm.qxCommunicationOk THEN
		// Связь есть
	END_IF
*)

VAR_INPUT
	ixHeartbeatSignal : BOOL;     // Пульсирующий сигнал от SCADA (heartbeat)
	itTimeout : TIME := T#5S;     // Таймаут отсутствия изменений сигнала (по умолчанию 5 секунд)
	xReset : BOOL := FALSE;       // Сброс ошибки связи
END_VAR

VAR_OUTPUT
	qxCommunicationOk : BOOL := FALSE;        // TRUE = связь есть (активная), FALSE = связи нет
	qxCommunicationLost : BOOL := TRUE;       // TRUE = связь потеряна (защёлкивается до Reset)
	qxSignalChanged : BOOL := FALSE;          // TRUE = сигнал изменился в текущем цикле
	qnChangeCount : UDINT := 0;               // Счётчик изменений сигнала (для диагностики)
	qtTimeSinceLastChange : TIME := T#0S;     // Время с последнего изменения сигнала
END_VAR

VAR
	// Таймер контроля таймаута
	fbTimeoutTimer : TON;

	// Предыдущее значение сигнала для детектора изменений
	_xPreviousSignal : BOOL := FALSE;

	// Флаг первого цикла (для инициализации)
	_xFirstCycle : BOOL := TRUE;
END_VAR

// ========================================
// СБРОС ОШИБКИ СВЯЗИ (должен быть ПЕРВЫМ)
// ========================================

// Сброс счётчика изменений и состояния при команде Reset
IF xReset THEN
	qnChangeCount := 0;
	qtTimeSinceLastChange := T#0S;
	qxCommunicationLost := FALSE;
	qxCommunicationOk := FALSE;
	_xFirstCycle := TRUE;  // Сбросить первый цикл для корректной инициализации

	// КРИТИЧНО: Сбросить таймер, иначе он останется с Q=TRUE и старым ET
	fbTimeoutTimer(IN := FALSE, PT := itTimeout);
END_IF;

// ========================================
// ИНИЦИАЛИЗАЦИЯ ПЕРВОГО ЦИКЛА
// ========================================

IF _xFirstCycle THEN
	_xPreviousSignal := ixHeartbeatSignal;
	_xFirstCycle := FALSE;
END_IF;

// ========================================
// ДЕТЕКТОР ИЗМЕНЕНИЙ СИГНАЛА
// ========================================

// Определяем изменение сигнала путём сравнения с предыдущим значением
qxSignalChanged := (ixHeartbeatSignal <> _xPreviousSignal);

// Подсчёт изменений сигнала
IF qxSignalChanged THEN
	qnChangeCount := qnChangeCount + 1;
END_IF;

// ========================================
// ТАЙМЕР КОНТРОЛЯ ТАЙМАУТА
// ========================================

// Таймер запускается когда НЕТ изменений сигнала
// Сбрасывается при каждом изменении сигнала
fbTimeoutTimer(
	IN := NOT qxSignalChanged,  // Таймер работает когда нет изменений
	PT := itTimeout
);

// Обновляем время с последнего изменения из таймера
qtTimeSinceLastChange := fbTimeoutTimer.ET;

// ========================================
// ОПРЕДЕЛЕНИЕ СОСТОЯНИЯ СВЯЗИ
// ========================================

// qxCommunicationOk - текущее состояние связи (пульсация активна)
// qxCommunicationLost - защёлкивающийся флаг потери связи (сбрасывается только по xReset)

// Связь восстановлена при изменении сигнала
IF qxSignalChanged THEN
	qxCommunicationOk := TRUE;
	// Не сбрасываем qxCommunicationLost - это защёлка для SCADA
END_IF;

// Таймаут истёк - связь потеряна
IF fbTimeoutTimer.Q THEN
	qxCommunicationOk := FALSE;
	qxCommunicationLost := TRUE;  // Защёлкивается до Reset
END_IF;

// Сохраняем текущее значение для следующего цикла
_xPreviousSignal := ixHeartbeatSignal;

END_FUNCTION_BLOCK
