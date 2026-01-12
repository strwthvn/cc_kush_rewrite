TYPE E_StageActuator :
(
	IDLE := 0,      // Бездействие (остановлен)
	STARTING := 1,  // Процесс запуска
	WORK := 2,      // Рабочий режим
	STOPPING := 3,  // Процесс остановки
	FAULT := 4      // Авария
);
END_TYPE
