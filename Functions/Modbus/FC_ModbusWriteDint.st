// Запись DINT в 2 последовательных Modbus регистра через UNION
// Возвращает TRUE при успешной записи
// DINT (32 бита) записывается в 2 регистра (по 16 бит каждый)
FUNCTION FC_ModbusWriteDint : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Начальный индекс (записывает 2 регистра: N и N+1)
    diValue : DINT;                 // Значение для записи
END_VAR
VAR
    uConverter : U_DintToWord;
    pTargetRegister : POINTER TO WORD;
END_VAR
    // Преобразовать DINT в массив WORD
    uConverter.diTag := diValue;

    // Запись первого регистра (младшее слово)
    pTargetRegister := pRegisters + iRegisterIndex*2;
    pTargetRegister^ := uConverter.wTag[1];

    // Запись второго регистра (старшее слово)
    pTargetRegister := pTargetRegister + 2;
    pTargetRegister^ := uConverter.wTag[0];

    FC_ModbusWriteDint := TRUE;

END_FUNCTION
