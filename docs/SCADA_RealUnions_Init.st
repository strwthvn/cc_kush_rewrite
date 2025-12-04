// Инициализация объединений U_RealToWord для SCADA
// Вызывать в цикле программы для обновления значений

// 1.2 Расчётные значения
uIcurPrecent.rTag := ICUR_PRECENT;
uElectricityMeter.rTag := rElectricityMeter;
uEfficiencyLimitRate.rTag := EFFICIENCY_LIMIT_RATE;

// 2.1 Настройки ЧРП
uVfdFrequencyMax.rTag := VFD_FREQUENCY_MAX;
uVfdFrequencyStep.rTag := VFD_FREQUENCY_STEP;
uVfdFrequencyInaccurancy.rTag := VFD_FREQUENCY_INACCURANCY;
uVfdFrequencySyncTolerance.rTag := VFD_FREQUENCY_SYNC_TOLERANCE;

// 2.2 Частоты двигателей
uMotorFrequencyConveyor.rTag := MOTOR_FREQUENCY_CONVEYOR;
uMotorFrequencyDumperConveyor.rTag := MOTOR_FREQUENCY_DUMPER_CONVEYOR;
uMotorFrequencyDumperRotation.rTag := MOTOR_FREQUENCY_DUMPER_ROTATION;
uConveyorDefaultSpeed.rTag := CONVEYOR_DEAFULT_SPEED;

// 2.4 Уставки бункеров
uBunkerWorkPrecent1.rTag := BUNKER_WORK_PRECENT_1;
uBunkerWorkPrecent2.rTag := BUNKER_WORK_PRECENT_2;
uBunkerWorkPrecent3.rTag := BUNKER_WORK_PRECENT_3;
uBunkerMinimalWeight.rTag := BUNKER_MINIMAL_WEIGHT;

// 2.6 Прочие уставки
uAnnunciatorLightHz.rTag := ANNUNCIATOR_LIGHT_HZ;

// 2.7 Уставки аварийных значений - Температура подшипников вибропитателя
uMotorVibfeederTempLL.rTag := MOTOR_VIBFEEDER_TEMP_POINTS.LL_Value;
uMotorVibfeederTempL.rTag := MOTOR_VIBFEEDER_TEMP_POINTS.L_Value;
uMotorVibfeederTempH.rTag := MOTOR_VIBFEEDER_TEMP_POINTS.H_Value;
uMotorVibfeederTempHH.rTag := MOTOR_VIBFEEDER_TEMP_POINTS.HH_Value;

// Ток мотора вибропитателя
uMotorVibfeederCurrentLL.rTag := MOTOR_VIBFEEDER_CURRENT_POINTS.LL_Value;
uMotorVibfeederCurrentL.rTag := MOTOR_VIBFEEDER_CURRENT_POINTS.L_Value;
uMotorVibfeederCurrentH.rTag := MOTOR_VIBFEEDER_CURRENT_POINTS.H_Value;
uMotorVibfeederCurrentHH.rTag := MOTOR_VIBFEEDER_CURRENT_POINTS.HH_Value;

// Ток мотора вибратора
uMotorVibratorCurrentLL.rTag := MOTOR_VIBRATOR_CURRENT_POINTS.LL_Value;
uMotorVibratorCurrentL.rTag := MOTOR_VIBRATOR_CURRENT_POINTS.L_Value;
uMotorVibratorCurrentH.rTag := MOTOR_VIBRATOR_CURRENT_POINTS.H_Value;
uMotorVibratorCurrentHH.rTag := MOTOR_VIBRATOR_CURRENT_POINTS.HH_Value;

// Ток мотора конвейера
uMotorConveyorCurrentLL.rTag := MOTOR_CONVEYOR_CURRENT_POINTS.LL_Value;
uMotorConveyorCurrentL.rTag := MOTOR_CONVEYOR_CURRENT_POINTS.L_Value;
uMotorConveyorCurrentH.rTag := MOTOR_CONVEYOR_CURRENT_POINTS.H_Value;
uMotorConveyorCurrentHH.rTag := MOTOR_CONVEYOR_CURRENT_POINTS.HH_Value;

// Ток мотора поворота отвалообразователя
uMotorRotationCurrentLL.rTag := MOTOR_ROTATION_CURRENT_POINTS.LL_Value;
uMotorRotationCurrentL.rTag := MOTOR_ROTATION_CURRENT_POINTS.L_Value;
uMotorRotationCurrentH.rTag := MOTOR_ROTATION_CURRENT_POINTS.H_Value;
uMotorRotationCurrentHH.rTag := MOTOR_ROTATION_CURRENT_POINTS.HH_Value;

// 3.1 Системные состояния MAIN
uMainIcurPrecent.rTag := ICUR_PRECENT;

// 6.1 Бункеры - веса и пропорции
uBunker1Weight.rTag := stBunker[1].rWeight;
uBunker1ProportionActual.rTag := stBunker[1].rProportionActual;
uBunker1VibFeederFrequency.rTag := stBunker[1].rMotorVibFeederCommonFrequency;
uBunker1DumpingPrecent.rTag := stBunker[1].cmdDumpingPrecent;

uBunker2Weight.rTag := stBunker[2].rWeight;
uBunker2ProportionActual.rTag := stBunker[2].rProportionActual;
uBunker2VibFeederFrequency.rTag := stBunker[2].rMotorVibFeederCommonFrequency;
uBunker2DumpingPrecent.rTag := stBunker[2].cmdDumpingPrecent;

uBunker3Weight.rTag := stBunker[3].rWeight;
uBunker3ProportionActual.rTag := stBunker[3].rProportionActual;
uBunker3VibFeederFrequency.rTag := stBunker[3].rMotorVibFeederCommonFrequency;
uBunker3DumpingPrecent.rTag := stBunker[3].cmdDumpingPrecent;

// VFD - Отвалообразователь конвейер
uDumperMotorConveyor1OutFreq.rTag := stDumper.MotorConveyor[1].VFD.qrOutFrequency;
uDumperMotorConveyor1ActualFreq.rTag := stDumper.MotorConveyor[1].VFD.rActualFrequency;
uDumperMotorConveyor1Current.rTag := stDumper.MotorConveyor[1].VFD.wMotorCurrent.rTag;
uDumperMotorConveyor1SetFreq.rTag := stDumper.MotorConveyor[1].VFD.cmdSetFrequency;

uDumperMotorConveyor2OutFreq.rTag := stDumper.MotorConveyor[2].VFD.qrOutFrequency;
uDumperMotorConveyor2ActualFreq.rTag := stDumper.MotorConveyor[2].VFD.rActualFrequency;
uDumperMotorConveyor2Current.rTag := stDumper.MotorConveyor[2].VFD.wMotorCurrent.rTag;
uDumperMotorConveyor2SetFreq.rTag := stDumper.MotorConveyor[2].VFD.cmdSetFrequency;

// VFD - Отвалообразователь поворот
uDumperMotorRotation1OutFreq.rTag := stDumper.MotorRotation[1].VFD.qrOutFrequency;
uDumperMotorRotation1ActualFreq.rTag := stDumper.MotorRotation[1].VFD.rActualFrequency;
uDumperMotorRotation1Current.rTag := stDumper.MotorRotation[1].VFD.wMotorCurrent.rTag;
uDumperMotorRotation1SetFreq.rTag := stDumper.MotorRotation[1].VFD.cmdSetFrequency;

uDumperMotorRotation2OutFreq.rTag := stDumper.MotorRotation[2].VFD.qrOutFrequency;
uDumperMotorRotation2ActualFreq.rTag := stDumper.MotorRotation[2].VFD.rActualFrequency;
uDumperMotorRotation2Current.rTag := stDumper.MotorRotation[2].VFD.wMotorCurrent.rTag;
uDumperMotorRotation2SetFreq.rTag := stDumper.MotorRotation[2].VFD.cmdSetFrequency;

// VFD - Конвейер
uConveyorMotor1OutFreq.rTag := stConveyor.MotorConveyor[1].VFD.qrOutFrequency;
uConveyorMotor1ActualFreq.rTag := stConveyor.MotorConveyor[1].VFD.rActualFrequency;
uConveyorMotor1Current.rTag := stConveyor.MotorConveyor[1].VFD.wMotorCurrent.rTag;
uConveyorMotor1SetFreq.rTag := stConveyor.MotorConveyor[1].VFD.cmdSetFrequency;

uConveyorMotor2OutFreq.rTag := stConveyor.MotorConveyor[2].VFD.qrOutFrequency;
uConveyorMotor2ActualFreq.rTag := stConveyor.MotorConveyor[2].VFD.rActualFrequency;
uConveyorMotor2Current.rTag := stConveyor.MotorConveyor[2].VFD.wMotorCurrent.rTag;
uConveyorMotor2SetFreq.rTag := stConveyor.MotorConveyor[2].VFD.cmdSetFrequency;

// Температуры подшипников вибропитателей
uBunker1VibFeeder1TempBearing1.rTag := stBunker[1].MotorVibFeeder[1].fbTempBearing[1].qrProcessedValue;
uBunker1VibFeeder1TempBearing2.rTag := stBunker[1].MotorVibFeeder[1].fbTempBearing[2].qrProcessedValue;
uBunker1VibFeeder2TempBearing1.rTag := stBunker[1].MotorVibFeeder[2].fbTempBearing[1].qrProcessedValue;
uBunker1VibFeeder2TempBearing2.rTag := stBunker[1].MotorVibFeeder[2].fbTempBearing[2].qrProcessedValue;

uBunker2VibFeeder1TempBearing1.rTag := stBunker[2].MotorVibFeeder[1].fbTempBearing[1].qrProcessedValue;
uBunker2VibFeeder1TempBearing2.rTag := stBunker[2].MotorVibFeeder[1].fbTempBearing[2].qrProcessedValue;
uBunker2VibFeeder2TempBearing1.rTag := stBunker[2].MotorVibFeeder[2].fbTempBearing[1].qrProcessedValue;
uBunker2VibFeeder2TempBearing2.rTag := stBunker[2].MotorVibFeeder[2].fbTempBearing[2].qrProcessedValue;

uBunker3VibFeeder1TempBearing1.rTag := stBunker[3].MotorVibFeeder[1].fbTempBearing[1].qrProcessedValue;
uBunker3VibFeeder1TempBearing2.rTag := stBunker[3].MotorVibFeeder[1].fbTempBearing[2].qrProcessedValue;
uBunker3VibFeeder2TempBearing1.rTag := stBunker[3].MotorVibFeeder[2].fbTempBearing[1].qrProcessedValue;
uBunker3VibFeeder2TempBearing2.rTag := stBunker[3].MotorVibFeeder[2].fbTempBearing[2].qrProcessedValue;

// VFD бункеров - вибраторы
// Бункер 1
uBunker1Vibrator1OutFreq.rTag := stBunker[1].MotorVibrator[1].VFD.qrOutFrequency;
uBunker1Vibrator1ActualFreq.rTag := stBunker[1].MotorVibrator[1].VFD.rActualFrequency;
uBunker1Vibrator1Current.rTag := stBunker[1].MotorVibrator[1].VFD.wMotorCurrent.rTag;
uBunker1Vibrator1SetFreq.rTag := stBunker[1].MotorVibrator[1].VFD.cmdSetFrequency;

uBunker1Vibrator2OutFreq.rTag := stBunker[1].MotorVibrator[2].VFD.qrOutFrequency;
uBunker1Vibrator2ActualFreq.rTag := stBunker[1].MotorVibrator[2].VFD.rActualFrequency;
uBunker1Vibrator2Current.rTag := stBunker[1].MotorVibrator[2].VFD.wMotorCurrent.rTag;
uBunker1Vibrator2SetFreq.rTag := stBunker[1].MotorVibrator[2].VFD.cmdSetFrequency;

uBunker1Vibrator3OutFreq.rTag := stBunker[1].MotorVibrator[3].VFD.qrOutFrequency;
uBunker1Vibrator3ActualFreq.rTag := stBunker[1].MotorVibrator[3].VFD.rActualFrequency;
uBunker1Vibrator3Current.rTag := stBunker[1].MotorVibrator[3].VFD.wMotorCurrent.rTag;
uBunker1Vibrator3SetFreq.rTag := stBunker[1].MotorVibrator[3].VFD.cmdSetFrequency;

uBunker1Vibrator4OutFreq.rTag := stBunker[1].MotorVibrator[4].VFD.qrOutFrequency;
uBunker1Vibrator4ActualFreq.rTag := stBunker[1].MotorVibrator[4].VFD.rActualFrequency;
uBunker1Vibrator4Current.rTag := stBunker[1].MotorVibrator[4].VFD.wMotorCurrent.rTag;
uBunker1Vibrator4SetFreq.rTag := stBunker[1].MotorVibrator[4].VFD.cmdSetFrequency;

// Бункер 2
uBunker2Vibrator1OutFreq.rTag := stBunker[2].MotorVibrator[1].VFD.qrOutFrequency;
uBunker2Vibrator1ActualFreq.rTag := stBunker[2].MotorVibrator[1].VFD.rActualFrequency;
uBunker2Vibrator1Current.rTag := stBunker[2].MotorVibrator[1].VFD.wMotorCurrent.rTag;
uBunker2Vibrator1SetFreq.rTag := stBunker[2].MotorVibrator[1].VFD.cmdSetFrequency;

uBunker2Vibrator2OutFreq.rTag := stBunker[2].MotorVibrator[2].VFD.qrOutFrequency;
uBunker2Vibrator2ActualFreq.rTag := stBunker[2].MotorVibrator[2].VFD.rActualFrequency;
uBunker2Vibrator2Current.rTag := stBunker[2].MotorVibrator[2].VFD.wMotorCurrent.rTag;
uBunker2Vibrator2SetFreq.rTag := stBunker[2].MotorVibrator[2].VFD.cmdSetFrequency;

uBunker2Vibrator3OutFreq.rTag := stBunker[2].MotorVibrator[3].VFD.qrOutFrequency;
uBunker2Vibrator3ActualFreq.rTag := stBunker[2].MotorVibrator[3].VFD.rActualFrequency;
uBunker2Vibrator3Current.rTag := stBunker[2].MotorVibrator[3].VFD.wMotorCurrent.rTag;
uBunker2Vibrator3SetFreq.rTag := stBunker[2].MotorVibrator[3].VFD.cmdSetFrequency;

uBunker2Vibrator4OutFreq.rTag := stBunker[2].MotorVibrator[4].VFD.qrOutFrequency;
uBunker2Vibrator4ActualFreq.rTag := stBunker[2].MotorVibrator[4].VFD.rActualFrequency;
uBunker2Vibrator4Current.rTag := stBunker[2].MotorVibrator[4].VFD.wMotorCurrent.rTag;
uBunker2Vibrator4SetFreq.rTag := stBunker[2].MotorVibrator[4].VFD.cmdSetFrequency;

// Бункер 3
uBunker3Vibrator1OutFreq.rTag := stBunker[3].MotorVibrator[1].VFD.qrOutFrequency;
uBunker3Vibrator1ActualFreq.rTag := stBunker[3].MotorVibrator[1].VFD.rActualFrequency;
uBunker3Vibrator1Current.rTag := stBunker[3].MotorVibrator[1].VFD.wMotorCurrent.rTag;
uBunker3Vibrator1SetFreq.rTag := stBunker[3].MotorVibrator[1].VFD.cmdSetFrequency;

uBunker3Vibrator2OutFreq.rTag := stBunker[3].MotorVibrator[2].VFD.qrOutFrequency;
uBunker3Vibrator2ActualFreq.rTag := stBunker[3].MotorVibrator[2].VFD.rActualFrequency;
uBunker3Vibrator2Current.rTag := stBunker[3].MotorVibrator[2].VFD.wMotorCurrent.rTag;
uBunker3Vibrator2SetFreq.rTag := stBunker[3].MotorVibrator[2].VFD.cmdSetFrequency;

uBunker3Vibrator3OutFreq.rTag := stBunker[3].MotorVibrator[3].VFD.qrOutFrequency;
uBunker3Vibrator3ActualFreq.rTag := stBunker[3].MotorVibrator[3].VFD.rActualFrequency;
uBunker3Vibrator3Current.rTag := stBunker[3].MotorVibrator[3].VFD.wMotorCurrent.rTag;
uBunker3Vibrator3SetFreq.rTag := stBunker[3].MotorVibrator[3].VFD.cmdSetFrequency;

uBunker3Vibrator4OutFreq.rTag := stBunker[3].MotorVibrator[4].VFD.qrOutFrequency;
uBunker3Vibrator4ActualFreq.rTag := stBunker[3].MotorVibrator[4].VFD.rActualFrequency;
uBunker3Vibrator4Current.rTag := stBunker[3].MotorVibrator[4].VFD.wMotorCurrent.rTag;
uBunker3Vibrator4SetFreq.rTag := stBunker[3].MotorVibrator[4].VFD.cmdSetFrequency;

// VFD бункеров - вибропитатели
// Бункер 1
uBunker1VibFeeder1OutFreq.rTag := stBunker[1].MotorVibFeeder[1].VFD.qrOutFrequency;
uBunker1VibFeeder1ActualFreq.rTag := stBunker[1].MotorVibFeeder[1].VFD.rActualFrequency;
uBunker1VibFeeder1Current.rTag := stBunker[1].MotorVibFeeder[1].VFD.wMotorCurrent.rTag;
uBunker1VibFeeder1SetFreq.rTag := stBunker[1].MotorVibFeeder[1].VFD.cmdSetFrequency;

uBunker1VibFeeder2OutFreq.rTag := stBunker[1].MotorVibFeeder[2].VFD.qrOutFrequency;
uBunker1VibFeeder2ActualFreq.rTag := stBunker[1].MotorVibFeeder[2].VFD.rActualFrequency;
uBunker1VibFeeder2Current.rTag := stBunker[1].MotorVibFeeder[2].VFD.wMotorCurrent.rTag;
uBunker1VibFeeder2SetFreq.rTag := stBunker[1].MotorVibFeeder[2].VFD.cmdSetFrequency;

// Бункер 2
uBunker2VibFeeder1OutFreq.rTag := stBunker[2].MotorVibFeeder[1].VFD.qrOutFrequency;
uBunker2VibFeeder1ActualFreq.rTag := stBunker[2].MotorVibFeeder[1].VFD.rActualFrequency;
uBunker2VibFeeder1Current.rTag := stBunker[2].MotorVibFeeder[1].VFD.wMotorCurrent.rTag;
uBunker2VibFeeder1SetFreq.rTag := stBunker[2].MotorVibFeeder[1].VFD.cmdSetFrequency;

uBunker2VibFeeder2OutFreq.rTag := stBunker[2].MotorVibFeeder[2].VFD.qrOutFrequency;
uBunker2VibFeeder2ActualFreq.rTag := stBunker[2].MotorVibFeeder[2].VFD.rActualFrequency;
uBunker2VibFeeder2Current.rTag := stBunker[2].MotorVibFeeder[2].VFD.wMotorCurrent.rTag;
uBunker2VibFeeder2SetFreq.rTag := stBunker[2].MotorVibFeeder[2].VFD.cmdSetFrequency;

// Бункер 3
uBunker3VibFeeder1OutFreq.rTag := stBunker[3].MotorVibFeeder[1].VFD.qrOutFrequency;
uBunker3VibFeeder1ActualFreq.rTag := stBunker[3].MotorVibFeeder[1].VFD.rActualFrequency;
uBunker3VibFeeder1Current.rTag := stBunker[3].MotorVibFeeder[1].VFD.wMotorCurrent.rTag;
uBunker3VibFeeder1SetFreq.rTag := stBunker[3].MotorVibFeeder[1].VFD.cmdSetFrequency;

uBunker3VibFeeder2OutFreq.rTag := stBunker[3].MotorVibFeeder[2].VFD.qrOutFrequency;
uBunker3VibFeeder2ActualFreq.rTag := stBunker[3].MotorVibFeeder[2].VFD.rActualFrequency;
uBunker3VibFeeder2Current.rTag := stBunker[3].MotorVibFeeder[2].VFD.wMotorCurrent.rTag;
uBunker3VibFeeder2SetFreq.rTag := stBunker[3].MotorVibFeeder[2].VFD.cmdSetFrequency;
