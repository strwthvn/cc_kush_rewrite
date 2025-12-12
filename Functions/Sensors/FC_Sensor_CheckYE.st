FUNCTION FC_Sensor_CheckYE : BOOL
VAR_INPUT
	fbYE : REFERENCE TO FB_UniversalSignal;
END_VAR
VAR
END_VAR
// Обнаружение металла (1 - обнаружение, 0 - нет)
FC_Sensor_CheckYE := fbYE.qxSignal;

END_FUNCTION
