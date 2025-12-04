# Переменные управления частотой VFD (Variable Frequency Drive)

Этот документ описывает все переменные, используемые в алгоритме для принятия и отдачи частоты для частотных преобразователей (ПЧ/VFD) у моторов.

## Оглавление
1. [Структура ST_VFD](#структура-st_vfd)
2. [Использование в MAIN.st](#использование-в-mainst)
3. [Алгоритм управления частотой](#алгоритм-управления-частотой)

---

## Структура ST_VFD

### 1. Дискретные входы (DI) - Состояние VFD

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `fbStateRdyToStart` | `FB_UniversalSignal` | Готов к пуску - сигнал от ПЧ о готовности |
| `fbStateIsWorking` | `FB_UniversalSignal` | В работе - сигнал о работе ПЧ |
| `fbStateFailure` | `FB_UniversalSignal` | Ошибка - сигнал аварии от ПЧ |

### 2. Аналоговые входы (AI) - Измерение частоты

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `fbActualFrequency` | `FB_UniversalAnalogSignal` | Текущая частота вращения (обработанный сигнал) |
| `nActualFrequencyADC` | `INT` | Код АЦП модуля аналогового входа (сырое значение) |
| `rActualFrequency` | `REAL` | Текущая частота ЧРП - использовать в проверках |

### 3. Дискретные выходы (DO) - Команды управления

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `qxStart` | `BOOL` | Пуск ПЧ - команда на запуск |
| `qxResetFailure` | `BOOL` | Сброс аварии ПЧ - команда сброса ошибки |

### 4. Аналоговые выходы (AO) - Задание частоты

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `qrOutFrequency` | `REAL` | Выходная частота - задание частоты для ПЧ |
| `nSetOutSignalToModule` | `INT` | Код АЦП модуля аналогового выхода (для DA модуля) |

### 5. RS-485 / Modbus RTU

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `wMotorCurrent` | `U_RealToWord` | Ток электродвигателя (чтение через Modbus) |
| `uActualFrequency` | `U_RealToWord` | Актуальная частота (чтение через ModbusRTU) |

### 6. Объекты управления частотой

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `Device` | `FB_UniversalMechanism` | Универсальный механизм для ЧРП (пуск/останов) |
| `Frequency` | `FB_FrequencyControl` | Управление частотой (плавный разгон/торможение) |
| `fbRangeDiagnostic` | `FB_RangeDiagnostic` | Диагностика диапазона частоты (L/LL/H/HH) |
| `fbSimFreq` | `FB_FrequencySimulation` | Симуляция частоты (для тестирования) |

### 7. Переменные состояния (для проверок)

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `xStateFailure` | `BOOL` | Флаг ошибки (для проверок в логике) |
| `xStateIsWorking` | `BOOL` | Флаг работы (для проверок в логике) |
| `xStateRdyToStart` | `BOOL` | Флаг готовности к пуску (для проверок в логике) |

### 8. Команды АСУТП (SCADA)

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `cmdSetFrequency` | `REAL` | Ручное задание частоты от оператора |
| `cmdManualStart` | `BOOL` | Команда запуска (режим "Местный") |
| `cmdManualStop` | `BOOL` | Команда остановки (режим "Местный") |
| `cmdFrequencyDirectMode` | `BOOL` | Режим задания частоты: `FALSE` - Плавный переход, `TRUE` - Мгновенный переход |

### 9. Генерация состояний

| Переменная | Тип | Описание |
|-----------|-----|----------|
| `xStateWarning` | `BOOL` | Программное предупреждение (генерируется внутри логики) |
| `xStateFailureLocal` | `BOOL` | Программная ошибка (генерируется внутри логики) |

---

## Использование в MAIN.st

### 1. Пропорциональное управление частотой (FB_ProportionPID)

#### Входные переменные

| Переменная | Тип | Описание | Значение в MAIN.st |
|-----------|-----|----------|-------------------|
| `xEnable` | `BOOL` | Включение ПИД-регулятора | `AUTO_STEP = WORK` |
| `xReset` | `BOOL` | Сброс регулятора | Не подключено |
| `rProportionTarget_1` | `REAL` | Целевая пропорция бункера 1, % | `BUNKER_WORK_PRECENT_1` |
| `rProportionTarget_2` | `REAL` | Целевая пропорция бункера 2, % | `BUNKER_WORK_PRECENT_2` |
| `rProportionTarget_3` | `REAL` | Целевая пропорция бункера 3, % | `BUNKER_WORK_PRECENT_3` |
| `rProportionActual_1` | `REAL` | Фактическая пропорция бункера 1, % | Не подключено (TODO) |
| `rProportionActual_2` | `REAL` | Фактическая пропорция бункера 2, % | Не подключено (TODO) |
| `rProportionActual_3` | `REAL` | Фактическая пропорция бункера 3, % | Не подключено (TODO) |
| `rFrequency_Min` | `REAL` | Минимальная частота, Гц | `5.0` |
| `rFrequency_Max` | `REAL` | Максимальная частота, Гц | `50.0` |
| `rFrequency_TargetSum` | `REAL` | Целевая сумма частот всех вибропитателей, Гц | `90.0` |
| `rDeltaTime` | `REAL` | Период времени для расчета ПИД, с | `0.5` |

#### Выходные переменные

| Переменная | Тип | Описание | Куда подается |
|-----------|-----|----------|---------------|
| `qrFrequency_1` | `REAL` | Рассчитанная частота для бункера 1, Гц | `stBunker[1].rMotorVibFeederCommonFrequency` |
| `qrFrequency_2` | `REAL` | Рассчитанная частота для бункера 2, Гц | `stBunker[2].rMotorVibFeederCommonFrequency` |
| `qrFrequency_3` | `REAL` | Рассчитанная частота для бункера 3, Гц | `stBunker[3].rMotorVibFeederCommonFrequency` |

### 2. Связь с бункерами

```iecst
// Передача рассчитанной частоты в структуры бункеров (MAIN.st: 243-245)
stBunker[1].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_1;
stBunker[2].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_2;
stBunker[3].rMotorVibFeederCommonFrequency := fbProportionPID.qrFrequency_3;
```

---

## Алгоритм управления частотой

### Схема потока данных

```
┌─────────────────────────────────────────────────────────────────┐
│                         MAIN.st                                 │
│                                                                 │
│  Целевые пропорции (BUNKER_WORK_PRECENT_1/2/3)                 │
│           │                                                      │
│           ▼                                                      │
│  ┌───────────────────────┐                                      │
│  │  FB_ProportionPID     │                                      │
│  │  ─────────────────    │                                      │
│  │  • xEnable = WORK     │                                      │
│  │  • rFrequency_Min=5   │                                      │
│  │  • rFrequency_Max=50  │                                      │
│  │  • rTargetSum=90      │                                      │
│  └───────────────────────┘                                      │
│           │                                                      │
│           ▼                                                      │
│  qrFrequency_1/2/3 (Рассчитанные частоты)                      │
│           │                                                      │
│           ▼                                                      │
│  stBunker[1..3].rMotorVibFeederCommonFrequency                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ST_Bunker / ST_VFD                           │
│                                                                 │
│  rMotorVibFeederCommonFrequency                                │
│           │                                                      │
│           ▼                                                      │
│  ┌───────────────────────┐                                      │
│  │  FB_FrequencyControl  │                                      │
│  │  ─────────────────    │                                      │
│  │  • rTargetFrequency   │◄──── cmdSetFrequency (SCADA)        │
│  │  • xDirectSet         │◄──── cmdFrequencyDirectMode         │
│  │  • rStep              │                                      │
│  │  • xPulse             │                                      │
│  └───────────────────────┘                                      │
│           │                                                      │
│           ▼                                                      │
│  qrCurrentFrequency (Текущее значение с плавным изменением)    │
│           │                                                      │
│           ▼                                                      │
│  qrOutFrequency ──► nSetOutSignalToModule ──► AO модуль ──► ПЧ │
│                                                                 │
│  ┌───────────────────────┐                                      │
│  │ Обратная связь:       │                                      │
│  │ ПЧ ──► AI модуль ──►  │                                      │
│  │ nActualFrequencyADC ──►                                     │
│  │ FB_UniversalAnalogSignal ──► rActualFrequency              │
│  └───────────────────────┘                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Этапы работы

1. **Задание пропорций** (MAIN.st, стадия IDLE):
   - Оператор задает процентное соотношение материалов из бункеров
   - Проверка: `cmdSetPrecentBunker[1] + [2] + [3] = 100`

2. **Расчет частот** (MAIN.st, стадия INIT/WORK):
   - `FB_ProportionPID` рассчитывает частоты для каждого вибропитателя
   - Учитывает целевые пропорции и ограничения (5-50 Гц, сумма=90 Гц)
   - ПИД-регулятор корректирует частоты на основе фактических пропорций

3. **Плавное изменение частоты** (ST_VFD):
   - `FB_FrequencyControl.rTargetFrequency` = целевая частота
   - `FB_FrequencyControl.xDirectSet`:
     - `FALSE` - плавное изменение с шагом `rStep` по импульсам `xPulse`
     - `TRUE` - мгновенная установка частоты
   - Выход: `qrCurrentFrequency`

4. **Выдача аналогового сигнала**:
   - `qrOutFrequency` = текущая частота (REAL)
   - Преобразование в `nSetOutSignalToModule` (INT код для DA модуля)
   - Передача на аналоговый выход → ПЧ

5. **Обратная связь**:
   - Чтение частоты через аналоговый вход: `nActualFrequencyADC`
   - Обработка: `FB_UniversalAnalogSignal` → `rActualFrequency`
   - Альтернатива: чтение через Modbus RTU → `uActualFrequency`

6. **Диагностика**:
   - `FB_RangeDiagnostic` - контроль выхода частоты за пределы
   - `xStateWarning` / `xStateFailureLocal` - генерация предупреждений/ошибок

### Режимы управления

#### Автоматический режим (MAIN.st)
- Частота задается через `FB_ProportionPID`
- Автоматическая корректировка по фактическим пропорциям
- Работает только на стадии `AUTO_STEP = WORK`

#### Ручной режим (SCADA)
- `cmdSetFrequency` - ручное задание частоты оператором
- `cmdFrequencyDirectMode` - выбор режима изменения:
  - `FALSE` - плавный переход (безопасный)
  - `TRUE` - мгновенный (для экстренных случаев)

---

## Примеры использования

### Пример 1: Плавный разгон до 30 Гц

```iecst
Motor.VFD.Frequency(
    irMaxFrequency := 50.0,          // Максимальная частота
    rTargetFrequency := 30.0,        // Целевая частота
    xDirectSet := FALSE,             // Плавный режим
    rStep := 1.0,                    // Шаг 1 Гц
    xPulse := Clock_100ms            // Импульс каждые 100 мс
);

// Текущая частота доступна в:
rCurrent := Motor.VFD.Frequency.qrCurrentFrequency;

// Выдача на ПЧ:
Motor.VFD.qrOutFrequency := rCurrent;
```

### Пример 2: Мгновенная установка частоты

```iecst
Motor.VFD.Frequency(
    irMaxFrequency := 50.0,
    rTargetFrequency := 45.0,
    xDirectSet := TRUE,              // Мгновенный режим
    rStep := 1.0,
    xPulse := Clock_100ms
);
```

### Пример 3: Чтение фактической частоты

```iecst
// Через аналоговый вход
Motor.VFD.fbActualFrequency(
    ixRaw := Motor.VFD.nActualFrequencyADC,
    xMode4_20mA := TRUE,
    irRawMin := 0,
    irRawMax := 32767,
    irScaledMin := 0.0,
    irScaledMax := 50.0
);

rActual := Motor.VFD.fbActualFrequency.qrProcessedValue;

// ИЛИ через Modbus
rActual := Motor.VFD.uActualFrequency.rValue;
```

---

## Связанные документы

- `Library/FB_FrequencyControl.st` - Реализация плавного управления частотой
- `Library/FB_UniversalAnalogSignal.st` - Обработка аналоговых сигналов
- `POUs/MAIN.st` - Главная программа с автоматическим алгоритмом
- `DataTypes/ST_VFD.st` - Полная структура VFD
- `CLAUDE.md` - Общая архитектура проекта

---

**Дата создания:** 2025-12-01
**Версия:** 1.0
