// Запись BOOL в бит Modbus регистра
// Возвращает TRUE при успешной записи, FALSE при ошибке (неверный индекс бита)
FUNCTION FC_ModbusWriteBool : BOOL
VAR_INPUT
    pRegisters : POINTER TO WORD;  // Указатель на массив Modbus регистров
    iRegisterIndex : INT;           // Индекс регистра
    iBitIndex : INT;                // Номер бита в регистре (0..15)
    xValue : BOOL;                  // Значение для записи
END_VAR
VAR
    wMask : WORD;
    pTargetRegister : POINTER TO WORD;
END_VAR
    // Проверка диапазона индекса бита
    IF iBitIndex >= 0 AND iBitIndex <= 15 THEN
        // Вычислить адрес целевого регистра
        pTargetRegister := pRegisters + iRegisterIndex*2;

        wMask := SHL(1, iBitIndex);  // Создать маску для бита

        IF xValue THEN
            // Установить бит (OR)
            pTargetRegister^ := pTargetRegister^ OR wMask;
        ELSE
            // Сбросить бит (AND NOT)
            pTargetRegister^ := pTargetRegister^ AND NOT wMask;
        END_IF

        FC_ModbusWriteBool := TRUE;  // Успех
    ELSE
        FC_ModbusWriteBool := FALSE;  // Ошибка: неверный индекс бита
    END_IF

END_FUNCTION