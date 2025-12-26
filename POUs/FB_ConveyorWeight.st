FUNCTION_BLOCK FB_ConveyorWeight
VAR_INPUT
	wModbusReg : ARRAY [0..22] OF WORD;
END_VAR
VAR_OUTPUT
	qrWeight : REAL; 			//	0x0 Производительность
	qrSpeed : REAL; 			//	0x2 Скорость
	qrWorkLoad : REAL; 			//	0x4 Погонная нагрузка
	qrVoltageTenso_1 : REAL; 	//	0x6 Текущее напряжение тензодатчика 1
	qrVoltageTenso_2 : REAL; 	//	0x8 Текущее напряжение тензодатчика 2
	qrVoltageTenso_3 : REAL; 	//	0xA Текущее напряжение тензодатчика 3
	qrVoltageTenso_4 : REAL; 	//	0xC Текущее напряжение тензодатчика 4
 	qrCounterShift : REAL;		//	0xE Счётчик: смена
	qrCounterDay : REAL;		//	0xE Счётчик: смена
	qrCounterMonth : REAL;		//	0xE Счётчик: смена
	qrCounterCommon : REAL;		//	0xE Счётчик: смена
	
END_VAR
VAR
END_VAR

END_FUNCTION_BLOCK