VAR_GLOBAL
    // 1.2 Расчётные значения
    uIcurPrecent : U_RealToWord;                    // Application.ICUR_PRECENT
    uElectricityMeter : U_RealToWord;               // Application.rElectricityMeter
    uEfficiencyLimitRate : U_RealToWord;            // Application.EFFICIENCY_LIMIT_RATE

    // 2.1 Настройки ЧРП
    uVfdFrequencyMax : U_RealToWord;                // Application.VFD_FREQUENCY_MAX
    uVfdFrequencyStep : U_RealToWord;               // Application.VFD_FREQUENCY_STEP
    uVfdFrequencyInaccurancy : U_RealToWord;        // Application.VFD_FREQUENCY_INACCURANCY
    uVfdFrequencySyncTolerance : U_RealToWord;      // Application.VFD_FREQUENCY_SYNC_TOLERANCE

    // 2.2 Частоты двигателей
    uMotorFrequencyConveyor : U_RealToWord;         // Application.MOTOR_FREQUENCY_CONVEYOR
    uMotorFrequencyDumperConveyor : U_RealToWord;   // Application.MOTOR_FREQUENCY_DUMPER_CONVEYOR
    uMotorFrequencyDumperRotation : U_RealToWord;   // Application.MOTOR_FREQUENCY_DUMPER_ROTATION
    uConveyorDefaultSpeed : U_RealToWord;           // Application.CONVEYOR_DEAFULT_SPEED

    // 2.4 Уставки бункеров
    uBunkerWorkPrecent1 : U_RealToWord;             // Application.BUNKER_WORK_PRECENT_1
    uBunkerWorkPrecent2 : U_RealToWord;             // Application.BUNKER_WORK_PRECENT_2
    uBunkerWorkPrecent3 : U_RealToWord;             // Application.BUNKER_WORK_PRECENT_3
    uBunkerMinimalWeight : U_RealToWord;            // Application.BUNKER_MINIMAL_WEIGHT

    // 2.6 Прочие уставки
    uAnnunciatorLightHz : U_RealToWord;             // Application.ANNUNCIATOR_LIGHT_HZ

    // 2.7 Уставки аварийных значений - Температура подшипников вибропитателя
    uMotorVibfeederTempLL : U_RealToWord;           // Application.MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value
    uMotorVibfeederTempL : U_RealToWord;            // Application.MOTOR_VIBFEEDER_TEMP_POINTS.L_Value
    uMotorVibfeederTempH : U_RealToWord;            // Application.MOTOR_VIBFEEDER_TEMP_POINTS.H_Value
    uMotorVibfeederTempHH : U_RealToWord;           // Application.MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value

    // Ток мотора вибропитателя
    uMotorVibfeederCurrentLL : U_RealToWord;        // Application.MOTOR_VIBFEEDER_CURRENT_POINTS.LL_Value
    uMotorVibfeederCurrentL : U_RealToWord;         // Application.MOTOR_VIBFEEDER_CURRENT_POINTS.L_Value
    uMotorVibfeederCurrentH : U_RealToWord;         // Application.MOTOR_VIBFEEDER_CURRENT_POINTS.H_Value
    uMotorVibfeederCurrentHH : U_RealToWord;        // Application.MOTOR_VIBFEEDER_CURRENT_POINTS.HH_Value

    // Ток мотора вибратора
    uMotorVibratorCurrentLL : U_RealToWord;         // Application.MOTOR_VIBRATOR_CURRENT_POINTS.LL_Value
    uMotorVibratorCurrentL : U_RealToWord;          // Application.MOTOR_VIBRATOR_CURRENT_POINTS.L_Value
    uMotorVibratorCurrentH : U_RealToWord;          // Application.MOTOR_VIBRATOR_CURRENT_POINTS.H_Value
    uMotorVibratorCurrentHH : U_RealToWord;         // Application.MOTOR_VIBRATOR_CURRENT_POINTS.HH_Value

    // Ток мотора конвейера
    uMotorConveyorCurrentLL : U_RealToWord;         // Application.MOTOR_CONVEYOR_CURRENT_POINTS.LL_Value
    uMotorConveyorCurrentL : U_RealToWord;          // Application.MOTOR_CONVEYOR_CURRENT_POINTS.L_Value
    uMotorConveyorCurrentH : U_RealToWord;          // Application.MOTOR_CONVEYOR_CURRENT_POINTS.H_Value
    uMotorConveyorCurrentHH : U_RealToWord;         // Application.MOTOR_CONVEYOR_CURRENT_POINTS.HH_Value

    // Ток мотора поворота отвалообразователя
    uMotorRotationCurrentLL : U_RealToWord;         // Application.MOTOR_ROTATION_CURRENT_POINTS.LL_Value
    uMotorRotationCurrentL : U_RealToWord;          // Application.MOTOR_ROTATION_CURRENT_POINTS.L_Value
    uMotorRotationCurrentH : U_RealToWord;          // Application.MOTOR_ROTATION_CURRENT_POINTS.H_Value
    uMotorRotationCurrentHH : U_RealToWord;         // Application.MOTOR_ROTATION_CURRENT_POINTS.HH_Value

    // 3.1 Системные состояния MAIN
    uMainIcurPrecent : U_RealToWord;                // Application.MAIN.ICUR_PRECENT

    // 6.1 Бункеры - веса и пропорции
    uBunker1Weight : U_RealToWord;                  // Application.MAIN.stBunker[1].rWeight
    uBunker1ProportionActual : U_RealToWord;        // Application.MAIN.stBunker[1].rProportionActual
    uBunker1VibFeederFrequency : U_RealToWord;      // Application.MAIN.stBunker[1].rMotorVibFeederCommonFrequency
    uBunker1DumpingPrecent : U_RealToWord;          // Application.MAIN.stBunker[1].cmdDumpingPrecent

    uBunker2Weight : U_RealToWord;                  // Application.MAIN.stBunker[2].rWeight
    uBunker2ProportionActual : U_RealToWord;        // Application.MAIN.stBunker[2].rProportionActual
    uBunker2VibFeederFrequency : U_RealToWord;      // Application.MAIN.stBunker[2].rMotorVibFeederCommonFrequency
    uBunker2DumpingPrecent : U_RealToWord;          // Application.MAIN.stBunker[2].cmdDumpingPrecent

    uBunker3Weight : U_RealToWord;                  // Application.MAIN.stBunker[3].rWeight
    uBunker3ProportionActual : U_RealToWord;        // Application.MAIN.stBunker[3].rProportionActual
    uBunker3VibFeederFrequency : U_RealToWord;      // Application.MAIN.stBunker[3].rMotorVibFeederCommonFrequency
    uBunker3DumpingPrecent : U_RealToWord;          // Application.MAIN.stBunker[3].cmdDumpingPrecent

    // VFD выходные/текущие частоты и токи - Отвалообразователь конвейер
    uDumperMotorConveyor1OutFreq : U_RealToWord;    // Application.MAIN.stDumper.MotorConveyor[1].VFD.qrOutFrequency
    uDumperMotorConveyor1ActualFreq : U_RealToWord; // Application.MAIN.stDumper.MotorConveyor[1].VFD.rActualFrequency
    uDumperMotorConveyor1Current : U_RealToWord;    // Application.MAIN.stDumper.MotorConveyor[1].VFD.wMotorCurrent.rValue
    uDumperMotorConveyor1SetFreq : U_RealToWord;    // Application.MAIN.stDumper.MotorConveyor[1].VFD.cmdSetFrequency

    uDumperMotorConveyor2OutFreq : U_RealToWord;    // Application.MAIN.stDumper.MotorConveyor[2].VFD.qrOutFrequency
    uDumperMotorConveyor2ActualFreq : U_RealToWord; // Application.MAIN.stDumper.MotorConveyor[2].VFD.rActualFrequency
    uDumperMotorConveyor2Current : U_RealToWord;    // Application.MAIN.stDumper.MotorConveyor[2].VFD.wMotorCurrent.rValue
    uDumperMotorConveyor2SetFreq : U_RealToWord;    // Application.MAIN.stDumper.MotorConveyor[2].VFD.cmdSetFrequency

    // VFD - Отвалообразователь поворот
    uDumperMotorRotation1OutFreq : U_RealToWord;    // Application.MAIN.stDumper.MotorRotation[1].VFD.qrOutFrequency
    uDumperMotorRotation1ActualFreq : U_RealToWord; // Application.MAIN.stDumper.MotorRotation[1].VFD.rActualFrequency
    uDumperMotorRotation1Current : U_RealToWord;    // Application.MAIN.stDumper.MotorRotation[1].VFD.wMotorCurrent.rValue
    uDumperMotorRotation1SetFreq : U_RealToWord;    // Application.MAIN.stDumper.MotorRotation[1].VFD.cmdSetFrequency

    uDumperMotorRotation2OutFreq : U_RealToWord;    // Application.MAIN.stDumper.MotorRotation[2].VFD.qrOutFrequency
    uDumperMotorRotation2ActualFreq : U_RealToWord; // Application.MAIN.stDumper.MotorRotation[2].VFD.rActualFrequency
    uDumperMotorRotation2Current : U_RealToWord;    // Application.MAIN.stDumper.MotorRotation[2].VFD.wMotorCurrent.rValue
    uDumperMotorRotation2SetFreq : U_RealToWord;    // Application.MAIN.stDumper.MotorRotation[2].VFD.cmdSetFrequency

    // VFD - Конвейер
    uConveyorMotor1OutFreq : U_RealToWord;          // Application.MAIN.stConveyor.MotorConveyor[1].VFD.qrOutFrequency
    uConveyorMotor1ActualFreq : U_RealToWord;       // Application.MAIN.stConveyor.MotorConveyor[1].VFD.rActualFrequency
    uConveyorMotor1Current : U_RealToWord;          // Application.MAIN.stConveyor.MotorConveyor[1].VFD.wMotorCurrent.rValue
    uConveyorMotor1SetFreq : U_RealToWord;          // Application.MAIN.stConveyor.MotorConveyor[1].VFD.cmdSetFrequency

    uConveyorMotor2OutFreq : U_RealToWord;          // Application.MAIN.stConveyor.MotorConveyor[2].VFD.qrOutFrequency
    uConveyorMotor2ActualFreq : U_RealToWord;       // Application.MAIN.stConveyor.MotorConveyor[2].VFD.rActualFrequency
    uConveyorMotor2Current : U_RealToWord;          // Application.MAIN.stConveyor.MotorConveyor[2].VFD.wMotorCurrent.rValue
    uConveyorMotor2SetFreq : U_RealToWord;          // Application.MAIN.stConveyor.MotorConveyor[2].VFD.cmdSetFrequency

    // Температуры подшипников вибропитателей
    uBunker1VibFeeder1TempBearing1 : U_RealToWord;  // Application.MAIN.stBunker[1].MotorVibFeeder[1].fbTempBearing[1].qrProcessedValue
    uBunker1VibFeeder1TempBearing2 : U_RealToWord;  // Application.MAIN.stBunker[1].MotorVibFeeder[1].fbTempBearing[2].qrProcessedValue
    uBunker1VibFeeder2TempBearing1 : U_RealToWord;  // Application.MAIN.stBunker[1].MotorVibFeeder[2].fbTempBearing[1].qrProcessedValue
    uBunker1VibFeeder2TempBearing2 : U_RealToWord;  // Application.MAIN.stBunker[1].MotorVibFeeder[2].fbTempBearing[2].qrProcessedValue

    uBunker2VibFeeder1TempBearing1 : U_RealToWord;  // Application.MAIN.stBunker[2].MotorVibFeeder[1].fbTempBearing[1].qrProcessedValue
    uBunker2VibFeeder1TempBearing2 : U_RealToWord;  // Application.MAIN.stBunker[2].MotorVibFeeder[1].fbTempBearing[2].qrProcessedValue
    uBunker2VibFeeder2TempBearing1 : U_RealToWord;  // Application.MAIN.stBunker[2].MotorVibFeeder[2].fbTempBearing[1].qrProcessedValue
    uBunker2VibFeeder2TempBearing2 : U_RealToWord;  // Application.MAIN.stBunker[2].MotorVibFeeder[2].fbTempBearing[2].qrProcessedValue

    uBunker3VibFeeder1TempBearing1 : U_RealToWord;  // Application.MAIN.stBunker[3].MotorVibFeeder[1].fbTempBearing[1].qrProcessedValue
    uBunker3VibFeeder1TempBearing2 : U_RealToWord;  // Application.MAIN.stBunker[3].MotorVibFeeder[1].fbTempBearing[2].qrProcessedValue
    uBunker3VibFeeder2TempBearing1 : U_RealToWord;  // Application.MAIN.stBunker[3].MotorVibFeeder[2].fbTempBearing[1].qrProcessedValue
    uBunker3VibFeeder2TempBearing2 : U_RealToWord;  // Application.MAIN.stBunker[3].MotorVibFeeder[2].fbTempBearing[2].qrProcessedValue

    // VFD бункеров - вибраторы (частоты и токи)
    // Бункер 1
    uBunker1Vibrator1OutFreq : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[1].VFD.qrOutFrequency
    uBunker1Vibrator1ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[1].MotorVibrator[1].VFD.rActualFrequency
    uBunker1Vibrator1Current : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[1].VFD.wMotorCurrent.rValue
    uBunker1Vibrator1SetFreq : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[1].VFD.cmdSetFrequency

    uBunker1Vibrator2OutFreq : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[2].VFD.qrOutFrequency
    uBunker1Vibrator2ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[1].MotorVibrator[2].VFD.rActualFrequency
    uBunker1Vibrator2Current : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[2].VFD.wMotorCurrent.rValue
    uBunker1Vibrator2SetFreq : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[2].VFD.cmdSetFrequency

    uBunker1Vibrator3OutFreq : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[3].VFD.qrOutFrequency
    uBunker1Vibrator3ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[1].MotorVibrator[3].VFD.rActualFrequency
    uBunker1Vibrator3Current : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[3].VFD.wMotorCurrent.rValue
    uBunker1Vibrator3SetFreq : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[3].VFD.cmdSetFrequency

    uBunker1Vibrator4OutFreq : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[4].VFD.qrOutFrequency
    uBunker1Vibrator4ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[1].MotorVibrator[4].VFD.rActualFrequency
    uBunker1Vibrator4Current : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[4].VFD.wMotorCurrent.rValue
    uBunker1Vibrator4SetFreq : U_RealToWord;        // Application.MAIN.stBunker[1].MotorVibrator[4].VFD.cmdSetFrequency

    // Бункер 2
    uBunker2Vibrator1OutFreq : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[1].VFD.qrOutFrequency
    uBunker2Vibrator1ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[2].MotorVibrator[1].VFD.rActualFrequency
    uBunker2Vibrator1Current : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[1].VFD.wMotorCurrent.rValue
    uBunker2Vibrator1SetFreq : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[1].VFD.cmdSetFrequency

    uBunker2Vibrator2OutFreq : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[2].VFD.qrOutFrequency
    uBunker2Vibrator2ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[2].MotorVibrator[2].VFD.rActualFrequency
    uBunker2Vibrator2Current : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[2].VFD.wMotorCurrent.rValue
    uBunker2Vibrator2SetFreq : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[2].VFD.cmdSetFrequency

    uBunker2Vibrator3OutFreq : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[3].VFD.qrOutFrequency
    uBunker2Vibrator3ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[2].MotorVibrator[3].VFD.rActualFrequency
    uBunker2Vibrator3Current : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[3].VFD.wMotorCurrent.rValue
    uBunker2Vibrator3SetFreq : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[3].VFD.cmdSetFrequency

    uBunker2Vibrator4OutFreq : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[4].VFD.qrOutFrequency
    uBunker2Vibrator4ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[2].MotorVibrator[4].VFD.rActualFrequency
    uBunker2Vibrator4Current : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[4].VFD.wMotorCurrent.rValue
    uBunker2Vibrator4SetFreq : U_RealToWord;        // Application.MAIN.stBunker[2].MotorVibrator[4].VFD.cmdSetFrequency

    // Бункер 3
    uBunker3Vibrator1OutFreq : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[1].VFD.qrOutFrequency
    uBunker3Vibrator1ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[3].MotorVibrator[1].VFD.rActualFrequency
    uBunker3Vibrator1Current : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[1].VFD.wMotorCurrent.rValue
    uBunker3Vibrator1SetFreq : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[1].VFD.cmdSetFrequency

    uBunker3Vibrator2OutFreq : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[2].VFD.qrOutFrequency
    uBunker3Vibrator2ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[3].MotorVibrator[2].VFD.rActualFrequency
    uBunker3Vibrator2Current : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[2].VFD.wMotorCurrent.rValue
    uBunker3Vibrator2SetFreq : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[2].VFD.cmdSetFrequency

    uBunker3Vibrator3OutFreq : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[3].VFD.qrOutFrequency
    uBunker3Vibrator3ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[3].MotorVibrator[3].VFD.rActualFrequency
    uBunker3Vibrator3Current : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[3].VFD.wMotorCurrent.rValue
    uBunker3Vibrator3SetFreq : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[3].VFD.cmdSetFrequency

    uBunker3Vibrator4OutFreq : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[4].VFD.qrOutFrequency
    uBunker3Vibrator4ActualFreq : U_RealToWord;     // Application.MAIN.stBunker[3].MotorVibrator[4].VFD.rActualFrequency
    uBunker3Vibrator4Current : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[4].VFD.wMotorCurrent.rValue
    uBunker3Vibrator4SetFreq : U_RealToWord;        // Application.MAIN.stBunker[3].MotorVibrator[4].VFD.cmdSetFrequency

    // VFD бункеров - вибропитатели (частоты и токи)
    // Бункер 1
    uBunker1VibFeeder1OutFreq : U_RealToWord;       // Application.MAIN.stBunker[1].MotorVibFeeder[1].VFD.qrOutFrequency
    uBunker1VibFeeder1ActualFreq : U_RealToWord;    // Application.MAIN.stBunker[1].MotorVibFeeder[1].VFD.rActualFrequency
    uBunker1VibFeeder1Current : U_RealToWord;       // Application.MAIN.stBunker[1].MotorVibFeeder[1].VFD.wMotorCurrent.rValue
    uBunker1VibFeeder1SetFreq : U_RealToWord;       // Application.MAIN.stBunker[1].MotorVibFeeder[1].VFD.cmdSetFrequency

    uBunker1VibFeeder2OutFreq : U_RealToWord;       // Application.MAIN.stBunker[1].MotorVibFeeder[2].VFD.qrOutFrequency
    uBunker1VibFeeder2ActualFreq : U_RealToWord;    // Application.MAIN.stBunker[1].MotorVibFeeder[2].VFD.rActualFrequency
    uBunker1VibFeeder2Current : U_RealToWord;       // Application.MAIN.stBunker[1].MotorVibFeeder[2].VFD.wMotorCurrent.rValue
    uBunker1VibFeeder2SetFreq : U_RealToWord;       // Application.MAIN.stBunker[1].MotorVibFeeder[2].VFD.cmdSetFrequency

    // Бункер 2
    uBunker2VibFeeder1OutFreq : U_RealToWord;       // Application.MAIN.stBunker[2].MotorVibFeeder[1].VFD.qrOutFrequency
    uBunker2VibFeeder1ActualFreq : U_RealToWord;    // Application.MAIN.stBunker[2].MotorVibFeeder[1].VFD.rActualFrequency
    uBunker2VibFeeder1Current : U_RealToWord;       // Application.MAIN.stBunker[2].MotorVibFeeder[1].VFD.wMotorCurrent.rValue
    uBunker2VibFeeder1SetFreq : U_RealToWord;       // Application.MAIN.stBunker[2].MotorVibFeeder[1].VFD.cmdSetFrequency

    uBunker2VibFeeder2OutFreq : U_RealToWord;       // Application.MAIN.stBunker[2].MotorVibFeeder[2].VFD.qrOutFrequency
    uBunker2VibFeeder2ActualFreq : U_RealToWord;    // Application.MAIN.stBunker[2].MotorVibFeeder[2].VFD.rActualFrequency
    uBunker2VibFeeder2Current : U_RealToWord;       // Application.MAIN.stBunker[2].MotorVibFeeder[2].VFD.wMotorCurrent.rValue
    uBunker2VibFeeder2SetFreq : U_RealToWord;       // Application.MAIN.stBunker[2].MotorVibFeeder[2].VFD.cmdSetFrequency

    // Бункер 3
    uBunker3VibFeeder1OutFreq : U_RealToWord;       // Application.MAIN.stBunker[3].MotorVibFeeder[1].VFD.qrOutFrequency
    uBunker3VibFeeder1ActualFreq : U_RealToWord;    // Application.MAIN.stBunker[3].MotorVibFeeder[1].VFD.rActualFrequency
    uBunker3VibFeeder1Current : U_RealToWord;       // Application.MAIN.stBunker[3].MotorVibFeeder[1].VFD.wMotorCurrent.rValue
    uBunker3VibFeeder1SetFreq : U_RealToWord;       // Application.MAIN.stBunker[3].MotorVibFeeder[1].VFD.cmdSetFrequency

    uBunker3VibFeeder2OutFreq : U_RealToWord;       // Application.MAIN.stBunker[3].MotorVibFeeder[2].VFD.qrOutFrequency
    uBunker3VibFeeder2ActualFreq : U_RealToWord;    // Application.MAIN.stBunker[3].MotorVibFeeder[2].VFD.rActualFrequency
    uBunker3VibFeeder2Current : U_RealToWord;       // Application.MAIN.stBunker[3].MotorVibFeeder[2].VFD.wMotorCurrent.rValue
    uBunker3VibFeeder2SetFreq : U_RealToWord;       // Application.MAIN.stBunker[3].MotorVibFeeder[2].VFD.cmdSetFrequency
END_VAR
