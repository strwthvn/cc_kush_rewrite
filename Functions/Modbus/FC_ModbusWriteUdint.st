// Запись UDINT в 2 последовательных Modbus регистра через UNION
// Возвращает TRUE при успешной записи
// UDINT (32 бита) записывается в 2 регистра (по 16 бит каждый)
FUNCTION FC_ModbusWriteUdint : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Начальный индекс (записывает 2 регистра: N и N+1)
    udiValue : UDINT;               // Значение для записи
END_VAR
VAR
    uConverter : U_UdintToWord;
    pTargetRegister : POINTER TO WORD;
END_VAR
    // Преобразовать UDINT в массив WORD
    uConverter.udiTag := udiValue;

    // Запись первого регистра (младшее слово)
    pTargetRegister := pRegisters + iRegisterIndex*2;
    pTargetRegister^ := uConverter.wTag[1];

    // Запись второго регистра (старшее слово)
    pTargetRegister := pTargetRegister + 2;
    pTargetRegister^ := uConverter.wTag[0];

    FC_ModbusWriteUdint := TRUE;

END_FUNCTION
