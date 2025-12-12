FUNCTION FC_Sensor_CheckGS : BOOL
VAR_INPUT
	fbGS : REFERENCE TO FB_UniversalSignal;
END_VAR
VAR
END_VAR
// Контроль заштыбовки (1 - норма, 0 - заштыбовка)
FC_Sensor_CheckGS := NOT fbGS.qxSignal;

END_FUNCTION
