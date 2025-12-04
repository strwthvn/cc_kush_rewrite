# Использование управления частотой в ST_VFD

Данный документ описывает использование двух ключевых элементов управления частотой в структуре ST_VFD:
- `qrOutFrequency : REAL` - Выходная частота
- `Frequency : FB_FrequencyControl` - Функциональный блок управления частотой

## Структура ST_VFD (DataTypes/ST_VFD.st)

```iecst
TYPE ST_VFD :
STRUCT
    // Команды AO
    qrOutFrequency : REAL; // Выходная частота

    // Объекты устройства
    Frequency : FB_FrequencyControl; // Управление частотой
END_STRUCT
END_TYPE
```

---

## 1. Основной паттерн использования

### Инициализация и управление (POUs/FB_ConveyorControl.st)

```iecst
// Моторы конвейера - вызов FB_FrequencyControl
Conveyor.MotorConveyor[1].VFD.Frequency(
    irMaxFrequency := VFD_FREQUENCY_MAX,
    irStep := VFD_FREQUENCY_STEP,
    rTargetFrequency := rTargetFreqConv1,
    xPulse := PULSE_RTRIG.Q,
    xConditionToProceed := xConditionToProceed // Синхронизация с мотором 2
);

// Запись текущей частоты в выходную переменную
Conveyor.MotorConveyor[1].VFD.qrOutFrequency := Conveyor.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency;
```

**Расположение в коде:**
- POUs/FB_ConveyorControl.st:241-248
- POUs/FB_ConveyorControl.st:250-257

### Аналогично для отвалообразователя (POUs/FB_DumperControl.st)

```iecst
// Моторы конвейера отвалообразователя
Dumper.MotorConveyor[1].VFD.Frequency(
    irMaxFrequency := VFD_FREQUENCY_MAX,
    irStep := VFD_FREQUENCY_STEP,
    rTargetFrequency := rTargetFreqConv1,
    xPulse := PULSE_RTRIG.Q,
    xConditionToProceed := xConditionToProceed
);
Dumper.MotorConveyor[1].VFD.qrOutFrequency := Dumper.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency;

// Моторы поворота
Dumper.MotorRotation[1].VFD.Frequency(
    irMaxFrequency := VFD_FREQUENCY_MAX,
    irStep := VFD_FREQUENCY_STEP,
    rTargetFrequency := rTargetFreqRot1,
    xPulse := PULSE_RTRIG.Q,
    xConditionToProceed := TRUE
);
Dumper.MotorRotation[1].VFD.qrOutFrequency := Dumper.MotorRotation[1].VFD.Frequency.qrCurrentFrequency;
```

**Расположение в коде:**
- POUs/FB_DumperControl.st:333-340
- POUs/FB_DumperControl.st:342-349
- POUs/FB_DumperControl.st:352-359
- POUs/FB_DumperControl.st:361-368

---

## 2. Синхронизация моторов конвейера

### Проверка синхронизации частот (POUs/FB_ConveyorControl.st:228-234)

```iecst
// Проверка что оба ЧРП конвейера готовы и запущены
xVFDsReady := Conveyor.MotorConveyor[1].VFD.Device.qxActive
           AND Conveyor.MotorConveyor[2].VFD.Device.qxActive;

// Проверка синхронизации текущих частот (разница не превышает допуск)
xFrequenciesSynchronized := ABS(Conveyor.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency
                              - Conveyor.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency)
                              <= VFD_FREQUENCY_SYNC_TOLERANCE;

// Общее условие для продолжения плавного разгона
// Разгон продолжается только если оба ЧРП запущены И частоты синхронизированы
xConditionToProceed := xVFDsReady AND xFrequenciesSynchronized;
```

### Аналогично для отвалообразователя (POUs/FB_DumperControl.st:320-326)

```iecst
xFrequenciesSynchronized := ABS(Dumper.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency
                              - Dumper.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency)
                              <= VFD_FREQUENCY_SYNC_TOLERANCE;

xConditionToProceed := xVFDsReady AND xFrequenciesSynchronized;
```

---

## 3. Использование в аварийном останове (POUs/FB_EmergencyStopProcess.st)

### Остановка бункеров

```iecst
// Этап 1: Остановка бункеров
FOR i := 1 TO 3 DO
    // Остановка моторов вибраторов (4 шт на бункер)
    FOR j := 1 TO 4 DO
        Bunker[i].MotorVibrator[j].qxKM_Power := FALSE;
        Bunker[i].MotorVibrator[j].VFD.qxStart := FALSE;
        Bunker[i].MotorVibrator[j].VFD.Frequency.rTargetFrequency := 0.0;
        Bunker[i].MotorVibrator[j].VFD.qrOutFrequency := 0.0;
    END_FOR

    // Остановка моторов вибропитателей (2 шт на бункер)
    FOR j := 1 TO 2 DO
        Bunker[i].MotorVibFeeder[j].qxKM_Power := FALSE;
        Bunker[i].MotorVibFeeder[j].VFD.qxStart := FALSE;
        Bunker[i].MotorVibFeeder[j].VFD.Frequency.rTargetFrequency := 0.0;
        Bunker[i].MotorVibFeeder[j].VFD.qrOutFrequency := 0.0;
    END_FOR
END_FOR
```

**Расположение в коде:** POUs/FB_EmergencyStopProcess.st:43-56

### Остановка конвейера

```iecst
// Этап 2: Остановка конвейера
FOR j := 1 TO 2 DO
    Conveyor.MotorConveyor[j].qxKM_Power := FALSE;
    Conveyor.MotorConveyor[j].VFD.qxStart := FALSE;
    Conveyor.MotorConveyor[j].VFD.Frequency.rTargetFrequency := 0.0;
    Conveyor.MotorConveyor[j].VFD.qrOutFrequency := 0.0;
END_FOR
```

**Расположение в коде:** POUs/FB_EmergencyStopProcess.st:96-99

### Остановка отвалообразователя

```iecst
// Этап 3: Остановка отвалообразователя
// Моторы конвейера
FOR j := 1 TO 2 DO
    Dumper.MotorConveyor[j].qxKM_Power := FALSE;
    Dumper.MotorConveyor[j].VFD.qxStart := FALSE;
    Dumper.MotorConveyor[j].VFD.Frequency.rTargetFrequency := 0.0;
    Dumper.MotorConveyor[j].VFD.qrOutFrequency := 0.0;
END_FOR

// Моторы поворота
FOR j := 1 TO 2 DO
    Dumper.MotorRotation[j].qxKM_Power := FALSE;
    Dumper.MotorRotation[j].VFD.qxStart := FALSE;
    Dumper.MotorRotation[j].VFD.Frequency.rTargetFrequency := 0.0;
    Dumper.MotorRotation[j].VFD.qrOutFrequency := 0.0;
    Dumper.MotorRotation[j].qxVFDReverseStart := FALSE;
END_FOR
```

**Расположение в коде:**
- POUs/FB_EmergencyStopProcess.st:116-119 (конвейер)
- POUs/FB_EmergencyStopProcess.st:124-127 (поворот)

---

## 4. Использование в симуляции (Library/FB_Simulation.st)

### Симуляция частоты отвалообразователя

```iecst
// Симуляция частоты ЧРП моторов конвейера отвалообразователя
Dumper.MotorConveyor[1].VFD.fbSimFreq(
    xProceed := Dumper.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal,
    irTarget := Dumper.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency,
    irStep := 0.2,
    irInputModule => Dumper.MotorConveyor[1].VFD.rActualFrequency
);

Dumper.MotorConveyor[2].VFD.fbSimFreq(
    xProceed := Dumper.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal,
    irTarget := Dumper.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency,
    irStep := 0.2,
    irInputModule => Dumper.MotorConveyor[2].VFD.rActualFrequency
);

// Симуляция частоты ЧРП моторов поворота отвалообразователя
Dumper.MotorRotation[1].VFD.fbSimFreq(
    xProceed := Dumper.MotorRotation[1].VFD.fbStateIsWorking.qxSignal,
    irTarget := Dumper.MotorRotation[1].VFD.Frequency.qrCurrentFrequency,
    irStep := 0.2,
    irInputModule => Dumper.MotorRotation[1].VFD.rActualFrequency
);

Dumper.MotorRotation[2].VFD.fbSimFreq(
    xProceed := Dumper.MotorRotation[2].VFD.fbStateIsWorking.qxSignal,
    irTarget := Dumper.MotorRotation[2].VFD.Frequency.qrCurrentFrequency,
    irStep := 0.2,
    irInputModule => Dumper.MotorRotation[2].VFD.rActualFrequency
);
```

**Расположение в коде:** Library/FB_Simulation.st:218-245

### Симуляция конвейера

```iecst
Conveyor.MotorConveyor[1].VFD.fbSimFreq(
    xProceed := Conveyor.MotorConveyor[1].VFD.fbStateIsWorking.qxSignal,
    irTarget := Conveyor.MotorConveyor[1].VFD.Frequency.qrCurrentFrequency,
    irStep := 0.2,
    irInputModule => Conveyor.MotorConveyor[1].VFD.rActualFrequency
);

Conveyor.MotorConveyor[2].VFD.fbSimFreq(
    xProceed := Conveyor.MotorConveyor[2].VFD.fbStateIsWorking.qxSignal,
    irTarget := Conveyor.MotorConveyor[2].VFD.Frequency.qrCurrentFrequency,
    irStep := 0.2,
    irInputModule => Conveyor.MotorConveyor[2].VFD.rActualFrequency
);
```

**Расположение в коде:** Library/FB_Simulation.st:284-296

### Симуляция бункеров

```iecst
FOR b := 1 TO 3 BY 1 DO
    // Вибропитатели (MotorVibFeeder[1..2])
    FOR m := 1 TO 2 BY 1 DO
        // Симуляция частоты ЧРП вибропитателя
        Bunker[b].MotorVibFeeder[m].VFD.fbSimFreq(
            xProceed := Bunker[b].MotorVibFeeder[m].VFD.fbStateIsWorking.qxSignal,
            irTarget := Bunker[b].MotorVibFeeder[m].VFD.Frequency.qrCurrentFrequency,
            irStep := 0.2,
            irInputModule => Bunker[b].MotorVibFeeder[m].VFD.rActualFrequency
        );
    END_FOR;

    // Вибраторы (MotorVibrator[1..4])
    FOR m := 1 TO 4 BY 1 DO
        // Симуляция частоты ЧРП вибратора
        Bunker[b].MotorVibrator[m].VFD.fbSimFreq(
            xProceed := Bunker[b].MotorVibrator[m].VFD.fbStateIsWorking.qxSignal,
            irTarget := Bunker[b].MotorVibrator[m].VFD.Frequency.qrCurrentFrequency,
            irStep := 0.2,
            irInputModule => Bunker[b].MotorVibrator[m].VFD.rActualFrequency
        );
    END_FOR;
END_FOR;
```

**Расположение в коде:** Library/FB_Simulation.st:320-358

---

## 5. Передача данных в SCADA (docs/SCADA_RealUnions_Init.st)

### Отвалообразователь

```iecst
// Моторы конвейера
uDumperMotorConveyor1OutFreq.rTag := stDumper.MotorConveyor[1].VFD.qrOutFrequency;
uDumperMotorConveyor2OutFreq.rTag := stDumper.MotorConveyor[2].VFD.qrOutFrequency;

// Моторы поворота
uDumperMotorRotation1OutFreq.rTag := stDumper.MotorRotation[1].VFD.qrOutFrequency;
uDumperMotorRotation2OutFreq.rTag := stDumper.MotorRotation[2].VFD.qrOutFrequency;
```

**Расположение в коде:** docs/SCADA_RealUnions_Init.st:80-96

### Конвейер

```iecst
uConveyorMotor1OutFreq.rTag := stConveyor.MotorConveyor[1].VFD.qrOutFrequency;
uConveyorMotor2OutFreq.rTag := stConveyor.MotorConveyor[2].VFD.qrOutFrequency;
```

**Расположение в коде:** docs/SCADA_RealUnions_Init.st:102-107

### Бункеры

```iecst
// Бункер 1
uBunker1Vibrator1OutFreq.rTag := stBunker[1].MotorVibrator[1].VFD.qrOutFrequency;
uBunker1Vibrator2OutFreq.rTag := stBunker[1].MotorVibrator[2].VFD.qrOutFrequency;
uBunker1Vibrator3OutFreq.rTag := stBunker[1].MotorVibrator[3].VFD.qrOutFrequency;
uBunker1Vibrator4OutFreq.rTag := stBunker[1].MotorVibrator[4].VFD.qrOutFrequency;

// Бункер 2
uBunker2Vibrator1OutFreq.rTag := stBunker[2].MotorVibrator[1].VFD.qrOutFrequency;
uBunker2Vibrator2OutFreq.rTag := stBunker[2].MotorVibrator[2].VFD.qrOutFrequency;
uBunker2Vibrator3OutFreq.rTag := stBunker[2].MotorVibrator[3].VFD.qrOutFrequency;
uBunker2Vibrator4OutFreq.rTag := stBunker[2].MotorVibrator[4].VFD.qrOutFrequency;

// Бункер 3
uBunker3Vibrator1OutFreq.rTag := stBunker[3].MotorVibrator[1].VFD.qrOutFrequency;
// ... и так далее
```

**Расположение в коде:** docs/SCADA_RealUnions_Init.st:130-172

---

## 6. Проверка достижения целевой частоты

### Переход из STARTING в WORK (POUs/FB_ConveyorControl.st:206-210)

```iecst
// Переход в режим WORK при достижении целевой частоты
IF Conveyor.MotorConveyor[1].VFD.rActualFrequency >= MOTOR_FREQUENCY_CONVEYOR - VFD_FREQUENCY_INACCURANCY
    AND Conveyor.MotorConveyor[2].VFD.rActualFrequency >= MOTOR_FREQUENCY_CONVEYOR - VFD_FREQUENCY_INACCURANCY
THEN
    STAGE := WORK;
END_IF;
```

**Расположение в коде:** POUs/FB_ConveyorControl.st:206-210

### Аналогично для отвалообразователя (POUs/FB_DumperControl.st:300-305)

```iecst
IF Dumper.MotorConveyor[1].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
    AND Dumper.MotorConveyor[2].VFD.rActualFrequency >= MOTOR_FREQUENCY_DUMPER_CONVEYOR - VFD_FREQUENCY_INACCURANCY
THEN
    STAGE := WORK;
END_IF;
```

**Расположение в коде:** POUs/FB_DumperControl.st:300-305

---

## Резюме

### Назначение qrOutFrequency

1. **Запись текущей частоты** из `Frequency.qrCurrentFrequency`
2. **Передача в SCADA** через unions (U_RealToWord) для Modbus
3. **Обнуление** при аварийном останове

### Назначение Frequency (FB_FrequencyControl)

1. **Плавное управление частотой** с настраиваемым шагом (irStep)
2. **Синхронизация моторов** через параметр `xConditionToProceed`
3. **Чтение текущей частоты** через `qrCurrentFrequency`
4. **Задание целевой частоты** через `rTargetFrequency`
5. **Источник данных для симуляции** (irTarget в FB_FrequencySimulation)

### Типичный flow управления

```
1. Задается целевая частота (rTargetFrequency)
2. FB_FrequencyControl плавно разгоняет до цели
3. Текущая частота записывается в qrOutFrequency
4. qrOutFrequency передается в SCADA
5. В симуляции Frequency.qrCurrentFrequency → fbSimFreq → rActualFrequency
```
