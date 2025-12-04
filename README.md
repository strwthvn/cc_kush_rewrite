# Новый проект - Функциональное программирование ПЛК

Этот проект представляет собой полную переработку исходного проекта управления конвейерами с перехода от объектно-ориентированного программирования (ООП) к традиционному функциональному программированию ПЛК в соответствии со стандартом IEC 61131-3.

## Основные изменения

### 1. Переход на функциональную библиотеку (newLib)

Все компоненты переписаны с использованием новой функциональной библиотеки, которая находится в директории `newLib/` родительского проекта.

**Основные замены:**

| Старый ООП блок | Новый функциональный блок | Описание изменения |
|----------------|---------------------------|-------------------|
| `FB_BasicSignal` | `FB_UniversalSignal` | Базовый сигнал без дополнительных функций |
| `FB_SignalWithRattling` | `FB_UniversalSignal` с `xEnableRattlingFilter := TRUE` | Сигнал с фильтрацией дребезга |
| `FB_SignalWithTrigger` | `FB_UniversalSignal` без фильтров | Сигнал только для детектирования фронтов |
| `FB_SignalWithFeedback` | `FB_UniversalSignal` с `xEnableFeedback := TRUE` | Сигнал с обратной связью |
| `FB_SignalWithFeedbackTimer` | `FB_UniversalSignal` с `xEnableFeedbackTimer := TRUE` | Сигнал с таймаутом обратной связи |
| `FB_AnalogSignal4_20mA` | `FB_UniversalAnalogSignal` с `xMode4_20mA := TRUE` | Аналоговый сигнал 4-20мА |
| `FB_BasicAnalogSignal` | `FB_UniversalAnalogSignal` | Универсальный аналоговый сигнал |
| `FB_MechanismWithFeedback` + `FB_BasicControl` | `FB_UniversalMechanism` | Объединенное управление механизмом |
| `FB_RangeDiagnostic_LH` | `FB_RangeDiagnostic` | Диагностика диапазона |
| `FB_FrequencyControl` | `FB_FrequencyControl` (без изменений) | Управление частотой |

### 2. Изменения в структурах данных

#### ST_Motor, ST_VFD, ST_MotorWithFeedback, ST_MotorWithReverse
- Заменены все `FB_SignalWithRattling` на `FB_UniversalSignal`
- Удалены объекты `Control : FB_BasicControl` (логика управления встроена в `FB_UniversalMechanism`)
- Заменены `cmdManualStartKM, cmdManualStopKM : FB_SignalWithTrigger` на простые `BOOL`
- Заменены `FB_AnalogSignal4_20mA` на `FB_UniversalAnalogSignal`
- Заменены `FB_RangeDiagnostic_LH` на `FB_RangeDiagnostic`

#### ST_Bunker, ST_Conveyor, ST_Dumper
- Все сигналы с фильтрацией дребезга используют `FB_UniversalSignal`
- Команды АСУТП изменены с `FB_SignalWithTrigger` на простые `BOOL`

#### ST_Commands, ST_CommonSignals
- Команды изменены с `FB_SignalWithTrigger` на `FB_UniversalSignal`

### 3. Полное исключение ООП - удалены все методы (METHOD)

**ВАЖНО:** В соответствии с требованием полного перехода на функциональное программирование, все блоки METHOD были удалены из проекта. Вся логика теперь находится либо в теле функциональных блоков (FUNCTION_BLOCK), либо вынесена в отдельные функции (FUNCTION).

#### FB_BunkerControl, FB_ConveyorControl, FB_DumperControl

**Удалены все METHOD блоки:**
- Все методы перенесены либо в тело FB, либо в отдельные FC файлы
- Вся логика инициализации, обработки ошибок и управления теперь встроена в основное тело FB
- Отдельные функции (FC_*) созданы для переиспользуемой логики

**Удалены вызовы методов из старой ООП версии:**
- Вызовы методов `.Control.Start()` и `.Control.Stop()`
- Вызовы методов `.Control.SetConditionToStart()` и `.Control.SetConditionToStop()`
- Методы `.Frequency.SetFrequencyTarget()` и `.Frequency.SetFrequencyDirect()`

**Заменены:**
- `.GetRtrig()` → прямое использование `.qxRisingEdge` или детекторов `R_TRIG`
- `.GetProcessedSignal()` → прямое использование `.qxSignal`
- `.GetScaledValue()` → прямое использование `.qrProcessedValue`
- `.GetPower()` → прямое использование `.qxPower`
- `.GetCurrentFrequency()` → прямое использование `.qrCurrentFrequency`

**Добавлено:**
- Прямое управление через `FB_UniversalMechanism`:
  ```iecst
  Motor.Device(
      ixFeedback := Motor.fbStateKM.qxSignal,
      xEnableFeedback := TRUE,
      xStartCommand := StartCmd,
      xStopCommand := StopCmd,
      xStartCondition := NOT HasError,
      xStopCondition := TRUE,
      xReset := EmergencyStop
  );

  Motor.qxKM_Power := Motor.Device.qxPower;
  ```

- Прямое управление частотой через входы `FB_FrequencyControl`:
  ```iecst
  Motor.VFD.Frequency.rTargetFrequency := TargetFreq;
  Motor.VFD.Frequency.xDirectSet := DirectMode;
  ```

### 4. Изменения в MAIN.st

**MAIN.st полностью переписан без методов:**
- Все METHOD блоки удалены и заменены отдельными FUNCTION файлами:
  - `METHOD VFD_ChangeReadMode` → `FC_VFD_ChangeReadMode.st`
  - `METHOD Get_ErrorCommon` → `FC_Get_ErrorCommon.st`
  - `METHOD Bunker_GetErrorWeight` → `FC_Bunker_GetErrorWeight.st`
  - `METHOD Init_Commands` → встроен в тело программы
  - `METHOD Build_ModbusRegisters` → встроен в тело программы

**Изменен интерфейс управляющих блоков:**
- `FB_DumperControl` и `FB_ConveyorControl` теперь имеют входы `xStart : BOOL` и выходы `eStage : E_StageWithPreStartAlarm`
- Вместо вызова методов `.Start_Conveyor()` используется установка флага `xStartDumper := TRUE` или `xStartConveyor := TRUE`
- Состояние контролируется через выходную переменную `eDumperStage` / `eConveyorStage`

**Основные изменения:**
- Заменены все `.GetRtrig()` на `.qxRisingEdge` для команд
- Заменены все `.GetProcessedSignal()` на `.qxSignal` для сигналов
- Заменены все `.GetScaledValue()` на `.qrProcessedValue` для аналоговых сигналов
- Заменены все `.GetPower()` на `.qxPower` для механизмов
- Инициализация команд теперь встроена в тело программы - команды инициализируются как `FB_UniversalSignal`

## Преимущества нового подхода

1. **Полное отсутствие ООП** - никаких METHOD блоков, только FUNCTION и FUNCTION_BLOCK
2. **Простота кода** - нет сложных иерархий наследования и вложенных вызовов методов
3. **Прямой доступ** - все выходы доступны напрямую через переменные
4. **Гибкость** - функциональность включается/выключается через входные флаги
5. **Читаемость** - вся логика сосредоточена в одном месте или вынесена в отдельные функции
6. **Меньше зависимостей** - нет необходимости в промежуточных объектах управления
7. **Традиционный ПЛК подход** - код полностью соответствует классическому стилю программирования ПЛК
8. **Модульность** - логика разделена на 4 папки: POUs, DataTypes, Functions, Library

## Структура проекта

Проект организован по папкам для лучшей читаемости и поддержки:

```
newProject/
├── README.md                           # Этот файл
│
├── POUs/                               # Program Organization Units
│   ├── MAIN.st                         # Главная программа (без методов)
│   ├── FB_BunkerControl.st             # Управление бункерами (без методов)
│   ├── FB_ConveyorControl.st           # Управление конвейерами (без методов)
│   └── FB_DumperControl.st             # Управление отвалообразователем (без методов)
│
├── DataTypes/                          # Типы данных проекта
│   ├── ST_Motor.st                     # Структура базового мотора
│   ├── ST_MotorWithFeedback.st         # Мотор с обратной связью
│   ├── ST_MotorWithReverse.st          # Мотор с реверсом
│   ├── ST_MotorVibFeeder.st            # Вибропитатель
│   ├── ST_VFD.st                       # ЧРП (частотный преобразователь)
│   ├── ST_Bunker.st                    # Бункер
│   ├── ST_ConveyorBasic.st             # Базовый конвейер
│   ├── ST_ConveyorPrefabricated.st     # Сборный конвейер
│   ├── ST_Dumper.st                    # Отвалообразователь
│   ├── ST_Commands.st                  # Команды АСУТП
│   ├── ST_CommonSignals.st             # Общие сигналы
│   ├── E_LightColor.st                 # Перечисление цветов сигнальных ламп
│   └── E_StageWithPreStartAlarm.st     # Этапы работы с предпусковой сигнализацией
│
├── Functions/                          # Функции проекта
│   ├── FC_Bunker_SetLightColor.st      # Установка цвета лампы бункера
│   ├── FC_Bunker_CheckWeight.st        # Проверка веса бункера
│   ├── FC_Bunker_GetErrorMotorVibrator.st      # Ошибки вибраторов
│   ├── FC_Bunker_GetErrorMotorVibFeeder.st     # Ошибки вибропитателей
│   ├── FC_Bunker_GetErrorBunker.st     # Общие ошибки бункера
│   ├── FC_Bunker_GetErrorWeight.st     # Проверка заполненности бункеров
│   ├── FC_Conveyor_GetErrorMotor.st    # Ошибки мотора конвейера
│   ├── FC_Conveyor_GetErrorSensors.st  # Ошибки датчиков конвейера
│   ├── FC_Conveyor_GetErrorCommon.st   # Общие ошибки конвейера
│   ├── FC_Dumper_GetErrorSensors.st    # Ошибки датчиков отвалообразователя
│   ├── FC_Dumper_GetErrorCommon.st     # Общие ошибки отвалообразователя
│   ├── FC_Get_ErrorCommon.st           # Общая ошибка всего комплекса
│   ├── FC_VFD_ChangeReadMode.st        # Изменение режима чтения ЧРП
│   └── FC_MotorSyncronizedWork.st      # Синхронизация работы моторов
│
└── Library/                            # Функциональная библиотека (из newLib)
    ├── FB_UniversalSignal.st           # Универсальный сигнал
    ├── FB_UniversalAnalogSignal.st     # Универсальный аналоговый сигнал
    ├── FB_UniversalMechanism.st        # Универсальное управление механизмом
    ├── FB_FrequencyControl.st          # Управление частотой
    ├── FB_FrequencySimulation.st       # Симуляция частоты
    ├── FB_NumericChangeDetector.st     # Детектор изменения числовых значений
    ├── FB_RangeDiagnostic.st           # Диагностика диапазона
    ├── FB_PreStartAlarm.st             # Предпусковая сигнализация
    ├── E_AlarmSetpoints.st             # Перечисление уставок сигнализации
    ├── E_StateFeedback.st              # Состояния обратной связи
    ├── E_StateMechanism.st             # Состояния механизма
    ├── E_StateRemote.st                # Режимы управления
    ├── ST_AlarmSetpoints.st            # Структура уставок сигнализации
    ├── ST_PreStartAlarmSettings.st     # Настройки предпусковой сигнализации
    ├── U_ByteToWord.st                 # Union: Byte to Word
    ├── U_RealToWord.st                 # Union: Real to Word
    ├── FC_SwapBytesInWord.st           # Смена байтов в слове
    ├── FC_SwapBytesInWordArray.st      # Смена байтов в массиве слов
    └── FC_SwapWordArrayElements.st     # Смена элементов массива слов
```

### Описание папок

- **POUs/** - Program Organization Units - основные программные блоки проекта (MAIN и управляющие FB)
- **DataTypes/** - все структуры данных (ST_*) и перечисления (E_*) специфичные для проекта
- **Functions/** - вспомогательные функции (FC_*) для обработки ошибок и других операций
- **Library/** - универсальная библиотека функциональных блоков (из newLib), используемая во всем проекте

## Примеры использования

### Пример 1: Инициализация сигнала с фильтрацией дребезга

**Было (ООП):**
```iecst
Motor.fbStateKM(ixSignal := I_Contactor);
xState := Motor.fbStateKM.GetProcessedSignal();
```

**Стало (Функциональное):**
```iecst
Motor.fbStateKM(
    ixSignal := I_Contactor,
    xEnableRattlingFilter := TRUE,
    tStabilityTime := T#100MS
);
xState := Motor.fbStateKM.qxSignal;
```

### Пример 2: Управление мотором

**Было (ООП):**
```iecst
Motor.Control.SetConditionToStart(Ready);
Motor.Control.Start(cmd := StartButton.GetRtrig());
Motor.Control.Stop(cmd := StopButton.GetRtrig());
xPower := Motor.Device.GetPower();
```

**Стало (Функциональное):**
```iecst
rtStart(CLK := StartButton);
rtStop(CLK := StopButton);

Motor.Device(
    ixFeedback := Motor.fbStateKM.qxSignal,
    xEnableFeedback := TRUE,
    xStartCommand := rtStart.Q,
    xStopCommand := rtStop.Q,
    xStartCondition := Ready,
    xStopCondition := TRUE,
    xReset := FALSE
);

xPower := Motor.Device.qxPower;
Motor.qxKM_Power := Motor.Device.qxPower;
```

### Пример 3: Управление частотой ЧРП

**Было (ООП):**
```iecst
Motor.VFD.Frequency(irMaxFrequency := 50.0);
Motor.VFD.Frequency.Calculate(rStep := 1.0, xPulse := Clock);
Motor.VFD.Frequency.SetFrequencyTarget(30.0);
rCurrent := Motor.VFD.Frequency.GetCurrentFrequency();
```

**Стало (Функциональное):**
```iecst
Motor.VFD.Frequency(
    irMaxFrequency := 50.0,
    rStep := 1.0,
    xPulse := Clock,
    rTargetFrequency := 30.0,
    xDirectSet := FALSE  // Плавное изменение
);

rCurrent := Motor.VFD.Frequency.qrCurrentFrequency;
```

### Пример 4: Диагностика диапазона

**Было (ООП):**
```iecst
Motor.VFD.fbRangeDiagnostic(
    irValue := Current,
    irSetpointL := 10.0,
    irSetpointLL := 5.0,
    irSetpointH := 90.0,
    irSetpointHH := 95.0
);
xError := Motor.VFD.fbRangeDiagnostic.qxCriticalActive;
```

**Стало (Функциональное):**
```iecst
Motor.VFD.fbRangeDiagnostic(
    irValue := Current,
    irSetpointL := 10.0,
    irSetpointLL := 5.0,
    irSetpointH := 90.0,
    irSetpointHH := 95.0,
    ixEnable := TRUE  // Новый обязательный параметр
);
xError := Motor.VFD.fbRangeDiagnostic.qxCriticalActive;
```

## Миграция с ООП версии

Для миграции существующего кода:

1. Замените все функциональные блоки старой библиотеки на соответствующие из `newLib/`
2. Удалите все вызовы методов (`.Get...()`, `.Set...()`) и используйте прямой доступ к переменным
3. Замените `FB_SignalWithTrigger` на простые `BOOL` для команд или на `FB_UniversalSignal` для сигналов с обработкой
4. Удалите объекты `Control : FB_BasicControl` и используйте прямое управление через `FB_UniversalMechanism`
5. Обновите методы контроллеров согласно новым паттернам

## Дополнительная информация

Подробное описание функциональной библиотеки см. в `newLib/README.md` родительского проекта.

## Автор

Переписано с использованием Claude Code для перехода на функциональное программирование ПЛК.
