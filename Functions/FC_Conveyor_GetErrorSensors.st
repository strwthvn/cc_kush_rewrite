FUNCTION FC_Conveyor_GetErrorSensors : BOOL
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
END_VAR
VAR
END_VAR
FC_Conveyor_GetErrorSensors := (
	// == МОДУЛИ ДИСКРЕТНОГО ВХОДА ==
	// Контроль схода ленты (1 - норма, 0 - стоп)
	NOT Conveyor.fbZQAlarm[1].qxSignal
	OR NOT Conveyor.fbZQAlarm[2].qxSignal
	OR NOT Conveyor.fbZQAlarm[3].qxSignal
	OR NOT Conveyor.fbZQAlarm[4].qxSignal
	// Кабель-троссовый выключатель (1 - норма, 0 - стоп)
	OR NOT Conveyor.fbHQ_IsOk[1].qxSignal
	OR NOT Conveyor.fbHQ_IsOk[2].qxSignal
	OR NOT Conveyor.fbHQ_IsOk[3].qxSignal
	OR NOT Conveyor.fbHQ_IsOk[4].qxSignal
	// Контроль ограждения барабана (1 - норма, 0 - ограждения нет)
	OR NOT Conveyor.fbSQ_IsOk[1].qxSignal
	OR NOT Conveyor.fbSQ_IsOk[2].qxSignal
	// Контроль заштыбовки (1 - норма, 0 - ограждения нет)
	OR NOT Conveyor.fbGS1.qxSignal
	// Контроль продольного разрыва ленты (1 - норма, 0 - разрыв)
	OR NOT Conveyor.fbYS1.qxSignal
	// Обнаружение металла (1 - обнаружение, 0 - нет)
	OR Conveyor.fbYE1.qxSignal
);

END_FUNCTION