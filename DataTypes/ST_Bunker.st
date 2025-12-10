TYPE ST_Bunker :
STRUCT
	// == Двигатели ==
	MotorVibrator : ARRAY [1..4] OF ST_Motor; // Эл. двигатель вибратора 0,62кВт
	MotorVibFeeder : ARRAY [1..2] OF ST_MotorVibFeeder; // Эл. двигатель вибропитателя 7,5кВт 2

	// == Тензовесы ==
	// RS-485
	rWeightModbusReg : U_RealToWord; // Тензовесы (сигнал модбас)
	rWeight	: REAL; // Весы бункера
	
	rWeightUnderBunker : REAL; // Весы конвейерные под бункером
	
	// Пропорция от веса
	rProportionActual : REAL;
	
	// Частота двух моторов вибропитателя
	rMotorVibFeederCommonFrequency : REAL;
	
	// == Контроль открытия люка
	// DI:
	fbStateHatch : FB_UniversalSignal; // Положение люка (1 - закрыт , 0 - открыт )

	// == Светофор
	// DO:
	qxLightRed, qxLightYellow, qxLightGreen : BOOL; // Сигналы светофора (команды)

	// == Кнопки ПМУ ==
	// DI
	fbBtnStart : FB_UniversalSignal; // Кнопка "Пуск питателя" NO
	fbBtnStop : FB_UniversalSignal; // Кнопка "Стоп питателя" NO
	fbBtnEmergencyStop : FB_UniversalSignal; // Кнопка "Аварийная остановка" NC

	// АСУТП
	cmdStartFeeder : BOOL; // Команда "Пуск питателя"
	cmdStopFeeder : BOOL; // Команда "Стоп питателя"
	cmdEmergencyStopFeeder : BOOL; // Команда "Аварийная остановка"
	cmdDumpingPrecent : REAL; // Задание процентного соотношения сбрасывания
	cmdReset : BOOL; // Сброс ошибок
	cmdSetModeRepair, // Установить режим "Ремонт"
	cmdSetModeManual, // Установить режим "Ручной"
	cmdSetModeAuto : BOOL; // Установить режим "Авто"
	cmdAddVib1 : BOOL; // Включить управление вибратора 1 
	cmdAddVib2 : BOOL; // Включить управление вибратора 2
	cmdAddVib3 : BOOL; // Включить управление вибратора 3
	cmdAddVib4 : BOOL; // Включить управление вибратора 4
	
	cmdBuildCircuitOn, cmdBuildCircuitOff  : BOOL; // Команда собрать/разобрать схему
	
	cmdBuildCircuitOnVibrator, cmdBuildCircuitOffVibrator  : BOOL; // Команда собрать/разобрать схему вибратора
	
	// == Генерация состояний ==
	eLightColor : E_LightColor; // Текущий сигнал светофора
	eStateRemote: E_StateRemote; // Состояние режима управления (авто, ручной, ремонт)
	wLightColor : WORD; // Передача сигнала светофора по ModbusTCP
	
	xStateWarning : BOOL; // Программное предупреждение
	xStateFailure : BOOL; // Программная ошибка
END_STRUCT
END_TYPE
