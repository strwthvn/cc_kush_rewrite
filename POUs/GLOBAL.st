VAR_GLOBAL
	// Системные ФБ
	PULSE : BLINK;
	PULSE_RTRIG : R_TRIG;
	
	// Системные флаги
	xStateEmergencyStop : BOOL; // Система была аварийно остановлена
	xStateErrorAcceptIdle : BOOL; // Невозможно принять коэффицент шихтования по заданию оператора - сумма коэффицентов не равна 100
	xStateErrorCheckReady : BOOL; // Проверки стадии готовности к пуску провалились
	xStateAutoWorking : BOOL; // Система полностью запущена и работает в автоматическом режиме 
	// Расчёт КИУМ
	ICUR_PRECENT : REAL; // Коэффициент использования установленной мощности (в процентах)
	rElectricityMeter : REAL; // Раход электроэнергии
	
	// Ограничение производительности
	EFFICIENCY_LIMIT_RATE : REAL := 1; // Коэффицент ограничения производительности (0-1)
	
	// Переменные симуляции
	SIMULATION : BOOL := TRUE;
	
	// == MODBUS РЕГИСТРЫ ДЛЯ SCADA ==
	// Массив регистров для передачи данных в SCADA систему
	awModbusInputRegisters : ARRAY [0..511] OF WORD; // Modbus Input регистры
	awModbusHoldingRegisters : ARRAY [0..511] OF WORD; // Modbus Holding регистры
	
END_VAR
VAR_GLOBAL RETAIN 
	// == УСТАВКИ ==
	VFD_FREQUENCY_MAX : REAL := 50;
	VFD_FREQUENCY_STEP : REAL := 2;
	VFD_FREQUENCY_INACCURANCY : REAL := 0.5;
	VFD_FREQUENCY_SYNC_TOLERANCE : REAL := 1.5; // Допустимая разница частот для синхронизации моторов
	
		// == ПАРАМЕТРЫ АЦП/ЦАП ДЛЯ ЧРП ==
	VFD_ADC_MAX : INT := 27648; // Максимальный код АЦП (аналоговый вход/выход)
	VFD_ADC_MIN : INT := 0; // Минимальный код АЦП
	VFD_FREQ_MIN : REAL := 0.0; // Минимальная частота ЧРП (Гц)
	VFD_FREQ_MAX_RANGE : REAL := 50.0; // Максимальная частота для масштабирования АЦП (Гц)

	// == ПАРАМЕТРЫ ТОКА 4-20 мА ==
	VFD_CURRENT_MIN : REAL := 4.0; // Минимальный ток (мА)
	VFD_CURRENT_MAX : REAL := 20.0; // Максимальный ток (мА)
	VFD_CURRENT_ALARM_LL : REAL := 3.8; // Аварийно низкий уровень тока (обрыв линии)
	VFD_CURRENT_ALARM_L : REAL := 4.5; // Низкий уровень тока
	VFD_CURRENT_ALARM_H : REAL := 19.5; // Высокий уровень тока
	VFD_CURRENT_ALARM_HH : REAL := 20.2; // Аварийно высокий уровень тока (перегрузка)
	
	// == ПАРАМЕТРЫ ДИАПАЗОНА ТЕМПЕРАТУР ==
	TEMP_BEARING_MIN : REAL := 0.0; // Минимальная температура подшипникового узла (°C)
	TEMP_BEARING_MAX : REAL := 100.0; // Максимальная температура подшипникового узла (°C)
	
	// Настройка виброобрушения
	VIBRATOR_SETTINGS : ST_BunkerVibratorSettings := (
		TIME_ACTIVE := T#10S,
		TIME_PAUSE_VIBRATOR := T#10S,
		TIME_PAUSE_FB := T#30S,
		COUNT_CYCLE := 3
		);
	// Настройка пневмообрушения
	PNEUMO_SETTINGS : ST_BunkerVibratorSettings := (
		TIME_ACTIVE := T#10S,
		TIME_PAUSE_VIBRATOR := T#10S,
		TIME_PAUSE_FB := T#30S,
		COUNT_CYCLE := 3
		);
		
	// Опция плавного задания частоты
	VFD_SMOOTH_SET_FREQUENCY : BOOL := TRUE;
	
	// Таймеры последовательного запуска механизмов в автоматическом режиме
	TIME_AFTER_START_DUMPER : TIME := T#0S; // Время ожидания после запуска отвалообразователя
	TIME_AFTER_START_CONVEYOR : TIME := T#0S; // Время ожидания после запуска конвейера
	TIME_AFTER_START_BUNKER_1 : TIME := T#0S; // Время ожидания после запуска бункера 1
	TIME_AFTER_START_BUNKER_2 : TIME := T#0S; // Время ожидания после запуска бункера 2
	TIME_AFTER_START_BUNKER_3 : TIME := T#0S; // Время ожидания после запуска бункера 3
	
	// Таймер ожидания пропавшего сигнала обратной связи работы механизма
	TIME_WAITING_FEEDBACK : TIME := T#0S;
	
	// Скорость конвейера
	CONVEYOR_DEAFULT_SPEED : REAL := -1;
	
	// Температура подшипникового узла мотора вибропитателя
	MOTOR_VIBFEEDER_TEMP_POINTS : ST_AlarmSetpoints := (
		LL_Value := -1,
		L_Value := -1,
		H_Value := -1,
		HH_Value := -1);
	// Ток мотора вибропитателя
	MOTOR_VIBFEEDER_CURRENT_POINTS : ST_AlarmSetpoints := (
		LL_Value := -1,
		L_Value := -1,
		H_Value := -1,
		HH_Value := -1);
	// Ток мотора вибратора
	MOTOR_VIBRATOR_CURRENT_POINTS : ST_AlarmSetpoints := (
		LL_Value := -1,
		L_Value := -1,
		H_Value := -1,
		HH_Value := -1);
	// Ток мотора конвейера
	MOTOR_CONVEYOR_CURRENT_POINTS : ST_AlarmSetpoints := (
		LL_Value := -1,
		L_Value := -1,
		H_Value := -1,
		HH_Value := -1);
	// Ток мотора поворота отвалообразователя
	MOTOR_ROTATION_CURRENT_POINTS : ST_AlarmSetpoints := (
		LL_Value := -1,
		L_Value := -1,
		H_Value := -1,
		HH_Value := -1);
		
	// Предпусковая сигнализация конвейера отвалообразователя
	DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS : ST_PreStartAlarmSettings := (
		OPTION_ENABLE := TRUE, // Опция на включение ППЗ в алгоритм
		TIME_FIRST_SIGNAL := T#3S, // Время звучания первого сигнала
		TIME_FIRST_SIGNAL_PAUSE := T#3S, // Пауза после первого сигнала
		TIME_SECOND_SIGNAL := T#3S, // Время звучания второго сигнала
		TIME_SECOND_SIGNAL_PAUSE := T#3S); // Пауза после втотрого сигнала
		
	// Предпусковая сигнализация сборного конвейера
	CONVEYOR_PRESTART_ALARM_SETTINGS : ST_PreStartAlarmSettings := (
		OPTION_ENABLE := TRUE, // Опция на включение ППЗ в алгоритм
		TIME_FIRST_SIGNAL := T#3S, // Время звучания первого сигнала
		TIME_FIRST_SIGNAL_PAUSE := T#3S, // Пауза после первого сигнала
		TIME_SECOND_SIGNAL := T#3S, // Время звучания второго сигнала
		TIME_SECOND_SIGNAL_PAUSE := T#3S); // Пауза после втотрого сигнала

	// Световая индикация Гц
	ANNUNCIATOR_LIGHT_HZ : REAL := 2;
		
	// Частота мотора конвейера
	MOTOR_FREQUENCY_CONVEYOR : REAL := 50;
	// Частота мотора конвейера отвалообразователя
	MOTOR_FREQUENCY_DUMPER_CONVEYOR : REAL := 50;
	// Частота мотора поворота отвалообразователя
	MOTOR_FREQUENCY_DUMPER_ROTATION : REAL := -1;
		
	BUNKER_MINIMAL_WEIGHT :REAL := -1; // Уставка минимального веса бункера. Результат <= считывается алгоритмом как пустой бункер.
	
	// Уставки бункера
	PNEUMATIC_COLLAPSE_TIME : TIME := T#0S; // Уставка времени таймера пневмообрушения
	BUNKER_WORK_PRECENT_1 : REAL; // Уставка пропорции шихтования для бункера 1
	BUNKER_WORK_PRECENT_2 : REAL; // Уставка пропорции шихтования для бункера 2
	BUNKER_WORK_PRECENT_3 : REAL; // Уставка пропорции шихтования для бункера 3
	BUNKER_VIBFEEDER_START_FREQUENCY : REAL := 10.0; // Минимальная частота для запуска вибропитателей (Гц)
	
	// Светофор бункера
	BUNKER_WEIGHT_LIGHT_RED : BOOL; // Уставка веса бункера для красного светофора
	BUNKER_WEIGHT_LIGHT_YELLOW : BOOL; // Уставка веса бункера для жёлтого светофора
	BUNKER_WEIGHT_LIGHT_GREEN : BOOL; // Уставка веса бункера для зелёного светофора
	
	// Константы
	AMOUNT_BUNKER_MOTOR_VIBFEEDER : INT := 2;
	AMOUNT_BUNKER_MOTOR_VIBRATOR : INT := 4;
END_VAR