FUNCTION FC_Sensor_CheckZQWarning : BOOL
VAR_INPUT
	fbZQAlarm : REFERENCE TO ARRAY[1..4] OF FB_UniversalSignal;
END_VAR
VAR
END_VAR
// Контроль схода ленты - тревога (1 - норма, 0 - стоп)
FC_Sensor_CheckZQWarning := (
	NOT fbZQWarning[1].qxSignal
	OR NOT fbZQWarning[2].qxSignal
	OR NOT fbZQWarning[3].qxSignal
	OR NOT fbZQWarning[4].qxSignal
);

END_FUNCTION
