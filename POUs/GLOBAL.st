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
	SIMULATION_BUNKER_WEIGHT : BOOL := FALSE; // Включение симуляции расхода и пополнения веса бункеров
	
	// == MODBUS РЕГИСТРЫ ДЛЯ SCADA ==
	// Массив регистров для передачи данных в SCADA систему
	awModbusInputRegisters : ARRAY [0..511] OF WORD; // Modbus Input регистры
	awModbusHoldingRegisters : ARRAY [0..511] OF WORD; // Modbus Holding регистры

	// == СИГНАЛЫ СВЯЗИ СО SCADA ==
	SCADA_HEARTBEAT : BOOL := FALSE; // Пульсирующий сигнал от SCADA (0 → 1 → 0) для контроля связи

END_VAR
VAR_GLOBAL RETAIN
	// == НАСТРОЙКИ ОСТАНОВКИ ==
	BUNKER_INSTANT_STOP : BOOL := FALSE; // Флаг мгновенной остановки бункеров (TRUE = одновременная остановка всех 3-х бункеров, FALSE = последовательная остановка)

	// == ОПЦИИ ВКЛЮЧЕНИЯ ИСТОЧНИКОВ В ГЛОБАЛЬНУЮ АВАРИЙНУЮ ОСТАНОВКУ ==
	// TRUE = источник включен в цепь глобальной аварийной остановки комплекса
	// FALSE = источник НЕ вызывает глобальную остановку

	// Датчики безопасности
	ENABLE_GLOBAL_ESTOP_ZQ : BOOL := TRUE;       // Датчики схода ленты (ZQ Alarm)
	ENABLE_GLOBAL_ESTOP_HQ : BOOL := TRUE;       // Кабель-тросовые выключатели
	ENABLE_GLOBAL_ESTOP_SQ : BOOL := FALSE;      // Концевики ограждений барабана
	ENABLE_GLOBAL_ESTOP_GS : BOOL := FALSE;      // Заштыбовка
	ENABLE_GLOBAL_ESTOP_YS : BOOL := TRUE;       // Продольный разрыв ленты
	ENABLE_GLOBAL_ESTOP_YE : BOOL := TRUE;       // Металлодетектор
	ENABLE_GLOBAL_ESTOP_QR : BOOL := FALSE;      // Датчики скорости

	// Системные сигналы
	ENABLE_GLOBAL_ESTOP_SCADA_LOSS : BOOL := FALSE;          // Потеря связи со SCADA
	ENABLE_GLOBAL_ESTOP_PROPORTION : BOOL := FALSE;          // Ошибка суммы пропорций
	ENABLE_GLOBAL_ESTOP_MOTOR_CURRENT_HH : BOOL := FALSE;    // Аварийный уровень тока (HH)

	// Блокировочные зависимости (глобально)
	ENABLE_GLOBAL_ESTOP_DEPENDENCIES : BOOL := TRUE;         // Блокировочные зависимости между секциями

	// Блокировочные зависимости (индивидуально по секциям)
	// TRUE = секция останавливается при нарушении зависимостей
	// FALSE = секция НЕ останавливается при нарушении зависимостей
	ENABLE_ESTOP_DEPENDENCIES_DUMPER : BOOL := TRUE;         // Зависимости для отвалообразователя
	ENABLE_ESTOP_DEPENDENCIES_CONVEYOR : BOOL := TRUE;       // Зависимости для сборного конвейера
	ENABLE_ESTOP_DEPENDENCIES_BUNKER1 : BOOL := TRUE;        // Зависимости для бункера 1
	ENABLE_ESTOP_DEPENDENCIES_BUNKER2 : BOOL := TRUE;        // Зависимости для бункера 2
	ENABLE_ESTOP_DEPENDENCIES_BUNKER3 : BOOL := TRUE;        // Зависимости для бункера 3

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
		TIME_ACTIVE := T#15S,
		TIME_PAUSE_VIBRATOR := T#30S,
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
	VFD_SMOOTH_SET_FREQUENCY : BOOL := FALSE;
	
	// Таймеры последовательного запуска механизмов в автоматическом режиме
	TIME_AFTER_START_DUMPER : TIME := T#120S; // Время ожидания после запуска отвалообразователя
	TIME_AFTER_START_CONVEYOR : TIME := T#120S; // Время ожидания после запуска конвейера
	TIME_AFTER_START_BUNKER_1 : TIME := T#120S; // Время ожидания после запуска бункера 1
	TIME_AFTER_START_BUNKER_2 : TIME := T#120S; // Время ожидания после запуска бункера 2
	TIME_AFTER_START_BUNKER_3 : TIME := T#120S; // Время ожидания после запуска бункера 3

	// Таймеры контроля выполнения команд (тайм-ауты)
	TIME_TIMEOUT_START_DUMPER_CONVEYOR : TIME := T#30S; // Тайм-аут запуска моторов конвейера отвалообразователя (STARTING → WORK)
	TIME_TIMEOUT_START_DUMPER_ROTATION : TIME := T#20S; // Тайм-аут запуска моторов поворота отвалообразователя (STARTING → WORK)
	TIME_TIMEOUT_START_CONVEYOR : TIME := T#30S; // Тайм-аут запуска моторов сборного конвейера (STARTING → WORK)
	TIME_TIMEOUT_STOP_DUMPER_CONVEYOR : TIME := T#30S; // Тайм-аут остановки моторов конвейера отвалообразователя (STOPPING → IDLE)
	TIME_TIMEOUT_STOP_DUMPER_ROTATION : TIME := T#20S; // Тайм-аут остановки моторов поворота отвалообразователя (STOPPING → IDLE)
	TIME_TIMEOUT_STOP_CONVEYOR : TIME := T#30S; // Тайм-аут остановки моторов сборного конвейера (STOPPING → IDLE)
	TIME_TIMEOUT_STOP_BUNKER : TIME := T#20S; // Тайм-аут остановки вибропитателей бункера (WORK → IDLE)
	
	// Таймер ожидания пропавшего сигнала обратной связи работы механизма
	TIME_WAITING_FEEDBACK : TIME := T#0S;

	// == ПАРАМЕТРЫ СВЯЗИ СО SCADA ==
	SCADA_HEARTBEAT_TIMEOUT : TIME := T#5S; // Таймаут отсутствия изменений heartbeat сигнала (потеря связи)

	// Таймаут контроля суммы пропорций в режиме WORK
	BUNKER_PROPORTION_SUM_TIMEOUT : TIME := T#20S; // Время ожидания корректировки суммы пропорций оператором (сумма должна быть = 100%)

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
	// Ток мотора конвейера отвалообразователя
	MOTOR_CONVEYOR_CURRENT_POINTS : ST_AlarmSetpoints := (
		LL_Value := -1,
		L_Value := -1,
		H_Value := -1,
		HH_Value := -1);
	// Ток мотора конвейера сборного
	MOTOR_CONVEYOR_PREFABRICATED_CURRENT_POINTS : ST_AlarmSetpoints := (
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
		
	BUNKER_MINIMAL_WEIGHT :REAL := 0; // Уставка минимального веса бункера. Результат <= считывается алгоритмом как пустой бункер.
	
	// Уставки бункера
	PNEUMATIC_COLLAPSE_TIME : TIME := T#0S; // Уставка времени таймера пневмообрушения
	BUNKER_WORK_PRECENT_1 : REAL; // Уставка пропорции шихтования для бункера 1
	BUNKER_WORK_PRECENT_2 : REAL; // Уставка пропорции шихтования для бункера 2
	BUNKER_WORK_PRECENT_3 : REAL; // Уставка пропорции шихтования для бункера 3
	BUNKER_VIBFEEDER_START_FREQUENCY : REAL := 10.0; // Минимальная частота для запуска вибропитателей (Гц)
	BUNKER_VIBFEEDER_FREQUENCY_TARGET_SUM : REAL := 50.0; // Целевая суммарная частота вибропитателей (Гц)
    BUNKER_ENABLE_PID : BOOL := FALSE;
    BUNKER_ENABLE_PROPORTION_MONITORING : BOOL := FALSE;

	// == КОНТРОЛЬ МИНИМАЛЬНОЙ И МАКСИМАЛЬНОЙ ЧАСТОТЫ ВИБРОПИТАТЕЛЯ (ДЛЯ ПИД-РЕГУЛЯТОРА) ==
	BUNKER_VIBFEEDER_MIN_FREQUENCY_LIMIT : REAL := 5.0; // Минимальная допустимая частота вибропитателя (Гц) - при достижении этой уставки запускается таймер аварии
	BUNKER_VIBFEEDER_MIN_FREQUENCY_TIMEOUT : TIME := T#30S; // Время задержки перед аварийной остановкой при достижении минимальной частоты
	BUNKER_VIBFEEDER_MAX_FREQUENCY_LIMIT : REAL := 50.0; // Максимальная допустимая частота вибропитателя (Гц) - при достижении этой уставки запускается таймер аварии
	BUNKER_VIBFEEDER_MAX_FREQUENCY_TIMEOUT : TIME := T#30S; // Время задержки перед аварийной остановкой при достижении максимальной частоты

	// Ручное задание частоты на бункер (работает в ручном режиме управления)
	BUNKER_1_FREQ_VIBFEEDER : REAL := 30;
	BUNKER_1_FREQ_VIBRATOR : REAL := 30;
	BUNKER_2_FREQ_VIBFEEDER : REAL := 30;
	BUNKER_2_FREQ_VIBRATOR : REAL := 30;
	BUNKER_3_FREQ_VIBFEEDER : REAL := 30;
	BUNKER_3_FREQ_VIBRATOR : REAL := 30;
	
	// Светофор бункера
	BUNKER_WEIGHT_LIGHT_RED : REAL := 90; // Уставка веса бункера для красного светофора
	BUNKER_WEIGHT_LIGHT_YELLOW : REAL := 80; // Уставка веса бункера для жёлтого светофора
	BUNKER_WEIGHT_LIGHT_GREEN : REAL := 50; // Уставка веса бункера для зелёного светофора
	
	BUNKER_WEIGHT_LIGHT_RED_SPECIAL : REAL := 10; // Уставка веса бункера для красного светофора, когда сырье закончилось и требуется остановить подачу материала в остальные бункеры для будущего алгоритма опустошения
	
	// Константы
	AMOUNT_BUNKER_MOTOR_VIBFEEDER : INT := 2;
	AMOUNT_BUNKER_MOTOR_VIBRATOR : INT := 4;

	// == УСТАВКИ ЗАДЕРЖКИ СРАБАТЫВАНИЯ ДАТЧИКОВ БЕЗОПАСНОСТИ ==
	// Таймеры задержки для датчиков отвалообразователя (Dumper)
	TIME_DELAY_SENSOR_DUMPER_ZQ_ALARM : TIME := T#0S;   // Задержка срабатывания датчика схода ленты (Alarm)
	TIME_DELAY_SENSOR_DUMPER_ZQ_WARNING : TIME := T#0S; // Задержка срабатывания датчика схода ленты (Warning)
	TIME_DELAY_SENSOR_DUMPER_HQ : TIME := T#0S;         // Задержка срабатывания кабель-тросового выключателя
	TIME_DELAY_SENSOR_DUMPER_SQ : TIME := T#0S;         // Задержка срабатывания датчика ограждения барабана
	TIME_DELAY_SENSOR_DUMPER_GS : TIME := T#0S;         // Задержка срабатывания датчика заштыбовки
	TIME_DELAY_SENSOR_DUMPER_YS : TIME := T#0S;         // Задержка срабатывания датчика продольного разрыва
	TIME_DELAY_SENSOR_DUMPER_QR : TIME := T#0S;         // Задержка срабатывания датчика скорости

	// Таймеры задержки для датчиков сборного конвейера (Conveyor)
	TIME_DELAY_SENSOR_CONVEYOR_ZQ_ALARM : TIME := T#0S;   // Задержка срабатывания датчика схода ленты (Alarm)
	TIME_DELAY_SENSOR_CONVEYOR_ZQ_WARNING : TIME := T#0S; // Задержка срабатывания датчика схода ленты (Warning)
	TIME_DELAY_SENSOR_CONVEYOR_HQ : TIME := T#0S;         // Задержка срабатывания кабель-тросового выключателя
	TIME_DELAY_SENSOR_CONVEYOR_SQ : TIME := T#0S;         // Задержка срабатывания датчика ограждения барабана
	TIME_DELAY_SENSOR_CONVEYOR_GS : TIME := T#0S;         // Задержка срабатывания датчика заштыбовки
	TIME_DELAY_SENSOR_CONVEYOR_YS : TIME := T#0S;         // Задержка срабатывания датчика продольного разрыва
	TIME_DELAY_SENSOR_CONVEYOR_YE : TIME := T#0S;         // Задержка срабатывания металлодетектора
	TIME_DELAY_SENSOR_CONVEYOR_QR : TIME := T#0S;         // Задержка срабатывания датчика скорости
END_VAR