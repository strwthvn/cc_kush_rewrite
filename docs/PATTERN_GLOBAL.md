# Руководство разработчика PLC-проекта

> **Версия:** 1.0  
> **Стандарт:** IEC 61131-3, Structured Text  
> **Назначение:** Единый стандарт архитектуры, именования и качества кода для проектов промышленной автоматизации

---

## Содержание

1. [Философия проекта](#1-философия-проекта)
2. [Архитектурная иерархия](#2-архитектурная-иерархия)
3. [Соглашения об именовании](#3-соглашения-об-именовании)
4. [Правила проектирования FB](#4-правила-проектирования-fb)
5. [FSM — конечные автоматы](#5-fsm--конечные-автоматы)
6. [Команды и статусы](#6-команды-и-статусы)
7. [Работа с IO](#7-работа-с-io)
8. [Работа со временем](#8-работа-со-временем)
9. [SCADA / HMI интеграция](#9-scada--hmi-интеграция)
10. [Антипаттерны](#10-антипаттерны)
11. [Чеклист Code Review](#11-чеклист-code-review)
12. [Примеры реализации](#12-примеры-реализации)

---

## 1. Философия проекта

### 1.1 Базовые принципы

**PLC — это детерминированная циклическая машина.** Архитектура строится вокруг:

- Явного порядка вызовов
- Чёткого владения состоянием
- Строгих границ ответственности

> **Золотое правило:** В PLC порядок исполнения = архитектура

### 1.2 Критерии качества кода

| Критерий | Описание |
|----------|----------|
| **Детерминизм** | Одинаковые входы → одинаковый результат |
| **Масштабируемость** | Агрегаты клонируются без правки кода |
| **Тестируемость** | Unit можно симулировать без IO |
| **Читаемость** | Логику можно объяснить без запуска PLC |

### 1.3 Определение зрелости проекта

Проект архитектурно зрелый, если:

- [ ] Агрегаты клонируются без правки кода
- [ ] SCADA заменяется без изменения FSM
- [ ] Порядок вызовов очевиден из структуры FB
- [ ] При перезапуске PLC система приходит в безопасное состояние

---

## 2. Архитектурная иерархия

### 2.1 Пять уровней архитектуры

```
┌─────────────────────────────────────────────────────────────┐
│  LEVEL 4 — SCADA Interface                                  │
│  Адаптеры, маппинг команд, нормализация статусов            │
├─────────────────────────────────────────────────────────────┤
│  LEVEL 3 — Orchestration (Line / Plant)                     │
│  Координация агрегатов, Auto/Manual, interlock              │
├─────────────────────────────────────────────────────────────┤
│  LEVEL 2 — Unit / Aggregate (FSM)                           │
│  Управление одним агрегатом, владение FSM                   │
├─────────────────────────────────────────────────────────────┤
│  LEVEL 1 — Device Abstraction                               │
│  Абстракция устройств (Motor, VFD, Valve, Sensor)           │
├─────────────────────────────────────────────────────────────┤
│  LEVEL 0 — Hardware IO                                      │
│  Изоляция %IX/%QX, нормализация сигналов                    │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Правило взаимодействия уровней

> Каждый уровень знает **только о нижележащем** и не управляет логикой вышележащего.

### 2.3 Детализация по уровням

#### LEVEL 0 — Hardware IO

| Назначение | Изоляция физических адресов, нормализация сигналов |
|------------|---------------------------------------------------|
| **FB** | `FB_DigitalInput`, `FB_DigitalOutput`, `FB_AnalogInput`, `FB_AnalogOutput` |
| **Можно** | Фильтрация, масштабирование, диагностика обрыва |
| **Нельзя** | Логика агрегатов, FSM, команды |

#### LEVEL 1 — Device Abstraction

| Назначение | Абстракция физического устройства |
|------------|-----------------------------------|
| **FB** | `FB_MotorStarter`, `FB_VFD`, `FB_Valve`, `FB_Sensor` |
| **Можно** | Знать *как* управлять устройством |
| **Нельзя** | Знать *зачем*, знания о процессе, SCADA |

#### LEVEL 2 — Unit / Aggregate

| Назначение | Управление одним агрегатом |
|------------|----------------------------|
| **FB** | `FB_PumpUnit`, `FB_ConveyorUnit`, `FB_DumperUnit` |
| **Можно** | FSM агрегата, проверка инвариантов, обработка ошибок |
| **Нельзя** | Прямой доступ к IO, логика SCADA |

#### LEVEL 3 — Orchestration

| Назначение | Координация агрегатов |
|------------|----------------------|
| **FB** | `FB_PumpController`, `FB_LineController` |
| **Можно** | Auto/Manual логика, interlock, последовательности пуска |
| **Нельзя** | Управление IO, внутренние FSM агрегатов |

#### LEVEL 4 — SCADA Interface

| Назначение | Адаптация внешнего мира |
|------------|------------------------|
| **FB** | `FB_PumpScadaAdapter`, `FB_LineScadaAdapter` |
| **Можно** | Маппинг команд, нормализация статусов |
| **Нельзя** | Принятие решений, управление устройствами |

### 2.4 Пример структуры агрегата

```
FB_PumpAggregate
 ├─ FB_DigitalInput      (Level 0)
 ├─ FB_AnalogInput       (Level 0)
 ├─ FB_MotorStarter      (Level 1)
 ├─ FB_PumpUnit          (Level 2) — владеет FSM
 ├─ FB_PumpController    (Level 3)
 ├─ FB_PumpScadaAdapter  (Level 4)
 └─ FB_DigitalOutput     (Level 0)
```

### 2.5 Поток сигналов

**Команды (сверху вниз):**
```
SCADA → Adapter → Orchestration → Unit → Device → IO
```

**Обратная связь (снизу вверх):**
```
IO → Device → Unit → Adapter → SCADA
```

---

## 3. Соглашения об именовании

### 3.1 Префиксы типов данных

| Префикс | Тип | Пример |
|---------|-----|--------|
| `x` | BOOL | `xReady`, `xFault` |
| `n` | INT / UINT / SINT / DINT | `nCount`, `nIndex` |
| `r` | REAL / LREAL | `rTemperature`, `rPressure` |
| `t` | TIME / TON / TOF / TP | `tDelay`, `tTimeout` |
| `dt` | DATE_AND_TIME | `dtStartTime` |
| `s` | STRING | `sMessage`, `sAlarmText` |
| `e` | ENUM | `eState`, `eMode` |
| `st` | STRUCT | `stConfig`, `stStatus` |
| `a` | ARRAY | `aValues`, `aMotors` |
| `p` | POINTER / REFERENCE | `pData`, `refItem` |

### 3.2 Префиксы назначения переменных

| Префикс | Назначение | Пример |
|---------|------------|--------|
| `cmd` | Команда (импульс) | `cmdStart`, `cmdStop`, `cmdReset` |
| `st` | Статус (состояние) | `stReady`, `stRunning`, `stFault` |
| `cfg` | Конфигурация | `cfgTimeout`, `cfgMaxSpeed` |
| `prm` | Параметр | `prmSetpoint`, `prmLimit` |
| `fb` | Внутренний FB | `fbTimer`, `fbMotor` |
| `i` | Локальный счётчик цикла | `i`, `j`, `k` |

### 3.3 Именование Function Block

| Уровень | Шаблон | Примеры |
|---------|--------|---------|
| Level 0 | `FB_<Signal><Direction>` | `FB_DigitalInput`, `FB_AnalogOutput` |
| Level 1 | `FB_<DeviceType>` | `FB_MotorStarter`, `FB_VFD`, `FB_Valve` |
| Level 2 | `FB_<Equipment>Unit` | `FB_PumpUnit`, `FB_ConveyorUnit` |
| Level 3 | `FB_<Equipment>Controller` | `FB_PumpController`, `FB_LineController` |
| Level 4 | `FB_<Equipment>ScadaAdapter` | `FB_PumpScadaAdapter` |
| Aggregate | `FB_<Equipment>Aggregate` | `FB_PumpAggregate` |

### 3.4 Именование ENUM состояний

```iecst
TYPE E_PumpState :
(
    INIT        := 0,   // Инициализация
    IDLE        := 10,  // Ожидание
    STARTING    := 20,  // Запуск
    RUNNING     := 30,  // Работа
    STOPPING    := 40,  // Останов
    FAULT       := 100  // Авария
);
END_TYPE
```

**Правила:**
- Шаг нумерации: 10 (резерв для подсостояний)
- FAULT всегда >= 100
- INIT всегда = 0

### 3.5 Именование STRUCT

| Назначение | Шаблон | Пример |
|------------|--------|--------|
| Команды | `ST_<Equipment>Cmd` | `ST_PumpCmd` |
| Статусы | `ST_<Equipment>Status` | `ST_PumpStatus` |
| Конфигурация | `ST_<Equipment>Config` | `ST_PumpConfig` |
| Параметры | `ST_<Equipment>Params` | `ST_PumpParams` |
| Ошибки | `ST_<Equipment>Fault` | `ST_PumpFault` |

### 3.6 Именование экземпляров

```iecst
// В MAIN или Aggregate FB
fbPump_01       : FB_PumpAggregate;     // Насос №1
fbPump_02       : FB_PumpAggregate;     // Насос №2
fbConveyor_Main : FB_ConveyorAggregate; // Главный конвейер
```

### 3.7 Запрещённые практики именования

| ❌ Нельзя | ✅ Правильно |
|----------|-------------|
| `Motor1`, `M1` | `fbMotor_01` |
| `flag`, `temp` | `bIsRunning`, `rTemperature` |
| `x`, `data` | `nIndex`, `stSensorData` |
| `DoStuff` | `FB_ProcessCommand` |
| `MyFB` | `FB_ValveController` |

---

## 4. Правила проектирования FB

### 4.1 Принцип единственной ответственности

> **Один FB = одна роль** (агрегат / устройство / сервис)

Проверочные вопросы:
- Можно ли удалить FB без поломки остальных?
- Можно ли симулировать FB без реального IO?
- Можно ли описать назначение FB одним предложением?

### 4.2 Структура секций FB

```iecst
FUNCTION_BLOCK FB_PumpUnit
VAR_INPUT
    // Команды извне
    cmdStart    : BOOL;
    cmdStop     : BOOL;
    cmdReset    : BOOL;
    
    // Внешние статусы (от других FB)
    xMotorReady : BOOL;
    xMotorFault : BOOL;
END_VAR

VAR_OUTPUT
    // Статусы наружу
    stReady     : BOOL;
    stRunning   : BOOL;
    stFault     : BOOL;
    eState      : E_PumpState;
END_VAR

VAR
    // Внутреннее состояние
    eCurrentState   : E_PumpState;
    fbStartTimer    : TON;
    fbFaultTimer    : TON;
END_VAR
```

### 4.3 Single Writer Principle

> **Каждая переменная имеет ровно одного владельца.**

| Правило | Описание |
|---------|----------|
| Один писатель | Только один FB записывает в переменную |
| Нет перезаписи | Выходы FB не перезаписываются извне |
| Чёткое владение | Всегда можно указать, кто владеет переменной |

**Нарушение этого принципа = проект не масштабируется.**

### 4.4 Правила для STRUCT

| ✅ Разрешено в STRUCT | ❌ Запрещено в STRUCT |
|-----------------------|----------------------|
| Состояния | FUNCTION_BLOCK |
| Команды | Таймеры (TON, TOF) |
| Статусы | FSM логика |
| Ошибки | Методы |
| Конфигурация | |

> **STRUCT = данные, FB = поведение**

### 4.5 Aggregate FB

Aggregate FB — верхний уровень, который:
- Владеет всеми под-FB агрегата
- Контролирует порядок вызова
- Связывает уровни иерархии

```iecst
FUNCTION_BLOCK FB_PumpAggregate
VAR
    // Level 0
    fbDI_Running    : FB_DigitalInput;
    fbDI_Fault      : FB_DigitalInput;
    fbAI_Pressure   : FB_AnalogInput;
    fbDO_Start      : FB_DigitalOutput;
    
    // Level 1
    fbMotor         : FB_MotorStarter;
    
    // Level 2
    fbUnit          : FB_PumpUnit;
    
    // Level 3
    fbController    : FB_PumpController;
    
    // Level 4
    fbScada         : FB_PumpScadaAdapter;
END_VAR
```

**Порядок вызова в теле FB:**
```iecst
// 1. Обработка входов (Level 0)
fbDI_Running();
fbDI_Fault();
fbAI_Pressure();

// 2. Устройства (Level 1)
fbMotor(
    cmdStart := fbUnit.cmdMotorStart,
    xFeedback := fbDI_Running.bValue
);

// 3. Агрегат (Level 2)
fbUnit(
    xMotorReady := fbMotor.stReady,
    xMotorRunning := fbMotor.stRunning
);

// 4. Оркестрация (Level 3)
fbController(
    stUnitStatus := fbUnit.eState
);

// 5. SCADA адаптер (Level 4)
fbScada(
    stUnitStatus := fbUnit.eState
);

// 6. Выходы (Level 0)
fbDO_Start(bValue := fbMotor.cmdOutput);
```

---

## 5. FSM — конечные автоматы

### 5.1 Обязательные требования

| Требование | Описание |
|------------|----------|
| Явный ENUM | FSM выражен через ENUM, не INT |
| Одна переменная | Текущее состояние в одной переменной |
| Централизованные переходы | Все переходы видны в одном месте |

### 5.2 Обязательные состояния

| Состояние | Описание | Правила |
|-----------|----------|---------|
| `INIT` | Начальное | Всегда существует, сброс всех выходов |
| `IDLE` | Ожидание | Готовность к работе |
| `FAULT` | Авария | Устойчивое, автовыход запрещён |
| `STOPPING` | Останов | Отдельное состояние, не IF в RUNNING |

### 5.3 Шаблон FSM

```iecst
CASE eCurrentState OF
    
    E_PumpState.INIT:
        // Сброс всех выходов
        stRunning := FALSE;
        stFault := FALSE;
        cmdMotorStart := FALSE;
        
        // Безусловный переход
        eCurrentState := E_PumpState.IDLE;
        
    E_PumpState.IDLE:
        stReady := bMotorReady AND NOT bMotorFault;
        
        IF cmdStart AND stReady THEN
            eCurrentState := E_PumpState.STARTING;
        END_IF
        
    E_PumpState.STARTING:
        cmdMotorStart := TRUE;
        fbStartTimer(IN := TRUE, PT := cfgStartTimeout);
        
        IF bMotorRunning THEN
            fbStartTimer(IN := FALSE);
            eCurrentState := E_PumpState.RUNNING;
        ELSIF fbStartTimer.Q THEN
            fbStartTimer(IN := FALSE);
            eFaultCode := E_FaultCode.START_TIMEOUT;
            eCurrentState := E_PumpState.FAULT;
        END_IF
        
    E_PumpState.RUNNING:
        stRunning := TRUE;
        
        IF cmdStop THEN
            eCurrentState := E_PumpState.STOPPING;
        ELSIF bMotorFault THEN
            eFaultCode := E_FaultCode.MOTOR_FAULT;
            eCurrentState := E_PumpState.FAULT;
        END_IF
        
    E_PumpState.STOPPING:
        cmdMotorStart := FALSE;
        stRunning := FALSE;
        
        IF NOT bMotorRunning THEN
            eCurrentState := E_PumpState.IDLE;
        END_IF
        
    E_PumpState.FAULT:
        cmdMotorStart := FALSE;
        stRunning := FALSE;
        stFault := TRUE;
        
        // Только ручной сброс
        IF cmdReset AND NOT bMotorFault THEN
            stFault := FALSE;
            eFaultCode := E_FaultCode.NO_FAULT;
            eCurrentState := E_PumpState.INIT;
        END_IF
        
END_CASE
```

### 5.4 Правило: один агрегат = один FSM

- Не создавайте несколько FSM в одном FB без явного разделения
- Если нужно несколько FSM — выделите в отдельные FB

---

## 6. Команды и статусы

### 6.1 Команды

**Определение:** Команда — это **импульс**, а не состояние.

| Правило | Описание |
|---------|----------|
| Импульсность | Команда активна один цикл |
| Только VAR_INPUT | Команды приходят только через VAR_INPUT |
| Один источник | Один FB подаёт команду |

**Типовые команды:**
```iecst
VAR_INPUT
    cmdStart    : BOOL;     // Запуск
    cmdStop     : BOOL;     // Останов
    cmdReset    : BOOL;     // Сброс аварии
    cmdEnable   : BOOL;     // Разрешение (если требуется)
END_VAR
```

### 6.2 Статусы

**Определение:** Статус отражает **реальное состояние**, а не желание.

| Правило | Описание |
|---------|----------|
| Реальность | Статус = факт, не команда |
| Один владелец | Каждый статус имеет одного владельца |
| Не сбрасывается извне | SCADA не сбрасывает статус |

**Типовые статусы:**
```iecst
VAR_OUTPUT
    stReady     : BOOL;     // Готов к работе
    stRunning   : BOOL;     // В работе
    stStopped   : BOOL;     // Остановлен
    stFault     : BOOL;     // Авария
    eState      : E_State;  // Текущее состояние FSM
END_VAR
```

### 6.3 Антипаттерны команд и статусов

| ❌ Антипаттерн | ✅ Правильно |
|---------------|-------------|
| Кнопка = состояние RUN | Кнопка = импульс cmdStart |
| SCADA удерживает TRUE | SCADA подаёт фронт |
| Несколько FB пишут команду | Один источник команды |
| Статус из таймера + флага | Статус из FSM |

---

## 7. Работа с IO

### 7.1 Изоляция физических адресов

> Прямые адреса `%IX`, `%QX` используются **только** в FB Level 0.

```iecst
// Level 0 FB
FUNCTION_BLOCK FB_DigitalInput
VAR_INPUT
    pAddress    : POINTER TO BOOL;  // Или прямая привязка
END_VAR
VAR_OUTPUT
    xValue      : BOOL;             // Нормализованное значение
    xValid      : BOOL;             // Сигнал валиден
    xFault      : BOOL;             // Диагностика
END_VAR
```

### 7.2 Аналоговые сигналы

```iecst
FUNCTION_BLOCK FB_AnalogInput
VAR_INPUT
    nRawValue   : INT;              // Сырое значение АЦП
    rScaleLow   : REAL := 0.0;      // Нижняя граница шкалы
    rScaleHigh  : REAL := 100.0;    // Верхняя граница шкалы
    rRawLow     : REAL := 0.0;      // Нижняя граница АЦП
    rRawHigh    : REAL := 27648.0;  // Верхняя граница АЦП
END_VAR
VAR_OUTPUT
    rValue      : REAL;             // Масштабированное значение
    xValid      : BOOL;             // В пределах нормы
    xFault      : BOOL;             // Обрыв / КЗ
END_VAR
```

### 7.3 Датчики

| Выход | Описание |
|-------|----------|
| `Value` | Измеренное значение |
| `Valid` | Значение достоверно |
| `Fault` | Неисправность датчика |

**Правило:** Фильтрация и диагностика — внутри FB датчика, не в агрегате.

### 7.4 Исполнительные механизмы

**Контракт FB устройства:**
```iecst
// Входы (команды)
cmdStart    : BOOL;
cmdStop     : BOOL;
rSetpoint   : REAL;     // Для VFD / аналоговых

// Выходы (статусы)
stReady     : BOOL;
stRunning   : BOOL;
stFault     : BOOL;
rActual     : REAL;     // Для VFD / аналоговых
```

---

## 8. Работа со временем

### 8.1 Таймеры

| Правило | Описание |
|---------|----------|
| Принадлежность | Таймер принадлежит конкретному состоянию FSM |
| Явный сброс | Таймер сбрасывается явно при выходе из состояния |
| Локальность | Нет глобальных таймеров «на всё» |

### 8.2 Шаблон использования таймера

```iecst
E_State.STARTING:
    fbStartTimer(IN := TRUE, PT := cfgStartTimeout);
    
    IF bConditionMet THEN
        fbStartTimer(IN := FALSE);  // Явный сброс
        eCurrentState := E_State.RUNNING;
    ELSIF fbStartTimer.Q THEN
        fbStartTimer(IN := FALSE);  // Явный сброс
        eCurrentState := E_State.FAULT;
    END_IF

E_State.RUNNING:
    // fbStartTimer здесь не используется
```

### 8.3 Антипаттерны

| ❌ Антипаттерн | Проблема |
|---------------|----------|
| TON как событие | Неявная логика |
| Таймер вне FSM | Потеря контроля |
| Глобальный таймер | Непредсказуемость |

---

## 9. SCADA / HMI интеграция

### 9.1 Принципы

> **SCADA — это зеркало, а не мозг.**

| Разрешено | Запрещено |
|-----------|-----------|
| Отображение статусов | Управление последовательностью |
| Отправка команд | Аварийная логика |
| Квитирование аварий | Обход FSM |
| Задание уставок | Принятие решений |

### 9.2 SCADA Adapter FB

```iecst
FUNCTION_BLOCK FB_PumpScadaAdapter
VAR_INPUT
    // От SCADA
    scadaCmdStart   : BOOL;
    scadaCmdStop    : BOOL;
    scadaCmdReset   : BOOL;
    
    // От Unit
    eUnitState      : E_PumpState;
    bUnitFault      : BOOL;
END_VAR
VAR_OUTPUT
    // К Unit (нормализованные команды)
    cmdStart        : BOOL;
    cmdStop         : BOOL;
    cmdReset        : BOOL;
    
    // К SCADA (нормализованные статусы)
    nStateCode      : INT;          // Код состояния для SCADA
    bDisplayFault   : BOOL;         // Флаг аварии
END_VAR
VAR
    // Детекторы фронтов
    fbRtrigStart    : R_TRIG;
    fbRtrigStop     : R_TRIG;
    fbRtrigReset    : R_TRIG;
END_VAR

// Тело FB
fbRtrigStart(CLK := scadaCmdStart);
fbRtrigStop(CLK := scadaCmdStop);
fbRtrigReset(CLK := scadaCmdReset);

// Команды — только по фронту
cmdStart := fbRtrigStart.Q;
cmdStop := fbRtrigStop.Q;
cmdReset := fbRtrigReset.Q;

// Статусы — прямой маппинг
nStateCode := TO_INT(eUnitState);
bDisplayFault := bUnitFault;
```

### 9.3 Жёсткие запреты для SCADA

- ❌ SCADA не хранит состояние агрегата
- ❌ SCADA не принимает решений
- ❌ SCADA не может сломать агрегат

---

## 10. Антипаттерны

### 10.1 Архитектурные антипаттерны

| Антипаттерн | Проблема | Решение |
|-------------|----------|---------|
| «Бог-FB» | Один FB управляет всем | Декомпозиция по уровням |
| STRUCT с FB | Нарушение владения | STRUCT = данные, FB = поведение |
| Несколько FSM в FB | Сложность, ошибки | Один агрегат = один FSM |
| Прямой IO в Unit | Нетестируемость | IO только в Level 0 |
| Логика в SCADA | Недетерминизм | SCADA = зеркало |
| Неявный порядок вызовов | Недетерминизм | Явный порядок в Aggregate |

### 10.2 Антипаттерны FSM

| Антипаттерн | Проблема |
|-------------|----------|
| Подстадии на INT | Неявные состояния |
| Автовыход из FAULT | Опасное поведение |
| STOPPING в IF | Пропуск состояния |
| Переходы в разных местах | Потеря контроля |

### 10.3 Антипаттерны команд

| Антипаттерн | Проблема |
|-------------|----------|
| Команда = состояние | Залипание |
| SCADA удерживает TRUE | Неимпульсность |
| Несколько источников | Race condition |

### 10.4 Антипаттерны данных

| Антипаттерн | Проблема |
|-------------|----------|
| Глобальные переменные | Неявные связи |
| Магические числа | Нечитаемость |
| Состояние в флагах | Неявный FSM |

---

## 11. Чеклист Code Review

### 11.1 Перед началом кодирования

- [ ] Проект разбит на агрегаты, а не на «функции»
- [ ] Каждый агрегат имеет чёткую зону ответственности
- [ ] Нет «бога-FB», управляющего всем
- [ ] Определены все ENUM состояний
- [ ] Определены все STRUCT данных

### 11.2 Структура FB

- [ ] FB выполняет ровно одну роль
- [ ] FB можно удалить без поломки остальных
- [ ] FB можно симулировать без реального IO
- [ ] Нет прямого доступа к глобальным переменным
- [ ] Нет работы с физическим IO внутри агрегатного FB
- [ ] Нет логики SCADA внутри агрегатного FB

### 11.3 FSM

- [ ] FSM выражен явным ENUM
- [ ] Текущее состояние в одной переменной
- [ ] Все переходы видны в одном месте (CASE)
- [ ] INIT состояние существует
- [ ] FAULT — устойчивое состояние
- [ ] Автовыход из FAULT запрещён
- [ ] STOPPING — отдельное состояние
- [ ] Нет подстадий на INT
- [ ] Нет нескольких FSM в одном FB

### 11.4 Команды

- [ ] Команда — импульс, не состояние
- [ ] Команды не хранятся дольше одного цикла
- [ ] Команды приходят только через VAR_INPUT
- [ ] cmdStart, cmdStop, cmdReset определены
- [ ] Нет ситуации «несколько FB пишут одну команду»

### 11.5 Статусы

- [ ] Статус отражает реальное состояние
- [ ] Каждый статус имеет одного владельца
- [ ] Статус не сбрасывается из SCADA
- [ ] stReady, stRunning, stFault определены

### 11.6 Single Writer

- [ ] Каждая переменная имеет один FB-владелец
- [ ] Нет ситуации «два FB пишут один сигнал»
- [ ] Выходы FB не перезаписываются извне

### 11.7 Таймеры

- [ ] Таймер принадлежит конкретному состоянию
- [ ] Таймер сбрасывается явно
- [ ] Нет глобальных таймеров

### 11.8 IO и устройства

- [ ] Исполнительный механизм — отдельный FB
- [ ] Агрегат управляет через команды, не напрямую
- [ ] Датчик инкапсулирован в FB
- [ ] Фильтрация — внутри FB датчика
- [ ] FSM не проверяет «сырые» входы

### 11.9 SCADA

- [ ] SCADA не содержит логики процесса
- [ ] SCADA не принимает решений
- [ ] SCADA не хранит состояние агрегата
- [ ] Команды SCADA — по фронту

### 11.10 Инициализация

- [ ] INIT состояние существует явно
- [ ] После рестарта агрегат не запускается сам
- [ ] Все команды сброшены при старте

### 11.11 Именование

- [ ] Используются стандартные префиксы типов
- [ ] FB именованы по шаблону уровня
- [ ] ENUM состояний с шагом 10
- [ ] Нет магических чисел в коде

### 11.12 Финальная проверка (жёсткая)

> Ответь «да» на всё:

- [ ] Я могу доказать корректность переходов FSM
- [ ] Я знаю владельца каждой переменной
- [ ] SCADA не может сломать агрегат
- [ ] При аварии система предсказуема
- [ ] Код скучен и очевиден

**Если где-то «ну почти» — возвращайся к началу.**

---

## 12. Примеры реализации

### 12.1 ENUM состояний

```iecst
TYPE E_PumpState :
(
    INIT        := 0,
    IDLE        := 10,
    STARTING    := 20,
    RUNNING     := 30,
    STOPPING    := 40,
    FAULT       := 100
);
END_TYPE

TYPE E_FaultCode :
(
    NO_FAULT        := 0,
    START_TIMEOUT   := 1,
    MOTOR_FAULT     := 2,
    OVERLOAD        := 3,
    SENSOR_FAULT    := 4
);
END_TYPE
```

### 12.2 STRUCT команд и статусов

```iecst
TYPE ST_PumpCmd :
STRUCT
    bStart      : BOOL;
    bStop       : BOOL;
    bReset      : BOOL;
END_STRUCT
END_TYPE

TYPE ST_PumpStatus :
STRUCT
    bReady      : BOOL;
    bRunning    : BOOL;
    bFault      : BOOL;
    eState      : E_PumpState;
    eFaultCode  : E_FaultCode;
END_STRUCT
END_TYPE

TYPE ST_PumpConfig :
STRUCT
    tStartTimeout   : TIME := T#10S;
    tStopTimeout    : TIME := T#5S;
    nMaxRestarts    : INT := 3;
END_STRUCT
END_TYPE
```

### 12.3 FB Level 0 — Digital Input

```iecst
FUNCTION_BLOCK FB_DigitalInput
VAR_INPUT
    bRawInput       : BOOL;         // Физический вход
    bInvert         : BOOL := FALSE;// Инверсия
    tFilterTime     : TIME := T#20MS;// Время фильтрации
END_VAR
VAR_OUTPUT
    bValue          : BOOL;         // Отфильтрованное значение
    bRisingEdge     : BOOL;         // Передний фронт
    bFallingEdge    : BOOL;         // Задний фронт
END_VAR
VAR
    fbFilter        : TON;
    fbRtrig         : R_TRIG;
    fbFtrig         : F_TRIG;
    bFiltered       : BOOL;
END_VAR

// Фильтрация дребезга
fbFilter(IN := bRawInput, PT := tFilterTime);
bFiltered := fbFilter.Q;

// Инверсия если нужно
IF bInvert THEN
    bValue := NOT bFiltered;
ELSE
    bValue := bFiltered;
END_IF

// Детекция фронтов
fbRtrig(CLK := bValue);
fbFtrig(CLK := bValue);
bRisingEdge := fbRtrig.Q;
bFallingEdge := fbFtrig.Q;
```

### 12.4 FB Level 1 — Motor Starter

```iecst
FUNCTION_BLOCK FB_MotorStarter
VAR_INPUT
    cmdStart        : BOOL;
    cmdStop         : BOOL;
    bFeedbackRun    : BOOL;         // Обратная связь
    bFeedbackFault  : BOOL;         // Авария от устройства
    tStartTimeout   : TIME := T#5S;
END_VAR
VAR_OUTPUT
    stReady         : BOOL;
    stRunning       : BOOL;
    stFault         : BOOL;
    bCmdOutput      : BOOL;         // Команда на контактор
END_VAR
VAR
    eState          : E_MotorState;
    fbStartTimer    : TON;
END_VAR

CASE eState OF
    
    E_MotorState.INIT:
        bCmdOutput := FALSE;
        stRunning := FALSE;
        stFault := FALSE;
        eState := E_MotorState.IDLE;
        
    E_MotorState.IDLE:
        stReady := NOT bFeedbackFault;
        
        IF cmdStart AND stReady THEN
            eState := E_MotorState.STARTING;
        END_IF
        
    E_MotorState.STARTING:
        bCmdOutput := TRUE;
        fbStartTimer(IN := TRUE, PT := tStartTimeout);
        
        IF bFeedbackRun THEN
            fbStartTimer(IN := FALSE);
            eState := E_MotorState.RUNNING;
        ELSIF fbStartTimer.Q OR bFeedbackFault THEN
            fbStartTimer(IN := FALSE);
            eState := E_MotorState.FAULT;
        END_IF
        
    E_MotorState.RUNNING:
        stRunning := TRUE;
        
        IF cmdStop THEN
            eState := E_MotorState.STOPPING;
        ELSIF bFeedbackFault OR NOT bFeedbackRun THEN
            eState := E_MotorState.FAULT;
        END_IF
        
    E_MotorState.STOPPING:
        bCmdOutput := FALSE;
        stRunning := FALSE;
        
        IF NOT bFeedbackRun THEN
            eState := E_MotorState.IDLE;
        END_IF
        
    E_MotorState.FAULT:
        bCmdOutput := FALSE;
        stRunning := FALSE;
        stFault := TRUE;
        
        // Сброс извне не показан — через cmdReset
        
END_CASE
```

### 12.5 MAIN — точка входа

```iecst
PROGRAM MAIN
VAR
    // Агрегаты (инстанцирование)
    fbPump_01       : FB_PumpAggregate;
    fbPump_02       : FB_PumpAggregate;
    fbConveyor_01   : FB_ConveyorAggregate;
    
    // Связи между агрегатами (Level 3)
    fbLineController: FB_LineController;
END_VAR

// MAIN не содержит логики!
// MAIN не содержит FSM!
// MAIN только вызывает агрегаты в правильном порядке

// 1. Вызов агрегатов
fbPump_01();
fbPump_02();
fbConveyor_01();

// 2. Линейный контроллер (координация)
fbLineController(
    stPump01 := fbPump_01.stStatus,
    stPump02 := fbPump_02.stStatus,
    stConveyor := fbConveyor_01.stStatus
);
```

---

## Приложения

### A. Контрольные вопросы архитектуры

При ревью проекта ответь на эти вопросы:

1. **Где живёт FSM агрегата?** → Должен быть в FB Level 2
2. **Кто владеет таймерами?** → FB, использующий таймер
3. **Кто последний пишет в выход?** → Один владелец
4. **Можно ли протестировать Unit без IO?** → Да, через VAR_INPUT

> Если нет чёткого ответа — архитектура нарушена.

### B. Шаблон пустого FB

```iecst
//=============================================================================
// FB: FB_TemplateName
// Описание: [Краткое описание назначения]
// Уровень: [0-4]
// Автор: [Имя]
// Дата: [YYYY-MM-DD]
//=============================================================================
FUNCTION_BLOCK FB_TemplateName
VAR_INPUT
    // Команды
    cmdStart    : BOOL;
    cmdStop     : BOOL;
    cmdReset    : BOOL;
    
    // Внешние данные
END_VAR

VAR_OUTPUT
    // Статусы
    stReady     : BOOL;
    stRunning   : BOOL;
    stFault     : BOOL;
    eState      : E_TemplateState;
END_VAR

VAR
    // FSM
    eCurrentState   : E_TemplateState;
    
    // Таймеры
    fbTimer         : TON;
    
    // Внутренние данные
END_VAR

//-----------------------------------------------------------------------------
// FSM
//-----------------------------------------------------------------------------
CASE eCurrentState OF
    
    E_TemplateState.INIT:
        // Инициализация
        eCurrentState := E_TemplateState.IDLE;
        
    E_TemplateState.IDLE:
        // Ожидание
        
    E_TemplateState.FAULT:
        // Обработка аварии
        
END_CASE

//-----------------------------------------------------------------------------
// Выходы
//-----------------------------------------------------------------------------
eState := eCurrentState;
```

---

> **Хорошая архитектура PLC — это когда система не даёт инженеру ошибиться.**

---

**Конец документа**