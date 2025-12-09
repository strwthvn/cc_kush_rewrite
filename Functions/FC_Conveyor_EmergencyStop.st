FUNCTION FC_Conveyor_EmergencyStop : BOOL
VAR_INPUT
	Conveyor : ST_ConveyorPrefabricated;
END_VAR
VAR
	j : INT;
END_VAR
FOR j := 1 TO 2 DO
	Conveyor.MotorConveyor[j].qxKM_Power := FALSE;
	Conveyor.MotorConveyor[j].VFD.qxStart := FALSE;
	Conveyor.MotorConveyor[j].VFD.Frequency.rTargetFrequency := 0.0;
	Conveyor.MotorConveyor[j].VFD.qrOutFrequency := 0.0;
END_FOR

END_FUNCTION