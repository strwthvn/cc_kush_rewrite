FUNCTION_BLOCK FB_FrequencySimulation
VAR_INPUT
    xProceed : BOOL;        // Флаг работы ФБ (TRUE = работает, FALSE = остановлен)
    irTarget : REAL;        // Цель частоты
    irStep : REAL;          // Шаг изменения за цикл
END_VAR
VAR_OUTPUT
    irInputModule : REAL;   // Текущие показания (симуляция обратной связи)
END_VAR
VAR
    rDifference : REAL;     // Разница между целью и текущим значением
END_VAR
// Проверяем флаг работы
IF xProceed THEN
    // Вычисляем разницу между целевым и текущим значением
    rDifference := irTarget - irInputModule;
    
    // Проверяем, не достигли ли мы уже цели
    IF ABS(rDifference) <= ABS(irStep) THEN
        // Если разница меньше или равна шагу, устанавливаем точное значение
        irInputModule := irTarget;
    ELSE
        // Иначе двигаемся к цели с заданным шагом
        IF rDifference > 0 THEN
            // Цель выше текущего значения - увеличиваем
            irInputModule := irInputModule + ABS(irStep);
        ELSE
            // Цель ниже текущего значения - уменьшаем
            irInputModule := irInputModule - ABS(irStep);
        END_IF;
    END_IF;
END_IF;

END_FUNCTION_BLOCK