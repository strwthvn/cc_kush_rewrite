FUNCTION FC_Conveyor_GetErrorCommon : BOOL
VAR_INPUT
	Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
END_VAR
VAR
END_VAR
FC_Conveyor_GetErrorCommon :=
	FC_Conveyor_GetErrorSensors(Conveyor := Conveyor)
	OR FC_Conveyor_GetErrorMotor(motor := Conveyor.MotorConveyor[1])
	OR FC_Conveyor_GetErrorMotor(motor := Conveyor.MotorConveyor[2]);

END_FUNCTION
