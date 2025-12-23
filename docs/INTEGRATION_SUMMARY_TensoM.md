# Интеграция весов Tenso-M - Сводка изменений

## Обзор

Интеграция весов Tenso-M встроена непосредственно в **FB_BunkerControl**. Каждый бункер автоматически управляет своими весами через собственный экземпляр менеджера связи Tenso-M.

---

## Изменённые файлы

### 1. **ST_Bunker** (DataTypes/ST_Bunker.st)

Добавлены переменные для работы с весами:

```iecst
// Структуры данных протокола Тензо-М
stWeight : TenM_COMM.UDT_Weight;
stComplexData : TenM_COMM.UDT_ComplexData;

// Данные веса
rWeightNet_Kg : REAL;                     // Вес НЕТТО, кг
nWeightDecimalPoints : INT;
xWeightStable : BOOL;
xWeightOverload : BOOL;

// Дополнительные данные
nWeightStatusByte : BYTE;
nWeightDI_State : DINT;
nWeightDO_State : DINT;
rWeightGross_Kg : REAL;

// Состояние связи
xWeightConnected : BOOL;
xWeightError : BOOL;
nWeightErrorCode : INT;

// Команды управления
cmdZeroWeight : BOOL;
cmdResetWeightError : BOOL;
```

### 2. **FB_BunkerControl** (POUs/FB_BunkerControl.st)

#### Добавлены входные параметры:

```iecst
VAR_INPUT
    // Параметры весов Tenso-M
    xEnableWeight : BOOL := TRUE;
    iWeightPortNo : UDINT := 3;
    iWeightBaudRate : UDINT := 19200;
    iWeightDeviceAddress : BYTE := 1;
END_VAR
```

#### Добавлены внутренние переменные:

```iecst
VAR
    // Весы Tenso-M (RS-485)
    _fbTensoCommManager : TenM_COMM.CommManager;
    _uTensoCmd : TenM_COMM.CMD_LIST;
    _aTensoData : ARRAY [0..127] OF BYTE;
    _nTensoDataLength : INT := 0;
    _tonTensoTimeout : TON;
    _rtZeroWeight : R_TRIG;
    _xZeroWeightPending : BOOL := FALSE;
    _xFirstWeightDataReceived : BOOL := FALSE;
    _nWeightNoDataCounter : UINT := 0;
    _nWeightNoDataLimit : UINT := 10;
END_VAR
```

#### Добавлена обработка весов (строки 850-980):

- Настройка циклических команд (0xCA, 0xC2)
- Вызов менеджера связи Tenso-M
- Обработка данных веса НЕТТО
- Обработка комплексной посылки
- Команда обнуления веса (0xC0)
- Контроль связи с весами
- Обработка ошибок

### 3. **GLOBAL** (POUs/GLOBAL.st)

Добавлены константы для весов:

```iecst
VAR_GLOBAL RETAIN
    // ПАРАМЕТРЫ ВЕСОВ TENSO-M (RS-485)
    WEIGHT_COM_PORT : UDINT := 3;
    WEIGHT_BAUD_RATE : UDINT := 19200;
    WEIGHT_ADDRESS_BUNKER_1 : BYTE := 1;
    WEIGHT_ADDRESS_BUNKER_2 : BYTE := 2;
    WEIGHT_ADDRESS_BUNKER_3 : BYTE := 3;
    WEIGHT_ENABLE : BOOL := TRUE;
END_VAR
```

### 4. **MAIN** (POUs/MAIN.st)

Обновлены вызовы FB_BunkerControl для всех 3 бункеров:

```iecst
fbBunker[1](
    Bunker := stBunker[1],
    // ... существующие параметры ...
    // Параметры весов Tenso-M
    xEnableWeight := WEIGHT_ENABLE,
    iWeightPortNo := WEIGHT_COM_PORT,
    iWeightBaudRate := WEIGHT_BAUD_RATE,
    iWeightDeviceAddress := WEIGHT_ADDRESS_BUNKER_1,
    eStage => eBunkerStage[1],
    eStageToSCADA => eBunkerStageToSCADA[1]
);
```

---

## Как это работает

### Циклический опрос

Каждый FB_BunkerControl автоматически:

1. **Открывает COM-порт** при `xEnableWeight = TRUE`
2. **Опрашивает весы** циклически:
   - Команда `0xCA` (ComplexData_Get) - статус + DI/DO + БРУТТО
   - Команда `0xC2` (NetWeight_Get) - вес НЕТТО
3. **Преобразует данные** из протокола Тензо-М в переменные бункера
4. **Обновляет** `stBunker[i].rWeightNet_Kg`, `xWeightStable`, и т.д.

### Независимость бункеров

- У каждого бункера **свой адрес весов** в сети RS-485
- Каждый FB_BunkerControl имеет **собственный экземпляр** `_fbTensoCommManager`
- Весы работают **параллельно** и **независимо** друг от друга

### Контроль связи

- Автоматическое определение потери связи (таймаут 10 циклов без данных)
- Флаг `xWeightConnected` показывает состояние связи
- Коды ошибок в `nWeightErrorCode` (см. TenM_COMM.ERROR_LIST)

---

## Доступ к данным

### Основные данные веса

```iecst
// Вес НЕТТО в килограммах
rWeight := stBunker[1].rWeightNet_Kg;

// Флаг успокоения
IF stBunker[1].xWeightStable THEN
    // Вес стабилен
END_IF

// Флаг перегруза
IF stBunker[1].xWeightOverload THEN
    // Превышен максимальный предел
END_IF
```

### Состояние связи

```iecst
// Проверка связи
IF stBunker[1].xWeightConnected THEN
    // Связь OK
ELSE
    // Нет связи
END_IF

// Проверка ошибок
IF stBunker[1].xWeightError THEN
    nErrorCode := stBunker[1].nWeightErrorCode;
END_IF
```

### Команды управления

```iecst
// Обнуление веса (команда 0xC0)
stBunker[1].cmdZeroWeight := TRUE;

// Сброс ошибок весов
stBunker[1].cmdResetWeightError := TRUE;
```

---

## Настройка адресов весов

Адреса весов настраиваются в **GLOBAL.st**:

```iecst
WEIGHT_ADDRESS_BUNKER_1 : BYTE := 1;  // Бункер 1 → адрес 1
WEIGHT_ADDRESS_BUNKER_2 : BYTE := 2;  // Бункер 2 → адрес 2
WEIGHT_ADDRESS_BUNKER_3 : BYTE := 3;  // Бункер 3 → адрес 3
```

Для изменения адреса:
1. Откройте **GLOBAL.st**
2. Измените значение `WEIGHT_ADDRESS_BUNKER_X`
3. Пересоберите проект

---

## Отключение весов (для отладки)

### Глобальное отключение всех весов

```iecst
WEIGHT_ENABLE := FALSE;  // в GLOBAL.st
```

### Отключение весов для одного бункера

```iecst
fbBunker[1](
    // ...
    xEnableWeight := FALSE,  // Отключить только для бункера 1
    // ...
);
```

---

## Требования

### Библиотеки CODESYS

Убедитесь, что в проекте установлена библиотека **TenM_COMM**:
- Содержит `CommManager`, `UDT_Weight`, `UDT_ComplexData`
- Функции преобразования: `RawData_TO_Weight`, `RawData_TO_ComplexData`
- Перечисления: `CMD_LIST`, `ERROR_LIST`

### Подключение оборудования

- **COM-порт**: RS-485 (указан в `WEIGHT_COM_PORT`)
- **Скорость**: 19200 бод (стандарт для Тензо-М)
- **Параметры**: 8N1 (8 бит данных, без контроля чётности, 1 стоп-бит)
- **Адреса весов**: уникальные для каждого бункера (1, 2, 3)

---

## Дополнительная документация

- [EXAMPLE_TensoM_Usage.md](EXAMPLE_TensoM_Usage.md) - подробный пример использования
- [Tenso-M/Описание библиотеки.pdf](Tenso-M/Описание%20библиотеки.pdf) - протокол Тензо-М
- [Tenso-M/Example.st](Tenso-M/Example.st) - пример от производителя библиотеки

---

## Преимущества встроенной интеграции

✅ **Автоматизация** - циклический опрос без дополнительного кода
✅ **Независимость** - каждый бункер работает со своими весами
✅ **Контроль связи** - автоматическое определение потери связи
✅ **Обработка ошибок** - коды ошибок и автоматический сброс
✅ **Команды управления** - обнуление веса по команде
✅ **Полные данные** - вес, статус, DI/DO, БРУТТО
✅ **Простота настройки** - параметры в GLOBAL.st

---

**Дата интеграции**: 2025-12-23
**Версия библиотеки TenM_COMM**: Уточните у производителя
**Протокол**: Тензо-М (RS-485)
