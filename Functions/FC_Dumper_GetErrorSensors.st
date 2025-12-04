FUNCTION FC_Dumper_GetErrorSensors : BOOL
VAR_INPUT
	Dumper : REFERENCE TO ST_Dumper;
END_VAR
VAR
END_VAR
FC_Dumper_GetErrorSensors := (
	// == МОДУЛИ ДИСКРЕТНОГО ВХОДА ==
	// Контроль схода ленты (1 - норма, 0 - стоп)
	NOT Dumper.fbZQAlarm[1].qxSignal
	OR NOT Dumper.fbZQAlarm[2].qxSignal
	OR NOT Dumper.fbZQAlarm[3].qxSignal
	OR NOT Dumper.fbZQAlarm[4].qxSignal
	// Кабель-троссовый выключатель (1 - норма, 0 - стоп)
	OR NOT Dumper.fbHQ_IsOk[1].qxSignal
	OR NOT Dumper.fbHQ_IsOk[2].qxSignal
	OR NOT Dumper.fbHQ_IsOk[3].qxSignal
	OR NOT Dumper.fbHQ_IsOk[4].qxSignal
	// Контроль ограждения барабана (1 - норма, 0 - ограждения нет)
	OR NOT Dumper.fbSQ_IsOk[1].qxSignal
	OR NOT Dumper.fbSQ_IsOk[2].qxSignal
	// Контроль заштыбовки (1 - норма, 0 - ограждения нет)
	OR NOT Dumper.fbGS1.qxSignal
	// Контроль продольного разрыва ленты (1 - норма, 0 - разрыв)
	OR NOT Dumper.fbYS1.qxSignal
);

END_FUNCTION