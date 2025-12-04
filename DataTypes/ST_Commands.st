TYPE ST_Commands :
STRUCT
	cmdResetAll : FB_UniversalSignal; // Сброс всех ошибок

	cmdStartCommon : FB_UniversalSignal; // Команда общего пуска
	cmdStopCommon : FB_UniversalSignal; // Команда общего останова
	cmdEmergencyStopCommon : FB_UniversalSignal; // Команда общей аварийной остановки

	cmdSetPrecentBunker : ARRAY [1..3] OF USINT; // Задание процента шихтования каждому бункеру (3)
END_STRUCT
END_TYPE
