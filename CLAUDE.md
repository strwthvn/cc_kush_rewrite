# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an industrial automation control system written in **IEC 61131-3 Structured Text** for controlling conveyor systems, dumpers, and material handling equipment. The system manages material dosing from 3 bunkers through vibratory feeders onto a conveyor line via a dumper with proportional control.

**Language**: IEC 61131-3 Structured Text (`.st` files)
**Domain**: Industrial automation, PLC programming, conveyor control systems, material dosing
**Programming Style**: Functional programming (no METHOD blocks, direct output access)
**Target Platform**: Programmable Logic Controller (PLC)

## Project Architecture

The project is organized into 4 main directories:

```
newProject/
├── POUs/              # Program Organization Units - main programs & control blocks
│   ├── System/        # System-level blocks (emergency stop collector)
│   ├── Dumper/        # Dumper control blocks (FC/, ST/, POU/)
│   └── Conveyor/      # Conveyor control blocks (FC/, POU/)
├── DataTypes/         # Type definitions (structures and enumerations)
│   ├── Structures/    # Equipment structures (ST_*)
│   ├── Enumerations/  # State enumerations (E_*)
│   └── Unions/        # Type conversion unions (U_*)
├── Functions/         # Pure functions for error checking and calculations
│   ├── Bunker/        # Bunker-related functions
│   ├── Conveyor/      # Conveyor-related functions
│   ├── Sensors/       # Safety sensor check functions
│   ├── Modbus/        # Modbus read/write functions
│   ├── System/        # System-wide functions
│   └── Utilities/     # Utility functions
└── Library/           # Universal functional blocks (core library)
```

### POUs/ - Program Organization Units

Contains the main program and control function blocks:

#### Main Program
- **MAIN.st**: Main program with automatic control sequencing
  - **Equipment**: 3 bunkers, 1 dumper, 1 conveyor
  - **Stages**: IDLE → INIT → START_DUMPER → START_CONV → START_VIBFEEDER → WORK → END_REPORT → ERROR
  - **Emergency stop**: Centralized via FB_EmergencyStopCollector
  - **PID control**: Optional proportional material dosing (BUNKER_ENABLE_PID)
  - **SCADA heartbeat**: Communication monitoring via FB_ScadaCommunication
  - **Modbus integration**: Real-time data exchange with SCADA
  - **Simulation support**: Full simulation mode for testing

- **GLOBAL.st**: Global variables and system settings
  - System flags (emergency stop, errors, auto working)
  - **Emergency stop options** (ENABLE_GLOBAL_ESTOP_* flags)
  - **Section dependencies** (ENABLE_ESTOP_DEPENDENCIES_* flags)
  - VFD parameters (frequency, ADC/DAC ranges, 4-20mA)
  - Equipment setpoints (temperatures, currents, vibrator settings)
  - **Timeouts** (TIME_TIMEOUT_START/STOP_* for command execution control)
  - Modbus register arrays (awModbusInputRegisters, awModbusHoldingRegisters)
  - SCADA heartbeat timeout (SCADA_HEARTBEAT_TIMEOUT)

#### System Blocks (POUs/System/)
- **FB_EmergencyStopCollector.st**: Centralized emergency stop collector
  - Collects ALL emergency stop signals in one place
  - **Guaranteed sources** (always active): E-Stop buttons (local and common), SCADA command
  - **Configurable sources** (via ENABLE_GLOBAL_ESTOP_* flags): sensors ZQ, HQ, SQ, GS, YS, YE, QR, SCADA loss, proportion error, motor current HH
  - **Section-level stops**: qxSectionStop_Dumper, qxSectionStop_Conveyor, qxSectionStop_Bunker1/2/3
  - **Diagnostics**: Reason codes for SCADA (qnReasonCode), reset blocked status
  - **Dependencies**: Section dependencies via ENABLE_ESTOP_DEPENDENCIES_* flags

#### Control Function Blocks (no methods, all inline)

**Bunker Control:**
- **FB_BunkerControl.st**: Bunker control with vibratory feeders
  - 2 vibratory feeders (ST_MotorVibFeeder) per bunker
  - 4 vibrators (ST_Motor) for material flow assistance
  - Temperature monitoring (bearing sensors, 4-20mA)
  - Weight-based proportioning
  - Traffic light signaling (red/yellow/green)
  - Pneumatic collapse control
  - Local (PMU) and remote (SCADA) modes

**Dumper Control (POUs/Dumper/):**
- **FB_DumperControl.st**: Dumper control with conveyor and rotation
  - 2 conveyor motors (22 kW each) with synchronization
  - 2 rotation motors (3 kW each) for dumper positioning
  - Pre-start alarm system (optional via DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS)
  - Safety sensor monitoring (ZQ, HQ, SQ, GS, YS, QR)
  - Smooth frequency ramping with sync tolerance
  - **Start/stop timeouts** (TIME_TIMEOUT_START/STOP_DUMPER_CONVEYOR/ROTATION)

- **Hardware sub-blocks (POUs/Dumper/POU/Hardware/):**
  - `FB_DumperConveyorMotors.st` - Conveyor motor control with synchronization
  - `FB_DumperRotationMotors.st` - Rotation motor control with end switches
  - `FB_DumperSensors.st` - Safety sensor processing (ZQ, HQ, SQ, GS, YS, QR)
  - `FB_DumperMotorErrors.st` - Motor error aggregation

- **I/O block (POUs/Dumper/POU/IO/):**
  - `FB_DumperIO.st` - Hardware I/O mapping

- **Functions (POUs/Dumper/FC/):**
  - `FC_Dumper_GetErrorSensors.st` - Sensor error check
  - `FC_Dumper_GetErrorCommon.st` - Common error aggregation
  - `FC_Dumper_EmergencyStop.st` - Emergency stop logic

**Conveyor Control (POUs/Conveyor/):**
- **FB_ConveyorControl.st**: Assembly conveyor startup sequencing
  - Similar structure to FB_DumperControl (2 motors, no rotation)
  - Safety interlocks and sensor monitoring
  - **Start/stop timeouts** (TIME_TIMEOUT_START/STOP_CONVEYOR)

- **Hardware sub-blocks (POUs/Conveyor/POU/Hardware/):**
  - `FB_ConveyorMotors.st` - Motor control with synchronization
  - `FB_ConveyorSensors.st` - Safety sensor processing (ZQ, HQ, SQ, GS, YS, YE, QR)
  - `FB_ConveyorMotorErrors.st` - Motor error aggregation

- **I/O block (POUs/Conveyor/POU/IO/):**
  - `FB_ConveyorIO.st` - Hardware I/O mapping

- **Functions (POUs/Conveyor/FC/):**
  - `FC_Conveyor_GetErrorSensors.st` - Sensor error check
  - `FC_Conveyor_GetErrorMotor.st` - Motor error check
  - `FC_Conveyor_GetErrorCommon.st` - Common error aggregation
  - `FC_Conveyor_EmergencyStop.st` - Emergency stop logic

#### Auxiliary Blocks
- **FB_VibratorControl.st**: Cyclic vibrator control (active → pause → active)
- **FB_PneumoCollapseControl.st**: Cyclic pneumatic collapse for material flow
- **FB_ConveyorWeight.st**: Conveyor weight processing (under bunkers)
- **FB_ModbusToSCADA.st**: Modbus data exchange with SCADA
- **FB_Simulation.st**: Hardware simulation for testing (full analog I/O loop simulation)

### DataTypes/

Equipment structures and enumerations:

#### Motor Structures (DataTypes/Structures/)
- **ST_Motor**: Base motor with contactor (KM), circuit breaker (QF), VFD
  - fbStateKM, fbStateQF: Signal processing with FB_UniversalSignal
  - Device: FB_UniversalMechanism for control
  - VFD: ST_VFD structure
  - xStateWarning, xStateFailure: Status flags

- **ST_MotorWithFeedback**: Motor with feedback signal (EXTENDS ST_Motor)
- **ST_MotorWithReverse**: Motor with reversing capability (for rotation)
- **ST_MotorVibFeeder**: Vibrating feeder motor with bearing temperature sensors
  - rTempBearing[1..2]: Temperature readings
  - fbRangeDiagnostic[1..2]: LL/L/H/HH diagnostics
  - fbAnalogInput[1..2]: 4-20mA to temperature conversion

#### VFD Structure
- **ST_VFD**: Variable Frequency Drive
  - Discrete inputs: fbStateRdyToStart, fbStateIsWorking, fbStateFailure
  - Analog I/O: nActualFrequencyADC (input), nSetOutSignalToModule (output)
  - Control: Device (FB_UniversalMechanism), Frequency (FB_FrequencyControl)
  - Diagnostics: fbRangeDiagnostic (current monitoring)
  - I/O blocks: fbAnalogInput, fbAnalogOutput (4-20mA conversion)
  - Modbus: wMotorCurrent, uActualFrequency (U_RealToWord unions)

#### Equipment Structures
- **ST_Bunker**: Bunker with vibratory feeders and vibrators
  - MotorVibrator[1..4]: Vibrators for material flow
  - MotorVibFeeder[1..2]: Vibratory feeders for dosing
  - rWeight: Weight in bunker
  - rWeightUnderBunker: Cumulative weight on conveyor (for proportion calculation)
  - rProportionActual: Actual proportion (calculated from weights)
  - rMotorVibFeederCommonFrequency: Target frequency from PID controller
  - fbStateHatch: Hatch position sensor
  - qxLightRed, qxLightYellow, qxLightGreen: Traffic light outputs
  - eLightColor: Current traffic light color (E_LightColor)
  - **Control modes**: eStateRemote, eVibratorStateRemote, eStateRemoteLighter
  - **SCADA commands**: cmdStartFeeder, cmdStopFeeder, cmdStartVibrator, cmdStopVibrator, etc.
  - **PMU buttons**: fbBtnStart, fbBtnStop, fbBtnEmergencyStop

- **ST_ConveyorBasic**: Base conveyor structure
  - MotorConveyor[1..2]: Main drive motors (ST_MotorWithFeedback)
  - Safety sensors (1 = OK, 0 = alarm):
    - fbZQAlarm[1..4], fbZQWarning[1..4]: Belt misalignment
    - fbHQ_IsOk[1..4]: Cable pull-cord emergency stops
    - fbSQ_IsOk[1..2]: Guard limit switches
    - fbGS1: Material buildup detection
    - fbQR[1..2]: Speed sensors
    - fbYS1: Longitudinal tear detection
  - xHLA, xSoundAlarm: Alarm outputs
  - **PMU buttons**: fbBtnStart, fbBtnStop, fbBtnEmergencyStop
  - **SCADA commands**: cmdStartConveyor, cmdStopConveyor, cmdEmergencyStop, cmdReset

- **ST_Dumper**: Dumper (EXTENDS ST_ConveyorBasic)
  - MotorRotation[1..2]: Rotation motors (ST_MotorWithReverse)
  - fbEndSwitchRight, fbEndSwitchLeft: Limit switches
  - fbBreakerRotation, qxBreakerRotation: Rotation brake
  - Rotation buttons: fbBtnTurnLeft, fbBtnTurnRight
  - fbBtnRemoteMode: Mode selector
  - States: xStateEnable, xStateStarting, xStateWarning, xStateFailure
  - fbPreStartAlarm: Pre-start alarm handler
  - **SCADA commands**: cmdTurnLeft, cmdTurnRight, cmdStopRotation, cmdBuildCircuitOn/Off

- **ST_ConveyorPrefabricated**: Assembly conveyor (EXTENDS ST_ConveyorBasic)

#### Support Structures
- **ST_Commands**: SCADA command signals
  - cmdResetAll, cmdStartCommon, cmdStopCommon, cmdEmergencyStopCommon
  - All use FB_UniversalSignal for edge detection

- **ST_CommonSignals**: Common system signals
  - fbEmergencyStopBtn, fbRemoteModeBtn, fbRealyCurrentControl
  - fbQF1, fb9QF1, fb10QF1, fb11QF1: Circuit breakers

- **ST_AlarmSetpoints**: LL/L/H/HH setpoints for diagnostics (LL_Value, L_Value, H_Value, HH_Value)
- **ST_PreStartAlarmSettings**: Pre-start alarm timing parameters (OPTION_ENABLE, TIME_FIRST_SIGNAL, etc.)
- **ST_BunkerVibratorSettings**: Vibrator cycle settings (TIME_ACTIVE, TIME_PAUSE_VIBRATOR, TIME_PAUSE_FB, COUNT_CYCLE)

#### Enumerations (DataTypes/Enumerations/)
- **E_StateFeedback**: Mechanism feedback states
  - Inactive (0): Normal when stopped
  - Active (1): Normal when running
  - Error_NoFeedback (2): Power on but no feedback
  - Error_UnexpectedFeedback (3): Feedback without power

- **E_StageWithPreStartAlarm**: Control stages
  - IDLE, PRESTART_ALARM, STARTING, WORK, ERROR

- **E_StateRemote**: Control modes
  - Manual (0): Local control (PMU buttons)
  - Remote (1): SCADA control
  - Auto (2): Automatic sequencing

- **E_StateMechanism**: Mechanism states
  - NotReady, Ready, Working, Warning, Error

- **E_ScadaStatesDevice**: SCADA status representation
  - NOT_READY, READY, STARTING, WORK, WORK_WITH_WARNING, WORK_WITH_ERROR, WARNING, ERROR

- **E_LightColor**: Traffic light colors
  - OFF (0), RED (1), YELLOW (2), GREEN (3)

- **E_VibratorState**: Vibrator cycle states
  - IDLE, ACTIVE, PAUSE_VIBRATOR, PAUSE_FB

- **E_AlarmSetpoints**: Alarm level enumeration
  - LL, L, NORMAL, H, HH

- **E_StageActuator**: Actuator stages (reserved)

#### Unions (DataTypes/Unions/)
- **U_RealToWord**: REAL ↔ ARRAY[0..1] OF WORD (for Modbus)
- **U_ByteToWord**: BYTE ↔ WORD (for bit packing)
- **U_TimeToWord**: TIME ↔ ARRAY[0..1] OF WORD (for Modbus)
- **U_DintToWord**: DINT ↔ ARRAY[0..1] OF WORD
- **U_UdintToWord**: UDINT ↔ ARRAY[0..1] OF WORD

### Functions/

Pure functions for reusable logic (no state, all FC_* files):

#### Bunker Functions (Functions/Bunker/)
- **FC_Bunker_CheckWeight**: Check if weight is sufficient
- **FC_Bunker_CheckCriticalWeight**: Check if at least one bunker has sufficient weight
- **FC_Bunker_CheckEmptyBunker**: Check if bunker is empty
- **FC_Bunker_GetErrorBunker**: Base bunker errors (hatch, weight)
- **FC_Bunker_GetErrorMotorVibFeeder**: Vibratory feeder errors (QF, KM, VFD, overheating, temperature, current)
- **FC_Bunker_GetErrorMotorVibrator**: Vibrator errors (QF, KM, VFD)
- **FC_Bunker_GetErrorWeight**: Weight sensor errors
- **FC_Bunker_GetLightColor**: Calculate traffic light color from states
- **FC_Bunker_SetLightColor**: Set traffic light physical outputs
- **FC_Bunker_EmergencyStop**: Bunker emergency stop logic

#### Sensor Functions (Functions/Sensors/)
Safety sensor check functions (return TRUE on error):
- **FC_Sensor_CheckZQAlarm**: Belt misalignment alarm
- **FC_Sensor_CheckZQWarning**: Belt misalignment warning
- **FC_Sensor_CheckHQ**: Cable pull-cord emergency stop
- **FC_Sensor_CheckSQ**: Guard limit switch
- **FC_Sensor_CheckGS**: Material buildup detection
- **FC_Sensor_CheckYS**: Longitudinal tear detection
- **FC_Sensor_CheckYE**: Metal detector

#### Conveyor Functions (Functions/Conveyor/)
- **FC_Conveyor_GetErrorMotor**: Motor errors (QF, feedback, VFD)
- **FC_Conveyor_GetErrorSensors**: Safety sensor errors (ZQ, HQ, SQ, GS, YS, YE)
- **FC_Conveyor_GetErrorCommon**: Aggregate all conveyor errors
- **FC_Conveyor_EmergencyStop**: Emergency stop logic

#### System Functions (Functions/System/)
- **FC_Get_ErrorCommon**: Aggregate ALL system errors
  - 3 bunkers + conveyor + dumper
  - Used for xStateErrorCheckReady in MAIN.st

#### Modbus Functions (Functions/Modbus/)
**Read functions:**
- **FC_ModbusReadBool**: Read BOOL from register bit
- **FC_ModbusReadInt**: Read INT from register
- **FC_ModbusReadDint**: Read DINT from 2 registers
- **FC_ModbusReadUdint**: Read UDINT from 2 registers
- **FC_ModbusReadReal**: Read REAL from 2 registers (using U_RealToWord)
- **FC_ModbusReadTime**: Read TIME from 2 registers (using U_TimeToWord)

**Write functions:**
- **FC_ModbusWriteBool**: Write BOOL to register bit (bitwise packing)
- **FC_ModbusWriteInt**: Write INT to register (1 WORD)
- **FC_ModbusWriteUInt**: Write UINT to register
- **FC_ModbusWriteDint**: Write DINT to 2 registers
- **FC_ModbusWriteUdint**: Write UDINT to 2 registers
- **FC_ModbusWriteReal**: Write REAL to 2 registers (using U_RealToWord)
- **FC_ModbusWriteTime**: Write TIME to 2 registers (using U_TimeToWord)

All Modbus functions use `POINTER TO WORD` for flexible array access with pointer arithmetic.

#### Utility Functions (Functions/Utilities/)
- **FC_MotorSyncronizedWork**: Check motor synchronization
- **FC_VFD_ChangeReadMode**: Switch VFD Modbus read mode
- **FC_SwapBytesInWord**: Swap bytes in word (Modbus byte order)
- **FC_SwapBytesInWordArray**: Swap bytes in word array
- **FC_SwapWordArrayElements**: Swap word array elements

### Library/

Universal functional blocks (the core functional programming library):

#### Signal Processing

**FB_UniversalSignal** - Unified discrete signal handling:
- **Optional features** (enable flags):
  - `xEnableRattlingFilter`: Debounce mechanical contacts
  - `xEnableFeedback`: Track feedback signal
  - `xEnableFeedbackTimer`: Detect missing feedback with timeout
- **Outputs**: qxSignal, qxInvertedSignal, qxRisingEdge, qxFallingEdge
- **Feedback outputs**: qxWaitingFeedback, qxFeedbackReceived, qxFeedbackTimeout
- **Diagnostics**: qxRattlingDetected, qnTransitionCount

**FB_UniversalAnalogSignal** - Unified analog signal processing:
- 4-20mA scaling with `xMode4_20mA := TRUE`
- Configurable range mapping (irRawMin/Max, irScaledMin/Max)
- Direct output: `qrProcessedValue`

**FB_AnalogInput** - 4-20mA analog input processing:
- ADC code → Engineering units conversion
- 4-20mA diagnostics (LL < 3.8mA = break, HH > 20.2mA = short)
- Simulation mode support
- Direct REAL output via REFERENCE TO

**FB_AnalogOutput** - 4-20mA analog output generation:
- Engineering units → DAC code conversion
- Clamping within range
- Enabled/disabled state management

#### Mechanism Control

**FB_UniversalMechanism** - Direct mechanism control:
- **Inputs**: xStartCommand, xStopCommand, xStartCondition, xStopCondition, xReset
- **Outputs**: qxPower, quFeedbackState, qxActive, qxInactive
- **Error outputs**: qxError_NoFeedback, qxError_UnexpectedFeedback, qxHasError
- **Optional feedback** with `xEnableFeedback := TRUE`

#### Frequency Control

**FB_FrequencyControl** - Smooth VFD frequency ramping:
- **Inputs**: rTargetFrequency, irStep, xPulse, xConditionToProceed
- **Output**: qrCurrentFrequency
- **Features**: Smooth ramping, hold, reset
- **Synchronization**: xConditionToProceed blocks ramping until motors sync

#### Diagnostics

**FB_RangeDiagnostic** - 4-level analog diagnostics (LL/L/H/HH):
- **Inputs**: irValue, irSetpointLL, irSetpointL, irSetpointH, irSetpointHH
- **Outputs**: qxAlarmLL, qxWarningL, qxWarningH, qxAlarmHH
- **Aggregates**: qxAlarmActive, qxWarningActive

**FB_NumericChangeDetector** - Numeric value change detection:
- Detects changes beyond threshold
- Stores previous value

**FB_PreStartAlarm** - Pre-start alarm sequencing:
- Two-stage alarm: 1st signal → pause → 2nd signal → pause → complete
- Timing parameters: itFirstSignal, itPauseAfterFirst, itSecondSignal, itPauseAfterSecond
- Output: qxAlarmPower (to horn/siren)

**FB_ProportionPID** - PID controller for bunker proportions:
- 3-channel PID (one per bunker)
- Inputs: target proportions, actual proportions (from weights)
- Outputs: frequencies for vibratory feeders
- Auto-normalization of proportions
- Anti-windup integral limiting
- Frequency scaling to maintain target sum

#### Communication

**FB_ScadaCommunication** - SCADA communication monitoring:
- **Inputs**: ixHeartbeatSignal (pulsing signal from SCADA), itTimeout
- **Outputs**: qxCommunicationOk, qxCommunicationLost (latched), qtTimeSinceLastChange
- **Principle**: Detects signal changes; if no change within timeout → communication lost

---

## Key Architecture Principles

### 1. No Object-Oriented Programming

**PROHIBITED:**
- ❌ METHOD blocks inside FUNCTION_BLOCK
- ❌ Inheritance with methods (EXTENDS with METHOD)
- ❌ Getter/setter methods
- ❌ Interface-based polymorphism with methods

**ALLOWED:**
- ✅ EXTENDS for structure composition (data only)
- ✅ All logic inline in FUNCTION_BLOCK body
- ✅ Separate FUNCTION files for pure logic
- ✅ Direct output access via `q` prefix

### 2. Centralized Emergency Stop

All emergency stops are collected in **FB_EmergencyStopCollector**:

```iecst
// In MAIN.st:
fbEmergencyStopCollector(
    // Guaranteed sources (always active)
    ixEStopButton := stCommonSignals.fbEmergencyStopBtn.qxSignal,
    ixScadaCommand := stCommands.cmdEmergencyStopCommon.qxRisingEdge,
    ixEStopDumper := stDumper.fbBtnEmergencyStop.qxSignal,
    // ... local E-Stop buttons

    // Configurable sources (via ENABLE_GLOBAL_ESTOP_* flags)
    ixScadaLoss := fbScadaCommunication.qxCommunicationLost,
    ixDumperErrorZQ := xDumperErrorZQ,
    // ... sensor errors

    ixReset := stCommands.cmdResetAll.qxRisingEdge
);

// Use outputs for section-level control
fbDumper.xStop := fbEmergencyStopCollector.qxSectionStop_Dumper;
fbConveyor.xStop := fbEmergencyStopCollector.qxSectionStop_Conveyor;
```

### 3. Direct Access Pattern

```iecst
// OLD OOP approach (DO NOT USE):
Motor.Control.Start(cmd := Button.GetRtrig());
xPower := Motor.Device.GetPower();

// NEW functional approach:
Motor.Device(
    xStartCommand := Button.qxRisingEdge,
    xStartCondition := Ready,
    ixFeedback := Motor.fbStateKM.qxSignal,
    xEnableFeedback := TRUE
);
xPower := Motor.Device.qxPower;  // Direct access
```

### 4. Enable Flag Pattern

Universal blocks use enable flags to activate optional features:

```iecst
// Minimal signal (edge detection only)
Signal(ixSignal := I_Input);

// Signal with debounce
Signal(
    ixSignal := I_Input,
    xEnableRattlingFilter := TRUE,
    tStabilityTime := T#100MS
);

// Signal with feedback and timeout
Signal(
    ixSignal := I_Command,
    ixFeedback := I_Feedback,
    xEnableFeedback := TRUE,
    xEnableFeedbackTimer := TRUE,
    itFeedbackTimeout := T#5S
);
```

### 5. Control Block Interface Pattern

All control blocks follow this interface:

```iecst
FUNCTION_BLOCK FB_xxxControl
VAR_INPUT
    Equipment : REFERENCE TO ST_xxx;
    xStart : BOOL;       // Start command
    xStop : BOOL;        // Emergency stop (from FB_EmergencyStopCollector)
    xReset : BOOL;       // Reset errors
END_VAR
VAR_OUTPUT
    eStage : E_StageWithPreStartAlarm;       // Current stage
    eStageToSCADA : E_ScadaStatesDevice;     // SCADA status
END_VAR
```

Usage in MAIN.st:
```iecst
// Call control block
fbDumper(
    Dumper := stDumper,
    xStart := xStartDumper,
    xStop := fbEmergencyStopCollector.qxSectionStop_Dumper,
    xReset := stCommands.cmdResetAll.qxRisingEdge,
    eStage => eDumperStage,
    eStageToSCADA => eDumperStageToSCADA
);

// Check completion
IF eDumperStage = E_StageWithPreStartAlarm.WORK THEN
    xStartDumper := FALSE;
    AUTO_STEP := START_CONV;
END_IF
```

### 6. Pure Functions for Error Checking

All error checking functions are pure (no side effects):

```iecst
FUNCTION FC_Conveyor_GetErrorMotor : BOOL
VAR_INPUT
    Motor : REFERENCE TO ST_Motor;
END_VAR
    FC_Conveyor_GetErrorMotor :=
        NOT Motor.fbStateQF.qxSignal          // QF tripped
        OR Motor.Device.qxError_NoFeedback    // No feedback
        OR Motor.VFD.fbStateFailure.qxSignal; // VFD error
END_FUNCTION
```

### 7. State Machines with CASE

All control blocks use CASE OF state machines:

```iecst
CASE STAGE OF
    IDLE:
        IF xStart THEN
            STAGE := STARTING;
        END_IF

    STARTING:
        Motor.Device.xStartCommand := TRUE;
        IF Motor.Device.qxActive THEN
            STAGE := WORK;
        END_IF

    WORK:
        IF xStop THEN
            Motor.Device.xStopCommand := TRUE;
            STAGE := IDLE;
        END_IF

    ERROR:
        IF xReset AND NOT HasErrors THEN
            STAGE := IDLE;
        END_IF
END_CASE;
```

---

## Hardware I/O Naming Conventions

Chinese standard sensor designations:

| Code  | Equipment Type                  | Russian Name                    |
|-------|---------------------------------|---------------------------------|
| **ZQ** | Belt misalignment sensors      | Контроль схода ленты            |
| **HQ** | Cable pull-cord emergency stops| Кабель-тросовый выключатель     |
| **SQ** | Limit switches                 | Концевые выключатели            |
| **GS** | Material buildup detection     | Контроль заштыбовки             |
| **YS** | Longitudinal tear detection    | Контроль продольного разрыва    |
| **YE** | Metal detector                 | Обнаружение металла             |
| **QR** | Speed sensors                  | Датчики скорости                |
| **QF** | Circuit breaker                | Автоматический выключатель      |
| **KM** | Contactor                      | Контактор                       |
| **HLA**| Light alarm                    | Световая сигнализация           |
| **HA** | Audio-visual alarm             | Светозвуковой оповещатель       |

---

## Variable Naming Conventions (IEC 61131-3)

### Prefixes

| Prefix | Type           | Example              | Description              |
|--------|----------------|----------------------|--------------------------|
| `i`    | Input          | `ixSignal`, `irValue`| Input parameter          |
| `q`    | Output         | `qxPower`, `qrFreq`  | Output parameter         |
| `x`    | BOOL           | `xStartCommand`      | Boolean variable         |
| `r`    | REAL           | `rCurrentFrequency`  | Real number              |
| `n`    | INT/UINT/DINT  | `nTransitionCount`   | Integer number           |
| `t`    | TIME           | `tStabilityTime`     | Time value               |
| `u`    | Enum (UINT)    | `uFeedbackState`     | Enumeration              |
| `e`    | Enum           | `eDumperStage`       | Enumeration (alt.)       |
| `st`   | Struct         | `stMotor`            | Structure instance       |
| `fb`   | Function Block | `fbSignal`           | Function block instance  |
| `_`    | Private        | `_xInternalState`    | Internal variable        |

### Type Naming

| Prefix | Type                | Example                  |
|--------|---------------------|--------------------------|
| `FB_`  | Function Block      | `FB_UniversalSignal`     |
| `FC_`  | Function            | `FC_Get_ErrorCommon`     |
| `ST_`  | Structure Type      | `ST_Motor`, `ST_VFD`     |
| `E_`   | Enumeration Type    | `E_StateFeedback`        |
| `U_`   | Union Type          | `U_RealToWord`           |

---

## Common Development Patterns

### Motor Control Pattern

```iecst
// 1. Initialize signal processing with debounce
Motor.fbStateKM(
    ixSignal := I_Contactor,
    xEnableRattlingFilter := TRUE,
    tStabilityTime := T#100MS
);

Motor.fbStateQF(
    ixSignal := I_CircuitBreaker,
    xEnableRattlingFilter := TRUE
);

// 2. Control mechanism with feedback
Motor.Device(
    ixFeedback := Motor.fbStateKM.qxSignal,
    xEnableFeedback := TRUE,
    xStartCommand := StartCmd,
    xStopCommand := StopCmd OR EmergencyStop,
    xStartCondition := Motor.fbStateQF.qxSignal AND NOT HasErrors,
    xReset := ResetButton
);

// 3. Apply outputs
Motor.qxKM_Power := Motor.Device.qxPower;
Q_MotorContactor := Motor.qxKM_Power;

// 4. Check errors
IF Motor.Device.qxError_NoFeedback THEN
    // Handle error: contactor command sent but no feedback
END_IF
```

### VFD Frequency Control Pattern

```iecst
// Smooth frequency ramping with synchronization
Motor.VFD.Frequency(
    irMaxFrequency := VFD_FREQUENCY_MAX,
    irStep := VFD_FREQUENCY_STEP,       // Hz per pulse
    rTargetFrequency := 50.0,
    xPulse := PULSE_RTRIG.Q,            // Ramping clock (200ms)
    xConditionToProceed := Synced       // Synchronization lock
);
Motor.VFD.qrOutFrequency := Motor.VFD.Frequency.qrCurrentFrequency;

// Analog output (frequency → 4-20mA → DAC code)
Motor.VFD.fbAnalogOutput(
    xEnable := Motor.VFD.Device.qxActive,
    rEngValue := Motor.VFD.qrOutFrequency,
    rEngValue_Max := VFD_FREQ_MAX_RANGE,
    rEngValue_Min := VFD_FREQ_MIN,
    rCurrent_Max := VFD_CURRENT_MAX,
    rCurrent_Min := VFD_CURRENT_MIN,
    iDAC_Max := VFD_ADC_MAX,
    iDAC_Min := VFD_ADC_MIN,
    xEnableClamp := TRUE
);
Motor.VFD.nSetOutSignalToModule := Motor.VFD.fbAnalogOutput.iDAC_Code;
```

### Emergency Stop Pattern (Centralized)

```iecst
// 1. Configure options in GLOBAL.st
ENABLE_GLOBAL_ESTOP_ZQ : BOOL := TRUE;      // Enable ZQ sensors in global E-stop
ENABLE_GLOBAL_ESTOP_HQ : BOOL := TRUE;      // Enable HQ sensors
ENABLE_ESTOP_DEPENDENCIES_DUMPER : BOOL := TRUE;  // Enable dependencies for dumper

// 2. Call collector in MAIN.st
fbEmergencyStopCollector(
    // Guaranteed sources
    ixEStopButton := stCommonSignals.fbEmergencyStopBtn.qxSignal,
    ixScadaCommand := stCommands.cmdEmergencyStopCommon.qxRisingEdge,
    ixEStopDumper := stDumper.fbBtnEmergencyStop.qxSignal,
    ixEStopConveyor := stConveyor.fbBtnEmergencyStop.qxSignal,
    ixEStopBunker1 := stBunker[1].fbBtnEmergencyStop.qxSignal,
    ixEStopBunker2 := stBunker[2].fbBtnEmergencyStop.qxSignal,
    ixEStopBunker3 := stBunker[3].fbBtnEmergencyStop.qxSignal,

    // Configurable sources
    ixScadaLoss := fbScadaCommunication.qxCommunicationLost,
    ixDumperErrorZQ := xDumperErrorZQ,
    ixDumperErrorHQ := xDumperErrorHQ,
    // ...

    ixReset := stCommands.cmdResetAll.qxRisingEdge
);

// 3. Use section-level outputs
xStateEmergencyStop := fbEmergencyStopCollector.qxGlobalEmergencyStop;

// 4. Check reason for diagnostics
IF fbEmergencyStopCollector.qnReasonCode = 10 THEN
    // HQ (cable pull-cord) triggered
END_IF
```

### Pre-Start Alarm Pattern

```iecst
// Pre-start alarm sequencing
fbPreStartAlarm(
    ixStart := (STAGE = PRESTART_ALARM),
    ixStop := xStop OR xReset,
    itFirstSignal := T#5S,              // 1st horn duration
    itPauseAfterFirst := T#2S,          // Pause
    itSecondSignal := T#3S,             // 2nd horn duration
    itPauseAfterSecond := T#2S,         // Pause before start
    qxAlarmPower => Q_Horn              // Output to horn
);

IF fbPreStartAlarm.qxComplete THEN
    STAGE := STARTING;
END_IF
```

### SCADA Communication Pattern

```iecst
// Monitor SCADA heartbeat
fbScadaCommunication(
    ixHeartbeatSignal := SCADA_HEARTBEAT,
    itTimeout := SCADA_HEARTBEAT_TIMEOUT,  // Default T#5S
    xReset := stCommands.cmdResetAll.qxRisingEdge
);

// Check communication status
IF fbScadaCommunication.qxCommunicationLost THEN
    // SCADA connection lost - handle accordingly
    // If ENABLE_GLOBAL_ESTOP_SCADA_LOSS = TRUE, this triggers emergency stop
END_IF
```

### Modbus Functions Pattern

```iecst
// === HOLDING REGISTERS (SCADA → PLC) - Read setpoints ===
FC_ModbusReadReal(
    pRegisters := ADR(awModbusHoldingRegisters),
    iRegisterIndex := 30,
    rValue => VFD_FREQUENCY_MAX
);

FC_ModbusReadTime(
    pRegisters := ADR(awModbusHoldingRegisters),
    iRegisterIndex := 150,
    tValue => TIME_AFTER_START_DUMPER
);

// === INPUT REGISTERS (PLC → SCADA) - Write monitoring data ===
FC_ModbusWriteReal(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 30,
    rValue := stBunker[1].rWeight
);

FC_ModbusWriteBool(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 0,
    iBitIndex := 0,
    xValue := xStateEmergencyStop
);
```

---

## Automatic Control Sequence (MAIN.st)

### State Machine

```
1. IDLE
   ├─ Wait for operator input: BUNKER_WORK_PRECENT_1/2/3 (sum = 100%)
   ├─ Validate: no more than 1 bunker with 0%
   ├─ Check: xStateErrorCheckReady = TRUE (no errors)
   └─ Command: cmdStartCommon → INIT

2. INIT
   └─ Calculate initial vibratory feeder frequencies → START_DUMPER

3. START_DUMPER
   ├─ Set xStartDumper := TRUE
   ├─ fbDumper runs: IDLE → [PRESTART_ALARM] → STARTING → WORK
   ├─ Wait TIME_AFTER_START_DUMPER after WORK
   └─ When timer elapsed → START_CONV

4. START_CONV
   ├─ Set xStartConveyor := TRUE
   ├─ fbConveyor runs: IDLE → [PRESTART_ALARM] → STARTING → WORK
   ├─ Wait TIME_AFTER_START_CONVEYOR after WORK
   └─ When timer elapsed → START_VIBFEEDER

5. START_VIBFEEDER
   ├─ Sequential bunker start: 1 → 2 → 3
   ├─ Skip bunkers with BUNKER_WORK_PRECENT = 0
   ├─ Wait TIME_AFTER_START_BUNKER_x between bunkers
   └─ When all active bunkers = WORK → WORK

6. WORK
   ├─ Monitor proportion sum (if BUNKER_ENABLE_PROPORTION_MONITORING)
   ├─ PID control (if BUNKER_ENABLE_PID): fbProportionPid(...)
   ├─ Traffic light control for bunkers
   └─ On stop command → END_REPORT

7. END_REPORT
   ├─ Generate work report
   └─ Wait for all equipment to stop → IDLE

8. ERROR
   ├─ Emergency stop via FB_EmergencyStopCollector
   ├─ Reset all start commands
   └─ On reset + no errors → IDLE
```

### Motor Synchronization

Conveyor and dumper motors synchronize during ramp-up:

```iecst
// Synchronization conditions
xVFDsReady := Motor1.VFD.Device.qxActive
           AND Motor2.VFD.Device.qxActive;

xFrequenciesSynchronized :=
    ABS(Motor1.VFD.rActualFrequency - Motor2.VFD.rActualFrequency)
    <= VFD_FREQUENCY_SYNC_TOLERANCE;

// Condition for ramping
xConditionToProceed := xVFDsReady AND xFrequenciesSynchronized;

// Pass to both frequency controllers
Motor1.VFD.Frequency(
    xConditionToProceed := xConditionToProceed
);
Motor2.VFD.Frequency(
    xConditionToProceed := xConditionToProceed
);
```

---

## SCADA Integration

### Status Reporting

Each section reports status via E_ScadaStatesDevice:

```iecst
// Priority order (most critical to least critical)
IF STAGE = ERROR THEN
    eStageToSCADA := E_ScadaStatesDevice.ERROR;
ELSIF STAGE = WORK AND xStateFailure THEN
    eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_ERROR;
ELSIF STAGE = WORK AND xStateWarning THEN
    eStageToSCADA := E_ScadaStatesDevice.WORK_WITH_WARNING;
ELSIF STAGE = WORK THEN
    eStageToSCADA := E_ScadaStatesDevice.WORK;
ELSIF STAGE = STARTING OR STAGE = PRESTART_ALARM THEN
    eStageToSCADA := E_ScadaStatesDevice.STARTING;
ELSIF STAGE = IDLE AND xStateWarning THEN
    eStageToSCADA := E_ScadaStatesDevice.WARNING;
ELSIF STAGE = IDLE AND xStateFailure THEN
    eStageToSCADA := E_ScadaStatesDevice.NOT_READY;
ELSE
    eStageToSCADA := E_ScadaStatesDevice.READY;
END_IF
```

---

## Testing and Simulation

### Simulation Mode

Set `SIMULATION := TRUE` in GLOBAL.st to enable simulation:

```iecst
// Analog inputs automatically switch to simulation
Motor.VFD.fbAnalogInput(
    xSimulation := SIMULATION,
    iADC_Code := Motor.VFD.nActualFrequencyADC,
    refEngValue := Motor.VFD.rActualFrequency,
    refSimValue := Motor.VFD.rSimulatedFrequency
);
```

### VFD Simulation

VFD frequency simulation uses full analog I/O loop to match real hardware:

```iecst
// FB_Simulation.st - Simulation of analog I/O loop:
// DAC code from analog output → ADC code to analog input
Dumper.MotorConveyor[1].VFD.nActualFrequencyADC := Dumper.MotorConveyor[1].VFD.nSetOutSignalToModule;
```

---

## Migration Notes

When working with this codebase:

1. **NEVER add METHOD blocks** - use inline logic or separate FUNCTION files
2. **Use direct outputs** - `Motor.Device.qxPower` not `Motor.Device.GetPower()`
3. **Use enable flags** - `xEnableFeedback := TRUE` instead of specialized FB types
4. **REFERENCE TO for structures** - efficient parameter passing
5. **Commands are BOOL** - use FB_UniversalSignal for edge detection
6. **State machines use CASE** - not method-based transitions
7. **Pure functions for checks** - no side effects, REFERENCE TO for input
8. **Centralized emergency stop** - all E-stop logic goes through FB_EmergencyStopCollector
9. **SCADA communication monitoring** - use FB_ScadaCommunication for heartbeat
