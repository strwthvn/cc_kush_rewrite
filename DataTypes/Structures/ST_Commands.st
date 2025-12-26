TYPE ST_Commands :
STRUCT
	cmdResetAll : FB_UniversalSignal; // Сброс всех ошибок

	cmdStartCommon : FB_UniversalSignal; // Команда общего пуска
	cmdStopCommon : FB_UniversalSignal; // Команда общего останова
	cmdEmergencyStopCommon : FB_UniversalSignal; // Команда общей аварийной остановки
	
	cmdSetToAuto, cmdSetToManual, cmdSetToRepair : BOOL; // Команды перевода режима управления

	cmdAutoDisableBlock : BOOL; // Флаг отключения автоматических блокировок в ручном режиме
END_STRUCT
END_TYPE
