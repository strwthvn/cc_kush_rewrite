FUNCTION FC_Bunker_GetErrorMotorVibFeeder : BOOL
VAR_INPUT
	Bunker : REFERENCE TO ST_Bunker;
END_VAR
VAR
END_VAR
FC_Bunker_GetErrorMotorVibFeeder := 
		Bunker.MotorVibFeeder[1].VFD.xStateFailure // Ошибка ЧРП, полученная по дискретному входу
		OR Bunker.MotorVibFeeder[1].VFD.xStateFailureLocal // Ошибка ЧРП, полученная программным путём
		OR Bunker.MotorVibFeeder[1].VFD.fbRangeDiagnostic.qxCriticalActive // Критическое значение тока эл. двигателя
		OR NOT Bunker.MotorVibFeeder[1].fbStatorOverheat.qxSignal // Перегрев статора (1 - норма, 0 - перегрев)
		OR Bunker.MotorVibFeeder[1].fbRangeDiagnostic[1].qxCriticalActive // Критический уровень нагрева подпишникового узла 1
		OR Bunker.MotorVibFeeder[1].fbRangeDiagnostic[2].qxCriticalActive // Критический уровень нагрева подпишникового узла 2

		OR Bunker.MotorVibFeeder[2].VFD.xStateFailure // Ошибка ЧРП, полученная по дискретному входу
		OR Bunker.MotorVibFeeder[2].VFD.xStateFailureLocal // Ошибка ЧРП, полученная программным путём
		OR Bunker.MotorVibFeeder[2].VFD.fbRangeDiagnostic.qxCriticalActive // Критическое значение тока эл. двигателя
		OR NOT Bunker.MotorVibFeeder[2].fbStatorOverheat.qxSignal // Перегрев статора (1 - норма, 0 - перегрев)
		OR Bunker.MotorVibFeeder[2].fbRangeDiagnostic[1].qxCriticalActive // Критический уровень нагрева подпишникового узла 1
		OR Bunker.MotorVibFeeder[2].fbRangeDiagnostic[2].qxCriticalActive; // Критический уровень нагрева подпишникового узла 2

END_FUNCTION