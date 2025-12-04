FUNCTION FC_Bunker_GetErrorBunker : BOOL
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
END_VAR
VAR
END_VAR
FC_Bunker_GetErrorBunker :=
	FC_Bunker_GetErrorMotorVibFeeder(Bunker := Bunker)
	OR FC_Bunker_GetErrorMotorVibrator(motor := Bunker.MotorVibrator[1])
	OR FC_Bunker_GetErrorMotorVibrator(motor := Bunker.MotorVibrator[2])
	OR FC_Bunker_GetErrorMotorVibrator(motor := Bunker.MotorVibrator[3])
	OR FC_Bunker_GetErrorMotorVibrator(motor := Bunker.MotorVibrator[4]);

END_FUNCTION