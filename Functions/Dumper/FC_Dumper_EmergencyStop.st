FUNCTION FC_Dumper_EmergencyStop  : BOOL
VAR_INPUT
	Dumper : ST_Dumper;
END_VAR
VAR
	j : INT := 0;
END_VAR
// Остановка моторов конвейера (унаследовано от ST_ConveyorBasic)
FOR j := 1 TO 2 DO
	Dumper.MotorConveyor[j].qxKM_Power := FALSE;
	Dumper.MotorConveyor[j].VFD.qxStart := FALSE;
	Dumper.MotorConveyor[j].VFD.Frequency.rTargetFrequency := 0.0;
	Dumper.MotorConveyor[j].VFD.qrOutFrequency := 0.0;
END_FOR
       
// Остановка моторов поворота
FOR j := 1 TO 2 DO
	Dumper.MotorRotation[j].qxKM_Power := FALSE;
	Dumper.MotorRotation[j].VFD.qxStart := FALSE;
	Dumper.MotorRotation[j].VFD.Frequency.rTargetFrequency := 0.0;
	Dumper.MotorRotation[j].VFD.qrOutFrequency := 0.0;
	Dumper.MotorRotation[j].qxVFDReverseStart := FALSE;
END_FOR

END_FUNCTION