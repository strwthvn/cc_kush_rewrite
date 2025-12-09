FUNCTION FC_Bunker_EmergencyStop : BOOL
VAR_INPUT
	Bunker : ST_Bunker;
END_VAR
VAR
	j : INT;
END_VAR
// Остановка моторов вибраторов (4 шт на бункер)
FOR j := 1 TO 4 DO
	Bunker.MotorVibrator[j].qxKM_Power := FALSE;
	Bunker.MotorVibrator[j].VFD.qxStart := FALSE;
	Bunker.MotorVibrator[j].VFD.Frequency.rTargetFrequency := 0.0;
	Bunker.MotorVibrator[j].VFD.qrOutFrequency := 0.0;
END_FOR

// Остановка моторов вибропитателей (2 шт на бункер)
FOR j := 1 TO 2 DO
	Bunker.MotorVibFeeder[j].qxKM_Power := FALSE;
	Bunker.MotorVibFeeder[j].VFD.qxStart := FALSE;
	Bunker.MotorVibFeeder[j].VFD.Frequency.rTargetFrequency := 0.0;
	Bunker.MotorVibFeeder[j].VFD.qrOutFrequency := 0.0;
END_FOR

// Установка красного сигнала светофора
FC_Bunker_SetLightColor(Bunker := Bunker, eColor := E_LightColor.RED);

END_FUNCTION