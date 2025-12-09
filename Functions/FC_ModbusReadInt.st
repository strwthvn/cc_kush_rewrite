// Чтение INT из Modbus регистра
// Возвращает TRUE при успешном чтении
FUNCTION FC_ModbusReadInt : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Индекс регистра
END_VAR
VAR_OUTPUT
    iValue : INT;                   // Прочитанное значение
END_VAR
VAR
    pTargetRegister : POINTER TO WORD;
END_VAR
    // Вычислить адрес целевого регистра и прочитать значение
    pTargetRegister := pRegisters + iRegisterIndex*2;
    iValue := WORD_TO_INT(pTargetRegister^);
    FC_ModbusReadInt := TRUE;

END_FUNCTION