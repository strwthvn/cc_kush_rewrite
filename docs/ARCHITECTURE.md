# Архитектура системы управления

## Обзор проекта

Система автоматизированного управления промышленным оборудованием для дозирования материалов из бункеров на конвейер через отвалообразователь.

**Язык программирования**: IEC 61131-3 Structured Text
**Парадигма программирования**: Функциональное программирование (без ООП, без METHOD блоков)
**Целевая среда**: ПЛК (программируемый логический контроллер)

---

## Структура проекта

Проект организован в 4 основные директории:

```
newProject/
├── POUs/              # Program Organization Units - основные программы
├── DataTypes/         # Типы данных (структуры и перечисления)
├── Functions/         # Чистые функции для проверок и расчетов
└── Library/           # Универсальные функциональные блоки
```

---

## 1. POUs/ - Основные программы

### 1.1 MAIN.st
Главная программа с автоматом последовательного запуска оборудования.

**Стадии автоматического режима:**
```
IDLE              → Ожидание задания пропорций от оператора
INIT              → Расчет производительности вибропитателей
START_DUMPER      → Запуск отвалообразователя
START_CONV        → Запуск конвейера
START_VIBFEEDER   → Последовательный запуск бункеров 1→2→3
WORK              → Рабочий режим с ПИД-регулированием пропорций
END_REPORT        → Формирование отчета и остановка
ERROR             → Аварийная остановка с ожиданием сброса
```

**Основное оборудование:**
- **3 бункера** (`stBunker[1..3]`) с вибропитателями
- **Отвалообразователь** (`stDumper`) с конвейером и поворотным механизмом
- **Сборный конвейер** (`stConveyor`)

**Управление:**
- Последовательный запуск секций через флаги `xStartDumper`, `xStartConveyor`, `xStartBunker[1..3]`
- Контроль стадий через `eDumperStage`, `eConveyorStage`, `eBunkerStage[1..3]`
- ПИД-регулирование пропорций через `fbProportionPid`

### 1.2 FB_BunkerControl.st
Управление бункером с вибропитателями.

**Основные функции:**
- Запуск/остановка вибропитателей (2 шт. на бункер)
- Контроль температуры подшипников через аналоговые входы
- Контроль тока двигателей через диагностику диапазонов
- Управление вибраторами (4 шт.) и пневмообрушением
- Светофорная сигнализация состояния бункера

**Автомат состояний:**
```
IDLE      → Сброс частот, ожидание команды xStart
STARTING  → Запуск контакторов и ЧРП, выход на стартовую частоту
WORK      → Управление частотой от ПИД-регулятора (MAIN.st)
ERROR     → Остановка с ожиданием сброса ошибки
```

### 1.3 FB_DumperControl.st
Управление отвалообразователем с конвейером и поворотным механизмом.

**Основные функции:**
- Синхронный запуск двух моторов конвейера (22 кВт каждый)
- Контроль синхронизации частот с допуском `VFD_FREQUENCY_SYNC_TOLERANCE`
- Управление двумя моторами поворота (3 кВт каждый)
- Предпусковая сигнализация (опциональная)
- Контроль датчиков безопасности (ZQ, HQ, SQ, GS, YS)

**Особенности:**
- Плавный разгон с контролем синхронизации моторов
- Условие `xConditionToProceed = xVFDsReady AND xFrequenciesSynchronized`
- Разгон продолжается только при синхронизации частот

### 1.4 FB_ConveyorControl.st
Управление сборным конвейером (аналогично FB_DumperControl).

### 1.5 Вспомогательные блоки
- **FB_EmergencyStopProcess** - обработка аварийного останова
- **FB_VibratorControl** - циклическое управление вибраторами
- **FB_PneumoCollapseControl** - циклическое пневмообрушение
- **FB_Simulation** - симуляция работы оборудования
- **FB_FrequencySimulation** - симуляция частоты ЧРП

---

## 2. DataTypes/ - Типы данных

### 2.1 Структуры оборудования

#### ST_Motor
Базовая структура двигателя с контактором и ЧРП.

```iecst
TYPE ST_Motor :
STRUCT
    VFD : ST_VFD;                      // ЧРП
    fbStateKM : FB_UniversalSignal;    // Состояние контактора
    qxKM_Power : BOOL;                 // Управление контактором
    fbStateQF : FB_UniversalSignal;    // Состояние автомат. выключателя
    Device : FB_UniversalMechanism;    // Универсальный механизм
    StateRemote : E_StateRemote;       // Режим управления
END_STRUCT
END_TYPE
```

#### ST_MotorWithFeedback
Двигатель с обратной связью (расширяет ST_Motor).

#### ST_MotorWithReverse
Двигатель с реверсом (для поворотных механизмов).

#### ST_MotorVibFeeder
Вибропитатель с датчиками температуры подшипников.

```iecst
TYPE ST_MotorVibFeeder :
STRUCT
    VFD : ST_VFD;
    rTempBearing : ARRAY[1..2] OF REAL;         // Температура подшипников
    nTempBearingRawSignal : ARRAY[1..2] OF INT; // Сырой сигнал АЦП
    fbRangeDiagnostic : ARRAY[1..2] OF FB_RangeDiagnostic;
    fbAnalogInput : ARRAY[1..2] OF FB_AnalogInput;
    // ... остальные поля
END_STRUCT
END_TYPE
```

#### ST_VFD
Частотно-регулируемый привод (ЧРП).

```iecst
TYPE ST_VFD :
STRUCT
    // Дискретные входы
    fbStateRdyToStart : FB_UniversalSignal;  // Готов к пуску
    fbStateIsWorking : FB_UniversalSignal;   // В работе
    fbStateFailure : FB_UniversalSignal;     // Ошибка

    // Аналоговые сигналы
    nActualFrequencyADC : INT;               // Код АЦП текущей частоты
    nSetOutSignalToModule : INT;             // Код ЦАП выходной частоты

    // Команды
    qxStart : BOOL;                          // Пуск ЧРП
    qrOutFrequency : REAL;                   // Выходная частота (Гц)

    // Функциональные блоки
    Device : FB_UniversalMechanism;          // Механизм управления
    Frequency : FB_FrequencyControl;         // Плавное изменение частоты
    fbRangeDiagnostic : FB_RangeDiagnostic;  // Диагностика тока
    fbAnalogInput : FB_AnalogInput;          // Вход (4-20 мА → Гц)
    fbAnalogOutput : FB_AnalogOutput;        // Выход (Гц → 4-20 мА)

    rActualFrequency : REAL;                 // Текущая частота
END_STRUCT
END_TYPE
```

#### ST_Bunker
Бункер с вибропитателями, вибраторами и весовым контролем.

```iecst
TYPE ST_Bunker :
STRUCT
    MotorVibrator : ARRAY[1..4] OF ST_Motor;           // Вибраторы
    MotorVibFeeder : ARRAY[1..2] OF ST_MotorVibFeeder; // Вибропитатели

    rWeight : REAL;                       // Вес в бункере
    rWeightUnderBunker : REAL;            // Кумулятивный вес на конвейере
    rProportionActual : REAL;             // Фактическая пропорция
    rMotorVibFeederCommonFrequency : REAL; // Общая частота вибропитателей

    fbStateHatch : FB_UniversalSignal;    // Положение люка
    qxLightRed, qxLightYellow, qxLightGreen : BOOL; // Светофор
    eLightColor : E_LightColor;           // Текущий цвет

    xStateWarning : BOOL;                 // Предупреждение
    xStateFailure : BOOL;                 // Ошибка
END_STRUCT
END_TYPE
```

#### ST_ConveyorBasic
Базовая структура конвейера.

```iecst
TYPE ST_ConveyorBasic :
STRUCT
    MotorConveyor : ARRAY[1..2] OF ST_MotorWithFeedback;

    // Датчики безопасности (1 - норма, 0 - тревога/предупреждение)
    fbZQAlarm : ARRAY[1..4] OF FB_UniversalSignal;    // Контроль схода ленты
    fbZQWarning : ARRAY[1..4] OF FB_UniversalSignal;  // Предупреждение схода
    fbHQ_IsOk : ARRAY[1..4] OF FB_UniversalSignal;    // Кабель-трос
    fbSQ_IsOk : ARRAY[1..2] OF FB_UniversalSignal;    // Ограждения
    fbGS1 : FB_UniversalSignal;                       // Заштыбовка
    fbQR : ARRAY[1..2] OF FB_UniversalSignal;         // Датчики скорости
    fbYS1 : FB_UniversalSignal;                       // Продольный разрыв

    xHLA : BOOL;                          // Световая сигнализация
    xSoundAlarm : BOOL;                   // Звуковая сигнализация
END_STRUCT
END_TYPE
```

#### ST_Dumper
Отвалообразователь (расширяет ST_ConveyorBasic).

```iecst
TYPE ST_Dumper EXTENDS ST_ConveyorBasic :
STRUCT
    MotorRotation : ARRAY[1..2] OF ST_MotorWithReverse; // Поворот
    fbEndSwitchRight, fbEndSwitchLeft : FB_UniversalSignal;

    // ПМУ (пульт местного управления)
    fbBtnStart, fbBtnStop, fbBtnEmergencyStop : FB_UniversalSignal;
    fbBtnTurnLeft, fbBtnTurnRight : FB_UniversalSignal;
    fbBtnRemoteMode : FB_UniversalSignal;

    // Состояния
    xStateWarning : BOOL;
    xStateFailure : BOOL;
    xStateEnable : BOOL;      // Полностью запущен
    xStateStarting : BOOL;    // Процесс запуска

    fbPreStartAlarm : FB_PreStartAlarm;
END_STRUCT
END_TYPE
```

#### ST_ConveyorPrefabricated
Сборный конвейер (расширяет ST_ConveyorBasic, аналогичен ST_Dumper).

### 2.2 Перечисления

#### E_StateFeedback
Состояния обратной связи механизма.

```iecst
TYPE E_StateFeedback :
(
    Inactive                  := 0,  // Неактивен (норма при остановке)
    Active                    := 1,  // Активен (норма при работе)
    Error_NoFeedback          := 2,  // Нет обратной связи при питании
    Error_UnexpectedFeedback  := 3   // Обратная связь без питания
);
END_TYPE
```

#### E_StageWithPreStartAlarm
Стадии запуска с предпусковой сигнализацией.

```iecst
TYPE E_StageWithPreStartAlarm :
(
    IDLE,             // Ожидание
    PRESTART_ALARM,   // Предпусковая сигнализация
    STARTING,         // Запуск
    WORK,             // Работа
    ERROR             // Ошибка
);
END_TYPE
```

#### E_StateRemote
Режимы управления.

```iecst
TYPE E_StateRemote :
(
    Manual    := 0,   // Местный (ПМУ)
    Remote    := 1,   // Дистанционный (SCADA)
    Automatic := 2    // Автоматический
);
END_TYPE
```

#### E_ScadaStatesDevice
Состояния для передачи в SCADA.

```iecst
TYPE E_ScadaStatesDevice :
(
    NOT_READY,          // Не готов к пуску (есть ошибки)
    READY,              // Готов к пуску
    STARTING,           // Процесс запуска
    WORK,               // Работа (норма)
    WORK_WITH_WARNING,  // Работа с предупреждением
    WORK_WITH_ERROR,    // Работа с ошибкой
    WARNING,            // Предупреждение без работы
    ERROR               // Ошибка
);
END_TYPE
```

#### E_LightColor
Цвета светофора бункера.

```iecst
TYPE E_LightColor :
(
    OFF    := 0,  // Выключен
    RED    := 1,  // Красный (ошибка)
    YELLOW := 2,  // Желтый (предупреждение)
    GREEN  := 3   // Зеленый (норма)
);
END_TYPE
```

### 2.3 Объединения (Unions)

#### U_RealToWord
Конвертация REAL ↔ 2×WORD для Modbus.

```iecst
TYPE U_RealToWord :
UNION
    rTag : REAL;
    wTag : ARRAY[0..1] OF WORD;
END_UNION
END_TYPE
```

---

## 3. Functions/ - Чистые функции

Все функции начинаются с префикса `FC_` и являются чистыми (без побочных эффектов).

### 3.1 Функции проверки бункеров

#### FC_Bunker_GetErrorBunker
Проверка базовых ошибок бункера (люк открыт, вес недостаточен).

#### FC_Bunker_GetErrorMotorVibFeeder
Проверка ошибок вибропитателей (QF, KM, ЧРП, перегрев, температура, ток).

#### FC_Bunker_GetErrorMotorVibrator
Проверка ошибок вибраторов (QF, KM, ЧРП).

#### FC_Bunker_GetErrorWeight
Проверка ошибок весового тракта.

#### FC_Bunker_CheckWeight
Проверка достаточности веса в бункере.

#### FC_Bunker_SetLightColor
Расчет цвета светофора на основе состояний.

```iecst
FUNCTION FC_Bunker_SetLightColor : E_LightColor
VAR_INPUT
    xStateFailure : BOOL;
    xStateWarning : BOOL;
    xStateEnable : BOOL;
END_VAR

    IF xStateFailure THEN
        FC_Bunker_SetLightColor := E_LightColor.RED;
    ELSIF xStateWarning THEN
        FC_Bunker_SetLightColor := E_LightColor.YELLOW;
    ELSIF xStateEnable THEN
        FC_Bunker_SetLightColor := E_LightColor.GREEN;
    ELSE
        FC_Bunker_SetLightColor := E_LightColor.OFF;
    END_IF
END_FUNCTION
```

### 3.2 Функции проверки конвейеров

#### FC_Conveyor_GetErrorMotor
Проверка ошибок двигателей конвейера.

```iecst
FUNCTION FC_Conveyor_GetErrorMotor : BOOL
VAR_INPUT
    Motor : REFERENCE TO ST_Motor;
END_VAR

    FC_Conveyor_GetErrorMotor :=
        NOT Motor.fbStateQF.qxSignal              // QF отключен
        OR Motor.Device.qxError_NoFeedback        // Нет обратной связи
        OR Motor.VFD.fbStateFailure.qxSignal;     // Ошибка ЧРП
END_FUNCTION
```

#### FC_Conveyor_GetErrorSensors
Проверка датчиков безопасности конвейера.

```iecst
FUNCTION FC_Conveyor_GetErrorSensors : BOOL
VAR_INPUT
    Conveyor : REFERENCE TO ST_ConveyorBasic;
END_VAR

    FC_Conveyor_GetErrorSensors :=
        NOT Conveyor.fbZQAlarm[1].qxSignal        // Сход ленты
        OR NOT Conveyor.fbZQAlarm[2].qxSignal
        OR NOT Conveyor.fbZQAlarm[3].qxSignal
        OR NOT Conveyor.fbZQAlarm[4].qxSignal
        OR NOT Conveyor.fbHQ_IsOk[1].qxSignal     // Кабель-трос
        OR NOT Conveyor.fbHQ_IsOk[2].qxSignal
        OR NOT Conveyor.fbHQ_IsOk[3].qxSignal
        OR NOT Conveyor.fbHQ_IsOk[4].qxSignal
        OR NOT Conveyor.fbSQ_IsOk[1].qxSignal     // Ограждения
        OR NOT Conveyor.fbSQ_IsOk[2].qxSignal
        OR NOT Conveyor.fbGS1.qxSignal            // Заштыбовка
        OR NOT Conveyor.fbYS1.qxSignal;           // Разрыв ленты
END_FUNCTION
```

#### FC_Conveyor_GetErrorCommon
Агрегация всех ошибок конвейера (моторы + датчики).

### 3.3 Функции проверки отвалообразователя

#### FC_Dumper_GetErrorSensors
Проверка датчиков отвалообразователя.

#### FC_Dumper_GetErrorCommon
Агрегация всех ошибок отвалообразователя.

```iecst
FUNCTION FC_Dumper_GetErrorCommon : BOOL
VAR_INPUT
    Dumper : REFERENCE TO ST_Dumper;
END_VAR

    FC_Dumper_GetErrorCommon :=
        FC_Conveyor_GetErrorMotor(Motor := Dumper.MotorConveyor[1])
        OR FC_Conveyor_GetErrorMotor(Motor := Dumper.MotorConveyor[2])
        OR FC_Conveyor_GetErrorMotor(Motor := Dumper.MotorRotation[1])
        OR FC_Conveyor_GetErrorMotor(Motor := Dumper.MotorRotation[2])
        OR FC_Dumper_GetErrorSensors(Dumper := Dumper);
END_FUNCTION
```

### 3.4 Общие функции

#### FC_Get_ErrorCommon
Агрегация всех ошибок системы (3 бункера + конвейер + отвалообразователь).

```iecst
FUNCTION FC_Get_ErrorCommon : BOOL
VAR_INPUT
    Bunker1 : REFERENCE TO ST_Bunker;
    Bunker2 : REFERENCE TO ST_Bunker;
    Bunker3 : REFERENCE TO ST_Bunker;
    Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
    Dumper : REFERENCE TO ST_Dumper;
END_VAR

    FC_Get_ErrorCommon :=
        FC_Bunker_GetErrorBunker(Bunker := Bunker1)
        OR FC_Bunker_GetErrorBunker(Bunker := Bunker2)
        OR FC_Bunker_GetErrorBunker(Bunker := Bunker3)
        OR FC_Conveyor_GetErrorCommon(Conveyor := Conveyor)
        OR FC_Dumper_GetErrorCommon(Dumper := Dumper);
END_FUNCTION
```

#### FC_MotorSyncronizedWork
Проверка синхронизации двух моторов.

#### FC_VFD_ChangeReadMode
Переключение режима чтения Modbus для ЧРП.

### 3.5 Утилиты

#### FC_SwapBytesInWord
Обмен байтов в слове (для порядка байтов Modbus).

#### FC_SwapBytesInWordArray
Обмен байтов в массиве слов.

#### FC_SwapWordArrayElements
Перестановка элементов массива слов.

---

## 4. Library/ - Универсальные функциональные блоки

Ядро функциональной библиотеки. Все блоки используют паттерн **"enable flags"** для активации опциональных функций.

### 4.1 FB_UniversalSignal
Универсальная обработка дискретных сигналов.

**Опциональные функции (через enable flags):**
- `xEnableRattlingFilter` - фильтрация дребезга контактов
- `xEnableFeedback` - отслеживание обратной связи
- `xEnableFeedbackTimer` - таймаут обратной связи

```iecst
FUNCTION_BLOCK FB_UniversalSignal
VAR_INPUT
    ixSignal : BOOL;                         // Входной сигнал
    ixFeedback : BOOL;                       // Обратная связь
    itFeedbackTimeout : TIME := T#5S;        // Таймаут обратной связи
    xEnableFeedback : BOOL := FALSE;         // Включить обратную связь
    xEnableFeedbackTimer : BOOL := FALSE;    // Включить таймер
    xEnableRattlingFilter : BOOL := FALSE;   // Включить фильтр дребезга
    tStabilityTime : TIME := T#100MS;        // Время стабилизации
    nMaxTransitions : UINT := 5;             // Макс. переходов для дребезга
    tDetectionWindow : TIME := T#200MS;      // Окно детекции
END_VAR
VAR_OUTPUT
    qxSignal : BOOL;                         // Обработанный сигнал
    qxInvertedSignal : BOOL;                 // Инверсия
    qxRisingEdge : BOOL;                     // Передний фронт
    qxFallingEdge : BOOL;                    // Задний фронт
    qxWaitingFeedback : BOOL;                // Ожидание обратной связи
    qxFeedbackReceived : BOOL;               // Обратная связь получена
    qxFeedbackTimeout : BOOL;                // Таймаут обратной связи
    qxRattlingDetected : BOOL;               // Дребезг обнаружен
    qnTransitionCount : UINT;                // Счетчик переходов
END_VAR
```

**Примеры использования:**

```iecst
// 1. Базовый сигнал (только edge detection)
Signal(ixSignal := I_Input);

// 2. Сигнал с фильтром дребезга
Signal(
    ixSignal := I_ContactorFeedback,
    xEnableRattlingFilter := TRUE,
    tStabilityTime := T#100MS
);

// 3. Команда с отслеживанием обратной связи
Signal(
    ixSignal := I_StartCommand,
    ixFeedback := I_MotorRunning,
    xEnableFeedback := TRUE,
    xEnableFeedbackTimer := TRUE,
    itFeedbackTimeout := T#5S
);
```

### 4.2 FB_UniversalMechanism
Универсальное управление механизмом с обратной связью.

**Основные функции:**
- Управление питанием механизма
- Отслеживание состояния обратной связи
- Обнаружение ошибок обратной связи

```iecst
FUNCTION_BLOCK FB_UniversalMechanism
VAR_INPUT
    ixFeedback : BOOL;                       // Обратная связь
    xEnableFeedback : BOOL := FALSE;         // Включить отслеживание
    xStartCommand : BOOL;                    // Команда запуска
    xStopCommand : BOOL;                     // Команда останова
    xStartCondition : BOOL := TRUE;          // Условие запуска
    xStopCondition : BOOL := TRUE;           // Условие останова
    xReset : BOOL;                           // Принудительный сброс
END_VAR
VAR_OUTPUT
    qxPower : BOOL;                          // Состояние питания
    quFeedbackState : E_StateFeedback;       // Состояние обратной связи
    qxActive : BOOL;                         // Механизм активен
    qxInactive : BOOL;                       // Механизм неактивен
    qxError_NoFeedback : BOOL;               // Ошибка: нет обратной связи
    qxError_UnexpectedFeedback : BOOL;       // Ошибка: неожиданная связь
    qxHasError : BOOL;                       // Есть любая ошибка
END_VAR
```

**Примеры использования:**

```iecst
// Управление контактором с обратной связью
Motor.Device(
    ixFeedback := Motor.fbStateKM.qxSignal,
    xEnableFeedback := TRUE,
    xStartCommand := StartBtn.qxRisingEdge,
    xStopCommand := StopBtn.qxRisingEdge OR EmergencyStop,
    xStartCondition := Motor.fbStateQF.qxSignal AND NOT HasErrors,
    xReset := ResetButton
);
Motor.qxKM_Power := Motor.Device.qxPower;

// Проверка ошибок
IF Motor.Device.qxError_NoFeedback THEN
    // Обработка отсутствия обратной связи
END_IF
```

### 4.3 FB_FrequencyControl
Плавное управление частотой ЧРП.

**Основные функции:**
- Плавное изменение частоты с заданным шагом
- Ограничение максимальной частоты
- Условие продолжения разгона (для синхронизации моторов)

```iecst
FUNCTION_BLOCK FB_FrequencyControl
VAR_INPUT
    irMaxFrequency : REAL := 100.0;          // Максимальная частота
    irStep : REAL := 1.0;                    // Шаг изменения (Гц)
    rTargetFrequency : REAL := 0.0;          // Целевая частота
    xPulse : BOOL;                           // Импульс для изменения
    xConditionToProceed : BOOL := TRUE;      // Условие продолжения
    xReset : BOOL;                           // Сброс в ноль
    xHold : BOOL;                            // Удержание текущей
END_VAR
VAR_OUTPUT
    qrCurrentFrequency : REAL;               // Текущая частота
    qrTargetFrequency : REAL;                // Целевая частота
    qxTargetReached : BOOL;                  // Цель достигнута
END_VAR
```

**Примеры использования:**

```iecst
// Плавный разгон с синхронизацией двух моторов
Motor1.VFD.Frequency(
    irMaxFrequency := 50.0,
    irStep := 2.0,
    rTargetFrequency := 50.0,
    xPulse := PULSE_RTRIG.Q,                // Импульс каждые 200 мс
    xConditionToProceed := Motors_Synchronized // Ждем синхронизации
);
Motor1.VFD.qrOutFrequency := Motor1.VFD.Frequency.qrCurrentFrequency;

// Проверка синхронизации
Motors_Synchronized := ABS(Motor1.VFD.rActualFrequency
                          - Motor2.VFD.rActualFrequency) < 1.5;
```

### 4.4 FB_RangeDiagnostic
Диагностика аналоговых значений с уставками LL/L/H/HH.

**Основные функции:**
- 4-уровневая диагностика (LL, L, H, HH)
- Раздельные флаги для предупреждений и аварий
- Гистерезис для предотвращения дребезга

```iecst
FUNCTION_BLOCK FB_RangeDiagnostic
VAR_INPUT
    irValue : REAL;                          // Текущее значение
    irSetpointLL : REAL;                     // Уставка LL (авария низкий)
    irSetpointL : REAL;                      // Уставка L (предупреждение)
    irSetpointH : REAL;                      // Уставка H (предупреждение)
    irSetpointHH : REAL;                     // Уставка HH (авария высокий)
    ixEnable : BOOL := TRUE;                 // Включить диагностику
END_VAR
VAR_OUTPUT
    qxAlarmLL : BOOL;                        // Авария LL
    qxWarningL : BOOL;                       // Предупреждение L
    qxWarningH : BOOL;                       // Предупреждение H
    qxAlarmHH : BOOL;                        // Авария HH
    qxAlarmActive : BOOL;                    // Любая авария
    qxWarningActive : BOOL;                  // Любое предупреждение
END_VAR
```

**Примеры использования:**

```iecst
// Контроль температуры подшипника
Motor.fbRangeDiagnostic(
    irValue := Motor.rTempBearing,
    irSetpointLL := -1.0,      // Обрыв датчика
    irSetpointL := 60.0,       // Предупреждение
    irSetpointH := 80.0,       // Предупреждение
    irSetpointHH := 90.0,      // Авария
    ixEnable := TRUE
);

IF Motor.fbRangeDiagnostic.qxAlarmHH THEN
    // Аварийная остановка
ELSIF Motor.fbRangeDiagnostic.qxWarningH THEN
    // Предупреждение оператору
END_IF
```

### 4.5 FB_AnalogInput
Преобразование аналогового входа 4-20 мА в инженерные единицы.

**Основные функции:**
- Масштабирование АЦП → физическая величина
- Поддержка режима 4-20 мА с диагностикой
- Симуляция для отладки

```iecst
FUNCTION_BLOCK FB_AnalogInput
VAR_INPUT
    xSimulation : BOOL := FALSE;             // Режим симуляции
    iADC_Code : INT;                         // Код АЦП модуля
    refSimValue : REFERENCE TO REAL;         // Симулируемое значение
    refEngValue : REFERENCE TO REAL;         // Инженерная величина
    rAlarm_LL : REAL;                        // Уставка LL (обрыв)
    rAlarm_L : REAL;                         // Уставка L
    rAlarm_H : REAL;                         // Уставка H
    rAlarm_HH : REAL;                        // Уставка HH (КЗ)
    iADC_Max : INT := 27648;                 // Максимальный код АЦП
    iADC_Min : INT := 0;                     // Минимальный код АЦП
    rEngValue_Max : REAL := 100.0;           // Максимум шкалы
    rEngValue_Min : REAL := 0.0;             // Минимум шкалы
    rCurrent_Max : REAL := 20.0;             // 20 мА
    rCurrent_Min : REAL := 4.0;              // 4 мА
END_VAR
VAR_OUTPUT
    qrEngValue : REAL;                       // Выходное значение
    qxAlarm_LL : BOOL;                       // Обрыв линии
    qxAlarm_HH : BOOL;                       // КЗ линии
END_VAR
```

### 4.6 FB_AnalogOutput
Преобразование инженерных единиц в аналоговый выход 4-20 мА.

```iecst
FUNCTION_BLOCK FB_AnalogOutput
VAR_INPUT
    xEnable : BOOL;                          // Разрешение выхода
    rEngValue : REAL;                        // Инженерная величина
    rEngValue_Max : REAL := 100.0;           // Максимум шкалы
    rEngValue_Min : REAL := 0.0;             // Минимум шкалы
    rCurrent_Max : REAL := 20.0;             // 20 мА
    rCurrent_Min : REAL := 4.0;              // 4 мА
    iDAC_Max : INT := 27648;                 // Максимальный код ЦАП
    iDAC_Min : INT := 0;                     // Минимальный код ЦАП
    xEnableClamp : BOOL := TRUE;             // Зажать в пределах
END_VAR
VAR_OUTPUT
    iDAC_Code : INT;                         // Код ЦАП для модуля
    qrCurrent : REAL;                        // Текущий ток (мА)
END_VAR
```

### 4.7 FB_PreStartAlarm
Предпусковая звуковая сигнализация.

**Основные функции:**
- Двухэтапная сигнализация (первый сигнал → пауза → второй сигнал → пауза → завершение)
- Прерывание по команде `ixStop`

```iecst
FUNCTION_BLOCK FB_PreStartAlarm
VAR_INPUT
    ixStart : BOOL;                          // Команда запуска
    ixStop : BOOL;                           // Команда прерывания
    itFirstSignal : TIME := T#3S;            // Длительность 1-го сигнала
    itPauseAfterFirst : TIME := T#3S;        // Пауза после 1-го
    itSecondSignal : TIME := T#3S;           // Длительность 2-го сигнала
    itPauseAfterSecond : TIME := T#3S;       // Пауза после 2-го
END_VAR
VAR_OUTPUT
    qxAlarmPower : BOOL;                     // Выход на сирену
    qxComplete : BOOL;                       // Последовательность завершена
END_VAR
```

### 4.8 FB_ProportionPID
ПИД-регулятор пропорций бункеров.

**Основные функции:**
- Трехканальный ПИД-регулятор (по одному на бункер)
- Автоматическая нормализация пропорций
- Масштабирование частот с ограничениями
- Anti-windup для интеграла

```iecst
FUNCTION_BLOCK FB_ProportionPID
VAR_INPUT
    xEnable : BOOL;                          // Разрешение работы
    xReset : BOOL;                           // Сброс интеграла

    rProportionTarget_1 : REAL;              // Целевая пропорция 1
    rProportionTarget_2 : REAL;              // Целевая пропорция 2
    rProportionTarget_3 : REAL;              // Целевая пропорция 3

    rProportionActual_1 : REAL;              // Фактическая пропорция 1
    rProportionActual_2 : REAL;              // Фактическая пропорция 2
    rProportionActual_3 : REAL;              // Фактическая пропорция 3

    rPID_Kp : REAL := 1.0;                   // Пропорциональный коэф.
    rPID_Ki : REAL := 0.2;                   // Интегральный коэф.
    rPID_Kd : REAL := 0.05;                  // Дифференциальный коэф.
    rPID_IntegralLimit : REAL := 10.0;       // Ограничение интеграла

    rFrequency_Min : REAL := 1.0;            // Минимум частоты (Гц)
    rFrequency_Max : REAL := 35.0;           // Максимум частоты (Гц)
    rFrequency_TargetSum : REAL := 90.0;     // Целевая сумма частот

    rDeltaTime : REAL := 0.1;                // Период вызова (сек)
END_VAR
VAR_OUTPUT
    qrFrequency_1 : REAL;                    // Частота бункера 1
    qrFrequency_2 : REAL;                    // Частота бункера 2
    qrFrequency_3 : REAL;                    // Частота бункера 3

    qxActive : BOOL;                         // Блок активен
    qxError : BOOL;                          // Ошибка
    quErrorCode : UINT;                      // Код ошибки

    qrFrequency_Sum : REAL;                  // Фактическая сумма частот
    qrProportionSum : REAL;                  // Сумма пропорций
    qxProportionNormalized : BOOL;           // Пропорции нормализованы
END_VAR
```

### 4.9 FB_NumericChangeDetector
Детектор изменения числового значения.

```iecst
FUNCTION_BLOCK FB_NumericChangeDetector
VAR_INPUT
    irValue : REAL;                          // Отслеживаемое значение
    irThreshold : REAL := 0.01;              // Порог изменения
END_VAR
VAR_OUTPUT
    qxChanged : BOOL;                        // Значение изменилось
    qrPreviousValue : REAL;                  // Предыдущее значение
END_VAR
```

---

## 5. Принципы архитектуры

### 5.1 Функциональное программирование

**НЕТ ООП:**
- ❌ Нет METHOD блоков внутри FUNCTION_BLOCK
- ❌ Нет наследования с методами
- ❌ Нет getter/setter методов

**ЕСТЬ функциональный подход:**
- ✅ Все логика inline внутри FUNCTION_BLOCK
- ✅ Прямой доступ к выходам (qxPower, qrFrequency)
- ✅ Конфигурация через VAR_INPUT параметры
- ✅ Enable flags для опциональных функций

### 5.2 Паттерн Enable Flags

Универсальные блоки используют флаги для активации функций:

```iecst
// Пример: FB_UniversalSignal
xEnableRattlingFilter := TRUE;    // Включить фильтр дребезга
xEnableFeedback := TRUE;          // Включить обратную связь
xEnableFeedbackTimer := TRUE;     // Включить таймер обратной связи
```

**Преимущества:**
- Один блок вместо нескольких специализированных
- Гибкая конфигурация без изменения кода
- Меньше дублирования кода

### 5.3 Прямой доступ к выходам

```iecst
// СТАРЫЙ ООП подход (НЕ ИСПОЛЬЗУЕТСЯ):
xPower := Motor.Device.GetPower();

// НОВЫЙ функциональный подход:
Motor.Device(
    xStartCommand := Button,
    xStartCondition := Ready
);
xPower := Motor.Device.qxPower;  // Прямой доступ
```

### 5.4 Чистые функции для проверок

Все функции проверок (FC_*) являются чистыми:
- Нет побочных эффектов
- Нет изменения состояния
- Только чтение параметров через REFERENCE TO
- Возвращают BOOL результат

```iecst
// Чистая функция агрегации ошибок
xError := FC_Get_ErrorCommon(
    Bunker1 := stBunker[1],
    Bunker2 := stBunker[2],
    Bunker3 := stBunker[3],
    Conveyor := stConveyor,
    Dumper := stDumper
);
```

### 5.5 Паттерн управления через флаги

Управление секциями через простые BOOL флаги:

```iecst
// В MAIN.st
xStartDumper := TRUE;              // Установить команду
fbDumper(
    Dumper := stDumper,
    xStart := xStartDumper,
    eStage => eDumperStage         // Получить стадию
);

// Проверка завершения
IF eDumperStage = E_StageWithPreStartAlarm.WORK THEN
    xStartDumper := FALSE;         // Сбросить команду
    AUTO_STEP := START_CONV;       // Следующий шаг
END_IF
```

### 5.6 Автоматы состояний (State Machines)

Все управляющие блоки используют `CASE OF` автоматы:

```iecst
CASE STAGE OF
    IDLE:
        // Ожидание команды запуска
        IF xStart THEN
            STAGE := STARTING;
        END_IF

    STARTING:
        // Запуск оборудования
        Motor.Device.xStartCommand := TRUE;
        IF Motor.Device.qxActive THEN
            STAGE := WORK;
        END_IF

    WORK:
        // Рабочий режим
        IF xStop THEN
            Motor.Device.xStopCommand := TRUE;
            STAGE := IDLE;
        END_IF

    ERROR:
        // Обработка ошибок
        IF xReset AND NOT HasErrors THEN
            STAGE := IDLE;
        END_IF
END_CASE
```

---

## 6. Алгоритм работы системы

### 6.1 Последовательность запуска (MAIN.st)

```
1. IDLE
   ├─ Оператор задает пропорции BUNKER_WORK_PRECENT_1/2/3
   ├─ Проверка: сумма = 100%, не более 1 бункера с нулевой пропорцией
   ├─ Проверка: xStateErrorCheckReady = TRUE (нет ошибок)
   └─ Команда: cmdStartCommon → переход в INIT

2. INIT
   └─ Расчет начальных частот вибропитателей → START_DUMPER

3. START_DUMPER
   ├─ Установка xStartDumper := TRUE
   ├─ fbDumper запускает:
   │  ├─ PRESTART_ALARM (если включена)
   │  ├─ STARTING: запуск контакторов и ЧРП
   │  └─ WORK: разгон до целевой частоты
   └─ Переход в START_CONV при eDumperStage = WORK

4. START_CONV
   ├─ Установка xStartConveyor := TRUE
   ├─ fbConveyor запускает аналогично fbDumper
   └─ Переход в START_VIBFEEDER при eConveyorStage = WORK

5. START_VIBFEEDER
   ├─ Последовательный запуск бункеров: 1 → 2 → 3
   ├─ Пропуск бункеров с BUNKER_WORK_PRECENT = 0
   └─ Переход в WORK когда все активные бункеры запущены

6. WORK
   ├─ Расчет фактических пропорций из весов:
   │  ├─ rWeight1 = stBunker[1].rWeightUnderBunker - stBunker[2].rWeightUnderBunker
   │  ├─ rWeight2 = stBunker[2].rWeightUnderBunker - stBunker[3].rWeightUnderBunker
   │  └─ rWeight3 = stBunker[3].rWeightUnderBunker
   ├─ ПИД-регулирование: fbProportionPid(...)
   │  ├─ Входы: целевые и фактические пропорции
   │  └─ Выходы: частоты вибропитателей
   ├─ Передача частот бункерам:
   │  └─ stBunker[i].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_i
   └─ Переход в END_REPORT при команде останова

7. END_REPORT
   ├─ Формирование отчета работы
   └─ Переход в IDLE когда все секции остановлены

8. ERROR
   ├─ Аварийная остановка всех секций
   ├─ Сброс команд запуска
   └─ Переход в IDLE при команде сброса + отсутствие ошибок
```

### 6.2 ПИД-регулирование пропорций

FB_ProportionPID использует адаптивный алгоритм:

```
1. Нормализация целевых пропорций
   ├─ Если сумма ≠ 1.0, нормализовать к 1.0
   └─ Игнорировать бункеры с пропорцией < 0.001

2. Расчет ошибки регулирования для каждого бункера
   └─ error_i = proportionTarget_i - proportionActual_i

3. ПИД формула для каждого бункера
   ├─ integral_i += error_i * deltaTime (с ограничением anti-windup)
   ├─ derivative_i = (error_i - prevError_i) / deltaTime
   └─ output_i = Kp*error_i + Ki*integral_i + Kd*derivative_i

4. Преобразование ПИД-выхода в частоты
   ├─ freqBase_i = targetSum * proportionNorm_i
   ├─ scale_i = output_i / proportionNorm_i (с ограничением)
   └─ freqScaled_i = freqBase_i * scale_i

5. Нормализация для поддержания целевой суммарной частоты
   ├─ sumScaled = freqScaled_1 + freqScaled_2 + freqScaled_3
   └─ frequency_i = freqScaled_i * (targetSum / sumScaled)

6. Применение ограничений оборудования
   └─ frequency_i = CLAMP(frequency_i, frequencyMin, frequencyMax)
```

**Преимущества алгоритма:**
- Автоматическая коррекция отклонений пропорций
- Сохранение целевой суммарной частоты
- Защита от перегрузки и недогрузки моторов

### 6.3 Синхронизация моторов конвейера

FB_DumperControl и FB_ConveyorControl синхронизируют два мотора:

```iecst
// Условие продолжения разгона
xConditionToProceed := xVFDsReady AND xFrequenciesSynchronized;

// Проверка готовности
xVFDsReady := Motor1.VFD.Device.qxActive
           AND Motor2.VFD.Device.qxActive;

// Проверка синхронизации
xFrequenciesSynchronized :=
    ABS(Motor1.VFD.rActualFrequency - Motor2.VFD.rActualFrequency)
    <= VFD_FREQUENCY_SYNC_TOLERANCE;

// Передача условия в контроллеры частоты
Motor1.VFD.Frequency(
    rTargetFrequency := 50.0,
    xConditionToProceed := xConditionToProceed // БЛОКИРОВКА
);
Motor2.VFD.Frequency(
    rTargetFrequency := 50.0,
    xConditionToProceed := xConditionToProceed // БЛОКИРОВКА
);
```

**Принцип работы:**
1. Оба мотора запускаются одновременно
2. Частоты увеличиваются по импульсу `xPulse`
3. Если разница частот превышает допуск → разгон приостанавливается
4. Частоты выравниваются → разгон продолжается

### 6.4 Предпусковая сигнализация

FB_PreStartAlarm реализует звуковое оповещение перед запуском:

```
┌─────────────┐ → ┌──────────┐ → ┌─────────────┐ → ┌──────────┐ → [COMPLETE]
│ 1-й сигнал  │   │  Пауза   │   │ 2-й сигнал  │   │  Пауза   │
│   T#3S      │   │  T#3S    │   │   T#3S      │   │  T#3S    │
└─────────────┘   └──────────┘   └─────────────┘   └──────────┘
      ▲                                                     │
      │ ixStart                                qxComplete   │
      └─────────────────────────────────────────────────────┘
```

### 6.5 Аналоговые входы/выходы (4-20 мА)

**Аналоговый вход (FB_AnalogInput):**
```
Физический ток → АЦП модуля → FB_AnalogInput → Инженерная величина
    4-20 мА          0-27648       масштабирование       0-100 Гц
```

**Аналоговый выход (FB_AnalogOutput):**
```
Инженерная величина → FB_AnalogOutput → ЦАП модуля → Физический ток
      0-50 Гц             масштабирование      0-27648         4-20 мА
```

**Диагностика токовой петли:**
- LL (< 3.8 мА): Обрыв линии
- L (4.0-4.5 мА): Минимальное значение
- H (19.5-20.0 мА): Максимальное значение
- HH (> 20.2 мА): Короткое замыкание

---

## 7. Связь с SCADA

### 7.1 Передача состояний

Каждая секция оборудования передает состояние через `E_ScadaStatesDevice`:

```iecst
// Приоритет проверки (от более критичных к менее критичным)
IF STAGE = ERROR THEN
    eStageToSCADA := E_ScadaStatesDevice.ERROR;
ELSIF STAGE = WORK AND xStateFailure THEN
    eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_ERROR;
ELSIF STAGE = WORK AND xStateWarning THEN
    eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_WARNING;
ELSIF STAGE = WORK THEN
    eStageToSCADA := E_ScadaStatesDevice.WORK;
ELSIF STAGE = STARTING THEN
    eStageToSCADA := E_ScadaStatesDevice.STARTING;
ELSIF STAGE = IDLE AND xStateWarning THEN
    eStageToSCADA := E_ScadaStatesDevice.WARNING;
ELSIF STAGE = IDLE AND xStateFailure THEN
    eStageToSCADA := E_ScadaStatesDevice.NOT_READY;
ELSE
    eStageToSCADA := E_ScadaStatesDevice.READY;
END_IF
```

### 7.2 Modbus тэги

MAIN.st инициализирует объединения `U_RealToWord` для обмена REAL через Modbus:

```iecst
// Инициализация тэгов (чтение из Modbus)
VFD_FREQUENCY_MAX := uVfdFrequencyMax.rTag;
BUNKER_WORK_PRECENT_1 := uBunkerWorkPrecent1.rTag;

// Передача данных (запись в Modbus)
uBunker1Weight.rTag := stBunker[1].rWeight;
uBunker1ProportionActual.rTag := stBunker[1].rProportionActual;
```

---

## 8. Симуляция

### 8.1 Режим симуляции

Глобальная переменная `SIMULATION := TRUE` активирует симуляцию всех аналоговых входов:

```iecst
Motor.VFD.fbAnalogInput(
    xSimulation := SIMULATION,           // Режим симуляции
    iADC_Code := Motor.VFD.nActualFrequencyADC,
    refEngValue := Motor.VFD.rActualFrequency,
    refSimValue := Motor.VFD.rSimulatedFrequency
);

// В режиме симуляции:
// rActualFrequency := rSimulatedFrequency
```

### 8.2 FB_FrequencySimulation

Симулирует плавное изменение частоты ЧРП:

```iecst
Motor.VFD.fbSimFreq(
    ixEnable := SIMULATION,
    irFrequencyTarget := Motor.VFD.qrOutFrequency,
    irFrequencyStep := 1.0,
    ixPulse := PULSE_RTRIG.Q
);
Motor.VFD.rSimulatedFrequency := Motor.VFD.fbSimFreq.qrFrequencyCurrent;
```

---

## 9. Соглашения и стандарты

### 9.1 Префиксы переменных (IEC 61131-3)

| Префикс | Тип           | Пример                  | Примечание                       |
|---------|---------------|-------------------------|----------------------------------|
| `i`     | Input         | `ixSignal`, `irValue`   | Входной параметр                 |
| `q`     | Output        | `qxPower`, `qrFrequency`| Выходной параметр                |
| `x`     | BOOL          | `xStartCommand`         | Булева переменная                |
| `r`     | REAL          | `rCurrentFrequency`     | Вещественное число               |
| `n`     | INT/UINT/DINT | `nTransitionCount`      | Целое число                      |
| `t`     | TIME          | `tStabilityTime`        | Время                            |
| `u`     | Enum (UINT)   | `uFeedbackState`        | Перечисление                     |
| `e`     | Enum          | `eDumperStage`          | Перечисление (альтернатива)      |
| `st`    | Struct        | `stMotor`               | Экземпляр структуры              |
| `fb`    | Function Block| `fbSignal`              | Экземпляр функционального блока  |
| `_`     | Private       | `_xInternalState`       | Внутренняя переменная            |

### 9.2 Префиксы типов

| Префикс | Тип                      | Пример                    |
|---------|--------------------------|---------------------------|
| `FB_`   | Function Block           | `FB_UniversalSignal`      |
| `FC_`   | Function                 | `FC_Get_ErrorCommon`      |
| `ST_`   | Structure Type           | `ST_Motor`, `ST_VFD`      |
| `E_`    | Enumeration Type         | `E_StateFeedback`         |
| `U_`    | Union Type               | `U_RealToWord`            |

### 9.3 Именование оборудования (китайские стандарты)

| Обозначение | Тип оборудования                | Русское название                |
|-------------|---------------------------------|---------------------------------|
| **ZQ**      | Belt misalignment sensors       | Контроль схода ленты            |
| **HQ**      | Cable pull-cord emergency stops | Кабель-тросовый выключатель     |
| **SQ**      | Limit switches                  | Концевые выключатели            |
| **GS**      | Material buildup detection      | Контроль заштыбовки             |
| **YS**      | Longitudinal tear detection     | Контроль продольного разрыва    |
| **YE**      | Metal detector                  | Обнаружение металла             |
| **QR**      | Speed sensors                   | Датчики скорости                |
| **QF**      | Circuit breaker                 | Автоматический выключатель      |
| **KM**      | Contactor                       | Контактор                       |
| **HLA**     | Light alarm                     | Световая сигнализация           |
| **HA**      | Audio-visual alarm              | Светозвуковой оповещатель       |

---

## 10. Ключевые отличия от ООП версии

| Аспект                      | Старая ООП версия                           | Новая функциональная версия              |
|-----------------------------|---------------------------------------------|------------------------------------------|
| **Структура блоков**        | METHOD внутри FUNCTION_BLOCK                | Вся логика inline в FUNCTION_BLOCK       |
| **Доступ к данным**         | `Motor.GetPower()`                          | `Motor.qxPower`                          |
| **Управление механизмом**   | `Motor.Control.Start(cmd := TRUE)`         | `Motor.Device.xStartCommand := TRUE`     |
| **Конфигурация функций**    | Отдельные FB для разных режимов             | Enable flags внутри универсального FB    |
| **Обратная связь**          | `FB_SignalWithFeedback`                     | `FB_UniversalSignal(xEnableFeedback)`    |
| **Частотное управление**    | `Motor.VFD.Frequency.SetFrequencyTarget()`  | `Motor.VFD.Frequency.rTargetFrequency`   |
| **Наследование**            | `FB_Mechanism` → `FB_MechanismWithFeedback` | Нет наследования, все в одном блоке      |
| **Интерфейсы**              | `I_Control` с методами                      | Нет интерфейсов                          |
| **Проверка ошибок**         | Методы внутри структур                      | Чистые функции FC_*                      |

---

## 11. Рекомендации по разработке

### 11.1 Общие правила

1. **НЕ использовать METHOD блоки** - вся логика должна быть inline
2. **Использовать enable flags** для опциональных функций
3. **Прямой доступ к выходам** через префикс `q`
4. **Чистые функции** для проверок и расчетов
5. **REFERENCE TO** для передачи больших структур

### 11.2 Добавление нового оборудования

```iecst
// 1. Создать структуру в DataTypes/
TYPE ST_NewEquipment :
STRUCT
    Motor : ST_Motor;
    fbSensor : FB_UniversalSignal;
    xStateFailure : BOOL;
END_STRUCT
END_TYPE

// 2. Создать функцию проверки в Functions/
FUNCTION FC_NewEquipment_GetError : BOOL
VAR_INPUT
    Equipment : REFERENCE TO ST_NewEquipment;
END_VAR
    FC_NewEquipment_GetError :=
        NOT Equipment.fbSensor.qxSignal
        OR FC_Conveyor_GetErrorMotor(Motor := Equipment.Motor);
END_FUNCTION

// 3. Создать управляющий блок в POUs/
FUNCTION_BLOCK FB_NewEquipmentControl
VAR_INPUT
    Equipment : REFERENCE TO ST_NewEquipment;
    xStart : BOOL;
    xStop : BOOL;
    xReset : BOOL;
END_VAR
VAR_OUTPUT
    eStage : E_StageWithPreStartAlarm;
    eStageToSCADA : E_ScadaStatesDevice;
END_VAR
VAR
    STAGE : E_StageWithPreStartAlarm := IDLE;
END_VAR

// Инициализация сигналов
Equipment.fbSensor(
    ixSignal := ,  // Подключить физический вход
    xEnableRattlingFilter := TRUE
);

// Автомат состояний
CASE STAGE OF
    IDLE:
        IF xStart THEN
            STAGE := STARTING;
        END_IF

    STARTING:
        Equipment.Motor.Device.xStartCommand := TRUE;
        IF Equipment.Motor.Device.qxActive THEN
            STAGE := WORK;
        END_IF

    WORK:
        IF xStop THEN
            Equipment.Motor.Device.xStopCommand := TRUE;
            STAGE := IDLE;
        END_IF

    ERROR:
        IF xReset AND NOT FC_NewEquipment_GetError(Equipment := Equipment) THEN
            STAGE := IDLE;
        END_IF
END_CASE;

eStage := STAGE;
END_FUNCTION_BLOCK

// 4. Интегрировать в MAIN.st
stNewEquipment : ST_NewEquipment;
fbNewEquipment : FB_NewEquipmentControl;

fbNewEquipment(
    Equipment := stNewEquipment,
    xStart := xStartNewEquipment,
    xStop := fbEmergencyStopProcess.qxStateStopProcess,
    xReset := stCommands.cmdResetAll.qxSignal
);
```

### 11.3 Отладка

1. **Режим симуляции**: `SIMULATION := TRUE` в GLOBAL.st
2. **Симуляция аналоговых входов**: автоматически включается при SIMULATION
3. **Симуляция частот**: FB_FrequencySimulation имитирует разгон ЧРП
4. **Проверка состояний**: мониторить `eStageToSCADA` для каждой секции

---

## Заключение

Архитектура системы построена на принципах **функционального программирования** с использованием **универсальных блоков** и **enable flags**. Отсутствие ООП упрощает код и делает его более прозрачным для ПЛК.

Основные преимущества:
- ✅ Простота и прозрачность кода
- ✅ Прямой доступ к переменным
- ✅ Универсальные блоки вместо иерархий наследования
- ✅ Чистые функции для проверок
- ✅ Гибкая конфигурация через enable flags
