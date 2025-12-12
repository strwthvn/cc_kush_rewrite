FUNCTION FC_ModbusToSCADA : BOOL
VAR_INPUT
    stBunker : ARRAY [1..3] OF ST_Bunker;
    stDumper : ST_DUMPER;
    stConveyor : ST_Conveyor;
    stCommands : ST_Commands;
END_VAR
VAR

END_VAR

// ========================================
// MODBUS РЕГИСТРЫ
// ========================================

// === HOLDING РЕГИСТРЫ (SCADA → PLC) - Чтение уставок ===

// Общие системные переменные и уставки (0-29)
// Регистры 0-1: BOOL флаги команд
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 0, xValue => stCommands.cmdStartCommon.ixSignal);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 1, xValue => stCommands.cmdStopCommon.ixSignal);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 2, xValue => stCommands.cmdEmergencyStopCommon.ixSignal);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 3, xValue => stCommands.cmdResetAll.ixSignal);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 8, xValue => stCommands.cmdSetToRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 9, xValue => stCommands.cmdSetToManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 0, iBitIndex := 10, xValue => stCommands.cmdSetToAuto);

// Уставки ЧРП (30-59)
// Регистры 30-31: BOOL флаги ЧРП
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 30, iBitIndex := 0, xValue => VFD_SMOOTH_SET_FREQUENCY);

FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 32, rValue => VFD_FREQUENCY_MAX);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 34, rValue => VFD_FREQUENCY_STEP);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 36, rValue => VFD_FREQUENCY_INACCURANCY);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 38, rValue => VFD_FREQUENCY_SYNC_TOLERANCE);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 40, rValue => MOTOR_FREQUENCY_CONVEYOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 42, rValue => MOTOR_FREQUENCY_DUMPER_CONVEYOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 44, rValue => MOTOR_FREQUENCY_DUMPER_ROTATION);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 46, rValue => CONVEYOR_DEAFULT_SPEED);

// Уставки бункеров (60-89)
// Регистры 60-61: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 62, rValue => BUNKER_WORK_PRECENT_1);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 64, rValue => BUNKER_WORK_PRECENT_2);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 66, rValue => BUNKER_WORK_PRECENT_3);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 68, rValue => BUNKER_MINIMAL_WEIGHT);

// Уставки аварийных значений - Температура (90-119)
// Регистры 90-91: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 92, rValue => MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 94, rValue => MOTOR_VIBFEEDER_TEMP_POINTS.L_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 96, rValue => MOTOR_VIBFEEDER_TEMP_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 98, rValue => MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value);

// Уставки аварийных значений - Ток (120-149)
// Регистры 120-121: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 122, rValue => MOTOR_VIBFEEDER_CURRENT_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 124, rValue => MOTOR_VIBFEEDER_CURRENT_POINTS.L_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 126, rValue => MOTOR_VIBFEEDER_CURRENT_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 128, rValue => MOTOR_VIBFEEDER_CURRENT_POINTS.HH_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 130, rValue => MOTOR_VIBRATOR_CURRENT_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 132, rValue => MOTOR_VIBRATOR_CURRENT_POINTS.L_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 134, rValue => MOTOR_VIBRATOR_CURRENT_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 136, rValue => MOTOR_VIBRATOR_CURRENT_POINTS.HH_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 138, rValue => MOTOR_CONVEYOR_CURRENT_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 140, rValue => MOTOR_CONVEYOR_CURRENT_POINTS.L_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 142, rValue => MOTOR_CONVEYOR_CURRENT_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 144, rValue => MOTOR_CONVEYOR_CURRENT_POINTS.HH_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 146, rValue => MOTOR_ROTATION_CURRENT_POINTS.LL_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 148, rValue => MOTOR_ROTATION_CURRENT_POINTS.L_Value);

// Уставки времени (150-179)
// Регистры 150-151: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 152, rValue => MOTOR_ROTATION_CURRENT_POINTS.H_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 154, rValue => MOTOR_ROTATION_CURRENT_POINTS.HH_Value);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 156, rValue => rTempTime);
VIBRATOR_SETTINGS.TIME_ACTIVE := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 158, rValue => rTempTime);
VIBRATOR_SETTINGS.TIME_PAUSE_VIBRATOR := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 160, rValue => rTempTime);
VIBRATOR_SETTINGS.TIME_PAUSE_FB := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 162, rValue => rTempTime);
PNEUMO_SETTINGS.TIME_ACTIVE := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 164, rValue => rTempTime);
PNEUMO_SETTINGS.TIME_PAUSE_VIBRATOR := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 166, rValue => rTempTime);
PNEUMO_SETTINGS.TIME_PAUSE_FB := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 168, rValue => rTempTime);
TIME_WAITING_FEEDBACK := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 170, rValue => rTempTime);
PNEUMATIC_COLLAPSE_TIME := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 172, rValue => rTempTime);
DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 174, rValue => rTempTime);
DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 176, rValue => rTempTime);
DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 178, rValue => rTempTime);
DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE := REAL_TO_TIME(rTempTime * 1000);

// Уставки времени (продолжение) (180-209)
// Регистры 180-181: BOOL флаги (резерв)
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 182, rValue => rTempTime);
CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 184, rValue => rTempTime);
CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 186, rValue => rTempTime);
CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL := REAL_TO_TIME(rTempTime * 1000);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 188, rValue => rTempTime);
CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE := REAL_TO_TIME(rTempTime * 1000);

// Команды - Отвалообразователь (210-239)
// Регистры 210-211: BOOL флаги управления отвалообразователем
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 0, xValue => stDumper.cmdStartConveyor);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 1, xValue => stDumper.cmdStopConveyor);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 2, xValue => stDumper.cmdEmergencyStop);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 3, xValue => stDumper.cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 8, xValue => stDumper.cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 9, xValue => stDumper.cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 10, xValue => stDumper.cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 11, xValue => stDumper.cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 210, iBitIndex := 12, xValue => stDumper.cmdBuildCircuitOff);


FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 0, xValue => stDumper.cmdTurnLeft);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 1, xValue => stDumper.cmdTurnRight);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 2, xValue => stDumper.cmdStopRotation);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 11, xValue => stDumper.cmdBuildCircuitOnRotation);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 211, iBitIndex := 12, xValue => stDumper.cmdBuildCircuitOffRotation);

// Настройка - Отвалообразователь (210-239)
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 212, iBitIndex := 0, xValue => DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.OPTION_ENABLE);

// Команды - Конвейер (240-269)
// Регистры 240-241: BOOL флаги управления конвейером
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 0, xValue => stConveyor.cmdStartConveyor);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 1, xValue => stConveyor.cmdStopConveyor);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 2, xValue => stConveyor.cmdEmergencyStop);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 3, xValue => stConveyor.cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 8, xValue => stConveyor.cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 9, xValue => stConveyor.cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 10, xValue => stConveyor.cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 11, xValue => stConveyor.cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 240, iBitIndex := 12, xValue => stConveyor.cmdBuildCircuitOff);

// Настройка - Конвейер (240-269)
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 242, iBitIndex := 0, xValue => CONVEYOR_PRESTART_ALARM_SETTINGS.OPTION_ENABLE);

// Команды - Бункер 1 (270-299)
// Регистры 270-271: BOOL флаги управления бункером 1
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 0, xValue => stBunker[1].cmdStartFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 1, xValue => stBunker[1].cmdStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 2, xValue => stBunker[1].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 3, xValue => stBunker[1].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 4, xValue => stBunker[1].cmdAddVib1);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 5, xValue => stBunker[1].cmdAddVib2);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 6, xValue => stBunker[1].cmdAddVib3);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 7, xValue => stBunker[1].cmdAddVib4);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 8, xValue => stBunker[1].cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 9, xValue => stBunker[1].cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 10, xValue => stBunker[1].cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 11, xValue => stBunker[1].cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 270, iBitIndex := 12, xValue => stBunker[1].cmdBuildCircuitOff);

FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 271, iBitIndex := 0, xValue => stBunker[1].cmdStartVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 271, iBitIndex := 1, xValue => stBunker[1].cmdStopVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 271, iBitIndex := 2, xValue => stBunker[1].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 271, iBitIndex := 3, xValue => stBunker[1].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 271, iBitIndex := 11, xValue => stBunker[1].cmdBuildCircuitOnVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 271, iBitIndex := 12, xValue => stBunker[1].cmdBuildCircuitOffVibrator);


FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 278, rValue => BUNKER_1_FREQ_VIBRATOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 282, rValue => BUNKER_1_FREQ_VIBFEEDER);

// Команды - Бункер 2 (300-329)
// Регистры 300-301: BOOL флаги управления бункером 2
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 0, xValue => stBunker[2].cmdStartFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 1, xValue => stBunker[2].cmdStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 2, xValue => stBunker[2].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 3, xValue => stBunker[2].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 4, xValue => stBunker[2].cmdAddVib1);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 5, xValue => stBunker[2].cmdAddVib2);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 6, xValue => stBunker[2].cmdAddVib3);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 7, xValue => stBunker[2].cmdAddVib4);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 8, xValue => stBunker[2].cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 9, xValue => stBunker[2].cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 10, xValue => stBunker[2].cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 11, xValue => stBunker[2].cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 300, iBitIndex := 12, xValue => stBunker[2].cmdBuildCircuitOff);

FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 301, iBitIndex := 0, xValue => stBunker[2].cmdStartVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 301, iBitIndex := 1, xValue => stBunker[2].cmdStopVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 301, iBitIndex := 2, xValue => stBunker[2].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 301, iBitIndex := 3, xValue => stBunker[2].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 301, iBitIndex := 11, xValue => stBunker[2].cmdBuildCircuitOnVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 301, iBitIndex := 12, xValue => stBunker[2].cmdBuildCircuitOffVibrator);


FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 308, rValue => BUNKER_2_FREQ_VIBRATOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 312, rValue => BUNKER_2_FREQ_VIBFEEDER);

// Команды - Бункер 3 (330-359)
// Регистры 330-331: BOOL флаги управления бункером 3
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 0, xValue => stBunker[3].cmdStartFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 1, xValue => stBunker[3].cmdStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 2, xValue => stBunker[3].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 3, xValue => stBunker[3].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 4, xValue => stBunker[3].cmdAddVib1);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 5, xValue => stBunker[3].cmdAddVib2);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 6, xValue => stBunker[3].cmdAddVib3);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 7, xValue => stBunker[3].cmdAddVib4);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 8, xValue => stBunker[3].cmdSetModeRepair);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 9, xValue => stBunker[3].cmdSetModeManual);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 10, xValue => stBunker[3].cmdSetModeAuto);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 11, xValue => stBunker[3].cmdBuildCircuitOn);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 330, iBitIndex := 12, xValue => stBunker[3].cmdBuildCircuitOff);

FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 331, iBitIndex := 0, xValue => stBunker[3].cmdStartVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 331, iBitIndex := 1, xValue => stBunker[3].cmdStopVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 331, iBitIndex := 2, xValue => stBunker[3].cmdEmergencyStopFeeder);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 331, iBitIndex := 3, xValue => stBunker[3].cmdReset);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 331, iBitIndex := 11, xValue => stBunker[3].cmdBuildCircuitOnVibrator);
FC_ModbusReadBool(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 331, iBitIndex := 12, xValue => stBunker[3].cmdBuildCircuitOffVibrator);


FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 338, rValue => BUNKER_3_FREQ_VIBRATOR);
FC_ModbusReadReal(pRegisters := ADR(awModbusHoldingRegisters), iRegisterIndex := 342, rValue => BUNKER_3_FREQ_VIBFEEDER);

// === INPUT РЕГИСТРЫ (PLC → SCADA) - Запись данных мониторинга ===

// Общие системные статусы (0-29)
// Регистры 0-1: BOOL флаги статусов системы
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 0, xValue := xStateAutoWorking);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 1, xValue := xStateEmergencyStop);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 2, xValue := xStateErrorCheckReady);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 3, xValue := xStateErrorAcceptIdle);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 4, xValue := stCommonSignals.fbEmergencyStopBtn.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 5, xValue := stCommonSignals.fbRemoteModeBtn.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 6, xValue := stCommonSignals.fbRealyCurrentControl.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 7, xValue := stCommonSignals.fbQF1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 8, xValue := stCommonSignals.fb9QF1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 9, xValue := stCommonSignals.fb10QF1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 10, xValue := stCommonSignals.fb11QF1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 11, xValue := stCommonSignals.qx6KM1);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 12, xValue := (stBunker[1].xStateRemoteAuto AND stBunker[2].xStateRemoteAuto AND stBunker[3].xStateRemoteAuto AND stDumper.xStateRemoteAuto AND stConveyor.xStateRemoteAuto));
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 13, xValue := NOT(stBunker[1].xStateRemoteAuto AND stBunker[2].xStateRemoteAuto AND stBunker[3].xStateRemoteAuto AND stDumper.xStateRemoteAuto AND stConveyor.xStateRemoteAuto));

FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 0, iBitIndex := 15, xValue := SIMULATION);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 2, rValue := ICUR_PRECENT);

// Бункер 1 (30-89)
// Регистры 30-31: BOOL флаги статусов бункера 1
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 0, xValue := stBunker[1].xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 1, xValue := stBunker[1].xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 2, xValue := stBunker[1].fbStateHatch.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 3, xValue := stBunker[1].qxLightRed);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 4, xValue := stBunker[1].qxLightYellow);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 5, xValue := stBunker[1].qxLightGreen);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 6, xValue := stBunker[1].fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 7, xValue := stBunker[1].fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 8, xValue := stBunker[1].fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 12, xValue := stBunker[1].xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 13, xValue := stBunker[1].xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 30, iBitIndex := 14, xValue := stBunker[1].xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 32, rValue := stBunker[1].rWeight);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 34, rValue := stBunker[1].rProportionActual);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 36, rValue := stBunker[1].rMotorVibFeederCommonFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 38, rValue := stBunker[1].cmdDumpingPrecent);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 40, rValue := stBunker[1].MotorVibrator[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 42, rValue := stBunker[1].MotorVibrator[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 44, rValue := stBunker[1].MotorVibrator[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 46, rValue := stBunker[1].MotorVibrator[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 48, rValue := stBunker[1].MotorVibrator[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 50, rValue := stBunker[1].MotorVibrator[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 52, rValue := stBunker[1].MotorVibrator[3].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 54, rValue := stBunker[1].MotorVibrator[3].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 56, rValue := stBunker[1].MotorVibrator[3].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 58, rValue := stBunker[1].MotorVibrator[4].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 60, rValue := stBunker[1].MotorVibrator[4].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 62, rValue := stBunker[1].MotorVibrator[4].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 64, rValue := stBunker[1].MotorVibFeeder[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 66, rValue := stBunker[1].MotorVibFeeder[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 68, rValue := stBunker[1].MotorVibFeeder[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 70, rValue := stBunker[1].MotorVibFeeder[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 72, rValue := stBunker[1].MotorVibFeeder[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 74, rValue := stBunker[1].MotorVibFeeder[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 76, rValue := stBunker[1].MotorVibFeeder[1].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 78, rValue := stBunker[1].MotorVibFeeder[1].rTempBearing[2]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 80, rValue := stBunker[1].MotorVibFeeder[2].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 82, rValue := stBunker[1].MotorVibFeeder[2].rTempBearing[2]);

GLOBAL.awModbusInputRegisters[84] := TO_WORD(eBunkerStageToSCADA[1]);

// Бункер 2 (90-149)
// Регистры 90-91: BOOL флаги статусов бункера 2
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 0, xValue := stBunker[2].xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 1, xValue := stBunker[2].xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 2, xValue := stBunker[2].fbStateHatch.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 3, xValue := stBunker[2].qxLightRed);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 4, xValue := stBunker[2].qxLightYellow);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 5, xValue := stBunker[2].qxLightGreen);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 6, xValue := stBunker[2].fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 7, xValue := stBunker[2].fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 8, xValue := stBunker[2].fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 12, xValue := stBunker[2].xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 13, xValue := stBunker[2].xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 90, iBitIndex := 14, xValue := stBunker[2].xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 92, rValue := stBunker[2].rWeight);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 94, rValue := stBunker[2].rProportionActual);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 96, rValue := stBunker[2].rMotorVibFeederCommonFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 98, rValue := stBunker[2].cmdDumpingPrecent);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 100, rValue := stBunker[2].MotorVibrator[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 102, rValue := stBunker[2].MotorVibrator[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 104, rValue := stBunker[2].MotorVibrator[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 106, rValue := stBunker[2].MotorVibrator[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 108, rValue := stBunker[2].MotorVibrator[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 110, rValue := stBunker[2].MotorVibrator[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 112, rValue := stBunker[2].MotorVibrator[3].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 114, rValue := stBunker[2].MotorVibrator[3].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 116, rValue := stBunker[2].MotorVibrator[3].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 118, rValue := stBunker[2].MotorVibrator[4].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 120, rValue := stBunker[2].MotorVibrator[4].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 122, rValue := stBunker[2].MotorVibrator[4].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 124, rValue := stBunker[2].MotorVibFeeder[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 126, rValue := stBunker[2].MotorVibFeeder[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 128, rValue := stBunker[2].MotorVibFeeder[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 130, rValue := stBunker[2].MotorVibFeeder[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 132, rValue := stBunker[2].MotorVibFeeder[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 134, rValue := stBunker[2].MotorVibFeeder[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 136, rValue := stBunker[2].MotorVibFeeder[1].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 138, rValue := stBunker[2].MotorVibFeeder[1].rTempBearing[2]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 140, rValue := stBunker[2].MotorVibFeeder[2].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 142, rValue := stBunker[2].MotorVibFeeder[2].rTempBearing[2]);

GLOBAL.awModbusInputRegisters[144] := TO_WORD(eBunkerStageToSCADA[2]);

// Бункер 3 (150-209)
// Регистры 150-151: BOOL флаги статусов бункера 3
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 0, xValue := stBunker[3].xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 1, xValue := stBunker[3].xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 2, xValue := stBunker[3].fbStateHatch.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 3, xValue := stBunker[3].qxLightRed);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 4, xValue := stBunker[3].qxLightYellow);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 5, xValue := stBunker[3].qxLightGreen);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 6, xValue := stBunker[3].fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 7, xValue := stBunker[3].fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 8, xValue := stBunker[3].fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 12, xValue := stBunker[3].xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 13, xValue := stBunker[3].xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 150, iBitIndex := 14, xValue := stBunker[3].xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 152, rValue := stBunker[3].rWeight);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 154, rValue := stBunker[3].rProportionActual);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 156, rValue := stBunker[3].rMotorVibFeederCommonFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 158, rValue := stBunker[3].cmdDumpingPrecent);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 160, rValue := stBunker[3].MotorVibrator[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 162, rValue := stBunker[3].MotorVibrator[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 164, rValue := stBunker[3].MotorVibrator[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 166, rValue := stBunker[3].MotorVibrator[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 168, rValue := stBunker[3].MotorVibrator[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 170, rValue := stBunker[3].MotorVibrator[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 172, rValue := stBunker[3].MotorVibrator[3].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 174, rValue := stBunker[3].MotorVibrator[3].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 176, rValue := stBunker[3].MotorVibrator[3].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 178, rValue := stBunker[3].MotorVibrator[4].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 180, rValue := stBunker[3].MotorVibrator[4].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 182, rValue := stBunker[3].MotorVibrator[4].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 184, rValue := stBunker[3].MotorVibFeeder[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 186, rValue := stBunker[3].MotorVibFeeder[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 188, rValue := stBunker[3].MotorVibFeeder[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 190, rValue := stBunker[3].MotorVibFeeder[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 192, rValue := stBunker[3].MotorVibFeeder[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 194, rValue := stBunker[3].MotorVibFeeder[2].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 196, rValue := stBunker[3].MotorVibFeeder[1].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 198, rValue := stBunker[3].MotorVibFeeder[1].rTempBearing[2]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 200, rValue := stBunker[3].MotorVibFeeder[2].rTempBearing[1]);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 202, rValue := stBunker[3].MotorVibFeeder[2].rTempBearing[2]);

GLOBAL.awModbusInputRegisters[204] := TO_WORD(eBunkerStageToSCADA[3]);

// Отвалообразователь - Конвейер (210-239)
// Регистры 210-211: BOOL флаги статусов отвалообразователя
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 0, xValue := stDumper.xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 1, xValue := stDumper.xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 2, xValue := stDumper.xStateEnable);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 3, xValue := stDumper.xStateStarting);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 4, xValue := stDumper.fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 5, xValue := stDumper.fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 6, xValue := stDumper.fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 7, xValue := stDumper.fbBtnRemoteMode.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 8, xValue := stDumper.xHLA);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 9, xValue := stDumper.xSoundAlarm);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 10, xValue := stDumper.fbZQAlarm[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 11, xValue := stDumper.fbZQAlarm[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 12, xValue := stDumper.fbZQAlarm[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 13, xValue := stDumper.fbZQAlarm[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 14, xValue := stDumper.fbZQWarning[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 210, iBitIndex := 15, xValue := stDumper.fbZQWarning[2].qxSignal);

// Регистр 211: дополнительные сигналы обратной связи отвалообразователя
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 0, xValue := stDumper.fbZQWarning[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 1, xValue := stDumper.fbZQWarning[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 2, xValue := stDumper.fbHQ_IsOk[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 3, xValue := stDumper.fbHQ_IsOk[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 4, xValue := stDumper.fbHQ_IsOk[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 5, xValue := stDumper.fbHQ_IsOk[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 6, xValue := stDumper.fbSQ_IsOk[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 7, xValue := stDumper.fbSQ_IsOk[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 8, xValue := stDumper.fbGS1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 9, xValue := stDumper.fbQR[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 10, xValue := stDumper.fbQR[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 11, xValue := stDumper.fbYS1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 12, xValue := stDumper.xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 13, xValue := stDumper.xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 211, iBitIndex := 14, xValue := stDumper.xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 212, rValue := stDumper.MotorConveyor[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 214, rValue := stDumper.MotorConveyor[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 216, rValue := stDumper.MotorConveyor[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 218, rValue := stDumper.MotorConveyor[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 220, rValue := stDumper.MotorConveyor[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 222, rValue := stDumper.MotorConveyor[2].VFD.wMotorCurrent.rTag);

GLOBAL.awModbusInputRegisters[230] := TO_WORD(eDumperStageToSCADA);

// Отвалообразователь - Поворот (240-269)
// Регистры 240-241: BOOL флаги управления поворотом
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 240, iBitIndex := 0, xValue := stDumper.fbBtnTurnLeft.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 240, iBitIndex := 1, xValue := stDumper.fbBtnTurnRight.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 240, iBitIndex := 2, xValue := stDumper.fbEndSwitchRight.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 240, iBitIndex := 3, xValue := stDumper.fbEndSwitchLeft.qxSignal);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 242, rValue := stDumper.MotorRotation[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 244, rValue := stDumper.MotorRotation[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 246, rValue := stDumper.MotorRotation[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 248, rValue := stDumper.MotorRotation[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 250, rValue := stDumper.MotorRotation[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 252, rValue := stDumper.MotorRotation[2].VFD.wMotorCurrent.rTag);

// Конвейер (270-299)
// Регистры 270-271: BOOL флаги статусов конвейера
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 0, xValue := stConveyor.xStateWarning);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 1, xValue := stConveyor.xStateFailure);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 2, xValue := stConveyor.xStateEnable);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 3, xValue := stConveyor.xStateStarting);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 4, xValue := stConveyor.fbBtnStart.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 5, xValue := stConveyor.fbBtnStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 6, xValue := stConveyor.fbBtnEmergencyStop.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 7, xValue := stConveyor.xHLA);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 8, xValue := stConveyor.xSoundAlarm);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 9, xValue := stConveyor.fbYE1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 10, xValue := stConveyor.fbZQAlarm[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 11, xValue := stConveyor.fbZQAlarm[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 12, xValue := stConveyor.fbZQAlarm[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 13, xValue := stConveyor.fbZQAlarm[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 14, xValue := stConveyor.fbZQWarning[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 270, iBitIndex := 15, xValue := stConveyor.fbZQWarning[2].qxSignal);

// Регистр 271: дополнительные сигналы обратной связи конвейера
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 0, xValue := stConveyor.fbZQWarning[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 1, xValue := stConveyor.fbZQWarning[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 2, xValue := stConveyor.fbHQ_IsOk[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 3, xValue := stConveyor.fbHQ_IsOk[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 4, xValue := stConveyor.fbHQ_IsOk[3].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 5, xValue := stConveyor.fbHQ_IsOk[4].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 6, xValue := stConveyor.fbSQ_IsOk[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 7, xValue := stConveyor.fbSQ_IsOk[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 8, xValue := stConveyor.fbGS1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 9, xValue := stConveyor.fbQR[1].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 10, xValue := stConveyor.fbQR[2].qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 11, xValue := stConveyor.fbYS1.qxSignal);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 12, xValue := stConveyor.xStateRemoteAuto);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 13, xValue := stConveyor.xStateRemoteManual);
FC_ModbusWriteBool(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 271, iBitIndex := 14, xValue := stConveyor.xStateRemoteRepair);

FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 272, rValue := stConveyor.MotorConveyor[1].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 274, rValue := stConveyor.MotorConveyor[1].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 276, rValue := stConveyor.MotorConveyor[1].VFD.wMotorCurrent.rTag);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 278, rValue := stConveyor.MotorConveyor[2].VFD.qrOutFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 280, rValue := stConveyor.MotorConveyor[2].VFD.rActualFrequency);
FC_ModbusWriteReal(pRegisters := ADR(awModbusInputRegisters), iRegisterIndex := 282, rValue := stConveyor.MotorConveyor[2].VFD.wMotorCurrent.rTag);

GLOBAL.awModbusInputRegisters[290] := TO_WORD(eConveyorStageToSCADA);

END_FUNCTION