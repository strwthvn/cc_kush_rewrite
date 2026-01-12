FUNCTION FC_Conveyor_EmergencyStop : BOOL
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
END_VAR
VAR
	j : INT;
END_VAR

// Аварийная остановка всех моторов конвейера
FOR j := 1 TO 2 DO
	Conveyor.MotorConveyor[j].qxKM_Power := FALSE;
	Conveyor.MotorConveyor[j].VFD.qxStart := FALSE;
	Conveyor.MotorConveyor[j].VFD.Frequency.rTargetFrequency := 0.0;
	Conveyor.MotorConveyor[j].VFD.qrOutFrequency := 0.0;
END_FOR

// Активация тормоза
Conveyor.qxBreakerConveyor := FALSE;

FC_Conveyor_EmergencyStop := TRUE;

END_FUNCTION
