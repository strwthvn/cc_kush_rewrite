FUNCTION_BLOCK FB_RangeDiagnostic
VAR_INPUT
    irValue : REAL;                             // Входное значение для контроля
    irSetpointL : REAL := 20.0;                 // Уставка предупреждения низкого уровня
    irSetpointLL : REAL := 10.0;                // Уставка аварии низкого уровня
    irSetpointH : REAL := 80.0;                 // Уставка предупреждения высокого уровня
    irSetpointHH : REAL := 90.0;                // Уставка аварии высокого уровня
    ixEnable : BOOL := TRUE;                    // Разрешение работы блока
    irHysteresis : REAL := 1.0;                 // Гистерезис для предотвращения дребезга
    xReset : BOOL;                              // Сброс состояния
    xForceNormal : BOOL;                        // Принудительная установка состояния "норма"

    // Встроенная настройка уставок
    xSetAllSetpoints : BOOL;                    // Установить все уставки (по переднему фронту)
    rSetpointLL_In : REAL;                      // Входная уставка LL для установки
    rSetpointL_In : REAL;                       // Входная уставка L для установки
    rSetpointH_In : REAL;                       // Входная уставка H для установки
    rSetpointHH_In : REAL;                      // Входная уставка HH для установки

    xSetSymmetric : BOOL;                       // Установить симметричные уставки (по переднему фронту)
    rCenterValue : REAL;                        // Центральное значение для симметричных уставок
    rWarningOffset : REAL;                      // Смещение для предупреждений (L, H)
    rAlarmOffset : REAL;                        // Смещение для аварий (LL, HH)

    xSetPercent : BOOL;                         // Установить уставки в процентах (по переднему фронту)
    rMinValue : REAL;                           // Минимальное значение диапазона
    rMaxValue : REAL;                           // Максимальное значение диапазона
    rLLPercent : REAL;                          // Процент для LL (0..100)
    rLPercent : REAL;                           // Процент для L (0..100)
    rHPercent : REAL;                           // Процент для H (0..100)
    rHHPercent : REAL;                          // Процент для HH (0..100)
END_VAR
VAR_OUTPUT
    quAlarmCode : E_AlarmSetpoints;             // Код текущего состояния аварии/предупреждения
    qxAlarmActive : BOOL;                       // TRUE = активна любая авария или предупреждение
    qxWarningActive : BOOL;                     // TRUE = активно предупреждение (L или H)
    qxCriticalActive : BOOL;                    // TRUE = активна критическая авария (LL или HH)
    qxIsNormal : BOOL;                          // TRUE = состояние "в норме"
    qxIsLowAlarm : BOOL;                        // TRUE = активны низкие аварии (L или LL)
    qxIsHighAlarm : BOOL;                       // TRUE = активны высокие аварии (H или HH)
    qxValidSetpoints : BOOL;                    // TRUE = уставки корректны
    qrDistanceToNearestSetpoint : REAL;         // Расстояние до ближайшей уставки
END_VAR
VAR
    _uPreviousAlarmCode : E_AlarmSetpoints := E_AlarmSetpoints.Normal;  // Предыдущий код аварии
    _uCurrentAlarmCode : E_AlarmSetpoints := E_AlarmSetpoints.Normal;   // Текущий код аварии
    _xValidSetpoints : BOOL := TRUE;            // Флаг корректности уставок
    _rHysteresisValue : REAL;                   // Текущее значение гистерезиса

    // Триггеры для команд настройки
    _rt_SetAllSetpoints : R_TRIG;
    _rt_SetSymmetric : R_TRIG;
    _rt_SetPercent : R_TRIG;
    rDistanceToL : REAL;
    rDistanceToLL : REAL;
    rDistanceToH : REAL;
    rDistanceToHH : REAL;
    rMinDistance : REAL;
    rRange : REAL;
END_VAR

// =====================================
// ВСТРОЕННАЯ НАСТРОЙКА УСТАВОК
// =====================================

// Установка всех уставок
_rt_SetAllSetpoints(CLK := xSetAllSetpoints);
IF _rt_SetAllSetpoints.Q THEN
    // Проверяем корректность перед установкой
    IF (rSetpointLL_In <= rSetpointL_In) AND (rSetpointL_In < rSetpointH_In) AND (rSetpointH_In <= rSetpointHH_In) THEN
        irSetpointLL := rSetpointLL_In;
        irSetpointL := rSetpointL_In;
        irSetpointH := rSetpointH_In;
        irSetpointHH := rSetpointHH_In;
    END_IF
END_IF

// Установка симметричных уставок
_rt_SetSymmetric(CLK := xSetSymmetric);
IF _rt_SetSymmetric.Q THEN
    IF (rWarningOffset >= 0.0) AND (rAlarmOffset >= rWarningOffset) THEN
        irSetpointL := rCenterValue - rWarningOffset;
        irSetpointLL := rCenterValue - rAlarmOffset;
        irSetpointH := rCenterValue + rWarningOffset;
        irSetpointHH := rCenterValue + rAlarmOffset;
    END_IF
END_IF

// Установка уставок в процентах
_rt_SetPercent(CLK := xSetPercent);
IF _rt_SetPercent.Q THEN
    IF (rMinValue < rMaxValue) AND
       (rLLPercent <= rLPercent) AND (rLPercent < rHPercent) AND (rHPercent <= rHHPercent) AND
       (rLLPercent >= 0.0) AND (rHHPercent <= 100.0) THEN

        rRange := rMaxValue - rMinValue;
        irSetpointLL := rMinValue + (rRange * rLLPercent / 100.0);
        irSetpointL := rMinValue + (rRange * rLPercent / 100.0);
        irSetpointH := rMinValue + (rRange * rHPercent / 100.0);
        irSetpointHH := rMinValue + (rRange * rHHPercent / 100.0);
    END_IF
END_IF

// =====================================
// СБРОС И ПРИНУДИТЕЛЬНАЯ НОРМА
// =====================================

// Сброс состояния
IF xReset THEN
    _uCurrentAlarmCode := E_AlarmSetpoints.Normal;
    _uPreviousAlarmCode := E_AlarmSetpoints.Normal;
    quAlarmCode := E_AlarmSetpoints.Normal;
    qxAlarmActive := FALSE;
    qxWarningActive := FALSE;
    qxCriticalActive := FALSE;
    RETURN;
END_IF

// Принудительная установка нормы
IF xForceNormal THEN
    _uCurrentAlarmCode := E_AlarmSetpoints.Normal;
    _uPreviousAlarmCode := E_AlarmSetpoints.Normal;
    quAlarmCode := E_AlarmSetpoints.Normal;
END_IF

// =====================================
// ВАЛИДАЦИЯ УСТАВОК
// =====================================
_xValidSetpoints := (irSetpointLL <= irSetpointL) AND
                   (irSetpointL < irSetpointH) AND
                   (irSetpointH <= irSetpointHH);

// Гистерезис не может быть отрицательным
IF irHysteresis < 0.0 THEN
    _rHysteresisValue := 0.0;
ELSE
    _rHysteresisValue := irHysteresis;
END_IF

qxValidSetpoints := _xValidSetpoints;

// =====================================
// ОСНОВНАЯ ЛОГИКА ОПРЕДЕЛЕНИЯ АВАРИЙ
// =====================================
IF ixEnable AND _xValidSetpoints AND NOT xForceNormal THEN
    // Сохраняем предыдущее состояние
    _uPreviousAlarmCode := _uCurrentAlarmCode;

    // Определяем новое состояние на основе текущего значения
    IF irValue <= irSetpointLL THEN
        _uCurrentAlarmCode := E_AlarmSetpoints.LL;
    ELSIF irValue <= irSetpointL THEN
        _uCurrentAlarmCode := E_AlarmSetpoints.L;
    ELSIF irValue >= irSetpointHH THEN
        _uCurrentAlarmCode := E_AlarmSetpoints.HH;
    ELSIF irValue >= irSetpointH THEN
        _uCurrentAlarmCode := E_AlarmSetpoints.H;
    ELSE
        // Проверяем гистерезис для возврата в нормальное состояние
        CASE _uPreviousAlarmCode OF
            E_AlarmSetpoints.LL:
                IF irValue > (irSetpointLL + _rHysteresisValue) THEN
                    _uCurrentAlarmCode := E_AlarmSetpoints.Normal;
                ELSE
                    _uCurrentAlarmCode := E_AlarmSetpoints.LL;
                END_IF

            E_AlarmSetpoints.L:
                IF irValue > (irSetpointL + _rHysteresisValue) THEN
                    _uCurrentAlarmCode := E_AlarmSetpoints.Normal;
                ELSE
                    _uCurrentAlarmCode := E_AlarmSetpoints.L;
                END_IF

            E_AlarmSetpoints.H:
                IF irValue < (irSetpointH - _rHysteresisValue) THEN
                    _uCurrentAlarmCode := E_AlarmSetpoints.Normal;
                ELSE
                    _uCurrentAlarmCode := E_AlarmSetpoints.H;
                END_IF

            E_AlarmSetpoints.HH:
                IF irValue < (irSetpointHH - _rHysteresisValue) THEN
                    _uCurrentAlarmCode := E_AlarmSetpoints.Normal;
                ELSE
                    _uCurrentAlarmCode := E_AlarmSetpoints.HH;
                END_IF

            E_AlarmSetpoints.Normal:
                _uCurrentAlarmCode := E_AlarmSetpoints.Normal;
        END_CASE
    END_IF
ELSE
    // При отключении или некорректных уставках - сброс в нормальное состояние
    _uCurrentAlarmCode := E_AlarmSetpoints.Normal;
END_IF

quAlarmCode := _uCurrentAlarmCode;

// =====================================
// ОБНОВЛЕНИЕ ВЫХОДНЫХ СИГНАЛОВ
// =====================================
qxAlarmActive := (_uCurrentAlarmCode <> E_AlarmSetpoints.Normal);
qxWarningActive := (_uCurrentAlarmCode = E_AlarmSetpoints.L) OR
                  (_uCurrentAlarmCode = E_AlarmSetpoints.H);
qxCriticalActive := (_uCurrentAlarmCode = E_AlarmSetpoints.LL) OR
                   (_uCurrentAlarmCode = E_AlarmSetpoints.HH);
qxIsNormal := (_uCurrentAlarmCode = E_AlarmSetpoints.Normal);
qxIsLowAlarm := (_uCurrentAlarmCode = E_AlarmSetpoints.L) OR
                (_uCurrentAlarmCode = E_AlarmSetpoints.LL);
qxIsHighAlarm := (_uCurrentAlarmCode = E_AlarmSetpoints.H) OR
                 (_uCurrentAlarmCode = E_AlarmSetpoints.HH);

// =====================================
// ВЫЧИСЛЕНИЕ РАССТОЯНИЯ ДО БЛИЖАЙШЕЙ УСТАВКИ
// =====================================

rDistanceToL := ABS(irValue - irSetpointL);
rDistanceToLL := ABS(irValue - irSetpointLL);
rDistanceToH := ABS(irValue - irSetpointH);
rDistanceToHH := ABS(irValue - irSetpointHH);

rMinDistance := rDistanceToL;
IF rDistanceToLL < rMinDistance THEN rMinDistance := rDistanceToLL; END_IF
IF rDistanceToH < rMinDistance THEN rMinDistance := rDistanceToH; END_IF
IF rDistanceToHH < rMinDistance THEN rMinDistance := rDistanceToHH; END_IF

qrDistanceToNearestSetpoint := rMinDistance;

END_FUNCTION_BLOCK