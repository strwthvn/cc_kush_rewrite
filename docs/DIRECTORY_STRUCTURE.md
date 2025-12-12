# Структура директории проекта

```
newProject/
├── POUs/                           # Program Organization Units
│   ├── MAIN.st
│   ├── GLOBAL.st
│   ├── FB_BunkerControl.st
│   ├── FB_ConveyorControl.st
│   ├── FB_DumperControl.st
│   ├── FB_EmergencyStopProcess.st
│   ├── FB_FrequencySimulation.st
│   ├── FB_PneumoCollapseControl.st
│   ├── FB_Simulation.st
│   └── FB_VibratorControl.st
│
├── DataTypes/                      # Типы данных
│   ├── E_AlarmSetpoints.st
│   ├── E_LightColor.st
│   ├── E_ScadaStatesDevice.st
│   ├── E_StateFeedback.st
│   ├── E_StateMechanism.st
│   ├── E_StateRemote.st
│   ├── E_StageWithPreStartAlarm.st
│   ├── E_VibratorState.st
│   ├── ST_AlarmSetpoints.st
│   ├── ST_Bunker.st
│   ├── ST_BunkerVibratorSettings.st
│   ├── ST_Commands.st
│   ├── ST_CommonSignals.st
│   ├── ST_ConveyorBasic.st
│   ├── ST_ConveyorPrefabricated.st
│   ├── ST_Dumper.st
│   ├── ST_Motor.st
│   ├── ST_MotorVibFeeder.st
│   ├── ST_MotorWithFeedback.st
│   ├── ST_MotorWithReverse.st
│   ├── ST_PreStartAlarmSettings.st
│   ├── ST_VFD.st
│   ├── U_ByteToWord.st
│   ├── U_RealToWord.st
│   └── U_TimeToWord.st
│
├── Functions/                      # Чистые функции
│   ├── FC_Bunker_CheckWeight.st
│   ├── FC_Bunker_EmergencyStop.st
│   ├── FC_Bunker_GetErrorBunker.st
│   ├── FC_Bunker_GetErrorMotorVibFeeder.st
│   ├── FC_Bunker_GetErrorMotorVibrator.st
│   ├── FC_Bunker_GetErrorWeight.st
│   ├── FC_Bunker_SetLightColor.st
│   ├── FC_Conveyor_EmergencyStop.st
│   ├── FC_Conveyor_GetErrorCommon.st
│   ├── FC_Conveyor_GetErrorMotor.st
│   ├── FC_Conveyor_GetErrorSensors.st
│   ├── FC_Dumper_EmergencyStop.st
│   ├── FC_Dumper_GetErrorCommon.st
│   ├── FC_Dumper_GetErrorSensors.st
│   ├── FC_Get_ErrorCommon.st
│   ├── FC_ModbusReadBool.st
│   ├── FC_ModbusReadInt.st
│   ├── FC_ModbusReadReal.st
│   ├── FC_ModbusReadTime.st
│   ├── FC_ModbusWriteBool.st
│   ├── FC_ModbusWriteInt.st
│   ├── FC_ModbusWriteReal.st
│   ├── FC_ModbusWriteTime.st
│   ├── FC_MotorSyncronizedWork.st
│   ├── FC_SwapBytesInWord.st
│   ├── FC_SwapBytesInWordArray.st
│   ├── FC_SwapWordArrayElements.st
│   └── FC_VFD_ChangeReadMode.st
│
├── Library/                        # Универсальные функциональные блоки
│   ├── FB_AnalogInput.st
│   ├── FB_AnalogOutput.st
│   ├── FB_FrequencyControl.st
│   ├── FB_NumericChangeDetector.st
│   ├── FB_PreStartAlarm.st
│   ├── FB_ProportionPID.st
│   ├── FB_RangeDiagnostic.st
│   ├── FB_UniversalAnalogSignal.st
│   ├── FB_UniversalMechanism.st
│   └── FB_UniversalSignal.st
│
└── docs/                           # Документация
    ├── SCADA_RealUnions.st
    └── SCADA_RealUnions_Init.st
```

**Всего файлов:** 75 файлов `.st`

**Распределение по категориям:**
- POUs: 10 файлов
- DataTypes: 25 файлов
- Functions: 30 файлов
- Library: 10 файлов