FUNCTION_BLOCK FB_FrequencyControl
VAR_INPUT
    irMaxFrequency : REAL := 100.0;             // Максимальная частота
    irStep : REAL := 1.0;                       // Шаг изменения частоты по умолчанию
    rTargetFrequency : REAL := 0.0;             // Целевая частота (уставка)
    xPulse : BOOL;                              // Импульсный сигнал для вычисления
    xConditionToProceed : BOOL := TRUE;         // Условия для продолжения вычисления
    xReset : BOOL;                              // Сброс частоты в ноль
    xHold : BOOL;                               // Удержание текущей частоты
END_VAR
VAR_OUTPUT
    qrCurrentFrequency : REAL;                  // Текущая выходная частота
    qrTargetFrequency : REAL;                   // Целевая частота
    qxTargetReached : BOOL;                     // Флаг достижения целевой частоты
END_VAR
VAR
    _rSetFrequency : REAL;                      // Целевая частота (уставка) внутренняя
    _rCurrentFrequency : REAL;                  // Текущая частота (внутренняя)
    _xInitialized : BOOL := FALSE;              // Флаг инициализации
END_VAR

// Инициализация при первом вызове
IF NOT _xInitialized THEN
    _rCurrentFrequency := 0.0;
    _rSetFrequency := 0.0;
    _xInitialized := TRUE;
END_IF

// Сброс частоты
IF xReset THEN
    _rCurrentFrequency := 0.0;
    _rSetFrequency := 0.0;
    qrCurrentFrequency := 0.0;
    qrTargetFrequency := 0.0;
    qxTargetReached := TRUE;
    RETURN;
END_IF

// Удержание текущей частоты
IF xHold THEN
    _rSetFrequency := _rCurrentFrequency;
    qxTargetReached := TRUE;
END_IF

// Обновление целевой частоты
_rSetFrequency := rTargetFrequency;

// Ограничение целевой частоты
IF _rSetFrequency > irMaxFrequency THEN
    _rSetFrequency := irMaxFrequency;
ELSIF _rSetFrequency < 0.0 THEN
    _rSetFrequency := 0.0;
END_IF

// Обработка изменения частоты
IF xPulse AND xConditionToProceed THEN
    // Плавное изменение частоты к уставке
    IF _rCurrentFrequency < _rSetFrequency - irStep THEN
        // Увеличиваем частоту
        _rCurrentFrequency := _rCurrentFrequency + irStep;
        qxTargetReached := FALSE;
    ELSIF _rCurrentFrequency > _rSetFrequency + irStep THEN
        // Уменьшаем частоту
        _rCurrentFrequency := _rCurrentFrequency - irStep;
        qxTargetReached := FALSE;
    ELSE
        // Достигли целевой частоты
        _rCurrentFrequency := _rSetFrequency;
        qxTargetReached := TRUE;
    END_IF
ELSE
    // Проверяем, достигнута ли целевая частота
    IF ABS(_rCurrentFrequency - _rSetFrequency) < 0.01 THEN
        qxTargetReached := TRUE;
    ELSE
        qxTargetReached := FALSE;
    END_IF
END_IF

// Обновляем выходные значения
qrCurrentFrequency := _rCurrentFrequency;
qrTargetFrequency := _rSetFrequency;

END_FUNCTION_BLOCK