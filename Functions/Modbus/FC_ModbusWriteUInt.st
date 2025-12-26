FUNCTION FC_ModbusWriteUInt : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Индекс регистра
    uValue : UINT;                  // Значение для записи (UINT или enumeration)
END_VAR
VAR
    pTargetRegister : POINTER TO WORD;
END_VAR
    // Вычислить адрес целевого регистра и записать значение
    pTargetRegister := pRegisters + iRegisterIndex*2;
    pTargetRegister^ := UINT_TO_WORD(uValue);
    FC_ModbusWriteUInt := TRUE;

END_FUNCTION