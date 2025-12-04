// Запись INT в Modbus регистр
// Возвращает TRUE при успешной записи
FUNCTION FC_ModbusWriteInt : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Индекс регистра
    iValue : INT;                   // Значение для записи
END_VAR
VAR
    pTargetRegister : POINTER TO WORD;
END_VAR
    // Вычислить адрес целевого регистра и записать значение
    pTargetRegister := pRegisters + iRegisterIndex;
    pTargetRegister^ := INT_TO_WORD(iValue);
    FC_ModbusWriteInt := TRUE;
END_FUNCTION
