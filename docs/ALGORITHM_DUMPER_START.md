# Алгоритм включения отвалообразователя

## Общая структура

Алгоритм включения отвалообразователя реализован в функциональном блоке `FB_DumperControl` и использует конечный автомат с четырьмя основными стадиями управления через перечисление `E_StageWithPreStartAlarm`.

### Переменные состояния функционального блока

**VAR (внутренние переменные):**
```iecst
fbConveyorPreStartAlarm : FB_PreStartAlarm;  // Блок предпусковой сигнализации
STAGE : E_StageWithPreStartAlarm := IDLE;    // Текущая стадия автомата

// Целевые частоты для моторов
rTargetFreqConv1 : REAL := 0.0;              // Целевая частота мотора конвейера 1
rTargetFreqConv2 : REAL := 0.0;              // Целевая частота мотора конвейера 2
rTargetFreqRot1 : REAL := 0.0;               // Целевая частота мотора поворота 1
rTargetFreqRot2 : REAL := 0.0;               // Целевая частота мотора поворота 2

// Переменные синхронизации моторов конвейера
xVFDsReady : BOOL;                           // Оба ЧРП конвейера готовы и запущены
xFrequenciesSynchronized : BOOL;             // Частоты синхронизированы в пределах допуска
xConditionToProceed : BOOL;                  // Общее условие для продолжения разгона

simInit : BOOL;                              // Флаг инициализации симуляции
i : INT;                                     // Счётчик циклов
```

Эти переменные используются для управления синхронным разгоном двух моторов конвейера и предотвращения их рассинхронизации.

## Состав оборудования отвалообразователя

### Моторы конвейера
- **2 электродвигателя привода конвейера** (22 кВт) с обратной связью
  - Контактор (KM) для каждого мотора
  - Автоматический выключатель (QF)
  - Датчик перегрева статора
  - Частотный преобразователь (VFD/ЧРП) для каждого мотора
  - Токовая диагностика

### Моторы поворота
- **2 электродвигателя привода поворота** (3 кВт) с реверсом
  - Контактор (KM) для каждого мотора
  - Автоматический выключатель (QF)
  - Датчик перегрева статора
  - Частотный преобразователь (VFD/ЧРП)
  - Датчик статуса вращения
  - Токовая диагностика

### Датчики безопасности
- **4 датчика ZQ** - контроль схода ленты (Alarm и Warning)
- **4 датчика HQ** - кабель-тросовые выключатели (аварийная остановка)
- **2 датчика SQ** - контроль ограждения барабана
- **Датчик GS1** - контроль заштыбовки (засорения)
- **Датчик YS1** - контроль продольного разрыва ленты
- **2 концевых выключателя** - крайние положения (левое/правое)

### Управление
- **Панель местного управления (ПМУ):**
  - Кнопка "Пуск"
  - Кнопка "Стоп"
  - Кнопка "Аварийная остановка"
  - Кнопки поворота влево/вправо
  - Переключатель режима (Местный/Дистанционный)

- **Светозвуковая сигнализация:**
  - Световая лампа (HL)
  - Звуковая сирена (HA)

## Этапы алгоритма включения

### 1. IDLE (Ожидание команды запуска)

**Действия на этой стадии:**
- Сброс всех целевых частот моторов в ноль:
  ```
  rTargetFreqConv1 := 0.0
  rTargetFreqConv2 := 0.0
  rTargetFreqRot1 := 0.0
  rTargetFreqRot2 := 0.0
  ```
- Вся обработка сигналов и диагностика работают в фоновом режиме
- Обновляются состояния всех датчиков через `FB_UniversalSignal` с фильтрацией дребезга
- Контакторы и ЧРП находятся в выключенном состоянии

**Условие перехода:**
- Получение команды запуска: `xStart := TRUE` (от MAIN программы или оператора)
- Переход в стадию `PRESTART_ALARM`

---

### 2. PRESTART_ALARM (Предпусковая сигнализация)

**Назначение:** Предупредить персонал о предстоящем пуске оборудования для обеспечения безопасности.

**Действия на этой стадии:**

Включается функциональный блок предпусковой сигнализации `FB_PreStartAlarm`:

```iecst
fbConveyorPreStartAlarm(
    ixStart := (STAGE = PRESTART_ALARM),
    ixStop := FALSE,
    itFirstSignal := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL,
    itPauseAfterFirst := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE,
    itSecondSignal := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL,
    itPauseAfterSecond := DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE,
    qxAlarmPower => Dumper.xHLA
);
```

**Последовательность сигналов:**
1. **Первый сигнал** - включается светозвуковая сигнализация (HLA) на время `TIME_FIRST_SIGNAL` (по умолчанию 3 секунды)
2. **Пауза 1** - сигнализация выключается на время `TIME_FIRST_SIGNAL_PAUSE` (по умолчанию 3 секунды)
3. **Второй сигнал** - повторное включение сигнализации на время `TIME_SECOND_SIGNAL` (по умолчанию 3 секунды)
4. **Пауза 2** - сигнализация выключается на время `TIME_SECOND_SIGNAL_PAUSE` (по умолчанию 3 секунды)
5. Флаг завершения `qxComplete` устанавливается в TRUE

**Условие перехода:**
- Когда `fbConveyorPreStartAlarm.qxComplete = TRUE`
- Переход в стадию `STARTING`

**Примечание:** Если `DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.OPTION_ENABLE = FALSE`, этот этап может быть пропущен (все времена = 0).

---

### 3. STARTING (Процесс запуска)


#### 3.1. Запуск контакторов моторов конвейера

**Команды:**
```iecst
Dumper.MotorConveyor[1].Device.xStartCommand := TRUE;
Dumper.MotorConveyor[2].Device.xStartCommand := TRUE;
```

**Обработка через FB_UniversalMechanism:**
- Проверяется `xStartCondition` (условие для запуска):
  - Автоматический выключатель (QF) включен
  - Нет перегрева статора
  - Нет других ошибок
- Устанавливается выход `qxPower := TRUE`
- Выходной сигнал подается на контактор: `qxKM_Power := Device.qxPower`
- Ожидается сигнал обратной связи от контактора `fbStateKM.qxSignal`
- Проверяется состояние обратной связи через `FB_UniversalMechanism`:
  - `qxActive` - контактор включен и есть обратная связь (норма)
  - `qxError_NoFeedback` - команда подана, но обратной связи нет (ошибка)
  - `qxError_UnexpectedFeedback` - обратная связь есть без команды (ошибка)

#### 3.2. Запуск частотных преобразователей (ЧРП)

**Последовательность:**

1. **Проверка готовности контакторов:**
   ```iecst
   Dumper.MotorConveyor[1].VFD.Device.xStartCommand := Dumper.MotorConveyor[1].Device.qxActive;
   Dumper.MotorConveyor[2].VFD.Device.xStartCommand := Dumper.MotorConveyor[2].Device.qxActive;
   ```
   - ЧРП запускается только после успешного включения контактора
   - `qxActive` означает, что контактор включен И получена обратная связь

2. **Управление ЧРП через FB_UniversalMechanism:**
   ```iecst
   Motor.VFD.Device(
       ixFeedback := Motor.VFD.fbStateIsWorking.qxSignal,
       xEnableFeedback := TRUE
   );
   Motor.VFD.qxStart := Motor.VFD.Device.qxPower;
   ```
   - Проверяется сигнал "ЧРП в работе" (`fbStateIsWorking`)
   - Устанавливается дискретный выход запуска ЧРП

#### 3.3. Управление частотой вращения

**Установка целевой частоты:**
```iecst
rTargetFreqConv1 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
rTargetFreqConv2 := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
```
- Глобальная константа `MOTOR_FREQUENCY_DUMPER_CONVEYOR` по умолчанию = 50 Гц

**Механизм синхронизации моторов:**

Перед обработкой частоты выполняется проверка синхронизации двух моторов конвейера:

```iecst
// Проверка что оба ЧРП конвейера готовы и запущены
xVFDsReady := Dumper.MotorConveyor[1].VFD.Device.qxActive
           AND Dumper.MotorConveyor[2].VFD.Device.qxActive;

// Проверка синхронизации текущих частот (разница не превышает допуск)
xFrequenciesSynchronized := ABS(Dumper.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency
                              - Dumper.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency)
                              <= VFD_FREQUENCY_SYNC_TOLERANCE;

// Общее условие для продолжения плавного разгона
xConditionToProceed := xVFDsReady AND xFrequenciesSynchronized;
```

**Параметры синхронизации:**
- `VFD_FREQUENCY_SYNC_TOLERANCE` = 1.5 Гц - допустимая разница частот между моторами
- `xVFDsReady` - оба ЧРП должны быть активны (`qxActive = TRUE`)
- `xFrequenciesSynchronized` - разница частот должна быть ≤ 1.5 Гц

**Обработка через FB_FrequencyControl:**
```iecst
Dumper.MotorConveyor[1].VFD.Frequency(
    irMaxFrequency := VFD_FREQUENCY_MAX,           // 50 Гц (максимум)
    irStep := VFD_FREQUENCY_STEP,                  // 2 Гц (шаг изменения)
    rTargetFrequency := rTargetFreqConv1,          // 50 Гц (целевая)
    xPulse := PULSE_RTRIG.Q,                       // Тактовый сигнал ~100 мс
    xConditionToProceed := xConditionToProceed     // Синхронизация с мотором 2
);

Dumper.MotorConveyor[2].VFD.Frequency(
    irMaxFrequency := VFD_FREQUENCY_MAX,
    irStep := VFD_FREQUENCY_STEP,
    rTargetFrequency := rTargetFreqConv2,
    xPulse := PULSE_RTRIG.Q,
    xConditionToProceed := xConditionToProceed     // Синхронизация с мотором 1
);
```

**Механизм плавного разгона с синхронизацией:**
1. Блок `FB_FrequencyControl` каждый импульс `xPulse` (примерно каждые 200 мс из GLOBAL.PULSE):
   - **Проверяет `xConditionToProceed`** - оба ЧРП активны И частоты синхронизированы
   - Если условие **FALSE** - разгон приостанавливается (частота не меняется)
   - Если условие **TRUE**:
     - Если текущая частота < целевой на величину больше шага:
       - Увеличивает частоту на `irStep` (2 Гц)
     - Если текущая частота > целевой:
       - Уменьшает частоту на `irStep`
     - Если достигнута целевая частота (в пределах допуска):
       - Устанавливает `qxTargetReached := TRUE`

2. Выходная частота передается на ЧРП:
   ```iecst
   Motor.VFD.qrOutFrequency := Motor.VFD.Frequency.qrCurrentFrequency;
   ```

3. **Разгон с 0 до 50 Гц с синхронизацией:**
   - Шаг: 2 Гц
   - Период импульса: ~200 мс
   - Количество шагов: 50 / 2 = 25
   - Время разгона (идеальное): 25 × 200 мс = **5 секунд**
   - **Реальное время разгона:** может быть больше из-за пауз при десинхронизации
   - Если разница частот превышает 1.5 Гц - оба мотора приостанавливают разгон до синхронизации

**Принцип работы синхронизации:**
- Моторы разгоняются **одновременно и синхронно**
- Если один мотор отстает более чем на 1.5 Гц - **оба мотора приостанавливают разгон**
- Медленный мотор догоняет быстрый (симуляция продолжает изменять `rActualFrequency`)
- Когда разница становится ≤ 1.5 Гц - разгон возобновляется
- Это предотвращает **механическую рассинхронизацию** конвейерной ленты

#### 3.4. Симуляция частоты (режим SIMULATION)

В режиме симуляции используется `FB_FrequencySimulation`:
```iecst
Dumper.MotorConveyor[1].VFD.fbSimFreq(
    xProceed := Motor.VFD.fbStateIsWorking.qxSignal,  // ЧРП включен
    irTarget := Motor.VFD.Frequency.qrCurrentFrequency, // Целевая частота
    irStep := 0.2,                                     // Шаг симуляции
    irInputModule => Motor.VFD.rActualFrequency       // Фактическая частота
);
```
- Симулирует реальное поведение ЧРП
- Плавно изменяет `rActualFrequency` к значению `qrCurrentFrequency`

#### 3.5. Мониторинг достижения рабочей частоты

**Проверка условия перехода:**
```iecst
IF Dumper.MotorConveyor[1].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
   AND Dumper.MotorConveyor[2].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
THEN
    STAGE := WORK;
END_IF;
```

**Параметры:**
- `MOTOR_FREQUENCY_DUMPER_CONVEYOR` = 50 Гц (целевая)
- `VFD_FREQUENCY_INACCURANCY` = 0.5 Гц (допуск)
- Условие: `rActualFrequency >= 49.5 Гц` для обоих моторов

**Условие перехода:**
- Оба мотора достигли частоты ≥ 49.5 Гц
- Переход в стадию `WORK`

---

### 4. WORK (Нормальная работа)

**Действия на этой стадии:**
- Отвалообразователь работает в штатном режиме
- Частота поддерживается на уровне 50 Гц
- Флаг состояния: `Dumper.xStateEnable := TRUE`
- Флаг процесса запуска: `Dumper.xStateStarting := FALSE`
- Все системы диагностики активны:
  - Контроль тока моторов через `FB_RangeDiagnostic`
  - Мониторинг датчиков безопасности
  - Контроль обратной связи от контакторов и ЧРП
  - Проверка перегрева статоров

**Дополнительные функции:**
- Управление поворотом отвалообразователя (через MotorRotation[1..2])
- Контроль крайних положений через концевые выключатели
- Обработка команд от ПМУ и SCADA

---

## Диагностика и контроль на всех этапах

### Непрерывная обработка сигналов

**1. Обработка дискретных сигналов через FB_UniversalSignal:**
```iecst
Motor.fbStateKM(
    ixSignal := I_ContactorFeedback,
    xEnableRattlingFilter := TRUE,
    tStabilityTime := T#100MS
);
```
- Фильтрация дребезга контактов (100 мс)
- Детектирование фронтов (qxRisingEdge, qxFallingEdge)
- Обработанный сигнал доступен через `qxSignal`

**2. Диагностика токов через FB_RangeDiagnostic:**
```iecst
Motor.VFD.fbRangeDiagnostic(
    irValue := Motor.VFD.wMotorCurrent.rTag,
    irSetpointL := MOTOR_CONVEYOR_CURRENT_POINTS.L_Value,
    irSetpointLL := MOTOR_CONVEYOR_CURRENT_POINTS.LL_Value,
    irSetpointH := MOTOR_CONVEYOR_CURRENT_POINTS.H_Value,
    irSetpointHH := MOTOR_CONVEYOR_CURRENT_POINTS.HH_Value,
    ixEnable := TRUE
);
```
- Контроль четырех уровней: LL (критически низкий), L (низкий), H (высокий), HH (критически высокий)
- Вывод: `qxCriticalActive` - есть критическое отклонение

**3. Проверка безопасности:**
- Датчики ZQ (сход ленты): сигнал тревоги = TRUE при сходе
- Датчики HQ (трос. выключатели): нормальное состояние = TRUE
- Датчики SQ (ограждения): нормальное состояние = TRUE
- Датчик GS1 (заштыбовка): нормальное состояние = TRUE
- Датчик YS1 (разрыв): нормальное состояние = TRUE

### Функции проверки ошибок

Используются отдельные функции для агрегации ошибок:

**FC_Dumper_GetErrorSensors:**
```iecst
Dumper.fbZQAlarm[1..4].qxSignal    // Сход ленты
OR NOT Dumper.fbHQ_IsOk[1..4].qxSignal    // Аварийный стоп
OR NOT Dumper.fbSQ_IsOk[1..2].qxSignal    // Ограждения
OR NOT Dumper.fbGS1.qxSignal               // Заштыбовка
OR NOT Dumper.fbYS1.qxSignal               // Разрыв ленты
```

**FC_Dumper_GetErrorCommon:**
- Объединяет все ошибки датчиков
- Проверяет состояние контакторов и ЧРП
- Возвращает общий флаг ошибки отвалообразователя

---

## Временная диаграмма запуска

```
Время (сек)  |  Стадия          |  Действие
-------------|------------------|----------------------------------
0            |  IDLE            |  Получена команда xStart
0            |  PRESTART_ALARM  |  Первый сигнал сирены (3 сек)
3            |  PRESTART_ALARM  |  Пауза 1 (3 сек)
6            |  PRESTART_ALARM  |  Второй сигнал сирены (3 сек)
9            |  PRESTART_ALARM  |  Пауза 2 (3 сек)
12           |  STARTING        |  Включение контакторов
12.1         |  STARTING        |  Получена обратная связь от KM
12.1         |  STARTING        |  Запуск ЧРП
12.2         |  STARTING        |  ЧРП готов, начало синхронного разгона
12.2         |  STARTING        |  Частота: 0 → 2 Гц (оба мотора)
12.4         |  STARTING        |  Частота: 2 → 4 Гц (синхронно)
...          |  ...             |  Проверка синхронизации (≤1.5 Гц)
17.0         |  STARTING        |  Частота: 48 → 50 Гц (синхронно)
17.2+        |  WORK            |  Достигнута рабочая частота 50 Гц
-------------|------------------|----------------------------------
Итого: ~17+ секунд от команды до рабочего режима
(время может увеличиться при десинхронизации моторов)
```

**Примечание:** С механизмом синхронизации время разгона может быть больше 5 секунд, если один из моторов отстает более чем на 1.5 Гц от другого. В этом случае оба мотора приостанавливают изменение частоты до восстановления синхронизации.

---

## Интеграция с основной программой (MAIN.st)

### Вызов в MAIN.st:
```iecst
fbDumper(
    Dumper := stDumper,
    xStart := xStartDumper,
    eStage => eDumperStage
);
```

### Автоматическая последовательность в MAIN:
```
CASE AUTO_STEP OF
    START_DUMPER:
        IF eDumperStage <> E_StageWithPreStartAlarm.WORK THEN
            xStartDumper := TRUE;  // Подать команду запуска
        ELSE
            xStartDumper := FALSE; // Сбросить команду
            AUTO_STEP := START_CONV; // Перейти к запуску конвейера
        END_IF;
```

---

## Условия для успешного запуска

**Обязательные условия:**
1.  Все автоматические выключатели (QF) включены
2.  Нет перегрева статоров моторов
3.  ЧРП готовы к пуску (fbStateRdyToStart = TRUE)
4.  ЧРП не в состоянии ошибки (fbStateFailure = FALSE)
5.  Все датчики безопасности в норме:
   - Нет схода ленты (ZQ)
   - Тросовые выключатели не сработали (HQ)
   - Ограждения закрыты (SQ)
   - Нет заштыбовки (GS1)
   - Нет разрыва ленты (YS1)
6.  Нет аварийной остановки (кнопка Emergency Stop)

**Если хотя бы одно условие не выполнено:**
- Блок `FB_UniversalMechanism` не даст команду на включение
- `xStartCondition := FALSE`
- Контактор не включится
- Переход в стадию WORK не произойдет

---

## Механизм синхронизации моторов конвейера

### Назначение

Два мотора конвейера (MotorConveyor[1] и MotorConveyor[2]) приводят в движение одну конвейерную ленту. Рассинхронизация их скоростей может привести к:
- Неравномерной нагрузке на конвейерную ленту
- Механическому износу подшипников и роликов
- Проскальзыванию или разрыву ленты
- Повышенному энергопотреблению

Для предотвращения этих проблем реализован **механизм синхронизации частот** моторов.

### Алгоритм синхронизации

**Шаг 1: Проверка готовности обоих ЧРП**
```iecst
xVFDsReady := Dumper.MotorConveyor[1].VFD.Device.qxActive
           AND Dumper.MotorConveyor[2].VFD.Device.qxActive;
```
- Оба ЧРП должны быть запущены (`qxActive = TRUE`)
- Если хотя бы один ЧРП не активен - разгон не начнётся

**Шаг 2: Проверка синхронизации текущих частот**
```iecst
xFrequenciesSynchronized := ABS(Dumper.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency
                              - Dumper.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency)
                              <= VFD_FREQUENCY_SYNC_TOLERANCE;
```
- Вычисляется абсолютная разница между текущими частотами моторов
- Допустимая разница: `VFD_FREQUENCY_SYNC_TOLERANCE = 1.5 Гц`
- Если разница ≤ 1.5 Гц - моторы синхронизированы

**Шаг 3: Формирование условия продолжения разгона**
```iecst
xConditionToProceed := xVFDsReady AND xFrequenciesSynchronized;
```
- Разгон продолжается только если **оба условия TRUE**
- Это условие передаётся в `FB_FrequencyControl` для обоих моторов

### Сценарии работы

**Сценарий 1: Нормальный синхронный разгон**
1. Оба ЧРП запущены и активны
2. Частоты обоих моторов: 0 Гц
3. Разница частот: 0 Гц ≤ 1.5 Гц ✅
4. `xConditionToProceed = TRUE` → оба мотора увеличивают частоту на 2 Гц
5. Частоты: 2 Гц и 2 Гц
6. Цикл повторяется до достижения 50 Гц

**Сценарий 2: Десинхронизация (один мотор отстаёт)**
1. Мотор 1: 10 Гц, Мотор 2: 8 Гц
2. Разница: |10 - 8| = 2 Гц > 1.5 Гц ❌
3. `xFrequenciesSynchronized = FALSE`
4. `xConditionToProceed = FALSE` → **разгон приостановлен**
5. FB_FrequencyControl **не меняет** `qrCurrentFrequency` для обоих моторов
6. Симуляция продолжает работу: `rActualFrequency` мотора 2 догоняет `qrCurrentFrequency`
7. Когда `rActualFrequency` мотора 2 достигает ~9 Гц:
   - Разница: |10 - 8| = 2 Гц (по-прежнему > 1.5 Гц)
8. Когда `rActualFrequency` мотора 2 достигает ~9.5 Гц:
   - Разница становится ≤ 1.5 Гц ✅
9. `xConditionToProceed = TRUE` → разгон возобновляется

**Сценарий 3: Один ЧРП не запустился**
1. Мотор 1: `qxActive = TRUE`, Мотор 2: `qxActive = FALSE`
2. `xVFDsReady = FALSE`
3. `xConditionToProceed = FALSE`
4. Разгон **не начнётся** до запуска обоих ЧРП
5. Система ожидает активации второго ЧРП

### Настройка

Для изменения допуска синхронизации редактируйте константу в `GLOBAL.st`:
```iecst
VFD_FREQUENCY_SYNC_TOLERANCE : REAL := 1.5; // Допустимая разница частот (Гц)
```
