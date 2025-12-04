FUNCTION FC_Bunker_GetErrorMotorVibrator : BOOL
VAR_INPUT
	motor : REFERENCE TO ST_Motor;
END_VAR
VAR
END_VAR
FC_Bunker_GetErrorMotorVibrator := (
	motor.VFD.xStateFailure // Ошибка ЧРП, полученная по дискретному входу
	OR motor.VFD.xStateFailureLocal // Ошибка ЧРП, полученная программным путём
	OR motor.VFD.fbRangeDiagnostic.qxCriticalActive // Критическое значение тока эл. двигателя
);

END_FUNCTION