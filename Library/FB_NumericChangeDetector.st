FUNCTION_BLOCK FB_NumericChangeDetector
VAR_INPUT
    irValue : REAL;                             // Входное числовое значение для мониторинга
    xReset : BOOL;                              // Сброс детектора изменений
END_VAR
VAR_OUTPUT
    qxChangeDetected : BOOL;                    // Импульс при обнаружении изменения значения
    qrCurrentValue : REAL;                      // Текущее отслеживаемое значение
    qrPreviousValue : REAL;                     // Предыдущее значение
    qrValueDifference : REAL;                   // Разность между текущим и предыдущим значением
    qxValueIncreased : BOOL;                    // Флаг увеличения значения
    qxValueDecreased : BOOL;                    // Флаг уменьшения значения
END_VAR
VAR
    _rPreviousValue : REAL := 0.0;              // Предыдущее значение для сравнения
    _xFirstCycle : BOOL := TRUE;                // Флаг первого цикла выполнения
    _rt_Change : R_TRIG;                        // Триггер для генерации импульса
    _xValueChanged : BOOL := FALSE;             // Внутренний флаг изменения
END_VAR

// Сброс детектора
IF xReset THEN
    _rPreviousValue := irValue;
    _xFirstCycle := TRUE;
    _xValueChanged := FALSE;
    _rt_Change(CLK := FALSE);
    qxChangeDetected := FALSE;
    qrValueDifference := 0.0;
    qxValueIncreased := FALSE;
    qxValueDecreased := FALSE;
    RETURN;
END_IF

// Пропускаем первый цикл для корректной инициализации
IF _xFirstCycle THEN
    _rPreviousValue := irValue;
    _xFirstCycle := FALSE;
    _xValueChanged := FALSE;
ELSE
    // Проверяем изменение значения
    IF _rPreviousValue <> irValue THEN
        _xValueChanged := TRUE;
    ELSE
        _xValueChanged := FALSE;
    END_IF
END_IF

// Генерируем импульс при изменении через R_TRIG
_rt_Change(CLK := _xValueChanged);
qxChangeDetected := _rt_Change.Q;

// Вычисляем разность
qrValueDifference := irValue - _rPreviousValue;

// Определяем направление изменения
qxValueIncreased := _xValueChanged AND (irValue > _rPreviousValue);
qxValueDecreased := _xValueChanged AND (irValue < _rPreviousValue);

// Обновляем предыдущее значение после всех вычислений
IF _xValueChanged THEN
    _rPreviousValue := irValue;
END_IF

// Обновляем выходы
qrCurrentValue := irValue;
qrPreviousValue := _rPreviousValue;

END_FUNCTION_BLOCK