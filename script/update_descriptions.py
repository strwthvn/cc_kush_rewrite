#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script to update Modbus register descriptions from code comments
"""

import json
import re

# Mapping of variable paths to their descriptions from code
DESCRIPTIONS = {
    # === GLOBAL.st ===
    "ICUR_PRECENT": "Коэффициент использования установленной мощности (в процентах)",
    "rElectricityMeter": "Раход электроэнергии",
    "EFFICIENCY_LIMIT_RATE": "Коэффицент ограничения производительности (0-1)",
    "ANNUNCIATOR_LIGHT_HZ": "Световая индикация Гц",

    "VFD_SMOOTH_SET_FREQUENCY": "Опция плавного задания частоты",
    "VFD_FREQUENCY_SYNC_TOLERANCE": "Допустимая разница частот для синхронизации моторов",
    "MOTOR_FREQUENCY_CONVEYOR": "Частота мотора конвейера",
    "MOTOR_FREQUENCY_DUMPER_CONVEYOR": "Частота мотора конвейера отвалообразователя",
    "MOTOR_FREQUENCY_DUMPER_ROTATION": "Частота мотора поворота отвалообразователя",
    "CONVEYOR_DEAFULT_SPEED": "Скорость конвейера",

    "BUNKER_WORK_PRECENT_1": "Уставка пропорции шихтования для бункера 1",
    "BUNKER_WORK_PRECENT_2": "Уставка пропорции шихтования для бункера 2",
    "BUNKER_WORK_PRECENT_3": "Уставка пропорции шихтования для бункера 3",
    "BUNKER_MINIMAL_WEIGHT": "Уставка минимального веса бункера. Результат <= считывается алгоритмом как пустой бункер.",

    # ST_AlarmSetpoints - используется для всех *_POINTS
    "LL_Value": "Уставка Low-Low",
    "L_Value": "Уставка Low",
    "H_Value": "Уставка High",
    "HH_Value": "Уставка High-High",

    # ST_BunkerVibratorSettings
    "TIME_ACTIVE": "Время активной работы вибратора",
    "TIME_PAUSE_VIBRATOR": "Время паузы вибратора между циклами",
    "TIME_PAUSE_FB": "Время паузы ФБ между подходами",

    "TIME_WAITING_FEEDBACK": "Таймер ожидания пропавшего сигнала обратной связи работы механизма",
    "PNEUMATIC_COLLAPSE_TIME": "Уставка времени таймера пневмообрушения",

    # ST_PreStartAlarmSettings
    "OPTION_ENABLE": "Опция на включение ППЗ в алгоритм",
    "TIME_FIRST_SIGNAL": "Время звучания первого сигнала",
    "TIME_FIRST_SIGNAL_PAUSE": "Пауза после первого сигнала",
    "TIME_SECOND_SIGNAL": "Время звучания второго сигнала",
    "TIME_SECOND_SIGNAL_PAUSE": "Пауза после втотрого сигнала",

    # === ST_Commands ===
    "cmdResetAll": "Сброс всех ошибок",
    "cmdStartCommon": "Команда общего пуска",
    "cmdStopCommon": "Команда общего останова",
    "cmdEmergencyStopCommon": "Команда общей аварийной остановки",

    # === ST_CommonSignals ===
    "fbEmergencyStopBtn": "Кнопка \"Аварийная остановка\"",
    "fbRemoteModeBtn": "Режим работы ( 1 - дистанционный, 0 - местный)",
    "fbRealyCurrentControl": "Реле контроля фаз",
    "fbQF1": "Состояние автомат. выключателя (1 - включен, 0 - выключен)",
    "fb9QF1": "Состояние автомат. выключателя (1 - включен, 0 - выключен)",
    "fb10QF1": "Состояние автомат. выключателя (1 - включен, 0 - выключен)",
    "fb11QF1": "Состояние автомат. выключателя (1 - включен, 0 - выключен)",
    "qx6KM1": "Контактор 6KM1",

    # === MAIN.st local vars ===
    "xStateAutoWorking": "Система полностью запущена и работает в автоматическом режиме",
    "xStateEmergencyStop": "Система была аварийно остановлена",
    "xStateErrorCheckReady": "Проверки стадии готовности к пуску провалились",
    "xStateErrorAcceptIdle": "Невозможно принять коэффицент шихтования по заданию оператора - сумма коэффицентов не равна 100",

    # === ST_Bunker ===
    "rWeight": "Весы бункера",
    "rProportionActual": "Пропорция от веса",
    "rMotorVibFeederCommonFrequency": "Частота двух моторов вибропитателя",
    "cmdDumpingPrecent": "Задание процентного соотношения сбрасывания",
    "xStateWarning": "Программное предупреждение",
    "xStateFailure": "Программная ошибка",
    "fbStateHatch": "Положение люка (1 - закрыт , 0 - открыт )",
    "qxLightRed": "Красный сигнал светофора",
    "qxLightYellow": "Желтый сигнал светофора",
    "qxLightGreen": "Зеленый сигнал светофора",
    "fbBtnStart": "Кнопка \"Пуск питателя\" NO",
    "fbBtnStop": "Кнопка \"Стоп питателя\" NO",
    "fbBtnEmergencyStop": "Кнопка \"Аварийная остановка\" NC",
    "cmdStartFeeder": "Команда \"Пуск питателя\"",
    "cmdStopFeeder": "Команда \"Стоп питателя\"",
    "cmdEmergencyStopFeeder": "Команда \"Аварийная остановка\"",
    "cmdReset": "Сброс ошибок",

    # === ST_VFD ===
    "qrOutFrequency": "Выходная частота",
    "rActualFrequency": "Текущая частота ЧРП",
    "wMotorCurrent": "Ток эл. двигателя",
    "cmdSetFrequency": "Ручное задание частоты",

    # === ST_MotorVibFeeder ===
    "rTempBearing": "Температура подшипникового узла (в °C)",

    # === ST_Dumper / ST_ConveyorBasic / ST_ConveyorPrefabricated ===
    "xStateEnable": "Механизм полностью запущен",
    "xStateStarting": "Процесс запуска (вместе с ППЗ)",
    "xHLA": "Световая сигнализация",
    "xSoundAlarm": "Звуковая сигнализация",
    "fbYE1": "Обнаружение металла (металлодетектор)",
    "cmdStartConveyor": "Команда пуска конвейера",
    "cmdStopConveyor": "Команда останова конвейера",
    "cmdEmergencyStop": "Команда аварийной остановки",
    "cmdTurnLeft": "Команда поворота влево",
    "cmdTurnRight": "Команда поворота вправо",
    "fbBtnTurnLeft": "Кнопка поворота влево",
    "fbBtnTurnRight": "Кнопка поворота вправо",
    "fbEndSwitchRight": "Концевой выключатель правого положения",
    "fbEndSwitchLeft": "Концевой выключатель левого положения",
    "fbBtnRemoteMode": "Кнопка режима",

    # SIMULATION
    "SIMULATION": "Режим симуляции",
}


def find_description(variable_path):
    """
    Find description for a variable path like 'stBunker[1].rWeight'
    Uses pattern matching to extract the core variable name
    """
    # Try exact match first
    if variable_path in DESCRIPTIONS:
        return DESCRIPTIONS[variable_path]

    # Extract the last component (e.g., 'rWeight' from 'stBunker[1].rWeight')
    parts = variable_path.replace('[', '.').replace(']', '').split('.')

    # Try matching from the end
    for i in range(len(parts)):
        key = '.'.join(parts[i:])
        if key in DESCRIPTIONS:
            return DESCRIPTIONS[key]

    # Try matching just the last component
    last_part = parts[-1]
    if last_part in DESCRIPTIONS:
        return DESCRIPTIONS[last_part]

    # Check for special patterns
    # Pattern: MotorVibrator[N].VFD.xxx or MotorVibFeeder[N].VFD.xxx
    if 'VFD' in parts:
        vfd_idx = parts.index('VFD')
        if vfd_idx + 1 < len(parts):
            vfd_field = parts[vfd_idx + 1]
            if vfd_field in DESCRIPTIONS:
                return DESCRIPTIONS[vfd_field]

    # Pattern: MotorVibFeeder[N].rTempBearing[N]
    if 'MotorVibFeeder' in parts and 'rTempBearing' in parts:
        return DESCRIPTIONS['rTempBearing']

    # Pattern: *_POINTS.LL_Value, etc.
    if '_POINTS' in variable_path:
        for key in ['LL_Value', 'L_Value', 'H_Value', 'HH_Value']:
            if key in parts:
                return DESCRIPTIONS[key]

    # Pattern: *_SETTINGS.TIME_xxx
    if '_SETTINGS' in variable_path or 'VIBRATOR_SETTINGS' in variable_path or 'PNEUMO_SETTINGS' in variable_path:
        for key in ['OPTION_ENABLE', 'TIME_ACTIVE', 'TIME_PAUSE_VIBRATOR', 'TIME_PAUSE_FB',
                    'TIME_FIRST_SIGNAL', 'TIME_FIRST_SIGNAL_PAUSE',
                    'TIME_SECOND_SIGNAL', 'TIME_SECOND_SIGNAL_PAUSE']:
            if key in parts:
                return DESCRIPTIONS[key]

    # Pattern: stCommands.cmdXxx.ixSignal
    if 'stCommands' in parts:
        for i, part in enumerate(parts):
            if part.startswith('cmd') and part in DESCRIPTIONS:
                return DESCRIPTIONS[part]

    # Pattern: stCommonSignals.fbXxx.qxSignal
    if 'stCommonSignals' in parts:
        for i, part in enumerate(parts):
            if part.startswith('fb') and part in DESCRIPTIONS:
                return DESCRIPTIONS[part]

    # Pattern: stBunker[N].fbXxx.qxSignal
    if 'stBunker' in parts or 'Bunker' in parts:
        for i, part in enumerate(parts):
            if (part.startswith('fb') or part.startswith('cmd') or
                part.startswith('qx') or part.startswith('r') or
                part.startswith('x')) and part in DESCRIPTIONS:
                return DESCRIPTIONS[part]

    # Pattern: stDumper/stConveyor fields
    if 'stDumper' in parts or 'stConveyor' in parts or 'Dumper' in parts or 'Conveyor' in parts:
        for i, part in enumerate(parts):
            if part in DESCRIPTIONS:
                return DESCRIPTIONS[part]

    # If still no match, return empty (will keep as "-")
    return None


def update_modbus_map(input_file, output_file):
    """
    Read JSON, update descriptions, write back
    """
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Update holding registers
    for reg in data['holding_registers']['registers']:
        var = reg['variable']
        desc = find_description(var)
        if desc:
            reg['description'] = desc

    # Update input registers
    for reg in data['input_registers']['registers']:
        var = reg['variable']
        desc = find_description(var)
        if desc:
            reg['description'] = desc

    # Write back with pretty formatting
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"Updated {output_file}")


if __name__ == '__main__':
    update_modbus_map('modbus_map.json', 'modbus_map.json')
