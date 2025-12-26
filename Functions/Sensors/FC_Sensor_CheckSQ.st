FUNCTION FC_Sensor_CheckSQ : BOOL
VAR_INPUT
	fbSQ_IsOk : REFERENCE TO ARRAY[1..2] OF FB_UniversalSignal;
END_VAR
VAR
END_VAR
// Контроль ограждения барабана (1 - норма, 0 - ограждения нет)
FC_Sensor_CheckSQ := (
	NOT fbSQ_IsOk[1].qxSignal
	OR NOT fbSQ_IsOk[2].qxSignal
);

END_FUNCTION