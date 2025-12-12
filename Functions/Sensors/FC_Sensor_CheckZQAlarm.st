FUNCTION FC_Sensor_CheckZQAlarm : BOOL
VAR_INPUT
	fbZQAlarm : REFERENCE TO ARRAY[1..4] OF FB_UniversalSignal;
END_VAR
VAR
END_VAR
// Контроль схода ленты - тревога (1 - норма, 0 - стоп)
FC_Sensor_CheckZQAlarm := (
	NOT fbZQAlarm[1].qxSignal
	OR NOT fbZQAlarm[2].qxSignal
	OR NOT fbZQAlarm[3].qxSignal
	OR NOT fbZQAlarm[4].qxSignal
);

END_FUNCTION
