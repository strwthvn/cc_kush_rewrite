FUNCTION FC_Dumper_GetErrorSensors : BOOL
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
END_VAR
VAR
END_VAR
FC_Dumper_GetErrorSensors := (
	// Контроль схода ленты - тревога
	FC_Sensor_CheckZQAlarm(fbZQAlarm := Dumper.fbZQAlarm)
	// Кабель-тросовый выключатель
	OR FC_Sensor_CheckHQ(fbHQ_IsOk := Dumper.fbHQ_IsOk)
	// Контроль ограждения барабана
	OR FC_Sensor_CheckSQ(fbSQ_IsOk := Dumper.fbSQ_IsOk)
	// Контроль заштыбовки
	OR FC_Sensor_CheckGS(fbGS := Dumper.fbGS1)
	// Контроль продольного разрыва ленты
	OR FC_Sensor_CheckYS(fbYS := Dumper.fbYS1)
);

END_FUNCTION