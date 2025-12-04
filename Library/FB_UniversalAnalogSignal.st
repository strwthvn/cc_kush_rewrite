FUNCTION_BLOCK FB_UniversalAnalogSignal
VAR_INPUT
    irRawValue : REAL;                          // Исходное значение аналогового сигнала
    xSimulationMode : BOOL := FALSE;            // Флаг режима симуляции сигнала
    rSimulatedValue : REAL := 0.0;              // Симулируемое значение

    // Диапазон входного аналогового сигнала
    rInputMin : REAL := 0.0;                    // Минимальное значение входного сигнала
    rInputMax : REAL := 10.0;                   // Максимальное значение входного сигнала

    // Диапазон масштабирования (выходные инженерные единицы)
    rScaleMin : REAL := 0.0;                    // Минимальное значение масштабированного диапазона
    rScaleMax : REAL := 100.0;                  // Максимальное значение масштабированного диапазона

    // Настройки
    xEnableRangeProtection : BOOL := TRUE;      // Включение защиты от выхода за диапазон
    xEnableDiagnostics : BOOL := TRUE;          // Включение диагностики сигнала

    // Пороги для расширенной диагностики (в % от диапазона)
    rUnderrangeThreshold : REAL := 5.0;         // Порог для определения критически низкого сигнала
    rOverrangeThreshold : REAL := 5.0;          // Порог для определения критически высокого сигнала

    // Режимы работы (для токовой петли 4-20мА)
    xMode4_20mA : BOOL := FALSE;                // Режим токовой петли 4-20мА
END_VAR
VAR_OUTPUT
    qrProcessedValue : REAL;                    // Обработанное значение сигнала
    qrNormalizedValue : REAL;                   // Нормализованное значение (0..1)
    qrPercentValue : REAL;                      // Процентное значение (0..100%)

    // Флаги диагностики
    qxOutOfRange : BOOL;                        // Флаг выхода за пределы диапазона
    qxSignalUnderrange : BOOL;                  // Сигнал ниже минимума входного диапазона
    qxSignalOverrange : BOOL;                   // Сигнал выше максимума входного диапазона
    qxCriticalLow : BOOL;                       // Критически низкий сигнал
    qxCriticalHigh : BOOL;                      // Критически высокий сигнал

    // Специфичные для токовой петли 4-20мА
    qxWireBreak : BOOL;                         // Обрыв линии (ток < 3.5 мА)
    qxOverload : BOOL;                          // Перегрузка (ток > 21 мА)
    qxUnderrange : BOOL;                        // Сигнал ниже 4 мА
    qxOverrange : BOOL;                         // Сигнал выше 20 мА
    qxHasError : BOOL;                          // Флаг наличия любой ошибки
END_VAR
VAR
    _rProcessedValue : REAL;                    // Обработанное значение сигнала (внутреннее)
    _rNormalizedValue : REAL := 0.0;            // Нормализованное значение (0..1)
    _rPercentValue : REAL := 0.0;               // Процентное значение (0..100%)

    // Диагностика сигнала
    _xOutOfRange : BOOL := FALSE;               // Флаг выхода за пределы диапазона
    _xSignalUnderrange : BOOL := FALSE;         // Сигнал ниже минимума входного диапазона
    _xSignalOverrange : BOOL := FALSE;          // Сигнал выше максимума входного диапазона
    _xCriticalLow : BOOL := FALSE;              // Критически низкий сигнал
    _xCriticalHigh : BOOL := FALSE;             // Критически высокий сигнал

    // Для режима 4-20мА
    _rCurrentMin : REAL := 4.0;                 // Минимальный ток (мА)
    _rCurrentMax : REAL := 20.0;                // Максимальный ток (мА)
    _rWireBreakThreshold : REAL := 3.5;         // Порог обрыва линии
    _rOverloadThreshold : REAL := 21.0;         // Порог перегрузки
    _xUnderrange : BOOL := FALSE;               // Сигнал ниже 4 мА
    _xOverrange : BOOL := FALSE;                // Сигнал выше 20 мА
    _xWireBreak : BOOL := FALSE;                // Обрыв линии
    _xOverload : BOOL := FALSE;                 // Перегрузка

    rRawSignal : REAL;
    rInputRange : REAL;
    rScaleRange : REAL;
    rNormalizedCurrent : REAL;
    rCriticalLowLimit : REAL;
    rCriticalHighLimit : REAL;
END_VAR

// Выбор источника сигнала (симуляция или реальный)
IF xSimulationMode THEN
    rRawSignal := rSimulatedValue;
ELSE
    rRawSignal := irRawValue;
END_IF

// Вычисление диапазонов
rInputRange := rInputMax - rInputMin;
rScaleRange := rScaleMax - rScaleMin;

// Проверка корректности диапазонов
IF (rInputRange = 0) OR (rScaleRange = 0) THEN
    _rProcessedValue := rScaleMin;
    _rNormalizedValue := 0.0;
    _rPercentValue := 0.0;
ELSE
    // Режим токовой петли 4-20мА
    IF xMode4_20mA THEN
        // Диагностика токового сигнала
        _xWireBreak := rRawSignal < _rWireBreakThreshold;
        _xOverload := rRawSignal > _rOverloadThreshold;
        _xUnderrange := (rRawSignal < _rCurrentMin) AND NOT _xWireBreak;
        _xOverrange := (rRawSignal > _rCurrentMax) AND NOT _xOverload;

        // Нормализация тока в диапазон 0..1
        IF (_rCurrentMax - _rCurrentMin) <> 0 THEN
            rNormalizedCurrent := (rRawSignal - _rCurrentMin) / (_rCurrentMax - _rCurrentMin);
        ELSE
            rNormalizedCurrent := 0.0;
        END_IF

        // С ограничением диапазона
        IF xEnableRangeProtection THEN
            IF rNormalizedCurrent < 0.0 THEN
                rNormalizedCurrent := 0.0;
            ELSIF rNormalizedCurrent > 1.0 THEN
                rNormalizedCurrent := 1.0;
            END_IF
        END_IF

        _rNormalizedValue := rNormalizedCurrent;
        _rProcessedValue := rScaleMin + rNormalizedCurrent * (rScaleMax - rScaleMin);
    ELSE
        // Универсальный режим
        // Нормализация входного сигнала (приведение к диапазону 0..1)
        _rNormalizedValue := (rRawSignal - rInputMin) / rInputRange;

        // Применение ограничений если включена защита
        IF xEnableRangeProtection THEN
            IF _rNormalizedValue < 0.0 THEN
                _rNormalizedValue := 0.0;
            ELSIF _rNormalizedValue > 1.0 THEN
                _rNormalizedValue := 1.0;
            END_IF
        END_IF

        // Масштабирование к выходному диапазону
        _rProcessedValue := rScaleMin + _rNormalizedValue * rScaleRange;
    END_IF

    // Процентное значение относительно масштабированного диапазона
    IF (rScaleMax - rScaleMin) <> 0 THEN
        _rPercentValue := ((_rProcessedValue - rScaleMin) / (rScaleMax - rScaleMin)) * 100.0;
    ELSE
        _rPercentValue := 0.0;
    END_IF
END_IF

// =====================================
// ДИАГНОСТИКА
// =====================================
IF xEnableDiagnostics THEN
    // Базовая диагностика диапазона
    _xSignalUnderrange := rRawSignal < rInputMin;
    _xSignalOverrange := rRawSignal > rInputMax;

    // Проверка выхода обработанного значения за пределы
    _xOutOfRange := (_rProcessedValue < rScaleMin) OR (_rProcessedValue > rScaleMax);

    // Расширенная диагностика (критические пределы)
    IF rInputRange <> 0 THEN
        rCriticalLowLimit := rInputMin - (rInputRange * rUnderrangeThreshold / 100.0);
        rCriticalHighLimit := rInputMax + (rInputRange * rOverrangeThreshold / 100.0);

        _xCriticalLow := rRawSignal < rCriticalLowLimit;
        _xCriticalHigh := rRawSignal > rCriticalHighLimit;
    END_IF
ELSE
    _xSignalUnderrange := FALSE;
    _xSignalOverrange := FALSE;
    _xOutOfRange := FALSE;
    _xCriticalLow := FALSE;
    _xCriticalHigh := FALSE;
END_IF

// =====================================
// ОБНОВЛЕНИЕ ВЫХОДОВ
// =====================================
qrProcessedValue := _rProcessedValue;
qrNormalizedValue := _rNormalizedValue;
qrPercentValue := _rPercentValue;

qxOutOfRange := _xOutOfRange;
qxSignalUnderrange := _xSignalUnderrange;
qxSignalOverrange := _xSignalOverrange;
qxCriticalLow := _xCriticalLow;
qxCriticalHigh := _xCriticalHigh;

qxWireBreak := _xWireBreak;
qxOverload := _xOverload;
qxUnderrange := _xUnderrange;
qxOverrange := _xOverrange;

// Общий флаг ошибки
IF xMode4_20mA THEN
    qxHasError := _xWireBreak OR _xOverload OR _xUnderrange OR _xOverrange;
ELSE
    qxHasError := _xSignalUnderrange OR _xSignalOverrange OR _xCriticalLow OR _xCriticalHigh;
END_IF

END_FUNCTION_BLOCK