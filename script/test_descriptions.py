#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Тестовый скрипт для проверки функции find_description()
"""

import sys
from pathlib import Path

# Добавить путь к модулю
sys.path.insert(0, str(Path(__file__).parent))

from migrate_from_fc import find_description

# Тестовые случаи
test_cases = [
    # Простые переменные
    "SIMULATION",
    "BUNKER_WORK_PRECENT_1",
    "VFD_FREQUENCY_SYNC_TOLERANCE",

    # Вложенные структуры
    "stBunker[1].rWeight",
    "stBunker[2].rProportionActual",
    "stBunker[1].fbStateHatch.qxSignal",

    # VFD переменные
    "stBunker[1].MotorVibFeeder[1].VFD.qrOutFrequency",
    "stBunker[2].MotorVibFeeder[1].VFD.rActualFrequency",
    "stDumper.MotorConveyor[1].VFD.wMotorCurrent",

    # Температура
    "stBunker[1].MotorVibFeeder[1].rTempBearing[1]",
    "stBunker[2].MotorVibFeeder[2].rTempBearing[2]",

    # Команды
    "stCommands.cmdResetAll.ixSignal",
    "stCommands.cmdStartCommon.ixSignal",

    # Общие сигналы
    "stCommonSignals.fbEmergencyStopBtn.qxSignal",
    "stCommonSignals.fbQF1.qxSignal",

    # Dumper/Conveyor
    "stDumper.xStateEnable",
    "stDumper.cmdStartConveyor.ixSignal",
    "stConveyor.xHLA",

    # Setpoints
    "BUNKER_1_TEMP_BEARING_1_POINTS.LL_Value",
    "BUNKER_2_TEMP_BEARING_2_POINTS.HH_Value",

    # Settings
    "BUNKER_1_VIBRATOR_SETTINGS.TIME_ACTIVE",
    "PRESTART_ALARM_DUMPER_SETTINGS.OPTION_ENABLE",

    # Переменная, которой нет в словаре (должна вернуть пустую строку)
    "stSomeUnknownVariable.xSomeField",
]

def main():
    print("=" * 80)
    print("Тест функции find_description()")
    print("=" * 80)

    found_count = 0
    not_found_count = 0

    for var_path in test_cases:
        description = find_description(var_path)
        if description:
            found_count += 1
            status = "✅"
        else:
            not_found_count += 1
            status = "❌"

        print(f"\n{status} {var_path}")
        if description:
            print(f"   → {description}")
        else:
            print(f"   → (описание не найдено)")

    print("\n" + "=" * 80)
    print(f"Результаты:")
    print(f"  Найдено: {found_count}/{len(test_cases)}")
    print(f"  Не найдено: {not_found_count}/{len(test_cases)}")
    print(f"  Покрытие: {found_count/len(test_cases)*100:.1f}%")
    print("=" * 80)

if __name__ == '__main__':
    main()
