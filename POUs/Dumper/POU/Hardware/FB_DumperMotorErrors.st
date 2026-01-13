FUNCTION_BLOCK FB_DumperMotorErrors
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
	xReset : BOOL; // Команда сброса зафиксированных ошибок
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

	// Агрегированный выход ошибок
	xErrorMotors : BOOL; // Любая ошибка моторов (VFD failure)

	// Готовность VFD (дискретный сигнал "Готов к пуску")
	xVFD_ReadyConv1 : BOOL; // VFD мотора конвейера 1 готов
	xVFD_ReadyConv2 : BOOL; // VFD мотора конвейера 2 готов
	xVFD_ReadyConv_All : BOOL; // Все VFD конвейера готовы

	xVFD_ReadyRot1 : BOOL; // VFD мотора поворота 1 готов
	xVFD_ReadyRot2 : BOOL; // VFD мотора поворота 2 готов
	xVFD_ReadyRot_All : BOOL; // Все VFD поворота готовы

	xVFD_Ready_All : BOOL; // Все VFD готовы к пуску
END_VAR
VAR
	// Внутренние переменные для текущих состояний ошибок (без фиксации)
	_xCurrentErrorMotorConv1 : BOOL;
	_xCurrentErrorMotorConv2 : BOOL;
	_xCurrentErrorMotorRot1 : BOOL;
	_xCurrentErrorMotorRot2 : BOOL;

	// RS-триггеры для фиксации ошибок
	_fbLatchErrorMotorConv1 : RS;
	_fbLatchErrorMotorConv2 : RS;
	_fbLatchErrorMotorRot1 : RS;
	_fbLatchErrorMotorRot2 : RS;
END_VAR

// ========================================
// FB_DumperMotorErrors - Проверка ошибок моторов отвалообразователя
// ========================================
//
// НАЗНАЧЕНИЕ:
// - Проверка всех моторов отвалообразователя на ошибки
// - Фиксация ошибок через RS-триггеры (память до сброса)
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
_xCurrentErrorMotorConv1 := NOT Dumper.MotorConveyor[1].VFD.fbStateFailure.qxSignal;

// Мотор конвейера 2
_xCurrentErrorMotorConv2 := NOT Dumper.MotorConveyor[2].VFD.fbStateFailure.qxSignal;

// Фиксируем ошибки через RS-триггеры (SET при ошибке, RESET по команде xReset)
_fbLatchErrorMotorConv1(SET := _xCurrentErrorMotorConv1, RESET1 := xReset);
_fbLatchErrorMotorConv2(SET := _xCurrentErrorMotorConv2, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorMotorConv1 := _fbLatchErrorMotorConv1.Q1;
xErrorMotorConv2 := _fbLatchErrorMotorConv2.Q1;

xErrorMotorConv_Any := xErrorMotorConv1 OR xErrorMotorConv2;

// ========================================
// ПРОВЕРКА МОТОРОВ ПОВОРОТА
// ========================================

// Мотор поворота 1
_xCurrentErrorMotorRot1 := NOT Dumper.MotorRotation[1].VFD.fbStateFailure.qxSignal;

// Мотор поворота 2
_xCurrentErrorMotorRot2 := NOT Dumper.MotorRotation[2].VFD.fbStateFailure.qxSignal;

// Фиксируем ошибки через RS-триггеры (SET при ошибке, RESET по команде xReset)
_fbLatchErrorMotorRot1(SET := _xCurrentErrorMotorRot1, RESET1 := xReset);
_fbLatchErrorMotorRot2(SET := _xCurrentErrorMotorRot2, RESET1 := xReset);

// Выходы - зафиксированные ошибки
xErrorMotorRot1 := _fbLatchErrorMotorRot1.Q1;
xErrorMotorRot2 := _fbLatchErrorMotorRot2.Q1;

xErrorMotorRot_Any := xErrorMotorRot1 OR xErrorMotorRot2;

// ========================================
// АГРЕГИРОВАНИЕ ОШИБОК
// ========================================

xErrorMotors := xErrorMotorConv_Any OR xErrorMotorRot_Any;

// ========================================
// ПРОВЕРКА ГОТОВНОСТИ VFD
// ========================================
// fbStateRdyToStart - NO контакт: 1 = готов к пуску, 0 = не готов
// Готовность проверяется в реальном времени (без фиксации)

// Готовность VFD конвейера
xVFD_ReadyConv1 := Dumper.MotorConveyor[1].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyConv2 := Dumper.MotorConveyor[2].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyConv_All := xVFD_ReadyConv1 AND xVFD_ReadyConv2;

// Готовность VFD поворота
xVFD_ReadyRot1 := Dumper.MotorRotation[1].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyRot2 := Dumper.MotorRotation[2].VFD.fbStateRdyToStart.qxSignal;
xVFD_ReadyRot_All := xVFD_ReadyRot1 AND xVFD_ReadyRot2;

// Общая готовность всех VFD
xVFD_Ready_All := xVFD_ReadyConv_All AND xVFD_ReadyRot_All;

END_FUNCTION_BLOCK
