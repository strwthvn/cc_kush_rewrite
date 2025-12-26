TYPE ST_VFD :
STRUCT
	// Состояние DI
	fbStateRdyToStart : FB_UniversalSignal; // Готов к пуску
	fbStateIsWorking : FB_UniversalSignal; // В работе
	fbStateFailure : FB_UniversalSignal; // Ошибка

	// Состояние AI
	fbActualFrequency : FB_UniversalAnalogSignal; // Текущая частота вращения
	nActualFrequencyADC : INT; // Код АЦП модуля аналогового входа
	nSetOutSignalToModule : INT; // Код АЦП модуля аналогового выхода

	// Команды DO
	qxStart : BOOL; // Пуск ПЧ
	qxResetFailure : BOOL; // Сброс аварии ПЧ

	// Команды AO
	qrOutFrequency : REAL; // Выходная частота
	rSimulatedFrequency : REAL; // Частота для режима симуляции модуля AI
	
	// RS-485
	wMotorCurrent : U_RealToWord; // Ток эл. двигателя
	uActualFrequency : U_RealToWord; // Актуальная частота (чтение через ModbusRTU)

	// Объекты устройства
	Device : FB_UniversalMechanism; // Универсальный механизм для ЧРП
	Frequency : FB_FrequencyControl; // Управление частотой
	fbRangeDiagnostic : FB_RangeDiagnostic; // Диагностика диапазона
	fbSimFreq : FB_FrequencySimulation; // Симуляция частоты
	fbAnalogInput : FB_AnalogInput; // Аналоговой вход частотного преобразователя
	fbAnalogOutput : FB_AnalogOutput; // Аналоговый выход частотного преобразователя
	
	rActualFrequency : REAL; // Текущая частота ЧРП - использовать в проверках
	xStateFailure : BOOL; // Ошибка (для проверок)
	xStateIsWorking : BOOL; // В работе (для проверок)
	xStateRdyToStart : BOOL; // Готов к пуску (для проверок)

	// Команды АСУТП
	cmdSetFrequency : REAL; // Ручное задание частоты
	// Команды в режиме управления "Местный"
	cmdManualStart : BOOL; // Запуск
	cmdManualStop : BOOL; // Остановка
	cmdFrequencyDirectMode : BOOL; // Режим мгновенного задания частоты: 0 - Плавный переход, 1 - Мгновенный переход

	// == Генерация состояний ==
	xStateWarning : BOOL; // Программное предупреждение
	xStateFailureLocal : BOOL; // Программная ошибка
END_STRUCT
END_TYPE
