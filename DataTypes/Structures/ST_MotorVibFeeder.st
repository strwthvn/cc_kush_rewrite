TYPE ST_MotorVibFeeder EXTENDS ST_MotorWithFeedback :
STRUCT
	// == Температура подшипникового узла ==
	// AI:
	nTempBearingRawSignal : ARRAY[1..2] OF INT; // Сырые коды АЦП от датчиков температуры
	rTempBearing : ARRAY[1..2] OF REAL; // Температура подшипникового узла (в °C)
	rSimulatedTempBearing : ARRAY[1..2] OF REAL; // Симулированная температура (для режима симуляции)
	eTempBearingAlarmSetPoints : E_AlarmSetpoints; // Состояния L LL H HH
	fbRangeDiagnostic : ARRAY [1..2] OF FB_RangeDiagnostic; // Проверки L LL H HH
	fbAnalogInput : ARRAY[1..2] OF FB_AnalogInput; // Аналоговые входы для двух датчиков температуры
END_STRUCT
END_TYPE
