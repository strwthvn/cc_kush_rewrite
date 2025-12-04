TYPE ST_CommonSignals :
STRUCT
	fbEmergencyStopBtn : FB_UniversalSignal; // Кнопка "Аварийная остановка"
	fbRemoteModeBtn : FB_UniversalSignal; // Режим работы ( 1 - дистанционный, 0 - местный)

	fbRealyCurrentControl : FB_UniversalSignal; // Реле контроля фаз

	// Состояние автомат. выключателя (1 - включен, 0 - выключен)
	fbQF1, fb9QF1, fb10QF1, fb11QF1 : FB_UniversalSignal;

	// 6KM1
	qx6KM1 : BOOL;
END_STRUCT
END_TYPE
