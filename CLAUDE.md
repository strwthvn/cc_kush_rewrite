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
├── DataTypes/         # Type definitions (structures and enumerations)
├── Functions/         # Pure functions for error checking and calculations
└── Library/           # Universal functional blocks (core library)
```

### POUs/ - Program Organization Units

Contains the main program and control function blocks:

#### Main Program
- **MAIN.st**: Main program with automatic control sequencing
  - **Equipment**: 3 bunkers, 1 dumper, 1 conveyor
  - **Stages**: IDLE → INIT → START_DUMPER → START_CONV → START_VIBFEEDER → WORK → END_REPORT → ERROR
  - **PID control**: Proportional material dosing from bunkers
  - **Modbus integration**: Real-time data exchange with SCADA
  - **Simulation support**: Full simulation mode for testing

- **GLOBAL.st**: Global variables and system settings
  - System flags (emergency stop, errors, auto working)
  - VFD parameters (frequency, ADC/DAC ranges, 4-20mA)
  - Equipment setpoints (temperatures, currents, vibrator settings)
  - Modbus register arrays (awModbusInputRegisters, awModbusHoldingRegisters)

#### Control Function Blocks (no methods, all inline)
- **FB_BunkerControl.st**: Bunker control with vibratory feeders
  - 2 vibratory feeders (ST_MotorVibFeeder) per bunker
  - 4 vibrators (ST_Motor) for material flow assistance
  - Temperature monitoring (bearing sensors, 4-20mA)
  - Weight-based proportioning
  - Traffic light signaling (red/yellow/green)
  - Pneumatic collapse control

- **FB_DumperControl.st**: Dumper control with conveyor and rotation
  - 2 conveyor motors (22 kW each) with synchronization
  - 2 rotation motors (3 kW each) for dumper positioning
  - Pre-start alarm system (optional)
  - Safety sensor monitoring (ZQ, HQ, SQ, GS, YS)
  - Smooth frequency ramping with sync tolerance

- **FB_ConveyorControl.st**: Assembly conveyor startup sequencing
  - Similar structure to FB_DumperControl
  - Safety interlocks and sensor monitoring

#### Auxiliary Blocks
- **FB_EmergencyStopProcess.st**: Emergency stop handler with sequential shutdown
- **FB_VibratorControl.st**: Cyclic vibrator control (active → pause → active)
- **FB_PneumoCollapseControl.st**: Cyclic pneumatic collapse for material flow
- **FB_Simulation.st**: Hardware simulation for testing
- **FB_FrequencySimulation.st**: VFD frequency simulation

### DataTypes/

Equipment structures and enumerations:

#### Motor Structures
- **ST_Motor**: Base motor with contactor (KM), circuit breaker (QF), VFD
  - fbStateKM, fbStateQF: Signal processing with FB_UniversalSignal
  - Device: FB_UniversalMechanism for control
  - VFD: ST_VFD structure
  - StateRemote: E_StateRemote (Manual/Remote/Automatic)

- **ST_MotorWithFeedback**: Motor with feedback signal
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
  - qxLight[Red/Yellow/Green]: Traffic light outputs
  - eLightColor: Current traffic light color

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

- **ST_Dumper**: Dumper (extends ST_ConveyorBasic)
  - MotorRotation[1..2]: Rotation motors (ST_MotorWithReverse)
  - fbEndSwitchRight, fbEndSwitchLeft: Limit switches
  - Control buttons: fbBtnStart, fbBtnStop, fbBtnEmergencyStop
  - Rotation buttons: fbBtnTurnLeft, fbBtnTurnRight
  - fbBtnRemoteMode: Mode selector
  - States: xStateEnable, xStateStarting, xStateWarning, xStateFailure
  - fbPreStartAlarm: Pre-start alarm handler

- **ST_ConveyorPrefabricated**: Assembly conveyor (extends ST_ConveyorBasic)

#### Support Structures
- **ST_Commands**: SCADA command signals
  - cmdResetAll, cmdStartCommon, cmdStopCommon, cmdEmergencyStopCommon
  - All use FB_UniversalSignal for edge detection

- **ST_CommonSignals**: Common system signals
  - fbEmergencyStopBtn, fbRemoteModeBtn, fbRealyCurrentControl
  - fbQF1, fb9QF1, fb10QF1, fb11QF1: Circuit breakers

- **ST_AlarmSetpoints**: LL/L/H/HH setpoints for diagnostics
- **ST_PreStartAlarmSettings**: Pre-start alarm timing parameters
- **ST_BunkerVibratorSettings**: Vibrator cycle settings

#### Enumerations
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
  - Automatic (2): Automatic sequencing

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

#### Unions
- **U_RealToWord**: REAL ↔ ARRAY[0..1] OF WORD (for Modbus)
- **U_ByteToWord**: BYTE ↔ WORD (for bit packing)

### Functions/

Pure functions for reusable logic (no state, all FC_* files):

#### Bunker Functions
- **FC_Bunker_CheckWeight**: Check if weight is sufficient
- **FC_Bunker_GetErrorBunker**: Base bunker errors (hatch, weight)
- **FC_Bunker_GetErrorMotorVibFeeder**: Vibratory feeder errors (QF, KM, VFD, overheating, temperature, current)
- **FC_Bunker_GetErrorMotorVibrator**: Vibrator errors (QF, KM, VFD)
- **FC_Bunker_GetErrorWeight**: Weight sensor errors
- **FC_Bunker_SetLightColor**: Calculate traffic light color from states

```iecst
FUNCTION FC_Bunker_SetLightColor : E_LightColor
VAR_INPUT
    xStateFailure : BOOL;
    xStateWarning : BOOL;
    xStateEnable : BOOL;
END_VAR
    IF xStateFailure THEN
        FC_Bunker_SetLightColor := E_LightColor.RED;
    ELSIF xStateWarning THEN
        FC_Bunker_SetLightColor := E_LightColor.YELLOW;
    ELSIF xStateEnable THEN
        FC_Bunker_SetLightColor := E_LightColor.GREEN;
    ELSE
        FC_Bunker_SetLightColor := E_LightColor.OFF;
    END_IF
END_FUNCTION
```

#### Conveyor Functions
- **FC_Conveyor_GetErrorMotor**: Motor errors (QF, feedback, VFD)
- **FC_Conveyor_GetErrorSensors**: Safety sensor errors (ZQ, HQ, SQ, GS, YS)
- **FC_Conveyor_GetErrorCommon**: Aggregate all conveyor errors

#### Dumper Functions
- **FC_Dumper_GetErrorSensors**: Dumper safety sensor errors
- **FC_Dumper_GetErrorCommon**: Aggregate all dumper errors (motors + sensors)

#### System Functions
- **FC_Get_ErrorCommon**: Aggregate ALL system errors
  - 3 bunkers + conveyor + dumper
  - Used for xStateErrorCheckReady in MAIN.st

```iecst
FUNCTION FC_Get_ErrorCommon : BOOL
VAR_INPUT
    Bunker1 : REFERENCE TO ST_Bunker;
    Bunker2 : REFERENCE TO ST_Bunker;
    Bunker3 : REFERENCE TO ST_Bunker;
    Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
    Dumper : REFERENCE TO ST_Dumper;
END_VAR
    FC_Get_ErrorCommon :=
        FC_Bunker_GetErrorBunker(Bunker := Bunker1)
        OR FC_Bunker_GetErrorBunker(Bunker := Bunker2)
        OR FC_Bunker_GetErrorBunker(Bunker := Bunker3)
        OR FC_Conveyor_GetErrorCommon(Conveyor := Conveyor)
        OR FC_Dumper_GetErrorCommon(Dumper := Dumper);
END_FUNCTION
```

#### Modbus Functions
- **FC_ModbusWriteBool**: Write BOOL to register bit (bitwise packing)
- **FC_ModbusWriteInt**: Write INT to register (1 WORD)
- **FC_ModbusWriteReal**: Write REAL to 2 consecutive registers (using U_RealToWord)
- **FC_ModbusWriteTime**: Write TIME to 2 consecutive registers (using U_TimeToWord)
- **FC_ModbusReadBool**: Read BOOL from register bit
- **FC_ModbusReadInt**: Read INT from register
- **FC_ModbusReadReal**: Read REAL from 2 consecutive registers
- **FC_ModbusReadTime**: Read TIME from 2 consecutive registers

All Modbus functions use `POINTER TO WORD` for flexible array access with pointer arithmetic.

```iecst
// Example: Write REAL value to Modbus Input registers
FC_ModbusWriteReal(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 30,
    rValue := stBunker[1].rWeight
);

// Example: Read REAL setpoint from Modbus Holding registers
FC_ModbusReadReal(
    pRegisters := ADR(awModbusHoldingRegisters),
    iRegisterIndex := 60,
    rValue => BUNKER_WORK_PRECENT_1
);
```

#### Utility Functions
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

```iecst
// Example: Contactor with debounce
Motor.fbStateKM(
    ixSignal := I_Contactor,
    xEnableRattlingFilter := TRUE,
    tStabilityTime := T#100MS
);

// Example: Command with feedback and timeout
StartSignal(
    ixSignal := I_StartButton,
    ixFeedback := I_MotorRunning,
    xEnableFeedback := TRUE,
    xEnableFeedbackTimer := TRUE,
    itFeedbackTimeout := T#5S
);
```

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

```iecst
// Control contactor with feedback
Motor.Device(
    ixFeedback := Motor.fbStateKM.qxSignal,
    xEnableFeedback := TRUE,
    xStartCommand := StartBtn,
    xStopCommand := StopBtn OR EmergencyStop,
    xStartCondition := Motor.fbStateQF.qxSignal AND NOT HasErrors,
    xReset := ResetButton
);
Motor.qxKM_Power := Motor.Device.qxPower;

// Check errors
IF Motor.Device.qxError_NoFeedback THEN
    // Contactor command sent but no feedback
END_IF
```

#### Frequency Control

**FB_FrequencyControl** - Smooth VFD frequency ramping:
- **Inputs**: rTargetFrequency, irStep, xPulse, xConditionToProceed
- **Output**: qrCurrentFrequency
- **Features**: Smooth ramping, hold, reset
- **Synchronization**: xConditionToProceed blocks ramping until motors sync

```iecst
// Smooth frequency ramp with synchronization
Motor1.VFD.Frequency(
    irMaxFrequency := 50.0,
    irStep := 2.0,                          // Hz per pulse
    rTargetFrequency := 50.0,
    xPulse := PULSE_RTRIG.Q,                // 200ms impulse
    xConditionToProceed := Motors_Synced    // Wait for sync
);
Motor1.VFD.qrOutFrequency := Motor1.VFD.Frequency.qrCurrentFrequency;

// Synchronization check
Motors_Synced := ABS(Motor1.VFD.rActualFrequency
                   - Motor2.VFD.rActualFrequency)
                 <= VFD_FREQUENCY_SYNC_TOLERANCE;
```

#### Diagnostics

**FB_RangeDiagnostic** - 4-level analog diagnostics (LL/L/H/HH):
- **Inputs**: irValue, irSetpointLL, irSetpointL, irSetpointH, irSetpointHH
- **Outputs**: qxAlarmLL, qxWarningL, qxWarningH, qxAlarmHH
- **Aggregates**: qxAlarmActive, qxWarningActive

```iecst
// Temperature monitoring
Motor.fbRangeDiagnostic(
    irValue := Motor.rTempBearing,
    irSetpointLL := -1.0,      // Sensor break
    irSetpointL := 60.0,       // Warning low
    irSetpointH := 80.0,       // Warning high
    irSetpointHH := 90.0,      // Alarm high
    ixEnable := TRUE
);

IF Motor.fbRangeDiagnostic.qxAlarmHH THEN
    // Emergency stop
ELSIF Motor.fbRangeDiagnostic.qxWarningH THEN
    // Warning
END_IF
```

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

```iecst
fbProportionPid(
    xEnable := AUTO_STEP = WORK,
    rProportionTarget_1 := BUNKER_WORK_PRECENT_1 / 100.0,
    rProportionTarget_2 := BUNKER_WORK_PRECENT_2 / 100.0,
    rProportionTarget_3 := BUNKER_WORK_PRECENT_3 / 100.0,
    rProportionActual_1 := stBunker[1].rProportionActual,
    rProportionActual_2 := stBunker[2].rProportionActual,
    rProportionActual_3 := stBunker[3].rProportionActual,
    rFrequency_TargetSum := 90.0,         // Target total frequency
    qrFrequency_1 => stBunker[1].rMotorVibFeederCommonFrequency,
    qrFrequency_2 => stBunker[2].rMotorVibFeederCommonFrequency,
    qrFrequency_3 => stBunker[3].rMotorVibFeederCommonFrequency
);
```

#### Simulation

**FB_FrequencySimulation** - VFD frequency simulation:
- Simulates smooth frequency changes
- Used in simulation mode to mimic VFD behavior

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

### 2. Direct Access Pattern

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

### 3. Enable Flag Pattern

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

**Advantages:**
- One universal block instead of multiple specialized blocks
- Flexible configuration without code changes
- Less code duplication

### 4. Control Block Interface Pattern

All control blocks follow this interface:

```iecst
FUNCTION_BLOCK FB_xxxControl
VAR_INPUT
    Equipment : REFERENCE TO ST_xxx;
    xStart : BOOL;       // Start command
    xStop : BOOL;        // Emergency stop
    xReset : BOOL;       // Reset errors
END_VAR
VAR_OUTPUT
    eStage : E_StageWithPreStartAlarm;       // Current stage
    eStageToSCADA : E_ScadaStatesDevice;     // SCADA status
END_VAR
VAR
    STAGE : E_StageWithPreStartAlarm := IDLE;
END_VAR
```

Usage in MAIN.st:
```iecst
// Set command flag
xStartDumper := TRUE;

// Call control block
fbDumper(
    Dumper := stDumper,
    xStart := xStartDumper,
    xStop := fbEmergencyStopProcess.qxStateStopProcess,
    xReset := stCommands.cmdResetAll.qxSignal,
    eStage => eDumperStage,
    eStageToSCADA => eDumperStageToSCADA
);

// Check completion
IF eDumperStage = E_StageWithPreStartAlarm.WORK THEN
    xStartDumper := FALSE;  // Reset command
    AUTO_STEP := START_CONV;
END_IF
```

### 5. Pure Functions for Error Checking

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

### 6. State Machines with CASE

All control blocks use CASE OF state machines:

```iecst
CASE STAGE OF
    IDLE:
        // Initialize, wait for start command
        IF xStart THEN
            STAGE := STARTING;
        END_IF

    STARTING:
        // Start equipment
        Motor.Device.xStartCommand := TRUE;
        IF Motor.Device.qxActive THEN
            STAGE := WORK;
        END_IF

    WORK:
        // Normal operation
        IF xStop THEN
            Motor.Device.xStopCommand := TRUE;
            STAGE := IDLE;
        END_IF

    ERROR:
        // Error handling
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

### Error Aggregation Pattern

```iecst
// Pure function for error checking
xError := FC_Get_ErrorCommon(
    Bunker1 := stBunker[1],
    Bunker2 := stBunker[2],
    Bunker3 := stBunker[3],
    Conveyor := stConveyor,
    Dumper := stDumper
);

// Inside FC_Get_ErrorCommon:
FUNCTION FC_Get_ErrorCommon : BOOL
VAR_INPUT
    Bunker1 : REFERENCE TO ST_Bunker;
    Bunker2 : REFERENCE TO ST_Bunker;
    Bunker3 : REFERENCE TO ST_Bunker;
    Conveyor : REFERENCE TO ST_ConveyorPrefabricated;
    Dumper : REFERENCE TO ST_Dumper;
END_VAR
    FC_Get_ErrorCommon :=
        FC_Bunker_GetErrorBunker(Bunker := Bunker1)
        OR FC_Bunker_GetErrorBunker(Bunker := Bunker2)
        OR FC_Bunker_GetErrorBunker(Bunker := Bunker3)
        OR FC_Conveyor_GetErrorCommon(Conveyor := Conveyor)
        OR FC_Dumper_GetErrorCommon(Dumper := Dumper);
END_FUNCTION
```

### Analog I/O Pattern (4-20mA)

```iecst
// Analog INPUT: ADC → 4-20mA → Engineering units
Motor.fbAnalogInput(
    xSimulation := SIMULATION,
    iADC_Code := Motor.nTempBearingRawSignal,
    refEngValue := Motor.rTempBearing,
    refSimValue := Motor.rSimulatedTempBearing,
    rAlarm_LL := VFD_CURRENT_ALARM_LL,   // < 3.8mA (break)
    rAlarm_HH := VFD_CURRENT_ALARM_HH,   // > 20.2mA (short)
    iADC_Max := VFD_ADC_MAX,
    iADC_Min := VFD_ADC_MIN,
    rEngValue_Max := TEMP_BEARING_MAX,
    rEngValue_Min := TEMP_BEARING_MIN,
    rCurrent_Max := VFD_CURRENT_MAX,
    rCurrent_Min := VFD_CURRENT_MIN
);

// Analog OUTPUT: Engineering units → 4-20mA → DAC code
Motor.fbAnalogOutput(
    xEnable := Motor.Device.qxActive,
    rEngValue := Motor.qrOutFrequency,
    rEngValue_Max := VFD_FREQ_MAX_RANGE,
    rEngValue_Min := VFD_FREQ_MIN,
    rCurrent_Max := VFD_CURRENT_MAX,
    rCurrent_Min := VFD_CURRENT_MIN,
    iDAC_Max := VFD_ADC_MAX,
    iDAC_Min := VFD_ADC_MIN,
    xEnableClamp := TRUE
);
Motor.nSetOutSignalToModule := Motor.fbAnalogOutput.iDAC_Code;
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
   └─ When eDumperStage = WORK → START_CONV

4. START_CONV
   ├─ Set xStartConveyor := TRUE
   ├─ fbConveyor runs: IDLE → [PRESTART_ALARM] → STARTING → WORK
   └─ When eConveyorStage = WORK → START_VIBFEEDER

5. START_VIBFEEDER
   ├─ Sequential bunker start: 1 → 2 → 3
   ├─ Skip bunkers with BUNKER_WORK_PRECENT = 0
   ├─ Each bunker: IDLE → STARTING → WORK
   └─ When all active bunkers = WORK → WORK

6. WORK
   ├─ Calculate actual proportions from cumulative weights:
   │  ├─ rWeight3 = stBunker[3].rWeightUnderBunker
   │  ├─ rWeight2 = stBunker[2].rWeightUnderBunker - rWeight3
   │  └─ rWeight1 = stBunker[1].rWeightUnderBunker - stBunker[2].rWeightUnderBunker
   ├─ PID control: fbProportionPid(...)
   │  ├─ Inputs: target & actual proportions
   │  └─ Outputs: vibratory feeder frequencies
   ├─ Transfer frequencies to bunkers
   └─ On stop command → END_REPORT

7. END_REPORT
   ├─ Generate work report
   └─ Wait for all equipment to stop → IDLE

8. ERROR
   ├─ Emergency stop all sections
   ├─ Reset all start commands
   └─ On reset + no errors → IDLE
```

### PID Proportional Control

The system uses adaptive PID control to maintain material proportions:

```
1. Normalize target proportions (sum = 1.0)
2. Calculate error: error_i = target_i - actual_i
3. PID formula: output_i = Kp*error + Ki*integral + Kd*derivative
4. Convert to frequencies:
   ├─ baseFreq_i = targetSum * proportion_i
   ├─ scale_i = output_i / proportion_i (limited)
   └─ freq_i = baseFreq_i * scale_i
5. Normalize to maintain target sum
6. Apply equipment limits (min/max frequency)
```

**Key features:**
- Auto-correction of proportion deviations
- Total frequency preservation
- Anti-windup integral limiting
- Equipment protection (min/max limits)

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
    xConditionToProceed := xConditionToProceed  // LOCKED
);
Motor2.VFD.Frequency(
    xConditionToProceed := xConditionToProceed  // LOCKED
);
```

**How it works:**
1. Both motors start simultaneously
2. Frequencies increase on pulse
3. If difference > tolerance → ramping pauses
4. Frequencies equalize → ramping continues

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

### Modbus Register Mapping

The project uses a structured Modbus register map with reserved gaps for future expansion (see `MODBUS_MAP.md`):

**Holding Registers (SCADA → PLC)** - Setpoints and commands:
- 0-29: General system variables and setpoints
- 30-59: VFD parameters
- 60-89: Bunker setpoints
- 90-119: Temperature alarm setpoints
- 120-149: Current alarm setpoints
- 150-209: Time setpoints
- 210-239: Dumper command frequencies
- 240-269: Conveyor command frequencies
- 270-359: Bunker command frequencies (3 bunkers × 30 registers each)

**Input Registers (PLC → SCADA)** - Monitoring data:
- 0-29: General system status
- 30-89: Bunker 1 monitoring (60 registers)
- 90-149: Bunker 2 monitoring (60 registers)
- 150-209: Bunker 3 monitoring (60 registers)
- 210-239: Dumper conveyor monitoring
- 240-269: Dumper rotation monitoring
- 270-299: Conveyor monitoring

MAIN.st uses FC_ModbusRead/Write functions for register access:

```iecst
// === HOLDING REGISTERS (SCADA → PLC) - Read setpoints ===
FC_ModbusReadReal(
    pRegisters := ADR(awModbusHoldingRegisters),
    iRegisterIndex := 30,
    rValue => VFD_FREQUENCY_MAX
);

FC_ModbusReadReal(
    pRegisters := ADR(awModbusHoldingRegisters),
    iRegisterIndex := 60,
    rValue => BUNKER_WORK_PRECENT_1
);

// === INPUT REGISTERS (PLC → SCADA) - Write monitoring data ===
FC_ModbusWriteReal(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 30,
    rValue := stBunker[1].rWeight
);

FC_ModbusWriteReal(
    pRegisters := ADR(awModbusInputRegisters),
    iRegisterIndex := 210,
    rValue := stDumper.MotorConveyor[1].VFD.qrOutFrequency
);
```

**Advantages of this approach:**
- ✅ No intermediate Union variables needed
- ✅ Direct register access with pointer arithmetic
- ✅ Structured map with 30-register gaps for future expansion
- ✅ Clear documentation in MODBUS_MAP.md
- ✅ Type-safe functions prevent errors

---

## Testing and Simulation

### Simulation Mode

Set `SIMULATION := TRUE` in GLOBAL.st to enable simulation:

```iecst
// Analog inputs automatically switch to simulation
Motor.VFD.fbAnalogInput(
    xSimulation := SIMULATION,           // Simulation mode
    iADC_Code := Motor.VFD.nActualFrequencyADC,
    refEngValue := Motor.VFD.rActualFrequency,
    refSimValue := Motor.VFD.rSimulatedFrequency
);

// In simulation mode:
// rActualFrequency := rSimulatedFrequency
```

### VFD Simulation

FB_FrequencySimulation mimics smooth VFD frequency changes:

```iecst
Motor.VFD.fbSimFreq(
    ixEnable := SIMULATION,
    irFrequencyTarget := Motor.VFD.qrOutFrequency,
    irFrequencyStep := 1.0,
    ixPulse := PULSE_RTRIG.Q
);
Motor.VFD.rSimulatedFrequency := Motor.VFD.fbSimFreq.qrFrequencyCurrent;
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

---

## Additional Documentation

- **MODBUS_MAP.md**: Complete Modbus register map with addressing and data types
- **docs/ARCHITECTURE.md**: Detailed architecture documentation (Russian)
- **README.md**: Functional library overview (Russian)
- **docs/SCADA_Tags.md**: Modbus tag mapping
- **docs/VFD_Frequency_Variables.md**: VFD frequency variable reference
- **docs/VFD_Frequency_Usage.md**: VFD frequency control guide
