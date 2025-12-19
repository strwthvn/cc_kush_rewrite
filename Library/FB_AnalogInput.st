FUNCTION_BLOCK FB_AnalogInput
VAR_INPUT
    // Основные входы
    xSimulation     : BOOL;             // Флаг симуляции
    iADC_Code       : INT;              // Код АЦП от модуля аналогового входа
    refEngValue     : REFERENCE TO REAL; // Ссылка на переменную в инженерных единицах
    refSimValue     : REFERENCE TO REAL; // Ссылка на переменную для ручного задания в симуляции

    // Параметры уставок по току (4-20 мА)
    rAlarm_LL       : REAL := 1.1852;      // Аварийно низкий уровень тока (мА)
    rAlarm_L        : REAL := 3.9995;      // Низкий уровень тока (мА)
    rAlarm_H        : REAL := 20.0005;     // Высокий уровень тока (мА)
    rAlarm_HH       : REAL := 22.81;       // Аварийно высокий уровень тока (мА)

    // Параметры АЦП
    iADC_Max        : INT := 32767;     // Максимальный код АЦП
    iADC_Min        : INT := 0;         // Минимальный код АЦП

    // Параметры масштабирования
    rEngValue_Max   : REAL := 100.0;    // Максимальное значение в ед. измерения
    rEngValue_Min   : REAL := 0.0;      // Минимальное значение в ед. измерения

    // Параметры тока
    rCurrent_Max    : REAL := 20.0;     // Максимальный ток (мА)
    rCurrent_Min    : REAL := 4.0;      // Минимальный ток (мА)
END_VAR

VAR_OUTPUT
    // Выходы
    rCurrent_mA     : REAL;             // Ток 4-20 мА
    
    // Тревоги по току
    xAlarm_LL       : BOOL;             // Аварийно низкий уровень
    xAlarm_L        : BOOL;             // Низкий уровень
    xAlarm_H        : BOOL;             // Высокий уровень
    xAlarm_HH       : BOOL;             // Аварийно высокий уровень
	eAlarmStatus : E_AlarmSetpoints;
END_VAR

VAR
    rScaledValue    : REAL;             // Внутреннее масштабированное значение
    rADC_Range      : REAL;             // Диапазон АЦП
    rEng_Range      : REAL;             // Диапазон инженерных единиц
    rCurrent_Range  : REAL;             // Диапазон тока
    _xSimulation_Prev : BOOL;           // Предыдущее состояние симуляции (для детектирования фронта)
END_VAR

// Расчёт диапазонов
rADC_Range := INT_TO_REAL(iADC_Max - iADC_Min);
rEng_Range := rEngValue_Max - rEngValue_Min;
rCurrent_Range := rCurrent_Max - rCurrent_Min;

// Защита от деления на ноль
IF rADC_Range = 0.0 THEN
    rADC_Range := 1.0;
END_IF

// Масштабирование кода АЦП в ток 4-20 мА
rCurrent_mA := rCurrent_Min + 
               (INT_TO_REAL(iADC_Code - iADC_Min) / rADC_Range) * rCurrent_Range;

// Логика симуляции и масштабирования
IF xSimulation THEN
    // Режим симуляции активен

    // При переходе в режим симуляции (rising edge) - инициализировать симуляцию
    IF NOT _xSimulation_Prev AND __ISVALIDREF(refEngValue) AND __ISVALIDREF(refSimValue) THEN
        // Однократно передать текущее значение в переменную симуляции
        refSimValue := refEngValue;
    END_IF

    // В режиме симуляции - использовать значение из переменной симуляции
    IF __ISVALIDREF(refEngValue) AND __ISVALIDREF(refSimValue) THEN
        refEngValue := refSimValue;
    END_IF

ELSE
    // Режим симуляции выключен - работает обычное масштабирование
    IF __ISVALIDREF(refEngValue) THEN
        rScaledValue := rEngValue_Min +
                        ((rCurrent_mA - rCurrent_Min) / rCurrent_Range) * rEng_Range;
        refEngValue := rScaledValue;
    END_IF
END_IF

// Сохранить текущее состояние симуляции для следующего цикла
_xSimulation_Prev := xSimulation;

// Обработка тревог по току
// Аварийно низкий уровень (обрыв линии)
xAlarm_LL := rCurrent_mA < rAlarm_LL;

// Низкий уровень
xAlarm_L := (rCurrent_mA >= rAlarm_LL) AND (rCurrent_mA < rAlarm_L);

// Высокий уровень
xAlarm_H := (rCurrent_mA > rAlarm_H) AND (rCurrent_mA <= rAlarm_HH);

// Аварийно высокий уровень (перегрузка)
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