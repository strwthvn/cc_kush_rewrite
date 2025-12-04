# Список тэгов для SCADA

Данный документ содержит список тэгов для подключения SCADA-системы к контроллеру.

**Соглашение о наименовании:**
- `Application.` - переменные из области GLOBAL
- `Application.MAIN.` - переменные и структуры из MAIN.st

---

## 1. СИСТЕМНЫЕ ПЕРЕМЕННЫЕ (Application.)

### 1.1 Системные флаги

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.xStateEmergencyStop` | BOOL | Система была аварийно остановлена |
| `Application.xStateErrorAcceptIdle` | BOOL | Ошибка задания пропорции шихтования (сумма ≠ 100) |
| `Application.xStateErrorCheckReady` | BOOL | Проверки готовности к пуску провалились |
| `Application.xStateAutoWorking` | BOOL | Система работает в автоматическом режиме |
| `Application.SIMULATION` | BOOL | Режим симуляции |

### 1.2 Расчётные значения

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.uIcurPrecent.rTag` | U_RealToWord | Коэффициент использования установленной мощности (%) |
| `Application.uElectricityMeter.rTag` | U_RealToWord | Расход электроэнергии |
| `Application.uEfficiencyLimitRate.rTag` | U_RealToWord | Коэффициент ограничения производительности (0-1) |

---

## 2. УСТАВКИ (Application. - RETAIN)

### 2.1 Настройки ЧРП

| Тэг | Тип | Значение по умолчанию | Описание |
|-----|-----|----------------------|----------|
| `Application.uVfdFrequencyMax.rTag` | U_RealToWord | 50 | Максимальная частота ЧРП |
| `Application.uVfdFrequencyStep.rTag` | U_RealToWord | 2 | Шаг изменения частоты |
| `Application.uVfdFrequencyInaccurancy.rTag` | U_RealToWord | 0.5 | Допустимая погрешность частоты |
| `Application.uVfdFrequencySyncTolerance.rTag` | U_RealToWord | 1.5 | Допустимая разница частот для синхронизации |
| `Application.VFD_SMOOTH_SET_FREQUENCY` | BOOL | TRUE | Плавное задание частоты |

### 2.2 Частоты двигателей

| Тэг | Тип | Значение по умолчанию | Описание |
|-----|-----|----------------------|----------|
| `Application.uMotorFrequencyConveyor.rTag` | U_RealToWord | 50 | Частота мотора конвейера |
| `Application.uMotorFrequencyDumperConveyor.rTag` | U_RealToWord | 50 | Частота мотора конвейера отвалообразователя |
| `Application.uMotorFrequencyDumperRotation.rTag` | U_RealToWord | -1 | Частота мотора поворота отвалообразователя |
| `Application.uConveyorDefaultSpeed.rTag` | U_RealToWord | -1 | Скорость конвейера |

### 2.3 Таймеры последовательного запуска

| Тэг | Тип | Значение по умолчанию | Описание |
|-----|-----|----------------------|----------|
| `Application.TIME_AFTER_START_DUMPER` | TIME | T#0S | Время ожидания после запуска отвалообразователя |
| `Application.TIME_AFTER_START_CONVEYOR` | TIME | T#0S | Время ожидания после запуска конвейера |
| `Application.TIME_AFTER_START_BUNKER_1` | TIME | T#0S | Время ожидания после запуска бункера 1 |
| `Application.TIME_AFTER_START_BUNKER_2` | TIME | T#0S | Время ожидания после запуска бункера 2 |
| `Application.TIME_AFTER_START_BUNKER_3` | TIME | T#0S | Время ожидания после запуска бункера 3 |
| `Application.TIME_WAITING_FEEDBACK` | TIME | T#0S | Таймер ожидания обратной связи |

### 2.4 Уставки бункеров

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.uBunkerWorkPrecent1.rTag` | U_RealToWord | Пропорция шихтования для бункера 1 |
| `Application.uBunkerWorkPrecent2.rTag` | U_RealToWord | Пропорция шихтования для бункера 2 |
| `Application.uBunkerWorkPrecent3.rTag` | U_RealToWord | Пропорция шихтования для бункера 3 |
| `Application.uBunkerMinimalWeight.rTag` | U_RealToWord | Минимальный вес бункера (пустой бункер) |
| `Application.PNEUMATIC_COLLAPSE_TIME` | TIME | Время таймера пневмообрушения |

### 2.5 Настройки виброобрушения

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.VIBRATOR_SETTINGS.TIME_ACTIVE` | TIME | Время активной работы вибратора |
| `Application.VIBRATOR_SETTINGS.TIME_PAUSE_VIBRATOR` | TIME | Время паузы вибратора между циклами |
| `Application.VIBRATOR_SETTINGS.TIME_PAUSE_FB` | TIME | Время паузы ФБ между подходами |
| `Application.VIBRATOR_SETTINGS.COUNT_CYCLE` | INT | Количество срабатываний в одном подходе |

### 2.6 Настройки пневмообрушения

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.PNEUMO_SETTINGS.TIME_ACTIVE` | TIME | Время активной работы пневмообрушения |
| `Application.PNEUMO_SETTINGS.TIME_PAUSE_VIBRATOR` | TIME | Время паузы между циклами |
| `Application.PNEUMO_SETTINGS.TIME_PAUSE_FB` | TIME | Время паузы ФБ между подходами |
| `Application.PNEUMO_SETTINGS.COUNT_CYCLE` | INT | Количество срабатываний в одном подходе |

### 2.7 Уставки аварийных значений

#### Температура подшипников вибропитателя

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.uMotorVibfeederTempLL.rTag` | U_RealToWord | Уставка Low-Low |
| `Application.uMotorVibfeederTempL.rTag` | U_RealToWord | Уставка Low |
| `Application.uMotorVibfeederTempH.rTag` | U_RealToWord | Уставка High |
| `Application.uMotorVibfeederTempHH.rTag` | U_RealToWord | Уставка High-High |

#### Ток мотора вибропитателя

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.uMotorVibfeederCurrentLL.rTag` | U_RealToWord | Уставка Low-Low |
| `Application.uMotorVibfeederCurrentL.rTag` | U_RealToWord | Уставка Low |
| `Application.uMotorVibfeederCurrentH.rTag` | U_RealToWord | Уставка High |
| `Application.uMotorVibfeederCurrentHH.rTag` | U_RealToWord | Уставка High-High |

#### Ток мотора вибратора

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.uMotorVibratorCurrentLL.rTag` | U_RealToWord | Уставка Low-Low |
| `Application.uMotorVibratorCurrentL.rTag` | U_RealToWord | Уставка Low |
| `Application.uMotorVibratorCurrentH.rTag` | U_RealToWord | Уставка High |
| `Application.uMotorVibratorCurrentHH.rTag` | U_RealToWord | Уставка High-High |

#### Ток мотора конвейера

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.uMotorConveyorCurrentLL.rTag` | U_RealToWord | Уставка Low-Low |
| `Application.uMotorConveyorCurrentL.rTag` | U_RealToWord | Уставка Low |
| `Application.uMotorConveyorCurrentH.rTag` | U_RealToWord | Уставка High |
| `Application.uMotorConveyorCurrentHH.rTag` | U_RealToWord | Уставка High-High |

#### Ток мотора поворота отвалообразователя

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.uMotorRotationCurrentLL.rTag` | U_RealToWord | Уставка Low-Low |
| `Application.uMotorRotationCurrentL.rTag` | U_RealToWord | Уставка Low |
| `Application.uMotorRotationCurrentH.rTag` | U_RealToWord | Уставка High |
| `Application.uMotorRotationCurrentHH.rTag` | U_RealToWord | Уставка High-High |

### 2.8 Настройки предпусковой сигнализации

#### Отвалообразователь

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.OPTION_ENABLE` | BOOL | Включение ППЗ в алгоритм |
| `Application.DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL` | TIME | Время первого сигнала |
| `Application.DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE` | TIME | Пауза после первого сигнала |
| `Application.DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL` | TIME | Время второго сигнала |
| `Application.DUMPER_CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE` | TIME | Пауза после второго сигнала |

#### Конвейер

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.CONVEYOR_PRESTART_ALARM_SETTINGS.OPTION_ENABLE` | BOOL | Включение ППЗ в алгоритм |
| `Application.CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL` | TIME | Время первого сигнала |
| `Application.CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_FIRST_SIGNAL_PAUSE` | TIME | Пауза после первого сигнала |
| `Application.CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL` | TIME | Время второго сигнала |
| `Application.CONVEYOR_PRESTART_ALARM_SETTINGS.TIME_SECOND_SIGNAL_PAUSE` | TIME | Пауза после второго сигнала |

### 2.9 Прочие уставки

| Тэг | Тип | Значение по умолчанию | Описание |
|-----|-----|----------------------|----------|
| `Application.uAnnunciatorLightHz.rTag` | U_RealToWord | 2 | Частота мигания световой индикации (Гц) |
| `Application.AMOUNT_BUNKER_MOTOR_VIBFEEDER` | INT | 2 | Количество моторов вибропитателя на бункер |
| `Application.AMOUNT_BUNKER_MOTOR_VIBRATOR` | INT | 4 | Количество моторов вибратора на бункер |

---

## 3. КОМАНДЫ И СОСТОЯНИЯ (Application.MAIN.)

### 3.1 Системные состояния MAIN

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.AUTO_STEP` | ENUM | Текущий шаг автоматического алгоритма |
| `Application.MAIN.xStateEmergencyStop` | BOOL | Флаг аварийного останова |
| `Application.MAIN.xStateErrorCheckReady` | BOOL | Готовность к пуску |
| `Application.MAIN.xStateErrorAcceptIdle` | BOOL | Ошибка задания пропорции |
| `Application.uMainIcurPrecent.rTag` | U_RealToWord | КИУМ в процентах |

### 3.2 Общие команды (stCommands)

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stCommands.cmdResetAll.qxSignal` | BOOL | Сброс всех ошибок - сигнал |
| `Application.MAIN.stCommands.cmdResetAll.qxRisingEdge` | BOOL | Сброс всех ошибок - фронт |
| `Application.MAIN.stCommands.cmdStartCommon.qxSignal` | BOOL | Общий пуск - сигнал |
| `Application.MAIN.stCommands.cmdStartCommon.qxRisingEdge` | BOOL | Общий пуск - фронт |
| `Application.MAIN.stCommands.cmdStopCommon.qxSignal` | BOOL | Общий останов - сигнал |
| `Application.MAIN.stCommands.cmdStopCommon.qxRisingEdge` | BOOL | Общий останов - фронт |
| `Application.MAIN.stCommands.cmdEmergencyStopCommon.qxSignal` | BOOL | Аварийный останов - сигнал |
| `Application.MAIN.stCommands.cmdEmergencyStopCommon.qxRisingEdge` | BOOL | Аварийный останов - фронт |
| `Application.MAIN.stCommands.cmdSetPrecentBunker[1]` | USINT | Задание % шихтования бункера 1 |
| `Application.MAIN.stCommands.cmdSetPrecentBunker[2]` | USINT | Задание % шихтования бункера 2 |
| `Application.MAIN.stCommands.cmdSetPrecentBunker[3]` | USINT | Задание % шихтования бункера 3 |

### 3.3 Общие сигналы (stCommonSignals)

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stCommonSignals.fbEmergencyStopBtn.qxSignal` | BOOL | Кнопка аварийной остановки |
| `Application.MAIN.stCommonSignals.fbRemoteModeBtn.qxSignal` | BOOL | Режим работы (1-дистанционный, 0-местный) |
| `Application.MAIN.stCommonSignals.fbRealyCurrentControl.qxSignal` | BOOL | Реле контроля фаз |
| `Application.MAIN.stCommonSignals.fbQF1.qxSignal` | BOOL | Автоматический выключатель QF1 |
| `Application.MAIN.stCommonSignals.fb9QF1.qxSignal` | BOOL | Автоматический выключатель 9QF1 |
| `Application.MAIN.stCommonSignals.fb10QF1.qxSignal` | BOOL | Автоматический выключатель 10QF1 |
| `Application.MAIN.stCommonSignals.fb11QF1.qxSignal` | BOOL | Автоматический выключатель 11QF1 |
| `Application.MAIN.stCommonSignals.qx6KM1` | BOOL | Контактор 6KM1 (DO) |

---

## 4. ОТВАЛООБРАЗОВАТЕЛЬ (Application.MAIN.stDumper)

### 4.1 Состояния и управление

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.xStartDumper` | BOOL | Команда запуска отвалообразователя |
| `Application.MAIN.eDumperStage` | ENUM | Стадия отвалообразователя (E_StageWithPreStartAlarm) |
| `Application.MAIN.stDumper.xStateWarning` | BOOL | Предупреждение |
| `Application.MAIN.stDumper.xStateFailure` | BOOL | Ошибка |
| `Application.MAIN.stDumper.xStateEnable` | BOOL | Полностью запущен |
| `Application.MAIN.stDumper.xStateStarting` | BOOL | Процесс запуска |

### 4.2 Команды АСУТП

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stDumper.cmdStartConveyor` | BOOL | Команда пуска конвейера |
| `Application.MAIN.stDumper.cmdStopConveyor` | BOOL | Команда останова конвейера |
| `Application.MAIN.stDumper.cmdEmergencyStop` | BOOL | Аварийный останов |
| `Application.MAIN.stDumper.cmdTurnLeft` | BOOL | Команда поворота влево |
| `Application.MAIN.stDumper.cmdTurnRight` | BOOL | Команда поворота вправо |
| `Application.MAIN.stDumper.cmdReset` | BOOL | Сброс ошибок |

### 4.3 Кнопки ПМУ

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stDumper.fbBtnStart.qxSignal` | BOOL | Кнопка "Пуск" |
| `Application.MAIN.stDumper.fbBtnStop.qxSignal` | BOOL | Кнопка "Стоп" |
| `Application.MAIN.stDumper.fbBtnEmergencyStop.qxSignal` | BOOL | Кнопка аварийной остановки |
| `Application.MAIN.stDumper.fbBtnTurnLeft.qxSignal` | BOOL | Кнопка поворота влево |
| `Application.MAIN.stDumper.fbBtnTurnRight.qxSignal` | BOOL | Кнопка поворота вправо |
| `Application.MAIN.stDumper.fbBtnRemoteMode.qxSignal` | BOOL | Переключатель режима |

### 4.4 Датчики безопасности

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stDumper.fbZQAlarm[1..4].qxSignal` | BOOL | Контроль схода ленты - тревога |
| `Application.MAIN.stDumper.fbZQWarning[1..4].qxSignal` | BOOL | Контроль схода ленты - предупреждение |
| `Application.MAIN.stDumper.fbHQ_IsOk[1..4].qxSignal` | BOOL | Кабель-тросовый выключатель |
| `Application.MAIN.stDumper.fbSQ_IsOk[1..2].qxSignal` | BOOL | Контроль ограждения барабана |
| `Application.MAIN.stDumper.fbGS1.qxSignal` | BOOL | Контроль заштыбовки |
| `Application.MAIN.stDumper.fbQR[1..2].qxSignal` | BOOL | Измерение скорости вращения барабана |
| `Application.MAIN.stDumper.fbYS1.qxSignal` | BOOL | Контроль продольного разрыва ленты |
| `Application.MAIN.stDumper.fbEndSwitchRight.qxSignal` | BOOL | Концевой выключатель - правый |
| `Application.MAIN.stDumper.fbEndSwitchLeft.qxSignal` | BOOL | Концевой выключатель - левый |

### 4.5 Светозвуковое оповещение

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stDumper.xHLA` | BOOL | Световая сигнализация (DO) |
| `Application.MAIN.stDumper.xSoundAlarm` | BOOL | Звуковая сигнализация (DO) |

### 4.6 Двигатели конвейера (MotorConveyor[1..2])

Для каждого двигателя N = 1, 2:

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stDumper.MotorConveyor[N].StateRemote` | ENUM | Режим управления |
| `Application.MAIN.stDumper.MotorConveyor[N].qxKM_Power` | BOOL | Пуск контактора (DO) |
| `Application.MAIN.stDumper.MotorConveyor[N].fbStateKM.qxSignal` | BOOL | Состояние контактора (DI) |
| `Application.MAIN.stDumper.MotorConveyor[N].fbStateQF.qxSignal` | BOOL | Состояние автовыключателя (DI) |
| `Application.MAIN.stDumper.MotorConveyor[N].fbStatorOverheat.qxSignal` | BOOL | Перегрев статора (DI) |
| `Application.MAIN.stDumper.MotorConveyor[N].Device.qxPower` | BOOL | Выход питания |
| `Application.MAIN.stDumper.MotorConveyor[N].Device.qxActive` | BOOL | Активен |
| `Application.MAIN.stDumper.MotorConveyor[N].Device.qxHasError` | BOOL | Есть ошибка |
| `Application.MAIN.stDumper.MotorConveyor[N].xStateWarning` | BOOL | Предупреждение |
| `Application.MAIN.stDumper.MotorConveyor[N].xStateFailure` | BOOL | Ошибка |
| `Application.MAIN.stDumper.MotorConveyor[N].cmdManualStartKM` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stDumper.MotorConveyor[N].cmdManualStopKM` | BOOL | Команда останова (местный) |

#### ЧРП двигателя конвейера

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stDumper.MotorConveyor[N].VFD.qxStart` | BOOL | Пуск ЧРП (DO) |
| `Application.MAIN.stDumper.MotorConveyor[N].VFD.qxResetFailure` | BOOL | Сброс аварии ЧРП (DO) |
| `Application.uDumperMotorConveyor[N]OutFreq.rTag` | U_RealToWord | Выходная частота (AO) |
| `Application.uDumperMotorConveyor[N]ActualFreq.rTag` | U_RealToWord | Текущая частота |
| `Application.MAIN.stDumper.MotorConveyor[N].VFD.xStateRdyToStart` | BOOL | Готов к пуску |
| `Application.MAIN.stDumper.MotorConveyor[N].VFD.xStateIsWorking` | BOOL | В работе |
| `Application.MAIN.stDumper.MotorConveyor[N].VFD.xStateFailure` | BOOL | Ошибка ЧРП |
| `Application.uDumperMotorConveyor[N]Current.rTag` | U_RealToWord | Ток двигателя |
| `Application.uDumperMotorConveyor[N]SetFreq.rTag` | U_RealToWord | Ручное задание частоты |
| `Application.MAIN.stDumper.MotorConveyor[N].VFD.cmdManualStart` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stDumper.MotorConveyor[N].VFD.cmdManualStop` | BOOL | Команда остановки (местный) |
| `Application.MAIN.stDumper.MotorConveyor[N].VFD.cmdFrequencyDirectMode` | BOOL | Режим задания частоты (0-плавный, 1-мгновенный) |

### 4.7 Двигатели поворота (MotorRotation[1..2])

Для каждого двигателя N = 1, 2:

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stDumper.MotorRotation[N].StateRemote` | ENUM | Режим управления |
| `Application.MAIN.stDumper.MotorRotation[N].qxKM_Power` | BOOL | Пуск контактора (DO) |
| `Application.MAIN.stDumper.MotorRotation[N].qxVFDReverseStart` | BOOL | Пуск ЧРП назад (DO) |
| `Application.MAIN.stDumper.MotorRotation[N].fbStateKM.qxSignal` | BOOL | Состояние контактора (DI) |
| `Application.MAIN.stDumper.MotorRotation[N].fbStateQF.qxSignal` | BOOL | Состояние автовыключателя (DI) |
| `Application.MAIN.stDumper.MotorRotation[N].fbStatorOverheat.qxSignal` | BOOL | Перегрев статора (DI) |
| `Application.MAIN.stDumper.MotorRotation[N].fbRotationStatus.qxSignal` | BOOL | Статус вращения (DI) |
| `Application.MAIN.stDumper.MotorRotation[N].Device.qxPower` | BOOL | Выход питания |
| `Application.MAIN.stDumper.MotorRotation[N].Device.qxActive` | BOOL | Активен |
| `Application.MAIN.stDumper.MotorRotation[N].Device.qxHasError` | BOOL | Есть ошибка |
| `Application.MAIN.stDumper.MotorRotation[N].xStateWarning` | BOOL | Предупреждение |
| `Application.MAIN.stDumper.MotorRotation[N].xStateFailure` | BOOL | Ошибка |
| `Application.MAIN.stDumper.MotorRotation[N].cmdManualStartKM` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stDumper.MotorRotation[N].cmdManualStopKM` | BOOL | Команда останова (местный) |

#### ЧРП двигателя поворота

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stDumper.MotorRotation[N].VFD.qxStart` | BOOL | Пуск ЧРП (DO) |
| `Application.MAIN.stDumper.MotorRotation[N].VFD.qxResetFailure` | BOOL | Сброс аварии ЧРП (DO) |
| `Application.uDumperMotorRotation[N]OutFreq.rTag` | U_RealToWord | Выходная частота (AO) |
| `Application.uDumperMotorRotation[N]ActualFreq.rTag` | U_RealToWord | Текущая частота |
| `Application.MAIN.stDumper.MotorRotation[N].VFD.xStateRdyToStart` | BOOL | Готов к пуску |
| `Application.MAIN.stDumper.MotorRotation[N].VFD.xStateIsWorking` | BOOL | В работе |
| `Application.MAIN.stDumper.MotorRotation[N].VFD.xStateFailure` | BOOL | Ошибка ЧРП |
| `Application.uDumperMotorRotation[N]Current.rTag` | U_RealToWord | Ток двигателя |
| `Application.uDumperMotorRotation[N]SetFreq.rTag` | U_RealToWord | Ручное задание частоты |
| `Application.MAIN.stDumper.MotorRotation[N].VFD.cmdManualStart` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stDumper.MotorRotation[N].VFD.cmdManualStop` | BOOL | Команда остановки (местный) |
| `Application.MAIN.stDumper.MotorRotation[N].VFD.cmdFrequencyDirectMode` | BOOL | Режим задания частоты (0-плавный, 1-мгновенный) |

---

## 5. КОНВЕЙЕР (Application.MAIN.stConveyor)

### 5.1 Состояния и управление

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.xStartConveyor` | BOOL | Команда запуска конвейера |
| `Application.MAIN.eConveyorStage` | ENUM | Стадия конвейера (E_StageWithPreStartAlarm) |
| `Application.MAIN.stConveyor.xStateWarning` | BOOL | Предупреждение |
| `Application.MAIN.stConveyor.xStateFailure` | BOOL | Ошибка |
| `Application.MAIN.stConveyor.xStateEnable` | BOOL | Полностью запущен |
| `Application.MAIN.stConveyor.xStateStarting` | BOOL | Процесс запуска |

### 5.2 Команды АСУТП

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stConveyor.cmdStartConveyor` | BOOL | Команда пуска |
| `Application.MAIN.stConveyor.cmdStopConveyor` | BOOL | Команда останова |
| `Application.MAIN.stConveyor.cmdEmergencyStop` | BOOL | Аварийный останов |
| `Application.MAIN.stConveyor.cmdReset` | BOOL | Сброс ошибок |

### 5.3 Кнопки ПМУ

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stConveyor.fbBtnStart.qxSignal` | BOOL | Кнопка "Пуск" |
| `Application.MAIN.stConveyor.fbBtnStop.qxSignal` | BOOL | Кнопка "Стоп" |
| `Application.MAIN.stConveyor.fbBtnEmergencyStop.qxSignal` | BOOL | Кнопка аварийной остановки |

### 5.4 Датчики безопасности

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stConveyor.fbZQAlarm[1..4].qxSignal` | BOOL | Контроль схода ленты - тревога |
| `Application.MAIN.stConveyor.fbZQWarning[1..4].qxSignal` | BOOL | Контроль схода ленты - предупреждение |
| `Application.MAIN.stConveyor.fbHQ_IsOk[1..4].qxSignal` | BOOL | Кабель-тросовый выключатель |
| `Application.MAIN.stConveyor.fbSQ_IsOk[1..2].qxSignal` | BOOL | Контроль ограждения барабана |
| `Application.MAIN.stConveyor.fbGS1.qxSignal` | BOOL | Контроль заштыбовки |
| `Application.MAIN.stConveyor.fbQR[1..2].qxSignal` | BOOL | Измерение скорости вращения барабана |
| `Application.MAIN.stConveyor.fbYS1.qxSignal` | BOOL | Контроль продольного разрыва ленты |
| `Application.MAIN.stConveyor.fbYE1.qxSignal` | BOOL | Металлодетектор |

### 5.5 Светозвуковое оповещение

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stConveyor.xHLA` | BOOL | Световая сигнализация (DO) |
| `Application.MAIN.stConveyor.xSoundAlarm` | BOOL | Звуковая сигнализация (DO) |

### 5.6 Двигатели конвейера (MotorConveyor[1..2])

Для каждого двигателя N = 1, 2:

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stConveyor.MotorConveyor[N].StateRemote` | ENUM | Режим управления |
| `Application.MAIN.stConveyor.MotorConveyor[N].qxKM_Power` | BOOL | Пуск контактора (DO) |
| `Application.MAIN.stConveyor.MotorConveyor[N].fbStateKM.qxSignal` | BOOL | Состояние контактора (DI) |
| `Application.MAIN.stConveyor.MotorConveyor[N].fbStateQF.qxSignal` | BOOL | Состояние автовыключателя (DI) |
| `Application.MAIN.stConveyor.MotorConveyor[N].fbStatorOverheat.qxSignal` | BOOL | Перегрев статора (DI) |
| `Application.MAIN.stConveyor.MotorConveyor[N].Device.qxPower` | BOOL | Выход питания |
| `Application.MAIN.stConveyor.MotorConveyor[N].Device.qxActive` | BOOL | Активен |
| `Application.MAIN.stConveyor.MotorConveyor[N].Device.qxHasError` | BOOL | Есть ошибка |
| `Application.MAIN.stConveyor.MotorConveyor[N].xStateWarning` | BOOL | Предупреждение |
| `Application.MAIN.stConveyor.MotorConveyor[N].xStateFailure` | BOOL | Ошибка |
| `Application.MAIN.stConveyor.MotorConveyor[N].cmdManualStartKM` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stConveyor.MotorConveyor[N].cmdManualStopKM` | BOOL | Команда останова (местный) |

#### ЧРП двигателя конвейера

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stConveyor.MotorConveyor[N].VFD.qxStart` | BOOL | Пуск ЧРП (DO) |
| `Application.MAIN.stConveyor.MotorConveyor[N].VFD.qxResetFailure` | BOOL | Сброс аварии ЧРП (DO) |
| `Application.uConveyorMotor[N]OutFreq.rTag` | U_RealToWord | Выходная частота (AO) |
| `Application.uConveyorMotor[N]ActualFreq.rTag` | U_RealToWord | Текущая частота |
| `Application.MAIN.stConveyor.MotorConveyor[N].VFD.xStateRdyToStart` | BOOL | Готов к пуску |
| `Application.MAIN.stConveyor.MotorConveyor[N].VFD.xStateIsWorking` | BOOL | В работе |
| `Application.MAIN.stConveyor.MotorConveyor[N].VFD.xStateFailure` | BOOL | Ошибка ЧРП |
| `Application.uConveyorMotor[N]Current.rTag` | U_RealToWord | Ток двигателя |
| `Application.uConveyorMotor[N]SetFreq.rTag` | U_RealToWord | Ручное задание частоты |
| `Application.MAIN.stConveyor.MotorConveyor[N].VFD.cmdManualStart` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stConveyor.MotorConveyor[N].VFD.cmdManualStop` | BOOL | Команда остановки (местный) |
| `Application.MAIN.stConveyor.MotorConveyor[N].VFD.cmdFrequencyDirectMode` | BOOL | Режим задания частоты (0-плавный, 1-мгновенный) |

---

## 6. БУНКЕРЫ (Application.MAIN.stBunker[1..3])

Для каждого бункера N = 1, 2, 3:

### 6.1 Состояния и управление

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].xStateWarning` | BOOL | Предупреждение |
| `Application.MAIN.stBunker[N].xStateFailure` | BOOL | Ошибка |
| `Application.MAIN.stBunker[N].eLightColor` | ENUM | Текущий цвет светофора (E_LightColor) |
| `Application.uBunker[N]Weight.rTag` | U_RealToWord | Вес бункера |
| `Application.uBunker[N]ProportionActual.rTag` | U_RealToWord | Фактическая пропорция |
| `Application.uBunker[N]VibFeederFrequency.rTag` | U_RealToWord | Частота вибропитателей |

### 6.2 Команды АСУТП

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].cmdStartFeeder` | BOOL | Команда пуска питателя |
| `Application.MAIN.stBunker[N].cmdStopFeeder` | BOOL | Команда останова питателя |
| `Application.MAIN.stBunker[N].cmdEmergencyStopFeeder` | BOOL | Аварийный останов |
| `Application.uBunker[N]DumpingPrecent.rTag` | U_RealToWord | Задание % сбрасывания |
| `Application.MAIN.stBunker[N].cmdReset` | BOOL | Сброс ошибок |

### 6.3 Кнопки ПМУ

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].fbBtnStart.qxSignal` | BOOL | Кнопка "Пуск питателя" |
| `Application.MAIN.stBunker[N].fbBtnStop.qxSignal` | BOOL | Кнопка "Стоп питателя" |
| `Application.MAIN.stBunker[N].fbBtnEmergencyStop.qxSignal` | BOOL | Кнопка аварийной остановки |

### 6.4 Датчики

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].fbStateHatch.qxSignal` | BOOL | Положение люка (1-закрыт, 0-открыт) |

### 6.5 Светофор

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].qxLightRed` | BOOL | Красный сигнал (DO) |
| `Application.MAIN.stBunker[N].qxLightYellow` | BOOL | Жёлтый сигнал (DO) |
| `Application.MAIN.stBunker[N].qxLightGreen` | BOOL | Зелёный сигнал (DO) |

### 6.6 Двигатели вибраторов (MotorVibrator[1..4])

Для каждого вибратора M = 1, 2, 3, 4:

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].MotorVibrator[M].StateRemote` | ENUM | Режим управления |
| `Application.MAIN.stBunker[N].MotorVibrator[M].qxKM_Power` | BOOL | Пуск контактора (DO) |
| `Application.MAIN.stBunker[N].MotorVibrator[M].fbStateKM.qxSignal` | BOOL | Состояние контактора (DI) |
| `Application.MAIN.stBunker[N].MotorVibrator[M].fbStateQF.qxSignal` | BOOL | Состояние автовыключателя (DI) |
| `Application.MAIN.stBunker[N].MotorVibrator[M].Device.qxPower` | BOOL | Выход питания |
| `Application.MAIN.stBunker[N].MotorVibrator[M].Device.qxActive` | BOOL | Активен |
| `Application.MAIN.stBunker[N].MotorVibrator[M].Device.qxHasError` | BOOL | Есть ошибка |
| `Application.MAIN.stBunker[N].MotorVibrator[M].xStateWarning` | BOOL | Предупреждение |
| `Application.MAIN.stBunker[N].MotorVibrator[M].xStateFailure` | BOOL | Ошибка |
| `Application.MAIN.stBunker[N].MotorVibrator[M].cmdManualStartKM` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stBunker[N].MotorVibrator[M].cmdManualStopKM` | BOOL | Команда останова (местный) |

#### ЧРП вибратора

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].MotorVibrator[M].VFD.qxStart` | BOOL | Пуск ЧРП (DO) |
| `Application.MAIN.stBunker[N].MotorVibrator[M].VFD.qxResetFailure` | BOOL | Сброс аварии ЧРП (DO) |
| `Application.uBunker[N]Vibrator[M]OutFreq.rTag` | U_RealToWord | Выходная частота (AO) |
| `Application.uBunker[N]Vibrator[M]ActualFreq.rTag` | U_RealToWord | Текущая частота |
| `Application.MAIN.stBunker[N].MotorVibrator[M].VFD.xStateRdyToStart` | BOOL | Готов к пуску |
| `Application.MAIN.stBunker[N].MotorVibrator[M].VFD.xStateIsWorking` | BOOL | В работе |
| `Application.MAIN.stBunker[N].MotorVibrator[M].VFD.xStateFailure` | BOOL | Ошибка ЧРП |
| `Application.uBunker[N]Vibrator[M]Current.rTag` | U_RealToWord | Ток двигателя |
| `Application.uBunker[N]Vibrator[M]SetFreq.rTag` | U_RealToWord | Ручное задание частоты |
| `Application.MAIN.stBunker[N].MotorVibrator[M].VFD.cmdManualStart` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stBunker[N].MotorVibrator[M].VFD.cmdManualStop` | BOOL | Команда остановки (местный) |

### 6.7 Двигатели вибропитателей (MotorVibFeeder[1..2])

Для каждого вибропитателя M = 1, 2:

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].StateRemote` | ENUM | Режим управления |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].qxKM_Power` | BOOL | Пуск контактора (DO) |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].fbStateKM.qxSignal` | BOOL | Состояние контактора (DI) |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].fbStateQF.qxSignal` | BOOL | Состояние автовыключателя (DI) |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].fbStatorOverheat.qxSignal` | BOOL | Перегрев статора (DI) |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].Device.qxPower` | BOOL | Выход питания |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].Device.qxActive` | BOOL | Активен |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].Device.qxHasError` | BOOL | Есть ошибка |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].xStateWarning` | BOOL | Предупреждение |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].xStateFailure` | BOOL | Ошибка |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].cmdManualStartKM` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].cmdManualStopKM` | BOOL | Команда останова (местный) |

#### Температура подшипников вибропитателя

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.uBunker[N]VibFeeder[M]TempBearing1.rTag` | U_RealToWord | Температура подшипника 1 |
| `Application.uBunker[N]VibFeeder[M]TempBearing2.rTag` | U_RealToWord | Температура подшипника 2 |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].eTempBearingAlarmSetPoints` | ENUM | Состояние уставок (L/LL/H/HH) |

#### ЧРП вибропитателя

| Тэг | Тип | Описание |
|-----|-----|----------|
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].VFD.qxStart` | BOOL | Пуск ЧРП (DO) |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].VFD.qxResetFailure` | BOOL | Сброс аварии ЧРП (DO) |
| `Application.uBunker[N]VibFeeder[M]OutFreq.rTag` | U_RealToWord | Выходная частота (AO) |
| `Application.uBunker[N]VibFeeder[M]ActualFreq.rTag` | U_RealToWord | Текущая частота |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].VFD.xStateRdyToStart` | BOOL | Готов к пуску |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].VFD.xStateIsWorking` | BOOL | В работе |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].VFD.xStateFailure` | BOOL | Ошибка ЧРП |
| `Application.uBunker[N]VibFeeder[M]Current.rTag` | U_RealToWord | Ток двигателя |
| `Application.uBunker[N]VibFeeder[M]SetFreq.rTag` | U_RealToWord | Ручное задание частоты |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].VFD.cmdManualStart` | BOOL | Команда пуска (местный) |
| `Application.MAIN.stBunker[N].MotorVibFeeder[M].VFD.cmdManualStop` | BOOL | Команда остановки (местный) |

---

## 8. ПЕРЕЧИСЛЕНИЯ (ENUM)

### E_StageWithPreStartAlarm

| Значение | Описание |
|----------|----------|
| IDLE | Ожидание |
| PRESTART_ALARM | Предпусковая сигнализация |
| STARTING | Запуск |
| WORK | Работа |
| STOPPING | Останов |
| ERROR | Ошибка |

### E_StateRemote

| Значение | Описание |
|----------|----------|
| Manual (0) | Местный режим |
| Remote (1) | Дистанционный режим |
| Automatic (2) | Автоматический режим |

### E_LightColor

| Значение | Описание |
|----------|----------|
| Red | Красный |
| Yellow | Жёлтый |
| Green | Зелёный |

### E_StateFeedback

| Значение | Описание |
|----------|----------|
| Inactive (0) | Выключен, нет обратной связи |
| Active (1) | Включен с обратной связью |
| Error_NoFeedback (2) | Питание есть, обратной связи нет |
| Error_UnexpectedFeedback (3) | Обратная связь без питания |

### E_StateMechanism

| Значение | Описание |
|----------|----------|
| NotReady (0) | Не готов |
| Ready (1) | Готов |
| Working (2) | В работе |
| Warning (3) | Предупреждение |
| Error (4) | Ошибка |

### E_AlarmSetpoints

| Значение | Описание |
|----------|----------|
| OK | Норма |
| L | Low - нижний предел |
| LL | Low-Low - критически низкий |
| H | High - верхний предел |
| HH | High-High - критически высокий |

---

## Примечания

1. **Типы сигналов:**
   - `DI` - дискретный вход
   - `DO` - дискретный выход
   - `AI` - аналоговый вход
   - `AO` - аналоговый выход

2. **Индексация массивов:**
   - `[1..4]` означает элементы с 1 по 4 включительно
   - Нотация `[N]` означает подстановку номера элемента

3. **Выходы FB_UniversalSignal:**
   - `.qxSignal` - обработанный сигнал
   - `.qxRisingEdge` - передний фронт
   - `.qxFallingEdge` - задний фронт
   - `.qxWaitingFeedback` - ожидание обратной связи

4. **Выходы FB_UniversalMechanism:**
   - `.qxPower` - выход питания
   - `.qxActive` - механизм активен
   - `.qxHasError` - есть ошибка
   - `.quFeedbackState` - состояние обратной связи

5. **Выходы FB_UniversalAnalogSignal:**
   - `.qrProcessedValue` - обработанное значение

6. **Выходы U_RealToWord:**
   - `.rTag` - значение REAL
   - `.wTag[0]`, `.wTag[1]` - младшее и старшее слово (WORD)
