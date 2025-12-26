FUNCTION_BLOCK FB_DumperMotorErrors
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
END_VAR
VAR_OUTPUT
	// Ошибки моторов конвейера
	xErrorMotorConv1 : BOOL;
	xErrorMotorConv2 : BOOL;
	xErrorMotorConv_Any : BOOL;

	// Ошибки моторов поворота
	xErrorMotorRot1 : BOOL;
	xErrorMotorRot2 : BOOL;
	xErrorMotorRot_Any : BOOL;

	// Агрегированный выход
	xErrorMotors : BOOL; // Любая ошибка моторов
END_VAR

// ========================================
// FB_DumperMotorErrors - Проверка ошибок моторов отвалообразователя
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Проверка всех моторов отвалообразователя на ошибки
// - Формирование индивидуальных флагов ошибок
// - Агрегирование ошибок
//
// МОТОРЫ:
// - MotorConveyor[1..2]: Моторы конвейера (22 кВт)
// - MotorRotation[1..2]: Моторы поворота (3 кВт)
//
// ПРОВЕРЯЕМЫЕ ОШИБКИ:
// - Ошибка VFD (fbStateFailure: 0 = ошибка, 1 = норма, NC контакт)
//
// ========================================

// ========================================
// ПРОВЕРКА МОТОРОВ КОНВЕЙЕРА
// ========================================

// Мотор конвейера 1
// fbStateFailure - NC контакт: 0 = ошибка VFD, 1 = норма
xErrorMotorConv1 := NOT Dumper.MotorConveyor[1].VFD.fbStateFailure.qxSignal;

// Мотор конвейера 2
xErrorMotorConv2 := NOT Dumper.MotorConveyor[2].VFD.fbStateFailure.qxSignal;

xErrorMotorConv_Any := xErrorMotorConv1 OR xErrorMotorConv2;

// ========================================
// ПРОВЕРКА МОТОРОВ ПОВОРОТА
// ========================================

// Мотор поворота 1
xErrorMotorRot1 := NOT Dumper.MotorRotation[1].VFD.fbStateFailure.qxSignal;

// Мотор поворота 2
xErrorMotorRot2 := NOT Dumper.MotorRotation[2].VFD.fbStateFailure.qxSignal;

xErrorMotorRot_Any := xErrorMotorRot1 OR xErrorMotorRot2;

// ========================================
// АГРЕГИРОВАНИЕ ОШИБОК
// ========================================

xErrorMotors := xErrorMotorConv_Any OR xErrorMotorRot_Any;

END_FUNCTION_BLOCK
