// Запись TIME в 2 последовательных Modbus регистра через UNION
// Возвращает TRUE при успешной записи
// TIME (32 бита) упаковывается в 2 регистра (по 16 бит каждый)
FUNCTION FC_ModbusWriteTime : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Начальный индекс (занимает 2 регистра: N и N+1)
    tValue : TIME;                  // Значение для записи
END_VAR
VAR
    uConverter : U_TimeToWord;
    pTargetRegister : POINTER TO WORD;
END_VAR
    uConverter.tTag := tValue;

    // Запись первого регистра (младшее слово)
    pTargetRegister := pRegisters + iRegisterIndex*2;
    pTargetRegister^ := uConverter.wTag[1];

    // Запись второго регистра (старшее слово)
    pTargetRegister := pTargetRegister + 2;
    pTargetRegister^ := uConverter.wTag[0];

    FC_ModbusWriteTime := TRUE;

END_FUNCTION