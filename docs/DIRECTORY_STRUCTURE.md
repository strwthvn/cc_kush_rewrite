# Структура директории проекта

```
newProject/
├── POUs/                           # Program Organization Units
│   ├── MAIN.st                     # Главная программа
│   ├── GLOBAL.st                   # Глобальные переменные
│   ├── FB_BunkerControl.st         # Управление бункером
│   ├── FB_ConveyorControl.st       # Управление конвейером
│   ├── FB_ConveyorWeight.st        # Обработка данных весов конвейера (Modbus)
│   ├── FB_DumperControl.st         # Управление думпкаром
│   ├── FB_EmergencyStopProcess.st  # Процесс аварийной остановки
│   ├── FB_FrequencySimulation.st   # Симуляция частотника
│   ├── FB_PneumoCollapseControl.st # Управление пневмообрушением
│   ├── FB_Simulation.st            # Симуляция оборудования
│   ├── FB_VibratorControl.st       # Управление вибраторами
│   └── FC_ModbusToSCADA.st         # Функция передачи данных в SCADA
│
├── DataTypes/                      # Типы данных
│   │
│   ├── Enumerations/               # Перечисления
│   │   ├── E_AlarmSetpoints.st
│   │   ├── E_LightColor.st
│   │   ├── E_ScadaStatesDevice.st
│   │   ├── E_StageWithPreStartAlarm.st
│   │   ├── E_StateFeedback.st
│   │   ├── E_StateMechanism.st
│   │   ├── E_StateRemote.st
│   │   └── E_VibratorState.st
│   │
│   ├── Structures/                 # Структуры
│   │   ├── ST_AlarmSetpoints.st
│   │   ├── ST_Bunker.st
│   │   ├── ST_BunkerVibratorSettings.st
│   │   ├── ST_Commands.st
│   │   ├── ST_CommonSignals.st
│   │   ├── ST_ConveyorBasic.st
│   │   ├── ST_ConveyorPrefabricated.st
│   │   ├── ST_Dumper.st
│   │   ├── ST_Motor.st
│   │   ├── ST_MotorVibFeeder.st
│   │   ├── ST_MotorWithFeedback.st
│   │   ├── ST_MotorWithReverse.st
│   │   ├── ST_PreStartAlarmSettings.st
│   │   └── ST_VFD.st
│   │
│   └── Unions/                     # Объединения (для Modbus)
│       ├── U_ByteToWord.st
│       ├── U_RealToWord.st
│       └── U_TimeToWord.st
│
├── Functions/                      # Чистые функции
│   │
│   ├── Bunker/                     # Функции бункера
│   │   ├── FC_Bunker_CheckCriticalWeight.st
│   │   ├── FC_Bunker_CheckEmptyBunker.st
│   │   ├── FC_Bunker_CheckWeight.st
│   │   ├── FC_Bunker_EmergencyStop.st
│   │   ├── FC_Bunker_GetErrorBunker.st
│   │   ├── FC_Bunker_GetErrorMotorVibFeeder.st
│   │   ├── FC_Bunker_GetErrorMotorVibrator.st
│   │   ├── FC_Bunker_GetErrorWeight.st
│   │   ├── FC_Bunker_GetLightColor.st
│   │   └── FC_Bunker_SetLightColor.st
│   │
│   ├── Conveyor/                   # Функции конвейера
│   │   ├── FC_Conveyor_EmergencyStop.st
│   │   ├── FC_Conveyor_GetErrorCommon.st
│   │   ├── FC_Conveyor_GetErrorMotor.st
│   │   └── FC_Conveyor_GetErrorSensors.st
│   │
│   ├── Dumper/                     # Функции думпкара
│   │   ├── FC_Dumper_EmergencyStop.st
│   │   ├── FC_Dumper_GetErrorCommon.st
│   │   └── FC_Dumper_GetErrorSensors.st
│   │
│   ├── Modbus/                     # Функции Modbus
│   │   ├── FC_ModbusReadBool.st
│   │   ├── FC_ModbusReadDint.st
│   │   ├── FC_ModbusReadInt.st
│   │   ├── FC_ModbusReadReal.st
│   │   ├── FC_ModbusReadTime.st
│   │   ├── FC_ModbusWriteBool.st
│   │   ├── FC_ModbusWriteInt.st
│   │   ├── FC_ModbusWriteReal.st
│   │   ├── FC_ModbusWriteTime.st
│   │   └── FC_ModbusWriteUInt.st
│   │
│   ├── Sensors/                    # Функции датчиков
│   │   ├── FC_Sensor_CheckGS.st    # Контроль заштыбовки
│   │   ├── FC_Sensor_CheckHQ.st    # Тросовый выключатель
│   │   ├── FC_Sensor_CheckSQ.st    # Концевые выключатели
│   │   ├── FC_Sensor_CheckYE.st    # Металлодетектор
│   │   ├── FC_Sensor_CheckYS.st    # Контроль продольного разрыва
│   │   ├── FC_Sensor_CheckZQAlarm.st   # Схода ленты (авария)
│   │   └── FC_Sensor_CheckZQWarning.st # Схода ленты (предупреждение)
│   │
│   ├── System/                     # Системные функции
│   │   └── FC_Get_ErrorCommon.st   # Общие ошибки системы
│   │
│   └── Utilities/                  # Утилиты
│       ├── FC_MotorSyncronizedWork.st
│       ├── FC_SwapBytesInWord.st
│       ├── FC_SwapBytesInWordArray.st
│       ├── FC_SwapWordArrayElements.st
│       └── FC_VFD_ChangeReadMode.st
│
├── Library/                        # Универсальные функциональные блоки
│   ├── FB_AnalogInput.st           # Аналоговый вход (4-20 мА)
│   ├── FB_AnalogOutput.st          # Аналоговый выход (4-20 мА)
│   ├── FB_FrequencyControl.st      # Управление частотой
│   ├── FB_NumericChangeDetector.st # Детектор изменений
│   ├── FB_PreStartAlarm.st         # Предпусковая сигнализация
│   ├── FB_ProportionPID.st         # ПИД-регулятор пропорций
│   ├── FB_RangeDiagnostic.st       # Диагностика диапазонов (LL/L/H/HH)
│   ├── FB_ScadaCommunication.st    # Коммуникация с SCADA
│   ├── FB_UniversalAnalogSignal.st # Универсальный аналоговый сигнал
│   ├── FB_UniversalMechanism.st    # Универсальный механизм
│   └── FB_UniversalSignal.st       # Универсальный дискретный сигнал
│
└── docs/                           # Документация
    ├── DIRECTORY_STRUCTURE.md      # Структура проекта (этот файл)
    ├── SCADA_RealUnions.st         # Описание SCADA объединений
    ├── SCADA_RealUnions_Init.st    # Инициализация SCADA
    └── Tenso-M/                    # Документация Tenso-M
        └── Example.st
```

## Статистика файлов

**Всего файлов:** 88 файлов `.st`

**Распределение по категориям:**
- **POUs:** 12 файлов (программы и контроллеры оборудования)
  - MAIN.st (главная программа)
  - GLOBAL.st (глобальные переменные)
  - FB_BunkerControl.st (управление бункером)
  - FB_ConveyorControl.st (управление конвейером)
  - FB_ConveyorWeight.st (обработка данных весов)
  - FB_DumperControl.st (управление думпкаром)
  - FB_EmergencyStopProcess.st (процесс аварийной остановки)
  - FB_FrequencySimulation.st (симуляция частотника)
  - FB_PneumoCollapseControl.st (управление пневмообрушением)
  - FB_Simulation.st (симуляция оборудования)
  - FB_VibratorControl.st (управление вибраторами)
  - FC_ModbusToSCADA.st (функция передачи данных в SCADA)

- **DataTypes:** 25 файлов
  - Enumerations: 8 файлов
  - Structures: 14 файлов
  - Unions: 3 файла

- **Functions:** 40 файлов (чистые функции без состояния)
  - Bunker: 10 файлов
  - Conveyor: 4 файла
  - Dumper: 3 файла
  - Modbus: 10 файлов
  - Sensors: 7 файлов
  - System: 1 файл
  - Utilities: 5 файлов

- **Library:** 11 файлов (универсальные функциональные блоки)

**Дополнительно:**
- **docs/:** Документация проекта
- **export/:** Папка для экспорта (временная, все файлы распределены)