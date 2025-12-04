FUNCTION FC_Dumper_GetErrorCommon : BOOL
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
END_VAR
VAR
END_VAR
FC_Dumper_GetErrorCommon :=
	FC_Dumper_GetErrorSensors(Dumper := Dumper)
	OR FC_Conveyor_GetErrorMotor(motor := Dumper.MotorConveyor[1])
	OR FC_Conveyor_GetErrorMotor(motor := Dumper.MotorConveyor[2])
	OR FC_Conveyor_GetErrorMotor(motor := Dumper.MotorRotation[1])
	OR FC_Conveyor_GetErrorMotor(motor := Dumper.MotorRotation[2]);

END_FUNCTION