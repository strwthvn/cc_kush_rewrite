TYPE ST_ConveyorPrefabricated EXTENDS ST_ConveyorBasic :
STRUCT
	// Дополнительное оборудование для сборного конвейера

	// DI
	fbYE1 : FB_UniversalSignal; // Обнаружение металла (металлодетектор)

	// == Кнопки ПМУ ==
	fbBtnStart : FB_UniversalSignal; // Кнопка "Пуск"
	fbBtnStop : FB_UniversalSignal; // Кнопка "Стоп"
	fbBtnEmergencyStop : FB_UniversalSignal; // Кнопка "Аварийная остановка"

	// == АСУТП ==
	cmdEmergencyStop : BOOL; // Команда аварийной остановки
	cmdReset : BOOL; // Команда сброса

	// == Генерация состояний ==
	xStateWarning : BOOL; // Программное предупреждение
	xStateFailure : BOOL; // Программная ошибка
	xStateEnable : BOOL; // Конвейер полностью запущен
	xStateStarting : BOOL; // Процесс запуска (вместе с ППЗ)
	
	// Объекты структуры
	fbPreStartAlarm : FB_PreStartAlarm;
END_STRUCT
END_TYPE
