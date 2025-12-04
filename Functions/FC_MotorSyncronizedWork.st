FUNCTION FC_MotorSyncronizedWork : BOOL
VAR_INPUT
	motor1 : ST_Motor;
	motor2 : ST_Motor;
END_VAR
VAR
END_VAR
FC_MotorSyncronizedWork := (
	// Контактор и ЧРП в работе у мотора 1
		motor1.fbStateKM.qxSignal
	AND	motor1.VFD.fbStateIsWorking.qxSignal
	// Контактор и ЧРП в работе у мотора 2
	AND	motor2.fbStateKM.qxSignal
	AND	motor2.VFD.fbStateIsWorking.qxSignal )
	// Частота мотора 1 и мотора 2 равны с учётом погрешности
	AND ( ABS(motor1.VFD.rActualFrequency - motor2.VFD.rActualFrequency) <= VFD_FREQUENCY_INACCURANCY );

END_FUNCTION