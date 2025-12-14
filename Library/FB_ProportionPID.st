FUNCTION_BLOCK FB_ProportionPID

// ============================================================================
// ВХОДНЫЕ ПЕРЕМЕННЫЕ
// ============================================================================
VAR_INPUT
    // ------------------------------------------------------------------------
    // Команды управления
    // ------------------------------------------------------------------------
    xEnable                 : BOOL;         // Разрешение работы блока
    xReset                  : BOOL;         // Сброс интегральной составляющей ПИД

    // ------------------------------------------------------------------------
    // Целевые пропорции (уставки оператора)
    // ------------------------------------------------------------------------
    rProportionTarget_1     : REAL;         // Целевая пропорция бункера 1 [0..1]
    rProportionTarget_2     : REAL;         // Целевая пропорция бункера 2 [0..1]
    rProportionTarget_3     : REAL;         // Целевая пропорция бункера 3 [0..1]
                                            // Сумма должна = 1.0 (100%)
                                            // Значение 0.0 = бункер неактивен

    // ------------------------------------------------------------------------
    // Фактические пропорции (с конвейерных весов)
    // ------------------------------------------------------------------------
    rProportionActual_1     : REAL;         // Фактическая пропорция бункера 1 [0..1]
    rProportionActual_2     : REAL;         // Фактическая пропорция бункера 2 [0..1]
    rProportionActual_3     : REAL;         // Фактическая пропорция бункера 3 [0..1]

    // ------------------------------------------------------------------------
    // Параметры ПИД-регулятора
    // ------------------------------------------------------------------------
    rPID_Kp                 : REAL := 1.0;  // Пропорциональный коэффициент
    rPID_Ki                 : REAL := 0.2;  // Интегральный коэффициент
    rPID_Kd                 : REAL := 0.05; // Дифференциальный коэффициент
    rPID_IntegralLimit      : REAL := 10.0; // Ограничение интеграла (anti-windup)
    rPID_DerivativeFilter   : REAL := 0.1;  // Коэффициент фильтрации D-составляющей [0..1]
                                            // 0 = нет фильтрации, 1 = максимум фильтра

    // ------------------------------------------------------------------------
    // Базовые частоты (рассчитываются заранее в INIT)
    // ------------------------------------------------------------------------
    rFrequencyBase_1        : REAL;         // Базовая частота бункера 1, Гц
    rFrequencyBase_2        : REAL;         // Базовая частота бункера 2, Гц
    rFrequencyBase_3        : REAL;         // Базовая частота бункера 3, Гц

    // ------------------------------------------------------------------------
    // Параметры оборудования
    // ------------------------------------------------------------------------
    rFrequency_Min          : REAL := 1.0;  // Минимальная частота ЧРП, Гц
    rFrequency_Max          : REAL := 35.0; // Максимальная частота ЧРП, Гц
    rFrequency_TargetSum    : REAL := 90.0; // Целевая суммарная частота для нормализации, Гц

    // ------------------------------------------------------------------------
    // Параметры расчета
    // ------------------------------------------------------------------------
    rDeltaTime              : REAL := 0.1;  // Период вызова блока, сек

    // ------------------------------------------------------------------------
    // Параметры алгоритма
    // ------------------------------------------------------------------------
    rScaleLimit_Min         : REAL := 0.1;  // Минимальный коэффициент масштабирования
    rScaleLimit_Max         : REAL := 3.0;  // Максимальный коэффициент масштабирования
    rProportionThreshold    : REAL := 0.001; // Порог для определения неактивного бункера
END_VAR

// ============================================================================
// ВЫХОДНЫЕ ПЕРЕМЕННЫЕ
// ============================================================================
VAR_OUTPUT
    // ------------------------------------------------------------------------
    // Управляющие воздействия (частоты ЧРП)
    // ------------------------------------------------------------------------
    qrFrequency_1           : REAL;         // Уставка частоты ЧРП бункера 1, Гц
    qrFrequency_2           : REAL;         // Уставка частоты ЧРП бункера 2, Гц
    qrFrequency_3           : REAL;         // Уставка частоты ЧРП бункера 3, Гц

    // ------------------------------------------------------------------------
    // Состояние работы
    // ------------------------------------------------------------------------
    qxActive                : BOOL;         // Блок активен и регулирует частоты
    qxError                 : BOOL;         // Ошибка работы блока
    quErrorCode             : UINT;         // Код ошибки:
                                            // 0 = нет ошибок
                                            // 1 = сумма пропорций = 0
                                            // 2 = неверный DeltaTime
                                            // 3 = неверные пределы частот
                                            // 4 = неверная целевая сумма частот

    // ------------------------------------------------------------------------
    // Диагностическая информация
    // ------------------------------------------------------------------------
    qrFrequency_Sum         : REAL;         // Фактическая суммарная частота, Гц
    qrProportionSum         : REAL;         // Сумма целевых пропорций
    qxProportionNormalized  : BOOL;         // TRUE = пропорции автоматически нормализованы

    // ------------------------------------------------------------------------
    // Выходы ПИД-регуляторов (для диагностики)
    // ------------------------------------------------------------------------
    qrPID_Output_1          : REAL;         // Выход ПИД регулятора 1 [0..1]
    qrPID_Output_2          : REAL;         // Выход ПИД регулятора 2 [0..1]
    qrPID_Output_3          : REAL;         // Выход ПИД регулятора 3 [0..1]

    qrPID_Error_1           : REAL;         // Текущая ошибка ПИД 1
    qrPID_Error_2           : REAL;         // Текущая ошибка ПИД 2
    qrPID_Error_3           : REAL;         // Текущая ошибка ПИД 3

    qrPID_Integral_1        : REAL;         // Интегральная составляющая ПИД 1
    qrPID_Integral_2        : REAL;         // Интегральная составляющая ПИД 2
    qrPID_Integral_3        : REAL;         // Интегральная составляющая ПИД 3
END_VAR

// ============================================================================
// ВНУТРЕННИЕ ПЕРЕМЕННЫЕ
// ============================================================================
VAR
    // ------------------------------------------------------------------------
    // Состояние ПИД-регуляторов
    // ------------------------------------------------------------------------
    _rPrevError_1           : REAL := 0.0;  // Предыдущая ошибка ПИД 1
    _rPrevError_2           : REAL := 0.0;  // Предыдущая ошибка ПИД 2
    _rPrevError_3           : REAL := 0.0;  // Предыдущая ошибка ПИД 3

    _rIntegral_1            : REAL := 0.0;  // Интегральная составляющая ПИД 1
    _rIntegral_2            : REAL := 0.0;  // Интегральная составляющая ПИД 2
    _rIntegral_3            : REAL := 0.0;  // Интегральная составляющая ПИД 3

    _rDerivativeFiltered_1  : REAL := 0.0;  // Фильтрованная производная ПИД 1
    _rDerivativeFiltered_2  : REAL := 0.0;  // Фильтрованная производная ПИД 2
    _rDerivativeFiltered_3  : REAL := 0.0;  // Фильтрованная производная ПИД 3

    // ------------------------------------------------------------------------
    // Флаги активности бункеров
    // ------------------------------------------------------------------------
    _xBunker1_Active        : BOOL := FALSE; // Бункер 1 активен
    _xBunker2_Active        : BOOL := FALSE; // Бункер 2 активен
    _xBunker3_Active        : BOOL := FALSE; // Бункер 3 активен

    // ------------------------------------------------------------------------
    // Нормализованные пропорции
    // ------------------------------------------------------------------------
    _rProportionNorm_1      : REAL := 0.0;  // Нормализованная пропорция 1
    _rProportionNorm_2      : REAL := 0.0;  // Нормализованная пропорция 2
    _rProportionNorm_3      : REAL := 0.0;  // Нормализованная пропорция 3

    // ------------------------------------------------------------------------
    // Промежуточные расчеты частот
    // ------------------------------------------------------------------------
    _rFreqScaled_1          : REAL := 0.0;  // Масштабированная частота 1
    _rFreqScaled_2          : REAL := 0.0;  // Масштабированная частота 2
    _rFreqScaled_3          : REAL := 0.0;  // Масштабированная частота 3

    _rScale_1               : REAL := 1.0;  // Коэффициент масштабирования 1
    _rScale_2               : REAL := 1.0;  // Коэффициент масштабирования 2
    _rScale_3               : REAL := 1.0;  // Коэффициент масштабирования 3

    // ------------------------------------------------------------------------
    // Вспомогательные переменные
    // ------------------------------------------------------------------------
    _rError                 : REAL;         // Текущая ошибка (временная)
    _rDerivative            : REAL;         // Дифференциальная составляющая (временная)
    _rOutput                : REAL;         // Выход ПИД (временная)
    _rSumScaled             : REAL;         // Сумма масштабированных частот
    _rProportionSumInput    : REAL;         // Сумма входных пропорций
END_VAR

// ============================================================================
// ОСНОВНОЙ КОД ФУНКЦИОНАЛЬНОГО БЛОКА
// ============================================================================

// ============================================================================
// ПРОВЕРКА КОМАНДЫ ENABLE
// ============================================================================
IF NOT xEnable THEN
    // Блок выключен - сброс всех выходов
    qxActive := FALSE;
    qrFrequency_1 := 0.0;
    qrFrequency_2 := 0.0;
    qrFrequency_3 := 0.0;
    qrFrequency_Sum := 0.0;

    // Сброс диагностических выходов
    qrPID_Output_1 := 0.0;
    qrPID_Output_2 := 0.0;
    qrPID_Output_3 := 0.0;
    qrPID_Error_1 := 0.0;
    qrPID_Error_2 := 0.0;
    qrPID_Error_3 := 0.0;
    qrPID_Integral_1 := 0.0;
    qrPID_Integral_2 := 0.0;
    qrPID_Integral_3 := 0.0;

    // Сброс внутренних переменных ПИД
    _rIntegral_1 := 0.0;
    _rIntegral_2 := 0.0;
    _rIntegral_3 := 0.0;
    _rPrevError_1 := 0.0;
    _rPrevError_2 := 0.0;
    _rPrevError_3 := 0.0;
    _rDerivativeFiltered_1 := 0.0;
    _rDerivativeFiltered_2 := 0.0;
    _rDerivativeFiltered_3 := 0.0;

    RETURN; // Выход из блока
END_IF

// ============================================================================
// ВАЛИДАЦИЯ ПАРАМЕТРОВ И ДИАГНОСТИКА ОШИБОК
// ============================================================================
qxError := FALSE;
quErrorCode := 0;

// Проверка периода вызова
IF rDeltaTime <= 0.0 OR rDeltaTime > 1.0 THEN
    qxError := TRUE;
    quErrorCode := 2;
    RETURN;
END_IF

// Проверка пределов частот
IF rFrequency_Min >= rFrequency_Max THEN
    qxError := TRUE;
    quErrorCode := 3;
    RETURN;
END_IF

// Проверка целевой суммы частот
IF rFrequency_TargetSum <= 0.0 THEN
    qxError := TRUE;
    quErrorCode := 4;
    RETURN;
END_IF

// ============================================================================
// ВАЛИДАЦИЯ И НОРМАЛИЗАЦИЯ ЦЕЛЕВЫХ ПРОПОРЦИЙ
// ============================================================================
_rProportionSumInput := rProportionTarget_1 + rProportionTarget_2 + rProportionTarget_3;

// Проверка: сумма пропорций должна быть > 0
IF _rProportionSumInput < 0.0001 THEN
    // Все бункеры неактивны
    qxError := TRUE;
    quErrorCode := 1;
    qrFrequency_1 := 0.0;
    qrFrequency_2 := 0.0;
    qrFrequency_3 := 0.0;
    qrFrequency_Sum := 0.0;
    RETURN;
END_IF

// Нормализация пропорций, если сумма != 1.0
IF ABS(_rProportionSumInput - 1.0) > 0.001 THEN
    _rProportionNorm_1 := rProportionTarget_1 / _rProportionSumInput;
    _rProportionNorm_2 := rProportionTarget_2 / _rProportionSumInput;
    _rProportionNorm_3 := rProportionTarget_3 / _rProportionSumInput;
    qxProportionNormalized := TRUE;
ELSE
    _rProportionNorm_1 := rProportionTarget_1;
    _rProportionNorm_2 := rProportionTarget_2;
    _rProportionNorm_3 := rProportionTarget_3;
    qxProportionNormalized := FALSE;
END_IF

qrProportionSum := _rProportionNorm_1 + _rProportionNorm_2 + _rProportionNorm_3;

// ============================================================================
// ОПРЕДЕЛЕНИЕ АКТИВНОСТИ БУНКЕРОВ
// ============================================================================
_xBunker1_Active := (_rProportionNorm_1 > rProportionThreshold);
_xBunker2_Active := (_rProportionNorm_2 > rProportionThreshold);
_xBunker3_Active := (_rProportionNorm_3 > rProportionThreshold);

// ============================================================================
// ОБРАБОТКА КОМАНДЫ RESET (сброс интегралов)
// ============================================================================
IF xReset THEN
    _rIntegral_1 := 0.0;
    _rIntegral_2 := 0.0;
    _rIntegral_3 := 0.0;
    _rPrevError_1 := 0.0;
    _rPrevError_2 := 0.0;
    _rPrevError_3 := 0.0;
END_IF

// ============================================================================
// ОБНОВЛЕНИЕ ПИД-РЕГУЛЯТОРОВ
// ============================================================================

// ----------------------------------------------------------------------------
// ПИД-регулятор бункера 1
// ----------------------------------------------------------------------------
IF _xBunker1_Active THEN
    // Расчет ошибки регулирования
    _rError := _rProportionNorm_1 - rProportionActual_1;
    qrPID_Error_1 := _rError;

    // Расчет дифференциальной составляющей (сырая производная)
    _rDerivative := (_rError - _rPrevError_1) / rDeltaTime;

    // Низкочастотный фильтр первого порядка для D-составляющей
    // D_filtered(n) = alpha * D_raw + (1-alpha) * D_filtered(n-1)
    // alpha = 1 - rPID_DerivativeFilter (меньше alpha = больше фильтрации)
    _rDerivativeFiltered_1 := (1.0 - rPID_DerivativeFilter) * _rDerivative
                            + rPID_DerivativeFilter * _rDerivativeFiltered_1;

    // ПИД формула: u(t) = Kp*e(t) + Ki*∫e(t)dt + Kd*de(t)/dt
    _rOutput := rPID_Kp * _rError + rPID_Ki * _rIntegral_1 + rPID_Kd * _rDerivativeFiltered_1;

    // Условная интеграция (conditional integration anti-windup):
    // Накапливаем интеграл ТОЛЬКО если выход не насыщен
    // или если ошибка уменьшает насыщение
    IF (_rOutput >= 0.0 AND _rOutput <= 1.0) OR
       (_rOutput < 0.0 AND _rError > 0.0) OR
       (_rOutput > 1.0 AND _rError < 0.0) THEN
        _rIntegral_1 := _rIntegral_1 + _rError * rDeltaTime;

        // Ограничение интеграла (дополнительная защита)
        IF _rIntegral_1 > rPID_IntegralLimit THEN
            _rIntegral_1 := rPID_IntegralLimit;
        ELSIF _rIntegral_1 < -rPID_IntegralLimit THEN
            _rIntegral_1 := -rPID_IntegralLimit;
        END_IF
    END_IF

    qrPID_Integral_1 := _rIntegral_1;

    // Ограничение выхода в диапазоне [0..1]
    IF _rOutput < 0.0 THEN
        _rOutput := 0.0;
    ELSIF _rOutput > 1.0 THEN
        _rOutput := 1.0;
    END_IF

    qrPID_Output_1 := _rOutput;

    // Сохранение ошибки для следующей итерации
    _rPrevError_1 := _rError;
ELSE
    // Бункер неактивен - сброс ПИД
    qrPID_Output_1 := 0.0;
    qrPID_Error_1 := 0.0;
    qrPID_Integral_1 := 0.0;
    _rIntegral_1 := 0.0;              // КРИТИЧНО: сброс внутреннего интеграла
    _rPrevError_1 := 0.0;
    _rDerivativeFiltered_1 := 0.0;    // Сброс фильтра производной
END_IF

// ----------------------------------------------------------------------------
// ПИД-регулятор бункера 2
// ----------------------------------------------------------------------------
IF _xBunker2_Active THEN
    _rError := _rProportionNorm_2 - rProportionActual_2;
    qrPID_Error_2 := _rError;

    _rDerivative := (_rError - _rPrevError_2) / rDeltaTime;
    _rDerivativeFiltered_2 := (1.0 - rPID_DerivativeFilter) * _rDerivative
                            + rPID_DerivativeFilter * _rDerivativeFiltered_2;

    _rOutput := rPID_Kp * _rError + rPID_Ki * _rIntegral_2 + rPID_Kd * _rDerivativeFiltered_2;

    // Условная интеграция (anti-windup)
    IF (_rOutput >= 0.0 AND _rOutput <= 1.0) OR
       (_rOutput < 0.0 AND _rError > 0.0) OR
       (_rOutput > 1.0 AND _rError < 0.0) THEN
        _rIntegral_2 := _rIntegral_2 + _rError * rDeltaTime;

        IF _rIntegral_2 > rPID_IntegralLimit THEN
            _rIntegral_2 := rPID_IntegralLimit;
        ELSIF _rIntegral_2 < -rPID_IntegralLimit THEN
            _rIntegral_2 := -rPID_IntegralLimit;
        END_IF
    END_IF

    qrPID_Integral_2 := _rIntegral_2;

    IF _rOutput < 0.0 THEN
        _rOutput := 0.0;
    ELSIF _rOutput > 1.0 THEN
        _rOutput := 1.0;
    END_IF

    qrPID_Output_2 := _rOutput;
    _rPrevError_2 := _rError;
ELSE
    qrPID_Output_2 := 0.0;
    qrPID_Error_2 := 0.0;
    qrPID_Integral_2 := 0.0;
    _rIntegral_2 := 0.0;              // КРИТИЧНО: сброс внутреннего интеграла
    _rPrevError_2 := 0.0;
    _rDerivativeFiltered_2 := 0.0;    // Сброс фильтра производной
END_IF

// ----------------------------------------------------------------------------
// ПИД-регулятор бункера 3
// ----------------------------------------------------------------------------
IF _xBunker3_Active THEN
    _rError := _rProportionNorm_3 - rProportionActual_3;
    qrPID_Error_3 := _rError;

    _rDerivative := (_rError - _rPrevError_3) / rDeltaTime;
    _rDerivativeFiltered_3 := (1.0 - rPID_DerivativeFilter) * _rDerivative
                            + rPID_DerivativeFilter * _rDerivativeFiltered_3;

    _rOutput := rPID_Kp * _rError + rPID_Ki * _rIntegral_3 + rPID_Kd * _rDerivativeFiltered_3;

    // Условная интеграция (anti-windup)
    IF (_rOutput >= 0.0 AND _rOutput <= 1.0) OR
       (_rOutput < 0.0 AND _rError > 0.0) OR
       (_rOutput > 1.0 AND _rError < 0.0) THEN
        _rIntegral_3 := _rIntegral_3 + _rError * rDeltaTime;

        IF _rIntegral_3 > rPID_IntegralLimit THEN
            _rIntegral_3 := rPID_IntegralLimit;
        ELSIF _rIntegral_3 < -rPID_IntegralLimit THEN
            _rIntegral_3 := -rPID_IntegralLimit;
        END_IF
    END_IF

    qrPID_Integral_3 := _rIntegral_3;

    IF _rOutput < 0.0 THEN
        _rOutput := 0.0;
    ELSIF _rOutput > 1.0 THEN
        _rOutput := 1.0;
    END_IF

    qrPID_Output_3 := _rOutput;
    _rPrevError_3 := _rError;
ELSE
    qrPID_Output_3 := 0.0;
    qrPID_Error_3 := 0.0;
    qrPID_Integral_3 := 0.0;
    _rIntegral_3 := 0.0;              // КРИТИЧНО: сброс внутреннего интеграла
    _rPrevError_3 := 0.0;
    _rDerivativeFiltered_3 := 0.0;    // Сброс фильтра производной
END_IF

// ============================================================================
// РАСЧЕТ ЧАСТОТ ЧРП (АДАПТИВНЫЙ АЛГОРИТМ)
// ============================================================================
// Базовые частоты (rFrequencyBase_1/2/3) рассчитываются заранее в INIT
// на основе пропорций и целевой суммарной частоты

// ----------------------------------------------------------------------------
// ШАГ 1: Применение ПИД-коррекции к базовым частотам
// ----------------------------------------------------------------------------
// Новый алгоритм: ПИД-выход напрямую добавляется к базовой частоте
// Формула: Freq = FreqBase + PID_Output * CorrectioRange
// где CorrectionRange = диапазон коррекции вокруг базовой частоты

// Бункер 1
IF _xBunker1_Active THEN
    // Диапазон коррекции = базовая частота (можно изменить на другой коэффициент)
    _rScale_1 := rFrequencyBase_1;

    // ПИД-выход [0..1] преобразуется в коррекцию [-FreqBase..+FreqBase]
    // qrPID_Output_1 = 0.5 → нет коррекции
    // qrPID_Output_1 > 0.5 → увеличение частоты
    // qrPID_Output_1 < 0.5 → уменьшение частоты
    _rFreqScaled_1 := rFrequencyBase_1 + (qrPID_Output_1 - 0.5) * 2.0 * _rScale_1;

    // Ограничение коэффициента масштабирования (для диагностики)
    _rScale_1 := _rFreqScaled_1 / rFrequencyBase_1;
    IF _rScale_1 < rScaleLimit_Min THEN
        _rScale_1 := rScaleLimit_Min;
        _rFreqScaled_1 := rFrequencyBase_1 * _rScale_1;
    ELSIF _rScale_1 > rScaleLimit_Max THEN
        _rScale_1 := rScaleLimit_Max;
        _rFreqScaled_1 := rFrequencyBase_1 * _rScale_1;
    END_IF
ELSE
    _rFreqScaled_1 := 0.0;
    _rScale_1 := 0.0;
END_IF

// Бункер 2
IF _xBunker2_Active THEN
    _rScale_2 := rFrequencyBase_2;
    _rFreqScaled_2 := rFrequencyBase_2 + (qrPID_Output_2 - 0.5) * 2.0 * _rScale_2;

    _rScale_2 := _rFreqScaled_2 / rFrequencyBase_2;
    IF _rScale_2 < rScaleLimit_Min THEN
        _rScale_2 := rScaleLimit_Min;
        _rFreqScaled_2 := rFrequencyBase_2 * _rScale_2;
    ELSIF _rScale_2 > rScaleLimit_Max THEN
        _rScale_2 := rScaleLimit_Max;
        _rFreqScaled_2 := rFrequencyBase_2 * _rScale_2;
    END_IF
ELSE
    _rFreqScaled_2 := 0.0;
    _rScale_2 := 0.0;
END_IF

// Бункер 3
IF _xBunker3_Active THEN
    _rScale_3 := rFrequencyBase_3;
    _rFreqScaled_3 := rFrequencyBase_3 + (qrPID_Output_3 - 0.5) * 2.0 * _rScale_3;

    _rScale_3 := _rFreqScaled_3 / rFrequencyBase_3;
    IF _rScale_3 < rScaleLimit_Min THEN
        _rScale_3 := rScaleLimit_Min;
        _rFreqScaled_3 := rFrequencyBase_3 * _rScale_3;
    ELSIF _rScale_3 > rScaleLimit_Max THEN
        _rScale_3 := rScaleLimit_Max;
        _rFreqScaled_3 := rFrequencyBase_3 * _rScale_3;
    END_IF
ELSE
    _rFreqScaled_3 := 0.0;
    _rScale_3 := 0.0;
END_IF

// ----------------------------------------------------------------------------
// ШАГ 2: Применение ограничений оборудования (до нормализации!)
// ----------------------------------------------------------------------------

// Бункер 1
IF _xBunker1_Active THEN
    IF _rFreqScaled_1 > rFrequency_Max THEN
        _rFreqScaled_1 := rFrequency_Max;
    ELSIF _rFreqScaled_1 < rFrequency_Min THEN
        _rFreqScaled_1 := rFrequency_Min;
    END_IF
ELSE
    _rFreqScaled_1 := 0.0;
END_IF

// Бункер 2
IF _xBunker2_Active THEN
    IF _rFreqScaled_2 > rFrequency_Max THEN
        _rFreqScaled_2 := rFrequency_Max;
    ELSIF _rFreqScaled_2 < rFrequency_Min THEN
        _rFreqScaled_2 := rFrequency_Min;
    END_IF
ELSE
    _rFreqScaled_2 := 0.0;
END_IF

// Бункер 3
IF _xBunker3_Active THEN
    IF _rFreqScaled_3 > rFrequency_Max THEN
        _rFreqScaled_3 := rFrequency_Max;
    ELSIF _rFreqScaled_3 < rFrequency_Min THEN
        _rFreqScaled_3 := rFrequency_Min;
    END_IF
ELSE
    _rFreqScaled_3 := 0.0;
END_IF

// ----------------------------------------------------------------------------
// ШАГ 3: Нормализация для поддержания целевой суммарной частоты
// ----------------------------------------------------------------------------
// КРИТИЧНО: нормализация ПОСЛЕ ограничений, чтобы сумма всегда = TargetSum
_rSumScaled := _rFreqScaled_1 + _rFreqScaled_2 + _rFreqScaled_3;

// Защита от деления на ноль
IF _rSumScaled < 0.01 THEN
    _rSumScaled := 0.01;
END_IF

qrFrequency_1 := _rFreqScaled_1 * (rFrequency_TargetSum / _rSumScaled);
qrFrequency_2 := _rFreqScaled_2 * (rFrequency_TargetSum / _rSumScaled);
qrFrequency_3 := _rFreqScaled_3 * (rFrequency_TargetSum / _rSumScaled);

// ============================================================================
// ОБНОВЛЕНИЕ ДИАГНОСТИЧЕСКИХ ВЫХОДОВ
// ============================================================================
qrFrequency_Sum := qrFrequency_1 + qrFrequency_2 + qrFrequency_3;
qxActive := TRUE;

END_FUNCTION_BLOCK