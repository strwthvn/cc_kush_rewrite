FUNCTION_BLOCK FB_UniversalMechanism
VAR_INPUT
    ixFeedback : BOOL;                          // Сигнал обратной связи от механизма
    xEnableFeedback : BOOL := FALSE;            // Включить отслеживание обратной связи

    // Управление
    xStartCommand : BOOL;                       // Команда на запуск
    xStopCommand : BOOL;                        // Команда на остановку
    xStartCondition : BOOL := TRUE;             // Условие для запуска (по умолчанию разрешено)
    xStopCondition : BOOL := TRUE;              // Условие для остановки (по умолчанию разрешено)
    xReset : BOOL;                              // Принудительное выключение
END_VAR
VAR_OUTPUT
    qxPower : BOOL;                             // Состояние питания механизма
    quFeedbackState : E_StateFeedback;          // Состояние обратной связи
    qxActive : BOOL;                            // Механизм активен (питание и обратная связь в норме)
    qxInactive : BOOL;                          // Механизм неактивен (нет питания, нет обратной связи)
    qxError_NoFeedback : BOOL;                  // Ошибка: нет обратной связи при наличии питания
    qxError_UnexpectedFeedback : BOOL;          // Ошибка: обратная связь есть при отсутствии питания
    qxHasError : BOOL;                          // Флаг наличия любой ошибки
END_VAR
VAR
    _xPower : BOOL := FALSE;                    // Внутреннее состояние питания
    _uFeedbackState : E_StateFeedback;          // Внутреннее состояние обратной связи
END_VAR

// =====================================
// УПРАВЛЕНИЕ ПИТАНИЕМ
// =====================================
// Принудительное выключение
IF xReset THEN
    _xPower := FALSE;
ELSE
    // Логика управления с приоритетом остановки
    IF xStopCommand AND xStopCondition THEN
        _xPower := FALSE;                       // Остановить
    ELSIF xStartCommand AND xStartCondition THEN
        _xPower := TRUE;                        // Запустить
    END_IF
    // Иначе сохраняется текущее состояние _xPower
END_IF

qxPower := _xPower;

// =====================================
// ОБРАБОТКА ОБРАТНОЙ СВЯЗИ
// =====================================
IF xEnableFeedback THEN
    // Определение состояния обратной связи
    IF NOT _xPower AND NOT ixFeedback THEN
        _uFeedbackState := E_StateFeedback.Inactive;                    // 0 - Неактивен (норма)
    ELSIF _xPower AND ixFeedback THEN
        _uFeedbackState := E_StateFeedback.Active;                      // 1 - Активен (норма)
    ELSIF _xPower AND NOT ixFeedback THEN
        _uFeedbackState := E_StateFeedback.Error_NoFeedback;            // 2 - Ошибка: нет обратной связи
    ELSIF NOT _xPower AND ixFeedback THEN
        _uFeedbackState := E_StateFeedback.Error_UnexpectedFeedback;    // 3 - Ошибка: неожиданная обратная связь
    END_IF

    // Обновление выходных флагов
    qxActive := (_uFeedbackState = E_StateFeedback.Active);
    qxInactive := (_uFeedbackState = E_StateFeedback.Inactive);
    qxError_NoFeedback := (_uFeedbackState = E_StateFeedback.Error_NoFeedback);
    qxError_UnexpectedFeedback := (_uFeedbackState = E_StateFeedback.Error_UnexpectedFeedback);
    qxHasError := qxError_NoFeedback OR qxError_UnexpectedFeedback;
ELSE
    // Без обратной связи
    _uFeedbackState := E_StateFeedback.Inactive;
    qxActive := _xPower;
    qxInactive := NOT _xPower;
    qxError_NoFeedback := FALSE;
    qxError_UnexpectedFeedback := FALSE;
    qxHasError := FALSE;
END_IF

quFeedbackState := _uFeedbackState;

END_FUNCTION_BLOCK