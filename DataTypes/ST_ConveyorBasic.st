TYPE ST_ConveyorBasic :
STRUCT
	// == Двигатели ==
	MotorConveyor : ARRAY [1..2] OF ST_MotorWithFeedback; // Эл.двиг привода конвейера, 22кВт

	// Обратная связь
	// 1 - Норма, 0 - Предупреждение/Сход
	fbZQAlarm : ARRAY[1..4] OF FB_UniversalSignal; // Контроль схода ленты - тревога
	fbZQWarning : ARRAY[1..4] OF FB_UniversalSignal; // Контроль схода ленты - предупреждение
	// 1 - Норма, 0 - Тревога
	fbHQ_IsOk : ARRAY[1..4] OF FB_UniversalSignal; // Кабель-тросовый выключатель
	fbSQ_IsOk : ARRAY[1..2] OF FB_UniversalSignal; // Контроль ограждения барабана
	fbGS1 : FB_UniversalSignal; // Контроль заштыбовки
	fbQR : ARRAY[1..2] OF FB_UniversalSignal; // Измерение скорости вращения барабана
	fbYS1 : FB_UniversalSignal; // Контроль продольного разрыва ленты

	// DO
	// == Светозвуковое оповещение ==
	xHLA : BOOL; // Световая сигнализация
	xSoundAlarm : BOOL; // Звуковая сигнализация

	// == АСУТП ==
	cmdStartConveyor, cmdStopConveyor : BOOL;
	cmdSetModeRepair, // Установить режим "Ремонт"
	cmdSetModeManual, // Установить режим "Ручной"
	cmdSetModeAuto : BOOL; // Установить режим "Авто"

	// Генерация состояний
	eStateRemote: E_StateRemote; // Состояние режима управления (авто, ручной, ремонт)
END_STRUCT
END_TYPE
