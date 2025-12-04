// Чтение BOOL из бита Modbus регистра
// Возвращает TRUE при успешном чтении, FALSE при ошибке (неверный индекс бита)
FUNCTION FC_ModbusReadBool : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Индекс регистра
    iBitIndex : INT;                // Номер бита в регистре (0..15)
END_VAR
VAR_OUTPUT
    xValue : BOOL;                  // Прочитанное значение
END_VAR
VAR
    wMask : WORD;
    pTargetRegister : POINTER TO WORD;
END_VAR
    // Проверка диапазона индекса бита
    IF iBitIndex >= 0 AND iBitIndex <= 15 THEN
        // Вычислить адрес целевого регистра
        pTargetRegister := pRegisters + iRegisterIndex;

        // Создать маску для бита
        wMask := SHL(1, iBitIndex);

        // Прочитать бит
        xValue := (pTargetRegister^ AND wMask) <> 0;

        FC_ModbusReadBool := TRUE;  // Успех
    ELSE
        xValue := FALSE;
        FC_ModbusReadBool := FALSE;  // Ошибка: неверный индекс бита
    END_IF
END_FUNCTION
