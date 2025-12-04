FUNCTION_BLOCK FB_PreStartAlarm
VAR_INPUT
    ixStart : BOOL;                    // Сигнал на запуск
    ixStop : BOOL;                     // Сигнал на стоп (Reset)
    itFirstSignal : TIME;              // Уставка первого сигнала
    itPauseAfterFirst : TIME;          // Уставка паузы после первого сигнала
    itSecondSignal : TIME;             // Уставка второго сигнала
    itPauseAfterSecond : TIME;         // Уставка паузы после второго сигнала
END_VAR

VAR_OUTPUT
    qxAlarmPower : BOOL;               // Питание звуковой сигнализации
    qxActive : BOOL;                   // Активная работа ФБ
    qxComplete : BOOL;                 // Импульс о завершении работы
    qnSecondsRemaining : INT;          // Количество секунд до завершения
    qwSecondsRemaining : WORD;		    // Количество секунд до завершения (тип WORD)
END_VAR

VAR
    _eState : (
        IDLE := 0,              // Ожидание запуска
        FIRST_SIGNAL := 1,      // Первый звуковой сигнал
        PAUSE_AFTER_FIRST := 2, // Пауза после первого сигнала
        SECOND_SIGNAL := 3,     // Второй звуковой сигнал
        PAUSE_AFTER_SECOND := 4,// Пауза после второго сигнала
        COMPLETE := 5           // Завершение
    ) := IDLE;                         // Состояние автомата
    _tonTimer : TON;                   // Универсальный таймер для всех этапов
    _xCompleteInternal : BOOL;         // Внутренний сигнал завершения
    _rtrigComplete : R_TRIG;           // Детектор переднего фронта для импульса завершения
END_VAR

qwSecondsRemaining := TO_WORD(qnSecondsRemaining);

// Обработка сигнала СТОП (сброс)
IF ixStop THEN
    _eState := IDLE;
    qxActive := FALSE;
    qxAlarmPower := FALSE;
    _tonTimer(IN := FALSE);
    _xCompleteInternal := FALSE;
    qxComplete := FALSE;
    qnSecondsRemaining := 0;
    RETURN;
END_IF

// Автомат состояний
CASE _eState OF
    
    IDLE: // Ожидание запуска
        qxActive := FALSE;
        qxAlarmPower := FALSE;
        _xCompleteInternal := FALSE;
        _tonTimer(IN := FALSE);
        qnSecondsRemaining := 0;

        IF ixStart THEN
			qxActive := TRUE;
            _eState := FIRST_SIGNAL;
        END_IF
    
    FIRST_SIGNAL: // Первый сигнал
        qxAlarmPower := TRUE;
        _tonTimer(IN := TRUE, PT := itFirstSignal);

        // Расчет оставшегося времени в секундах
        qnSecondsRemaining := DINT_TO_INT(
            (TIME_TO_DINT(itFirstSignal - _tonTimer.ET) +
             TIME_TO_DINT(itPauseAfterFirst) +
             TIME_TO_DINT(itSecondSignal) +
             TIME_TO_DINT(itPauseAfterSecond)) / 1000
        );

        IF _tonTimer.Q THEN
            _tonTimer(IN := FALSE);
            _eState := PAUSE_AFTER_FIRST;
        END_IF
    
    PAUSE_AFTER_FIRST: // Пауза после первого сигнала
        qxAlarmPower := FALSE;
        _tonTimer(IN := TRUE, PT := itPauseAfterFirst);

        // Расчет оставшегося времени в секундах
        qnSecondsRemaining := DINT_TO_INT(
            (TIME_TO_DINT(itPauseAfterFirst - _tonTimer.ET) +
             TIME_TO_DINT(itSecondSignal) +
             TIME_TO_DINT(itPauseAfterSecond)) / 1000
        );

        IF _tonTimer.Q THEN
            _tonTimer(IN := FALSE);
            _eState := SECOND_SIGNAL;
        END_IF
    
    SECOND_SIGNAL: // Второй сигнал
        qxAlarmPower := TRUE;
        _tonTimer(IN := TRUE, PT := itSecondSignal);

        // Расчет оставшегося времени в секундах
        qnSecondsRemaining := DINT_TO_INT(
            (TIME_TO_DINT(itSecondSignal - _tonTimer.ET) +
             TIME_TO_DINT(itPauseAfterSecond)) / 1000
        );

        IF _tonTimer.Q THEN
            _tonTimer(IN := FALSE);
            _eState := PAUSE_AFTER_SECOND;
        END_IF
    
    PAUSE_AFTER_SECOND: // Пауза после второго сигнала
        qxAlarmPower := FALSE;
        _tonTimer(IN := TRUE, PT := itPauseAfterSecond);

        // Расчет оставшегося времени в секундах
        qnSecondsRemaining := DINT_TO_INT(
            TIME_TO_DINT(itPauseAfterSecond - _tonTimer.ET) / 1000
        );

        IF _tonTimer.Q THEN
            _tonTimer(IN := FALSE);
            _eState := COMPLETE;
        END_IF
    
    COMPLETE: // Завершение
        qxAlarmPower := FALSE;
        qxActive := FALSE;
        _xCompleteInternal := TRUE;
        qnSecondsRemaining := 0;
        _eState := IDLE;  // Вернуться в начальное состояние
END_CASE

// Генерация импульса завершения через R_TRIG
_rtrigComplete(CLK := _xCompleteInternal);
qxComplete := _rtrigComplete.Q;

END_FUNCTION_BLOCK