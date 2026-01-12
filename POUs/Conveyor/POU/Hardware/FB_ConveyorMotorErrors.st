FUNCTION_BLOCK FB_ConveyorMotorErrors
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
END_VAR
VAR_OUTPUT
	// Ошибки моторов конвейера
	xErrorMotorConv1 : BOOL;
	xErrorMotorConv2 : BOOL;
	xErrorMotorConv_Any : BOOL;

	// Агрегированный выход
	xErrorMotors : BOOL; // Любая ошибка моторов
END_VAR

// ========================================
// FB_ConveyorMotorErrors - Проверка ошибок моторов сборного конвейера
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Проверка всех моторов конвейера на ошибки
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
// ========================================

// ========================================
// ПРОВЕРКА МОТОРОВ КОНВЕЙЕРА
// ========================================

// Мотор конвейера 1
// fbStateFailure - NC контакт: 0 = ошибка VFD, 1 = норма
xErrorMotorConv1 := NOT Conveyor.MotorConveyor[1].VFD.fbStateFailure.qxSignal
                 OR Conveyor.MotorConveyor[1].VFD.xStateFailureLocal
                 OR Conveyor.MotorConveyor[1].VFD.fbRangeDiagnostic.qxCriticalActive
                 OR NOT Conveyor.MotorConveyor[1].fbStatorOverheat.qxSignal;

// Мотор конвейера 2
xErrorMotorConv2 := NOT Conveyor.MotorConveyor[2].VFD.fbStateFailure.qxSignal
                 OR Conveyor.MotorConveyor[2].VFD.xStateFailureLocal
                 OR Conveyor.MotorConveyor[2].VFD.fbRangeDiagnostic.qxCriticalActive
                 OR NOT Conveyor.MotorConveyor[2].fbStatorOverheat.qxSignal;

xErrorMotorConv_Any := xErrorMotorConv1 OR xErrorMotorConv2;

// ========================================
// АГРЕГИРОВАНИЕ ОШИБОК
// ========================================

xErrorMotors := xErrorMotorConv_Any;

END_FUNCTION_BLOCK
