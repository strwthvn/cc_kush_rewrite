FUNCTION FC_Sensor_CheckYS : BOOL
VAR_INPUT
	fbYS : REFERENCE TO FB_UniversalSignal;
END_VAR
VAR
END_VAR
// Контроль продольного разрыва ленты (1 - норма, 0 - разрыв)
FC_Sensor_CheckYS := NOT fbYS.qxSignal;

END_FUNCTION