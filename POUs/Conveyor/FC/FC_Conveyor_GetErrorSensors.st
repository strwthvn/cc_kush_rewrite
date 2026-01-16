FUNCTION FC_Conveyor_GetErrorSensors : BOOL
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
END_VAR
VAR
END_VAR
FC_Conveyor_GetErrorSensors := (
	// Контроль схода ленты - тревога
	FC_Sensor_CheckZQAlarm(fbZQAlarm := Conveyor.fbZQAlarm)
	// Кабель-тросовый выключатель
	OR FC_Sensor_CheckHQ(fbHQ_IsOk := Conveyor.fbHQ_IsOk)
	// Контроль ограждения барабана
	OR FC_Sensor_CheckSQ(fbSQ_IsOk := Conveyor.fbSQ_IsOk)
	// Контроль заштыбовки
	OR FC_Sensor_CheckGS(fbGS := Conveyor.fbGS1)
	// Контроль продольного разрыва ленты
	OR FC_Sensor_CheckYS(fbYS := Conveyor.fbYS1)
	// Обнаружение металла
	OR FC_Sensor_CheckYE(fbYE := Conveyor.fbYE1)
);

END_FUNCTION
