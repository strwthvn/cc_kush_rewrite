// Чтение TIME из 2 последовательных Modbus регистров через UNION
// Возвращает TRUE при успешном чтении
// TIME (32 бита) читается из 2 регистров (по 16 бит каждый)
FUNCTION FC_ModbusReadTime : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Начальный индекс (читает 2 регистра: N и N+1)
END_VAR
VAR_OUTPUT
    tValue : TIME;                  // Прочитанное значение
END_VAR
VAR
    uConverter : U_TimeToWord;
    pTargetRegister : POINTER TO WORD;
END_VAR
    // Чтение первого регистра (младшее слово)
    pTargetRegister := pRegisters + iRegisterIndex*2;
    uConverter.wTag[1] := pTargetRegister^;

    // Чтение второго регистра (старшее слово)
    pTargetRegister := pTargetRegister + 2;
    uConverter.wTag[0] := pTargetRegister^;

    // Преобразовать в TIME
    tValue := uConverter.tTag;

    FC_ModbusReadTime := TRUE;

END_FUNCTION