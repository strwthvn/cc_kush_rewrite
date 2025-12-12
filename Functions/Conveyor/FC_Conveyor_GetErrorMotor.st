FUNCTION FC_Conveyor_GetErrorMotor : BOOL
VAR_INPUT
	motor : REFERENCE TO ST_MotorWithFeedback;
END_VAR
VAR
END_VAR
FC_Conveyor_GetErrorMotor := (
	motor.VFD.fbStateFailure.qxInvertedSignal // Ошибка ЧРП (NC: TRUE=норма, инвертированный=TRUE=ошибка)
	OR motor.VFD.xStateFailureLocal // Ошибка ЧРП, полученная программным путём
	OR motor.VFD.fbRangeDiagnostic.qxCriticalActive // Критическое значение тока эл. двигателя
	OR NOT motor.fbStatorOverheat.qxSignal // Перегрев статора (1 - норма, 0 - перегрев)
);

END_FUNCTION