FUNCTION_BLOCK FB_ConveyorMotorErrors
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
	xReset : BOOL; // Команда сброса зафиксированных ошибок
END_VAR
VAR_OUTPUT
	// Ошибки моторов конвейера
	xErrorMotorConv1 : BOOL;
	xErrorMotorConv2 : BOOL;
	xErrorMotorConv_Any : BOOL;

	// Агрегированный выход ошибок
	xErrorMotors : BOOL; // Любая ошибка моторов (VFD failure)

	// Готовность VFD (дискретный сигнал "Готов к пуску")
	xVFD_ReadyConv1 : BOOL; // VFD мотора конвейера 1 готов
	xVFD_ReadyConv2 : BOOL; // VFD мотора конвейера 2 готов
	xVFD_ReadyConv_All : BOOL; // Все VFD конвейера готовы
END_VAR
VAR
	// Внутренние переменные для текущих состояний ошибок (без фиксации)
	_xCurrentErrorMotorConv1 : BOOL;
	_xCurrentErrorMotorConv2 : BOOL;

	// RS-триггеры для фиксации ошибок
	_fbLatchErrorMotorConv1 : RS;
	_fbLatchErrorMotorConv2 : RS;
END_VAR

// ========================================
// FB_ConveyorMotorErrors - Проверка ошибок моторов сборного конвейера
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Проверка всех моторов конвейера на ошибки
// - Фиксация ошибок через RS-триггеры (память до сброса)
// - Формирование индивидуальных флагов ошибок
// - Агрегирование ошибок
//
// МОТОРЫ:
// - MotorConveyor[1..2]: Моторы конвейера (22 кВт)
//
// ПРОВЕРЯЕМЫЕ ОШИБКИ:
// - Ошибка VFD (fbStateFailure: 0 = ошибка, 1 = норма, NC контакт)
// - Локальная ошибка VFD (xStateFailureLocal)
// - Критический ток (fbRangeDiagnostic.qxCriticalActive)
// - Перегрев статора (fbStatorOverheat: 1 = норма, 0 = перегрев)
//
// ПРОВЕРЯЕМАЯ ГОТОВНОСТЬ:
// - Готовность VFD (fbStateRdyToStart: 1 = готов, 0 = не готов, NO контакт)
//
// ЛОГИКА ФИКСАЦИИ:
// - При возникновении ошибки она фиксируется (SET в RS-триггер)
// - Ошибка сохраняется даже после устранения неисправности
// - Сброс всех зафиксированных ошибок через вход xReset
//
// ========================================

// ========================================
// ПРОВЕРКА МОТОРОВ КОНВЕЙЕРА
// ========================================

// Мотор конвейера 1
// fbStateFailure - NC контакт: 0 = ошибка VFD, 1 = норма
_xCurrentErrorMotorConv1 := NOT Conveyor.MotorConveyor[1].VFD.fbStateFailure.qxSignal
                         OR Conveyor.MotorConveyor[1].VFD.xStateFailureLocal
                         OR Conveyor.MotorConveyor[1].VFD.fbRangeDiagnostic.qxCriticalActive
                         OR NOT Conveyor.MotorConveyor[1].fbStatorOverheat.qxSignal;

// Мотор конвейера 2
_xCurrentErrorMotorConv2 := NOT Conveyor.MotorConveyor[2].VFD.fbStateFailure.qxSignal
                         OR Conveyor.MotorConveyor[2].VFD.xStateFailureLocal
                         OR Conveyor.MotorConveyor[2].VFD.fbRangeDiagnostic.qxCriticalActive
                         OR NOT Conveyor.MotorConveyor[2].fbStatorOverheat.qxSignal;

// Фиксируем ошибки через RS-триггеры (SET при ошибке, RESET по команде xReset)
_fbLatchErrorMotorConv1(SET := _xCurrentErrorMotorConv1, RESET1 := xReset);
_fbLatchErrorMotorConv2(SET := _xCurrentErrorMotorConv2, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorMotorConv1 := _fbLatchErrorMotorConv1.Q1;
xErrorMotorConv2 := _fbLatchErrorMotorConv2.Q1;

xErrorMotorConv_Any := xErrorMotorConv1 OR xErrorMotorConv2;

// ========================================
// АГРЕГИРОВАНИЕ ОШИБОК
// ========================================

xErrorMotors := xErrorMotorConv_Any;

// ========================================
// ПРОВЕРКА ГОТОВНОСТИ VFD
// ========================================
// fbStateRdyToStart - NO контакт: 1 = готов к пуску, 0 = не готов
// Готовность проверяется в реальном времени (без фиксации)

// Готовность VFD конвейера
xVFD_ReadyConv1 := Conveyor.MotorConveyor[1].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyConv2 := Conveyor.MotorConveyor[2].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyConv_All := xVFD_ReadyConv1 AND xVFD_ReadyConv2;

END_FUNCTION_BLOCK
