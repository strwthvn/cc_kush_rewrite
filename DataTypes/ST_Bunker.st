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
	rMotorVibFeederCommonFrequency : REAL; // Частота от автоматического режима (ПИД)
	rMotorVibFeederManualFrequency : REAL; // Частота для ручного режима (от SCADA)
	
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
	cmdStartVibrator : BOOL; // Команда "Пуск виратора"
	cmdStopVibrator : BOOL; // Команда "Стоп вибратора"

	cmdEmergencyStopVibFeeder : BOOL; // Команда "Аварийная остановка вибропитателей" (КРИТИЧЕСКАЯ - переводит в ERROR)
	cmdEmergencyStopVibrator : BOOL; // Команда "Аварийная остановка вибраторов" (НЕКРИТИЧЕСКАЯ - только отключает вибраторы)
	cmdDumpingPrecent : REAL; // Задание процентного соотношения сбрасывания
	cmdReset : BOOL; // Сброс ошибок
	cmdSetModeRepair, // Установить режим "Ремонт"
	cmdSetModeManual, // Установить режим "Ручной"
	cmdSetModeAuto : BOOL; // Установить режим "Авто"
	// Команды для вибраторов
	cmdVibratorSetModeRepair, // Установить режим "Ремонт"
	cmdVibratorSetModeManual, // Установить режим "Ручной"
	cmdVibratorSetModeAuto : BOOL; // Установить режим "Авто"
	
	cmdAddVib1 : BOOL; // Включить управление вибратора 1 
	cmdAddVib2 : BOOL; // Включить управление вибратора 2
	cmdAddVib3 : BOOL; // Включить управление вибратора 3
	cmdAddVib4 : BOOL; // Включить управление вибратора 4
	cmdBuildCircuitOn, cmdBuildCircuitOff  : BOOL; // Команда собрать/разобрать схему
	cmdBuildCircuitOnVibrator, cmdBuildCircuitOffVibrator  : BOOL; // Команда собрать/разобрать схему вибратора
	
	// == Генерация состояний ==
	eLightColor : E_LightColor; // Текущий сигнал светофора
	eStateRemote: E_StateRemote; // Состояние режима управления (авто, ручной, ремонт)
	eVibratorStateRemote: E_StateRemote; // Состояние режима управления (авто, ручной, ремонт)
	xStateRemoteAuto, xStateRemoteManual, xStateRemoteRepair : BOOL; // Состояния режима управления для передачи в SCADA
	xVibratorStateRemoteAuto, xVibratorStateRemoteManual, xVibratorStateRemoteRepair : BOOL; // Состояния режима управления для передачи в SCADA
	
	
	wLightColor : WORD; // Передача сигнала светофора по ModbusTCP
	
	xStateWarning : BOOL; // Программное предупреждение
	xStateFailure : BOOL; // Программная ошибка
END_STRUCT
END_TYPE
