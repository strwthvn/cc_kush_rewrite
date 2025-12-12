FUNCTION FC_Sensor_CheckHQ : BOOL
VAR_INPUT
	fbHQ_IsOk : REFERENCE TO ARRAY[1..4] OF FB_UniversalSignal;
END_VAR
VAR
END_VAR
// Кабель-тросовый выключатель (1 - норма, 0 - стоп)
FC_Sensor_CheckHQ := (
	NOT fbHQ_IsOk[1].qxSignal
	OR NOT fbHQ_IsOk[2].qxSignal
	OR NOT fbHQ_IsOk[3].qxSignal
	OR NOT fbHQ_IsOk[4].qxSignal
);

END_FUNCTION
