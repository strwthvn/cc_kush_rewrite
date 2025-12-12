FUNCTION_BLOCK FB_UniversalSignal
VAR_INPUT
    ixSignal : BOOL;                            // Входной дискретный сигнал
    ixFeedback : BOOL;                          // Сигнал обратной связи
    itFeedbackTimeout : TIME := T#5S;           // Время ожидания обратной связи
    xEnableFeedback : BOOL := FALSE;            // Включить отслеживание обратной связи
    xEnableFeedbackTimer : BOOL := FALSE;       // Включить таймер обратной связи
    xEnableRattlingFilter : BOOL := FALSE;      // Включить фильтрацию дребезга
    tStabilityTime : TIME := T#100MS;           // Время стабилизации сигнала
    nMaxTransitions : UINT := 5;                // Максимальное количество переходов для определения дребезга
    tDetectionWindow : TIME := T#200MS;         // Окно времени для подсчета переходов
END_VAR
VAR_OUTPUT
    qxSignal : BOOL;                            // Выходной обработанный сигнал
    qxInvertedSignal : BOOL;                    // Инвертированный сигнал
    qxRisingEdge : BOOL;                        // Передний фронт (0->1)
    qxFallingEdge : BOOL;                       // Задний фронт (1->0)
    qxWaitingFeedback : BOOL;                   // Флаг ожидания сигнала обратной связи
    qxFeedbackReceived : BOOL;                  // Флаг успешного получения обратной связи
    qxFeedbackTimeout : BOOL;                   // Флаг превышения времени ожидания обратной связи
    qxRattlingDetected : BOOL;                  // Флаг обнаружения дребезга
    qnTransitionCount : UINT;                   // Текущее количество переходов в окне обнаружения
END_VAR
VAR
    // Триггеры для детектирования фронтов
    _rt_Signal : R_TRIG;
    _ft_Signal : F_TRIG;

    // Обратная связь
    _inputSignalTrigger_rt : R_TRIG;
    _xWaitingFeedback : BOOL;
    _xFeedbackReceived : BOOL;

    // Таймер обратной связи
    _ton_FeedbackTimeout : TON;
    _xFeedbackTimeout : BOOL;

    // Фильтрация дребезга входного сигнала
    _ton_StabilityFilter : TON;
    _xFilteredSignal : BOOL;
    _rt_SignalChange : R_TRIG;
    _ft_SignalChange : F_TRIG;
    _nTransitionCounter : UINT;
    _ton_DetectionWindow : TON;
    _xRattlingDetected : BOOL;
    _xDetectionActive : BOOL;

    // Фильтрация дребезга сигнала обратной связи
    _ton_FeedbackStabilityFilter : TON;
    _xFilteredFeedback : BOOL;

    // Обработанные сигналы
    _xProcessedSignal : BOOL;
    _xProcessedFeedback : BOOL;
END_VAR
// =====================================
// ОБРАБОТКА ВХОДНОГО СИГНАЛА
// =====================================

// Выбор источника сигнала (с фильтром или без)
IF xEnableRattlingFilter THEN
    // Фильтрация дребезга
    _ton_StabilityFilter(IN := ixSignal, PT := tStabilityTime);
    _xFilteredSignal := _ton_StabilityFilter.Q;
    _xProcessedSignal := _xFilteredSignal;

    // Обнаружение дребезга
    _rt_SignalChange(CLK := ixSignal);
    _ft_SignalChange(CLK := ixSignal);

    IF _rt_SignalChange.Q OR _ft_SignalChange.Q THEN
        IF NOT _xDetectionActive THEN
            _xDetectionActive := TRUE;
            _nTransitionCounter := 1;
        ELSE
            _nTransitionCounter := _nTransitionCounter + 1;
        END_IF
    END_IF

    _ton_DetectionWindow(IN := _xDetectionActive, PT := tDetectionWindow);

    IF _ton_DetectionWindow.Q THEN
        IF _nTransitionCounter >= nMaxTransitions THEN
            _xRattlingDetected := TRUE;
        END_IF
        _xDetectionActive := FALSE;
        _nTransitionCounter := 0;
        _ton_DetectionWindow(IN := FALSE);
    END_IF

    qxRattlingDetected := _xRattlingDetected;
    qnTransitionCount := _nTransitionCounter;
ELSE
    _xProcessedSignal := ixSignal;
    qxRattlingDetected := FALSE;
    qnTransitionCount := 0;
END_IF

// =====================================
// ОБРАБОТКА СИГНАЛА ОБРАТНОЙ СВЯЗИ
// =====================================

// Применение фильтра дребезга к сигналу обратной связи (если включено)
IF xEnableFeedback AND xEnableRattlingFilter THEN
    // Фильтрация дребезга сигнала обратной связи
    _ton_FeedbackStabilityFilter(IN := ixFeedback, PT := tStabilityTime);
    _xFilteredFeedback := _ton_FeedbackStabilityFilter.Q;
    _xProcessedFeedback := _xFilteredFeedback;
ELSE
    // Без фильтрации - прямая передача сигнала
    _xProcessedFeedback := ixFeedback;
END_IF

// =====================================
// ДЕТЕКТИРОВАНИЕ ФРОНТОВ
// =====================================
_rt_Signal(CLK := _xProcessedSignal);
_ft_Signal(CLK := _xProcessedSignal);

qxRisingEdge := _rt_Signal.Q;
qxFallingEdge := _ft_Signal.Q;

// =====================================
// ОБРАТНАЯ СВЯЗЬ
// =====================================
IF xEnableFeedback THEN
    // Триггер для фиксации сигнала поступления команды
    _inputSignalTrigger_rt(CLK := _xProcessedSignal);

    // Задание флага ожидания при получении команды
    IF _inputSignalTrigger_rt.Q AND NOT _xWaitingFeedback THEN
        _xWaitingFeedback := TRUE;
        _xFeedbackReceived := FALSE;
    END_IF

    // Задание флага получения обратной связи (используется отфильтрованный сигнал)
    IF _xWaitingFeedback AND _xProcessedFeedback THEN
        _xFeedbackReceived := TRUE;
        _xWaitingFeedback := FALSE;
    END_IF

    // Таймер обратной связи (если включен)
    IF xEnableFeedbackTimer THEN
        _ton_FeedbackTimeout(IN := _xWaitingFeedback, PT := itFeedbackTimeout);

        IF _ton_FeedbackTimeout.Q AND NOT _xFeedbackTimeout THEN
            _xFeedbackTimeout := TRUE;
            _xWaitingFeedback := FALSE;
        END_IF

        IF _xFeedbackReceived THEN
            _ton_FeedbackTimeout(IN := FALSE);
            _xFeedbackTimeout := FALSE;
        END_IF

        qxFeedbackTimeout := _xFeedbackTimeout;
    ELSE
        qxFeedbackTimeout := FALSE;
    END_IF

    qxWaitingFeedback := _xWaitingFeedback;
    qxFeedbackReceived := _xFeedbackReceived;
ELSE
    qxWaitingFeedback := FALSE;
    qxFeedbackReceived := FALSE;
    qxFeedbackTimeout := FALSE;
END_IF

// =====================================
// ВЫХОДНЫЕ СИГНАЛЫ
// =====================================
qxSignal := _xProcessedSignal;
qxInvertedSignal := NOT _xProcessedSignal;

END_FUNCTION_BLOCK