# Пример использования весов Tenso-M в FB_BunkerControl

## Обзор

Интеграция весов Tenso-M встроена в `FB_BunkerControl`. Каждый бункер имеет собственный экземпляр менеджера связи Tenso-M для работы с весами по протоколу RS-485.

## Настройка в MAIN.st

### 1. Определите адреса весов в GLOBAL.st

```iecst
VAR_GLOBAL CONSTANT
    // Адреса весов Tenso-M в сети RS-485
    WEIGHT_ADDRESS_BUNKER_1 : BYTE := 1;  // Адрес весов бункера 1
    WEIGHT_ADDRESS_BUNKER_2 : BYTE := 2;  // Адрес весов бункера 2
    WEIGHT_ADDRESS_BUNKER_3 : BYTE := 3;  // Адрес весов бункера 3

    // Параметры COM-порта для весов (общие для всех)
    WEIGHT_COM_PORT : UDINT := 3;          // COM3
    WEIGHT_BAUD_RATE : UDINT := 19200;     // Стандарт для Тензо-М
END_VAR
```

### 2. Вызов FB_BunkerControl с параметрами весов

```iecst
// === БУНКЕР 1 ===
fbBunker[1](
    Bunker := stBunker[1],
    xLocalMode := FALSE,
    xStart := xStartBunker1,
    xStop := xStopBunker1,
    xEmergencyStopVibFeeder := xEmergencyStop,
    xEmergencyStopVibrator := FALSE,
    xReset := stCommands.cmdResetAll.qxSignal,
    irManualFrequency := BUNKER_MANUAL_FREQUENCY,
    irManualFrequencyVibrator := VIBRATOR_MANUAL_FREQUENCY,

    // Параметры весов Tenso-M
    xEnableWeight := TRUE,                         // Включить обмен с весами
    iWeightPortNo := WEIGHT_COM_PORT,              // COM3
    iWeightBaudRate := WEIGHT_BAUD_RATE,           // 19200
    iWeightDeviceAddress := WEIGHT_ADDRESS_BUNKER_1, // Адрес 1

    eStage => eBunker1Stage,
    eStageToSCADA => eBunker1StageToSCADA
);

// === БУНКЕР 2 ===
fbBunker[2](
    Bunker := stBunker[2],
    xLocalMode := FALSE,
    xStart := xStartBunker2,
    xStop := xStopBunker2,
    xEmergencyStopVibFeeder := xEmergencyStop,
    xEmergencyStopVibrator := FALSE,
    xReset := stCommands.cmdResetAll.qxSignal,
    irManualFrequency := BUNKER_MANUAL_FREQUENCY,
    irManualFrequencyVibrator := VIBRATOR_MANUAL_FREQUENCY,

    // Параметры весов Tenso-M
    xEnableWeight := TRUE,
    iWeightPortNo := WEIGHT_COM_PORT,
    iWeightBaudRate := WEIGHT_BAUD_RATE,
    iWeightDeviceAddress := WEIGHT_ADDRESS_BUNKER_2, // Адрес 2

    eStage => eBunker2Stage,
    eStageToSCADA => eBunker2StageToSCADA
);

// === БУНКЕР 3 ===
fbBunker[3](
    Bunker := stBunker[3],
    xLocalMode := FALSE,
    xStart := xStartBunker3,
    xStop := xStopBunker3,
    xEmergencyStopVibFeeder := xEmergencyStop,
    xEmergencyStopVibrator := FALSE,
    xReset := stCommands.cmdResetAll.qxSignal,
    irManualFrequency := BUNKER_MANUAL_FREQUENCY,
    irManualFrequencyVibrator := VIBRATOR_MANUAL_FREQUENCY,

    // Параметры весов Tenso-M
    xEnableWeight := TRUE,
    iWeightPortNo := WEIGHT_COM_PORT,
    iWeightBaudRate := WEIGHT_BAUD_RATE,
    iWeightDeviceAddress := WEIGHT_ADDRESS_BUNKER_3, // Адрес 3

    eStage => eBunker3Stage,
    eStageToSCADA => eBunker3StageToSCADA
);
```

## Доступ к данным весов

После вызова `FB_BunkerControl` все данные весов доступны в структуре `ST_Bunker`:

### Основные данные веса

```iecst
// Вес НЕТТО в килограммах
rWeight_Kg := stBunker[1].rWeightNet_Kg;

// Флаг успокоения веса (TRUE = вес стабилен)
IF stBunker[1].xWeightStable THEN
    // Вес стабилизировался, можно использовать для расчётов
END_IF

// Флаг перегруза
IF stBunker[1].xWeightOverload THEN
    // Превышен максимальный предел взвешивания
END_IF

// Количество знаков после запятой (для отображения)
nDecimalPoints := stBunker[1].nWeightDecimalPoints;
```

### Дополнительные данные (комплексная посылка)

```iecst
// Байт состояния весовой системы (побитовая расшифровка по протоколу)
nStatus := stBunker[1].nWeightStatusByte;

// Состояние дискретных входов/выходов весов
nDI := stBunker[1].nWeightDI_State;
nDO := stBunker[1].nWeightDO_State;

// Вес БРУТТО в килограммах
rGrossWeight := stBunker[1].rWeightGross_Kg;
```

### Состояние связи

```iecst
// Проверка связи с весами
IF stBunker[1].xWeightConnected THEN
    // Связь с весами установлена, данные актуальны
ELSE
    // Нет связи с весами (таймаут или ошибка)
END_IF

// Проверка ошибок
IF stBunker[1].xWeightError THEN
    // Ошибка связи с весами
    nErrorCode := stBunker[1].nWeightErrorCode;
    // Коды ошибок см. в TenM_COMM.ERROR_LIST
END_IF
```

## Управление весами

### Обнуление веса (команда 0xC0)

```iecst
// Импульсная команда обнуления
stBunker[1].cmdZeroWeight := TRUE;  // Отправить команду обнуления
// Команда автоматически сбрасывается после выполнения
```

### Сброс ошибок связи с весами

```iecst
// Импульсная команда сброса ошибок
stBunker[1].cmdResetWeightError := TRUE;
// Команда автоматически сбрасывается после выполнения
```

## Использование в расчётах пропорций

```iecst
// Использование веса в расчёте пропорций (MAIN.st)
IF stBunker[1].xWeightStable AND stBunker[1].xWeightConnected THEN
    // Вес стабилен и связь есть - можно использовать для ПИД-регулятора

    // Расчёт пропорции от общего веса на конвейере
    rTotalWeight := stBunker[1].rWeightUnderBunker;
    IF rTotalWeight > 0.0 THEN
        stBunker[1].rProportionActual := stBunker[1].rWeightNet_Kg / rTotalWeight;
    END_IF
END_IF
```

## Интеграция с Modbus (SCADA)

### Чтение данных весов в SCADA

```iecst
// Запись данных весов в Modbus Input Registers (PLC → SCADA)
FC_ModbusWriteReal(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 30,  // Начальный регистр для бункера 1
    rValue := stBunker[1].rWeightNet_Kg
);

FC_ModbusWriteBool(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 32,
    iBitIndex := 0,
    xValue := stBunker[1].xWeightStable
);

FC_ModbusWriteBool(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 32,
    iBitIndex := 1,
    xValue := stBunker[1].xWeightConnected
);

FC_ModbusWriteBool(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 32,
    iBitIndex := 2,
    xValue := stBunker[1].xWeightError
);

FC_ModbusWriteInt(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 33,
    nValue := stBunker[1].nWeightErrorCode
);
```

### Команды от SCADA

```iecst
// Чтение команд обнуления из Modbus Holding Registers (SCADA → PLC)
FC_ModbusReadBool(
    pRegisters := ADR(awModbusHoldingRegisters),
    iRegisterIndex := 100,
    iBitIndex := 0,
    xValue => stBunker[1].cmdZeroWeight
);

FC_ModbusReadBool(
    pRegisters := ADR(awModbusHoldingRegisters),
    iRegisterIndex := 100,
    iBitIndex := 1,
    xValue => stBunker[1].cmdResetWeightError
);
```

## Диагностика и отладка

### Мониторинг состояния связи

```iecst
// Вывод в лог состояния весов (для отладки)
IF NOT stBunker[1].xWeightConnected THEN
    LogError('Bunker 1: Weight connection lost');
END_IF

IF stBunker[1].xWeightError THEN
    LogError('Bunker 1: Weight error code: %d', stBunker[1].nWeightErrorCode);
    // Расшифровка кодов ошибок:
    // 5001 - TIME_OUT (таймаут)
    // 5062 - WRONG_RESPONSE_ADR (неверный адрес устройства в ответе)
    // 5063 - WRONG_RESPONSE_CMD (неверная команда в ответе)
    // 5065 - WRONG_CRC (неверный CRC в ответе от устройства)
    // и т.д. (см. TenM_COMM.ERROR_LIST)
END_IF
```

### Проверка исходных данных протокола

```iecst
// Доступ к исходным структурам протокола Тензо-М (для отладки)
stWeightRaw := stBunker[1].stWeight;
stComplexDataRaw := stBunker[1].stComplexData;

// Пример: проверка байта состояния весовой системы
nStatusByte := stBunker[1].nWeightStatusByte;
// Побитовая расшифровка согласно протоколу Тензо-М
```

## Отключение весов (для тестирования без оборудования)

```iecst
// Временное отключение весов для одного бункера
fbBunker[1](
    // ... другие параметры ...
    xEnableWeight := FALSE,  // Отключить обмен с весами
    // ...
);

// При отключении:
// - COM-порт закрывается
// - Все данные веса остаются в последнем состоянии
// - xWeightConnected = FALSE
// - Счётчики сбрасываются
```

## Преимущества встроенной интеграции

✅ **Автоматическая обработка** - циклический опрос весов без дополнительного кода
✅ **Контроль связи** - автоматическое определение потери связи
✅ **Обработка ошибок** - коды ошибок и автоматический сброс
✅ **Команды управления** - обнуление веса по команде от SCADA
✅ **Полные данные** - вес НЕТТО, БРУТТО, статус, DI/DO
✅ **Независимость** - каждый бункер работает с собственными весами по уникальному адресу

## Дополнительная информация

- Протокол Тензо-М: [docs/Tenso-M/Описание библиотеки.pdf](../docs/Tenso-M/Описание%20библиотеки.pdf)
- Пример использования библиотеки: [docs/Tenso-M/Example.st](../docs/Tenso-M/Example.st)
- Библиотека TenM_COMM: установить отдельно в проект CODESYS
