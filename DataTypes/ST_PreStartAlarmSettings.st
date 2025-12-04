TYPE ST_PreStartAlarmSettings :
STRUCT
	OPTION_ENABLE : BOOL; // Опция на включение ППЗ в алгоритм
	TIME_FIRST_SIGNAL : TIME; // Время звучания первого сигнала
	TIME_FIRST_SIGNAL_PAUSE : TIME; // Пауза после первого сигнала
	TIME_SECOND_SIGNAL : TIME; // Время звучания второго сигнала
	TIME_SECOND_SIGNAL_PAUSE : TIME; // Пауза после втотрого сигнала
END_STRUCT
END_TYPE

(*
FB_PreStartAlarm
    ixStart : BOOL;                    // Сигнал на запуск
    ixStop : BOOL;                     // Сигнал на стоп (Reset)
    itFirstSignal : TIME;              // Уставка первого сигнала
    itPauseAfterFirst : TIME;          // Уставка паузы после первого сигнала
    itSecondSignal : TIME;             // Уставка второго сигнала
    itPauseAfterSecond : TIME;         // Уставка паузы после второго сигнала
*)