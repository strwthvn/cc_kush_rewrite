// Запись REAL в 2 последовательных Modbus регистра через UNION
// Возвращает TRUE при успешной записи
// REAL (32 бита) упаковывается в 2 регистра (по 16 бит каждый)
FUNCTION FC_ModbusWriteReal : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Начальный индекс (занимает 2 регистра: N и N+1)
    rValue : REAL;                  // Значение для записи
END_VAR
VAR
    uConverter : U_RealToWord;
    pTargetRegister : POINTER TO WORD;
END_VAR
    uConverter.rTag := rValue;

    // Запись первого регистра (младшее слово)
    pTargetRegister := pRegisters + iRegisterIndex;
    pTargetRegister^ := uConverter.wTag[0];

    // Запись второго регистра (старшее слово)
    pTargetRegister := pTargetRegister + 1;
    pTargetRegister^ := uConverter.wTag[1];

    FC_ModbusWriteReal := TRUE;
END_FUNCTION
