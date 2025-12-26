TYPE ST_BunkerVibratorSettings :
STRUCT
	TIME_ACTIVE : TIME;					// Время активной работы вибратора
	TIME_PAUSE_VIBRATOR : TIME;			// Время паузы вибратора между циклами
	TIME_PAUSE_FB : TIME;				// Время паузы ФБ между подходами
	COUNT_CYCLE : INT; 					// Количество срабатываний в одном подходе
END_STRUCT
END_TYPE



(*


fbVibratorControl(
	MotorVibrator:= Bunker.MotorVibrator, 
	xEnable:= , 
	xManualStart:= , 
	rWorkingFrequency:= VFD_FREQUENCY_BUNKER_VIBRATOR, 
	tActiveTime:= , 
	tPauseVibrator:= , 
	tPauseFB:= , 
	nCycleCount:= , 
	xMotorsWorking=> , 
	tTimeToNext=> );
	

*)