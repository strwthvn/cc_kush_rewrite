FUNCTION FC_VFD_ChangeReadMode : BOOL
VAR_INPUT
	vfd : REFERENCE TO ST_VFD;
	mode : BOOL; // 0 - физический вход, 1 - Modbus
END_VAR
VAR
END_VAR
IF mode THEN
	vfd.rActualFrequency := vfd.uActualFrequency.rTag; // Чтение регистров ModbusRTU
ELSE
	vfd.rActualFrequency := vfd.fbActualFrequency.qrProcessedValue; // Чтение обработанного (масштабированного) аналогового сигнала с модуля
END_IF;

END_FUNCTION