FUNCTION_BLOCK FB_BunkerMotorErrors
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
	xReset : BOOL; // Команда сброса зафиксированных ошибок
END_VAR
VAR_OUTPUT
	// Ошибки вибропитателей (индивидуально)
	xErrorVibFeeder1 : BOOL;
	xErrorVibFeeder2 : BOOL;
	xErrorMotorVibFeeder_Any : BOOL; // Ошибка хотя бы одного вибропитателя

	// Ошибки вибраторов (индивидуально)
	xErrorVibrator1 : BOOL;
	xErrorVibrator2 : BOOL;
	xErrorVibrator3 : BOOL;
	xErrorVibrator4 : BOOL;
	xErrorMotorVibrator_Any : BOOL; // Ошибка хотя бы одного вибратора

	// Ошибки бункера
	xErrorBunker : BOOL; // Ошибка бункера (люк, вес)

	// Состояние автоматических выключателей (QF)
	xQF_OkVibFeeder1 : BOOL;
	xQF_OkVibFeeder2 : BOOL;
	xQF_OkVibFeeder_All : BOOL;

	xQF_OkVibrator1 : BOOL;
	xQF_OkVibrator2 : BOOL;
	xQF_OkVibrator3 : BOOL;
	xQF_OkVibrator4 : BOOL;
	xQF_OkVibrator_All : BOOL;

	xQF_Ok_All : BOOL; // Все QF включены

	// Готовность VFD
	xVFD_ReadyVibFeeder1 : BOOL;
	xVFD_ReadyVibFeeder2 : BOOL;
	xVFD_ReadyVibFeeder_All : BOOL;

	xVFD_ReadyVibrator1 : BOOL;
	xVFD_ReadyVibrator2 : BOOL;
	xVFD_ReadyVibrator3 : BOOL;
	xVFD_ReadyVibrator4 : BOOL;
	xVFD_ReadyVibrator_All : BOOL;

	xVFD_Ready_All : BOOL; // Все VFD готовы
END_VAR
VAR
	// Внутренние переменные для текущих состояний ошибок (без фиксации)
	_xCurrentErrorVibFeeder1 : BOOL;
	_xCurrentErrorVibFeeder2 : BOOL;
	_xCurrentErrorVibrator1 : BOOL;
	_xCurrentErrorVibrator2 : BOOL;
	_xCurrentErrorVibrator3 : BOOL;
	_xCurrentErrorVibrator4 : BOOL;
	_xCurrentErrorBunker : BOOL;

	// RS-триггеры для фиксации ошибок
	_fbLatchErrorVibFeeder1 : RS;
	_fbLatchErrorVibFeeder2 : RS;
	_fbLatchErrorVibrator1 : RS;
	_fbLatchErrorVibrator2 : RS;
	_fbLatchErrorVibrator3 : RS;
	_fbLatchErrorVibrator4 : RS;
	_fbLatchErrorBunker : RS;
END_VAR

// ========================================
// FB_BunkerMotorErrors - Проверка ошибок моторов бункера
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Проверка всех моторов бункера на ошибки
// - Фиксация ошибок через RS-триггеры (память до сброса)
// - Формирование индивидуальных флагов ошибок
// - Агрегирование ошибок
//
// МОТОРЫ:
// - MotorVibFeeder[1..2]: Вибропитатели (7.5 кВт)
// - MotorVibrator[1..4]: Вибраторы (0.62 кВт)
//
// ПРОВЕРЯЕМЫЕ ОШИБКИ:
// - Ошибка VFD (fbStateFailure: NC контакт - 0 = ошибка, 1 = норма)
// - Локальная ошибка VFD (xStateFailureLocal: программная установка ошибки)
//
// ЛОГИКА ФИКСАЦИИ:
// - При возникновении ошибки она фиксируется (SET в RS-триггер)
// - Ошибка сохраняется даже после устранения неисправности
// - Сброс всех зафиксированных ошибок через вход xReset
//
// ========================================

// ========================================
// ПРОВЕРКА ОШИБОК ВИБРОПИТАТЕЛЕЙ
// ========================================

// Вибропитатель 1
// fbStateFailure - NC контакт: 0 = ошибка VFD, 1 = норма
// Используем инвертированный сигнал (qxInvertedSignal: TRUE = ошибка)
_xCurrentErrorVibFeeder1 := Bunker.MotorVibFeeder[1].VFD.fbStateFailure.qxInvertedSignal
                         OR Bunker.MotorVibFeeder[1].VFD.xStateFailureLocal;

// Вибропитатель 2
_xCurrentErrorVibFeeder2 := Bunker.MotorVibFeeder[2].VFD.fbStateFailure.qxInvertedSignal
                         OR Bunker.MotorVibFeeder[2].VFD.xStateFailureLocal;

// Фиксируем ошибки через RS-триггеры
_fbLatchErrorVibFeeder1(SET := _xCurrentErrorVibFeeder1, RESET1 := xReset);
_fbLatchErrorVibFeeder2(SET := _xCurrentErrorVibFeeder2, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorVibFeeder1 := _fbLatchErrorVibFeeder1.Q1;
xErrorVibFeeder2 := _fbLatchErrorVibFeeder2.Q1;

xErrorMotorVibFeeder_Any := xErrorVibFeeder1 OR xErrorVibFeeder2;

// ========================================
// ПРОВЕРКА ОШИБОК ВИБРАТОРОВ
// ========================================

// Вибратор 1
_xCurrentErrorVibrator1 := Bunker.MotorVibrator[1].VFD.fbStateFailure.qxInvertedSignal
                        OR Bunker.MotorVibrator[1].VFD.xStateFailureLocal;

// Вибратор 2
_xCurrentErrorVibrator2 := Bunker.MotorVibrator[2].VFD.fbStateFailure.qxInvertedSignal
                        OR Bunker.MotorVibrator[2].VFD.xStateFailureLocal;

// Вибратор 3
_xCurrentErrorVibrator3 := Bunker.MotorVibrator[3].VFD.fbStateFailure.qxInvertedSignal
                        OR Bunker.MotorVibrator[3].VFD.xStateFailureLocal;

// Вибратор 4
_xCurrentErrorVibrator4 := Bunker.MotorVibrator[4].VFD.fbStateFailure.qxInvertedSignal
                        OR Bunker.MotorVibrator[4].VFD.xStateFailureLocal;

// Фиксируем ошибки через RS-триггеры
_fbLatchErrorVibrator1(SET := _xCurrentErrorVibrator1, RESET1 := xReset);
_fbLatchErrorVibrator2(SET := _xCurrentErrorVibrator2, RESET1 := xReset);
_fbLatchErrorVibrator3(SET := _xCurrentErrorVibrator3, RESET1 := xReset);
_fbLatchErrorVibrator4(SET := _xCurrentErrorVibrator4, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorVibrator1 := _fbLatchErrorVibrator1.Q1;
xErrorVibrator2 := _fbLatchErrorVibrator2.Q1;
xErrorVibrator3 := _fbLatchErrorVibrator3.Q1;
xErrorVibrator4 := _fbLatchErrorVibrator4.Q1;

xErrorMotorVibrator_Any := xErrorVibrator1 OR xErrorVibrator2 OR xErrorVibrator3 OR xErrorVibrator4;

// ========================================
// ПРОВЕРКА ОШИБОК БУНКЕРА
// ========================================

// Проверка положения люка (1 = закрыт, 0 = открыт)
// Открытый люк = ошибка
_xCurrentErrorBunker := NOT Bunker.fbStateHatch.qxSignal;

// Фиксируем ошибку через RS-триггер
_fbLatchErrorBunker(SET := _xCurrentErrorBunker, RESET1 := xReset);

// Выход - зафиксированная ошибка
xErrorBunker := _fbLatchErrorBunker.Q1;

// ========================================
// ПРОВЕРКА ГОТОВНОСТИ VFD
// ========================================
// fbStateRdyToStart - NO контакт: 1 = готов к пуску, 0 = не готов
// Готовность проверяется в реальном времени (без фиксации)

// Готовность VFD вибропитателей
xVFD_ReadyVibFeeder1 := Bunker.MotorVibFeeder[1].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyVibFeeder2 := Bunker.MotorVibFeeder[2].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyVibFeeder_All := xVFD_ReadyVibFeeder1 AND xVFD_ReadyVibFeeder2;

// Готовность VFD вибраторов
xVFD_ReadyVibrator1 := Bunker.MotorVibrator[1].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyVibrator2 := Bunker.MotorVibrator[2].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyVibrator3 := Bunker.MotorVibrator[3].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyVibrator4 := Bunker.MotorVibrator[4].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyVibrator_All := xVFD_ReadyVibrator1 AND xVFD_ReadyVibrator2 AND xVFD_ReadyVibrator3 AND xVFD_ReadyVibrator4;

// Общая готовность всех VFD
xVFD_Ready_All := xVFD_ReadyVibFeeder_All AND xVFD_ReadyVibrator_All;

// ========================================
// ПРОВЕРКА СОСТОЯНИЯ АВТОМАТИЧЕСКИХ ВЫКЛЮЧАТЕЛЕЙ (QF)
// ========================================
// fbStateQF - NO контакт: 1 = QF включен, 0 = QF выключен
// Состояние проверяется в реальном времени (без фиксации)
// Выключенный QF - не ошибка, но запуск мотора невозможен

// Состояние QF вибропитателей
xQF_OkVibFeeder1 := Bunker.MotorVibFeeder[1].fbStateQF.qxSignal;
xQF_OkVibFeeder2 := Bunker.MotorVibFeeder[2].fbStateQF.qxSignal;
xQF_OkVibFeeder_All := xQF_OkVibFeeder1 AND xQF_OkVibFeeder2;

// Состояние QF вибраторов
xQF_OkVibrator1 := Bunker.MotorVibrator[1].fbStateQF.qxSignal;
xQF_OkVibrator2 := Bunker.MotorVibrator[2].fbStateQF.qxSignal;
xQF_OkVibrator3 := Bunker.MotorVibrator[3].fbStateQF.qxSignal;
xQF_OkVibrator4 := Bunker.MotorVibrator[4].fbStateQF.qxSignal;
xQF_OkVibrator_All := xQF_OkVibrator1 AND xQF_OkVibrator2 AND xQF_OkVibrator3 AND xQF_OkVibrator4;

// Общее состояние всех QF
xQF_Ok_All := xQF_OkVibFeeder_All AND xQF_OkVibrator_All;

END_FUNCTION_BLOCK
