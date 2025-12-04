FUNCTION_BLOCK FB_AnalogOutput
VAR_INPUT
    // Основные входы
    xEnable         : BOOL := TRUE;     // Разрешение работы выхода
    rEngValue       : REAL;             // Значение в инженерных единицах для вывода

    // Параметры масштабирования
    rEngValue_Max   : REAL := 100.0;    // Максимальное значение в ед. измерения
    rEngValue_Min   : REAL := 0.0;      // Минимальное значение в ед. измерения

    // Параметры тока
    rCurrent_Max    : REAL := 20.0;     // Максимальный ток (мА)
    rCurrent_Min    : REAL := 4.0;      // Минимальный ток (мА)

    // Параметры АЦП (DAC)
    iDAC_Max        : INT := 32767;     // Максимальный код АЦП
    iDAC_Min        : INT := 0;         // Минимальный код АЦП

    // Параметры уставок по току (4-20 мА)
    rAlarm_LL       : REAL := 3.8;      // Аварийно низкий уровень тока (мА)
    rAlarm_L        : REAL := 4.5;      // Низкий уровень тока (мА)
    rAlarm_H        : REAL := 19.5;     // Высокий уровень тока (мА)
    rAlarm_HH       : REAL := 20.2;     // Аварийно высокий уровень тока (мА)

    // Опции
    xEnableClamp    : BOOL := TRUE;     // Включить ограничение выхода за пределы диапазона
END_VAR

VAR_OUTPUT
    // Выходы
    rCurrent_mA     : REAL;             // Выходной ток 4-20 мА
    iDAC_Code       : INT;              // Код АЦП для модуля аналогового выхода

    // Тревоги по току
    xAlarm_LL       : BOOL;             // Аварийно низкий уровень
    xAlarm_L        : BOOL;             // Низкий уровень
    xAlarm_H        : BOOL;             // Высокий уровень
    xAlarm_HH       : BOOL;             // Аварийно высокий уровень
    eAlarmStatus    : E_AlarmSetpoints; // Общий статус тревоги

    // Диагностика диапазона
    xOverRange      : BOOL;             // Превышение верхнего предела
    xUnderRange     : BOOL;             // Выход за нижний предел
    xOutOfRange     : BOOL;             // Общий флаг выхода за пределы
END_VAR

VAR
    rEng_Range      : REAL;             // Диапазон инженерных единиц
    rCurrent_Range  : REAL;             // Диапазон тока
    rDAC_Range      : REAL;             // Диапазон АЦП
    rNormalizedValue : REAL;            // Нормализованное значение (0.0 - 1.0)
    rEngValue_Clamped : REAL;           // Ограниченное значение в инженерных единицах
END_VAR

// Расчёт диапазонов
rEng_Range := rEngValue_Max - rEngValue_Min;
rCurrent_Range := rCurrent_Max - rCurrent_Min;
rDAC_Range := INT_TO_REAL(iDAC_Max - iDAC_Min);

// Защита от деления на ноль
IF rEng_Range = 0.0 THEN
    rEng_Range := 1.0;
END_IF

// Проверка выхода за пределы
xUnderRange := rEngValue < rEngValue_Min;
xOverRange := rEngValue > rEngValue_Max;
xOutOfRange := xUnderRange OR xOverRange;

// Ограничение значения (если включено)
IF xEnableClamp THEN
    IF rEngValue < rEngValue_Min THEN
        rEngValue_Clamped := rEngValue_Min;
    ELSIF rEngValue > rEngValue_Max THEN
        rEngValue_Clamped := rEngValue_Max;
    ELSE
        rEngValue_Clamped := rEngValue;
    END_IF
ELSE
    rEngValue_Clamped := rEngValue;
END_IF

// Нормализация значения (0.0 - 1.0)
rNormalizedValue := (rEngValue_Clamped - rEngValue_Min) / rEng_Range;

// Преобразование в ток 4-20 мА
rCurrent_mA := rCurrent_Min + rNormalizedValue * rCurrent_Range;

// Преобразование в код АЦП
IF xEnable THEN
    iDAC_Code := iDAC_Min + REAL_TO_INT(rNormalizedValue * rDAC_Range);
ELSE
    // Если выход отключен - безопасное значение (минимальный ток)
    iDAC_Code := iDAC_Min;
    rCurrent_mA := rCurrent_Min;
END_IF

// Обработка тревог по току
// Аварийно низкий уровень
xAlarm_LL := rCurrent_mA < rAlarm_LL;

// Низкий уровень
xAlarm_L := (rCurrent_mA >= rAlarm_LL) AND (rCurrent_mA < rAlarm_L);

// Высокий уровень
xAlarm_H := (rCurrent_mA > rAlarm_H) AND (rCurrent_mA <= rAlarm_HH);

// Аварийно высокий уровень
xAlarm_HH := rCurrent_mA > rAlarm_HH;

// Обновление общего статуса тревоги (по приоритету)
IF xAlarm_LL THEN
    eAlarmStatus := E_AlarmSetpoints.LL;
ELSIF xAlarm_HH THEN
    eAlarmStatus := E_AlarmSetpoints.HH;
ELSIF xAlarm_L THEN
    eAlarmStatus := E_AlarmSetpoints.L;
ELSIF xAlarm_H THEN
    eAlarmStatus := E_AlarmSetpoints.H;
ELSE
    eAlarmStatus := E_AlarmSetpoints.Normal;
END_IF

END_FUNCTION_BLOCK