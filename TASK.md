TYPE E_StateRemote :
(
    Auto   := 0,  // Режим "Автоматический"
    Manual   := 1,  // Режим "Ручной"
    Repair   := 2   // Режим "Ремонт"
);
END_TYPE


ST_ConveyorBasic, ST_Bunker имеет этот Remote

	cmdSetModeRepair, // Установить режим "Ремонт"
	cmdSetModeManual, // Установить режим "Ручной"
	cmdSetModeAuto : BOOL; // Установить режим "Авто"

    eStateRemote: E_StateRemote; // Состояние режима управления (авто, ручной, ремонт)



Требуется осуществить ручной режим управления в ФБ FB_BunkerControl, FB_ConveyorControl, FB_DumperControl

Добавить на вход ФБ команды переключения в режим. Зависимо от команды,