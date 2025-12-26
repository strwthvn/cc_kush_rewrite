TYPE E_StateFeedback :
(
    Inactive                   := 0,   // Обратная связь неактивна (норма при остановке)
    Active                     := 1,   // Обратная связь активна (норма при работе)
    Error_NoFeedback           := 2,   // Нет обратной связи при наличии питания
    Error_UnexpectedFeedback   := 3    // Обратная связь есть при отсутствии питания
);
END_TYPE
