TYPE ST_Motor :
STRUCT
	// == ЧРП ==
	VFD : ST_VFD;

	// == КОНТАКТОР ==
	// DI
	fbStateKM : FB_UniversalSignal; // Состояние контактора
	// DO
	qxKM_Power : BOOL; // Пуск контактора
	qxBrake : BOOL; // Тормоз
	
	// == Выключатель ==
	// DI
	fbStateQF : FB_UniversalSignal; // Состояние автомат. выключателя

	// == Объекты устройства ==
	Device : FB_UniversalMechanism; // Универсальный механизм с управлением
	StateRemote : E_StateRemote := 2;

	// == Команды АСУТП ==
	cmdManualStartKM : BOOL; // Команда пуска в режиме "Местный"
	cmdManualStopKM : BOOL; // Команда останова в режиме "Местный"

	// == Генерация состояний ==
	xStateWarning : BOOL; // Программное предупреждение
	xStateFailure : BOOL; // Программная ошибка
END_STRUCT
END_TYPE
