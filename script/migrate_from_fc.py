#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modbus Register Migration Tool
================================
Парсит файл FC_ModbusToSCADA.st и заполняет SQLite базу данных.
Автоматически добавляет описания переменных из встроенного словаря DESCRIPTIONS.

Использование:
    python migrate_from_fc.py              # Обычный режим
    python migrate_from_fc.py --verbose    # С выводом переменных без описаний
    python migrate_from_fc.py -v           # То же самое (короткая форма)

Возможности:
    - Парсинг FC_ModbusToSCADA.st
    - Автоматическое определение описаний переменных
    - Паттерн-матчинг для сложных путей (stBunker[1].VFD.qrOutFrequency)
    - Статистика покрытия описаниями
    - Verbose режим для отладки

Автор: Claude Code
Дата: 2025-12-12
Обновлено: 2025-12-17 (добавлены описания переменных)
"""

import re
import sqlite3
import os
import sys
from pathlib import Path
from typing import List, Tuple, Optional, Dict

# Пути к файлам
SCRIPT_DIR = Path(__file__).parent
DB_PATH = SCRIPT_DIR / 'db' / 'modbus_registers.db'
SCHEMA_PATH = SCRIPT_DIR / 'db' / 'schema.sql'
FC_MODBUS_PATH = SCRIPT_DIR.parent / 'POUs' / 'FB_ModbusToSCADA.st'

# Словарь описаний переменных (из update_descriptions.py)
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
    "cmdSetToRepair": "Команда переключения в режим \"Ремонт\"",
    "cmdSetToManual": "Команда переключения в режим \"Ручной\"",
    "cmdSetToAuto": "Команда переключения в режим \"Автоматический\"",
    "cmdBuildCircuitOn": "Команда \"Собрать цепь\"",
    "cmdBuildCircuitOff": "Команда \"Разобрать цепь\"",
    "cmdStartVibrator": "Команда \"Пуск вибраторов\"",
    "cmdStopVibrator": "Команда \"Стоп вибраторов\"",
    "cmdEmergencyStopVibrator": "Команда \"Аварийная остановка вибраторов\"",
    "cmdAddVib1": "Команда \"Добавить вибратор 1\"",
    "cmdAddVib2": "Команда \"Добавить вибратор 2\"",
    "cmdAddVib3": "Команда \"Добавить вибратор 3\"",
    "cmdAddVib4": "Команда \"Добавить вибратор 4\"",

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
    "xStateRemoteAuto": "Режим управления \"Автоматический\"",
    "xStateRemoteManual": "Режим управления \"Ручной\"",
    "xStateRemoteRepair": "Режим управления \"Ремонт\"",

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


def find_description(variable_path: str) -> str:
    """
    Найти описание для переменной по её пути (например, 'stBunker[1].rWeight')
    Использует паттерн-матчинг для извлечения ключевого имени переменной

    Args:
        variable_path: Путь к переменной (например, 'stBunker[1].MotorVibFeeder[1].VFD.qrOutFrequency')

    Returns:
        Описание переменной или пустую строку, если не найдено
    """
    # Попытка прямого совпадения
    if variable_path in DESCRIPTIONS:
        return DESCRIPTIONS[variable_path]

    # Извлечь компоненты пути (например, 'rWeight' из 'stBunker[1].rWeight')
    parts = variable_path.replace('[', '.').replace(']', '').split('.')

    # Попытка совпадения с конца
    for i in range(len(parts)):
        key = '.'.join(parts[i:])
        if key in DESCRIPTIONS:
            return DESCRIPTIONS[key]

    # Попытка совпадения только последнего компонента
    last_part = parts[-1]
    if last_part in DESCRIPTIONS:
        return DESCRIPTIONS[last_part]

    # Проверка специальных паттернов
    # Паттерн: MotorVibrator[N].VFD.xxx или MotorVibFeeder[N].VFD.xxx
    if 'VFD' in parts:
        vfd_idx = parts.index('VFD')
        if vfd_idx + 1 < len(parts):
            vfd_field = parts[vfd_idx + 1]
            if vfd_field in DESCRIPTIONS:
                return DESCRIPTIONS[vfd_field]

    # Паттерн: MotorVibFeeder[N].rTempBearing[N]
    if 'MotorVibFeeder' in parts and 'rTempBearing' in parts:
        return DESCRIPTIONS['rTempBearing']

    # Паттерн: *_POINTS.LL_Value, etc.
    if '_POINTS' in variable_path:
        for key in ['LL_Value', 'L_Value', 'H_Value', 'HH_Value']:
            if key in parts:
                return DESCRIPTIONS[key]

    # Паттерн: *_SETTINGS.TIME_xxx
    if '_SETTINGS' in variable_path or 'VIBRATOR_SETTINGS' in variable_path or 'PNEUMO_SETTINGS' in variable_path:
        for key in ['OPTION_ENABLE', 'TIME_ACTIVE', 'TIME_PAUSE_VIBRATOR', 'TIME_PAUSE_FB',
                    'TIME_FIRST_SIGNAL', 'TIME_FIRST_SIGNAL_PAUSE',
                    'TIME_SECOND_SIGNAL', 'TIME_SECOND_SIGNAL_PAUSE']:
            if key in parts:
                return DESCRIPTIONS[key]

    # Паттерн: stCommands.cmdXxx.ixSignal
    if 'stCommands' in parts:
        for i, part in enumerate(parts):
            if part.startswith('cmd') and part in DESCRIPTIONS:
                return DESCRIPTIONS[part]

    # Паттерн: stCommonSignals.fbXxx.qxSignal
    if 'stCommonSignals' in parts:
        for i, part in enumerate(parts):
            if part.startswith('fb') or part.startswith('qx'):
                if part in DESCRIPTIONS:
                    return DESCRIPTIONS[part]

    # Паттерн: stBunker[N].fbXxx.qxSignal
    if 'stBunker' in parts or 'Bunker' in parts:
        for i, part in enumerate(parts):
            if (part.startswith('fb') or part.startswith('cmd') or
                part.startswith('qx') or part.startswith('r') or
                part.startswith('x')):
                if part in DESCRIPTIONS:
                    return DESCRIPTIONS[part]

    # Паттерн: stDumper/stConveyor fields
    if 'stDumper' in parts or 'stConveyor' in parts or 'Dumper' in parts or 'Conveyor' in parts:
        for i, part in enumerate(parts):
            if part in DESCRIPTIONS:
                return DESCRIPTIONS[part]

    # Если ничего не найдено, вернуть пустую строку
    return ''


class ModbusRegister:
    """Класс для представления одного Modbus регистра"""
    def __init__(self, register_type: str, register_address: int, bit_index: Optional[int],
                 data_type: str, variable_name: str, section_name: str = ''):
        self.register_type = register_type
        self.register_address = register_address
        self.bit_index = bit_index
        self.data_type = data_type
        self.variable_name = variable_name
        self.section_name = section_name
        # Автоматически присвоить описание на основе имени переменной
        self.description = find_description(variable_name)


class FC_ModbusParser:
    """Парсер файла FC_ModbusToSCADA.st"""

    def __init__(self, file_path: Path):
        self.file_path = file_path
        self.registers: List[ModbusRegister] = []
        self.sections: Dict[Tuple[str, str], Tuple[int, int]] = {}  # (type, name) -> (start, end)
        self.current_section = ''

    def parse(self) -> List[ModbusRegister]:
        """Основной метод парсинга файла"""
        with open(self.file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Разбить на две части: Holding и Input регистры
        holding_section = self._extract_section(content, 'HOLDING РЕГИСТРЫ')
        input_section = self._extract_section(content, 'INPUT РЕГИСТРЫ')

        # Парсить каждую секцию
        if holding_section:
            self._parse_register_section(holding_section, 'holding_registers')
        if input_section:
            self._parse_register_section(input_section, 'input_registers')

        return self.registers

    def _extract_section(self, content: str, marker: str) -> Optional[str]:
        """Извлечь секцию кода между маркерами"""
        # Pattern matches from marker to either next === section, END_FUNCTION, or end of file
        pattern = rf'//\s*===\s*{marker}.*?$(.+?)(?=//\s*===|END_FUNCTION|\Z)'
        match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
        return match.group(1) if match else None

    def _parse_register_section(self, content: str, register_type: str):
        """Парсить секцию регистров"""
        lines = content.split('\n')

        for line in lines:
            # Проверка на DI/DO MODULES MAPPING секции (основная секция)
            di_do_match = re.match(r'//\s+(DI|DO)\s+MODULES\s+MAPPING\s*\((\d+)-(\d+)\)', line)
            if di_do_match:
                module_type = di_do_match.group(1)
                start_reg = int(di_do_match.group(2))
                end_reg = int(di_do_match.group(3))
                section_name = f"{module_type} MODULES MAPPING"
                self.current_section = section_name
                self.sections[(register_type, section_name)] = (start_reg, end_reg)
                continue

            # Проверка на подсекции модулей (Модуль DI1, DO1 и т.д.) - ПЕРЕД общим паттерном!
            module_subsection_match = re.match(r'//\s+Модуль\s+(DI|DO)(\d+)\s*\((\d+)-(\d+)\):\s*(.+)', line)
            if module_subsection_match:
                module_type = module_subsection_match.group(1)
                module_num = module_subsection_match.group(2)
                start_reg = int(module_subsection_match.group(3))
                end_reg = int(module_subsection_match.group(4))
                description = module_subsection_match.group(5)
                section_name = f"Модуль {module_type}{module_num}: {description}"
                self.current_section = section_name
                self.sections[(register_type, section_name)] = (start_reg, end_reg)
                continue

            # Проверка на секцию оборудования (стандартный формат - общий паттерн)
            section_match = re.match(r'//\s+(.+?)\s*\((\d+)-(\d+)\)', line)
            if section_match:
                section_name = section_match.group(1)
                start_reg = int(section_match.group(2))
                end_reg = int(section_match.group(3))
                self.current_section = section_name
                self.sections[(register_type, section_name)] = (start_reg, end_reg)
                continue

            # Парсинг вызовов функций FC_ModbusRead/Write
            self._parse_function_call(line, register_type)

    def _parse_function_call(self, line: str, register_type: str):
        """Парсить вызов функции FC_ModbusRead/WriteBool/Real/Int"""

        # FC_ModbusReadBool / FC_ModbusWriteBool
        bool_pattern = r'FC_Modbus(?:Read|Write)Bool\(\s*pRegisters\s*:=\s*ADR\((\w+)\).*?iRegisterIndex\s*:=\s*(\d+).*?iBitIndex\s*:=\s*(\d+).*?xValue\s*(?:=>|:=)\s*(.+?)\)'
        match = re.search(bool_pattern, line, re.DOTALL)
        if match:
            reg_array = match.group(1)
            reg_index = int(match.group(2))
            bit_index = int(match.group(3))
            variable = match.group(4).strip().rstrip(');')

            # Проверка типа регистра по имени массива
            if self._matches_register_type(reg_array, register_type):
                reg = ModbusRegister(
                    register_type=register_type,
                    register_address=reg_index,
                    bit_index=bit_index,
                    data_type='BOOL',
                    variable_name=variable,
                    section_name=self.current_section
                )
                self.registers.append(reg)
            return

        # FC_ModbusReadReal / FC_ModbusWriteReal
        real_pattern = r'FC_Modbus(?:Read|Write)Real\(\s*pRegisters\s*:=\s*ADR\((\w+)\).*?iRegisterIndex\s*:=\s*(\d+).*?rValue\s*(?:=>|:=)\s*(.+?)\)'
        match = re.search(real_pattern, line, re.DOTALL)
        if match:
            reg_array = match.group(1)
            reg_index = int(match.group(2))
            variable = match.group(3).strip().rstrip(');')

            if self._matches_register_type(reg_array, register_type):
                reg = ModbusRegister(
                    register_type=register_type,
                    register_address=reg_index,
                    bit_index=None,
                    data_type='REAL',
                    variable_name=variable,
                    section_name=self.current_section
                )
                self.registers.append(reg)
            return

        # FC_ModbusReadInt / FC_ModbusWriteInt
        int_pattern = r'FC_Modbus(?:Read|Write)Int\(\s*pRegisters\s*:=\s*ADR\((\w+)\).*?iRegisterIndex\s*:=\s*(\d+).*?nValue\s*(?:=>|:=)\s*(.+?)\)'
        match = re.search(int_pattern, line, re.DOTALL)
        if match:
            reg_array = match.group(1)
            reg_index = int(match.group(2))
            variable = match.group(3).strip().rstrip(');')

            if self._matches_register_type(reg_array, register_type):
                reg = ModbusRegister(
                    register_type=register_type,
                    register_address=reg_index,
                    bit_index=None,
                    data_type='INT',
                    variable_name=variable,
                    section_name=self.current_section
                )
                self.registers.append(reg)
            return

    def _matches_register_type(self, array_name: str, register_type: str) -> bool:
        """Проверка соответствия массива типу регистра"""
        if register_type == 'holding_registers':
            return 'Holding' in array_name
        elif register_type == 'input_registers':
            return 'Input' in array_name
        return False


class DatabaseMigrator:
    """Класс для миграции данных в SQLite"""

    def __init__(self, db_path: Path, schema_path: Path):
        self.db_path = db_path
        self.schema_path = schema_path
        self.conn: Optional[sqlite3.Connection] = None

    def initialize_database(self):
        """Создать БД из schema.sql"""
        if self.db_path.exists():
            print(f"⚠️  База данных {self.db_path} уже существует")
            response = input("Удалить и пересоздать? (y/N): ")
            if response.lower() != 'y':
                print("Отменено.")
                return False
            self.db_path.unlink()

        # Создать БД
        self.conn = sqlite3.connect(self.db_path)

        # Выполнить schema.sql
        with open(self.schema_path, 'r', encoding='utf-8') as f:
            schema_sql = f.read()

        self.conn.executescript(schema_sql)
        self.conn.commit()
        print(f"✅ База данных создана: {self.db_path}")
        return True

    def migrate_sections(self, sections: Dict[Tuple[str, str], Tuple[int, int]]):
        """Мигрировать секции в БД"""
        cursor = self.conn.cursor()

        for (reg_type, section_name), (start_reg, end_reg) in sections.items():
            # Получить register_type_id
            cursor.execute("SELECT id FROM register_types WHERE name = ?", (reg_type,))
            row = cursor.fetchone()
            if not row:
                print(f"⚠️  Неизвестный тип регистра: {reg_type}")
                continue
            register_type_id = row[0]

            # Вставить секцию
            try:
                cursor.execute("""
                    INSERT INTO sections (register_type_id, name, start_register, end_register)
                    VALUES (?, ?, ?, ?)
                """, (register_type_id, section_name, start_reg, end_reg))
            except sqlite3.IntegrityError:
                print(f"⚠️  Секция '{section_name}' уже существует, пропуск")

        self.conn.commit()
        print(f"✅ Мигрировано секций: {len(sections)}")

    def migrate_registers(self, registers: List[ModbusRegister], verbose: bool = False):
        """Мигрировать регистры в БД"""
        cursor = self.conn.cursor()
        inserted_count = 0
        skipped_count = 0
        descriptions_found = 0
        descriptions_missing = 0
        missing_vars = []

        for reg in registers:
            # Получить register_type_id
            cursor.execute("SELECT id FROM register_types WHERE name = ?", (reg.register_type,))
            row = cursor.fetchone()
            if not row:
                print(f"⚠️  Неизвестный тип регистра: {reg.register_type}")
                continue
            register_type_id = row[0]

            # Получить data_type_id
            cursor.execute("SELECT id FROM data_types WHERE name = ?", (reg.data_type,))
            row = cursor.fetchone()
            if not row:
                print(f"⚠️  Неизвестный тип данных: {reg.data_type}")
                continue
            data_type_id = row[0]

            # Получить section_id
            cursor.execute("""
                SELECT id FROM sections
                WHERE register_type_id = ? AND name = ?
            """, (register_type_id, reg.section_name))
            row = cursor.fetchone()
            if not row:
                # Секция не найдена, создать дефолтную
                cursor.execute("""
                    INSERT INTO sections (register_type_id, name, start_register, end_register)
                    VALUES (?, ?, 0, 65535)
                """, (register_type_id, 'Неопределенная секция'))
                section_id = cursor.lastrowid
            else:
                section_id = row[0]

            # Подсчет статистики описаний
            if reg.description:
                descriptions_found += 1
            else:
                descriptions_missing += 1
                missing_vars.append(reg.variable_name)

            # Вставить регистр
            try:
                cursor.execute("""
                    INSERT INTO registers (
                        register_type_id, section_id, register_address, bit_index,
                        data_type_id, variable_name, description
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    register_type_id, section_id, reg.register_address, reg.bit_index,
                    data_type_id, reg.variable_name, reg.description
                ))
                inserted_count += 1
            except sqlite3.IntegrityError as e:
                skipped_count += 1
                # print(f"⚠️  Дубликат: {reg.variable_name} @ {reg.register_address}.{reg.bit_index}")

        self.conn.commit()
        print(f"✅ Вставлено регистров: {inserted_count}")
        if skipped_count > 0:
            print(f"⚠️  Пропущено дубликатов: {skipped_count}")

        # Статистика описаний
        total_descriptions = descriptions_found + descriptions_missing
        if total_descriptions > 0:
            coverage_percent = (descriptions_found / total_descriptions) * 100
            print(f"\n📝 Статистика описаний:")
            print(f"   Найдено описаний: {descriptions_found}/{total_descriptions} ({coverage_percent:.1f}%)")
            if descriptions_missing > 0:
                print(f"   Без описаний: {descriptions_missing}")
                if verbose and missing_vars:
                    print(f"\n⚠️  Переменные без описаний:")
                    for var in missing_vars[:20]:  # Показать первые 20
                        print(f"      - {var}")
                    if len(missing_vars) > 20:
                        print(f"      ... и еще {len(missing_vars) - 20}")

    def close(self):
        """Закрыть соединение с БД"""
        if self.conn:
            self.conn.close()


def main(verbose: bool = False):
    """Главная функция"""
    print("=" * 60)
    print("Modbus Register Migration Tool")
    print("=" * 60)

    # Проверка наличия файлов
    if not FC_MODBUS_PATH.exists():
        print(f"❌ Файл не найден: {FC_MODBUS_PATH}")
        return

    if not SCHEMA_PATH.exists():
        print(f"❌ Файл схемы не найден: {SCHEMA_PATH}")
        return

    # Парсинг FC_ModbusToSCADA.st
    print(f"\n📄 Парсинг файла: {FC_MODBUS_PATH.name}")
    parser = FC_ModbusParser(FC_MODBUS_PATH)
    registers = parser.parse()
    sections = parser.sections

    print(f"   Найдено секций: {len(sections)}")
    print(f"   Найдено регистров: {len(registers)}")

    # Миграция в БД
    print(f"\n💾 Миграция в базу данных...")
    migrator = DatabaseMigrator(DB_PATH, SCHEMA_PATH)

    if not migrator.initialize_database():
        return

    migrator.migrate_sections(sections)
    migrator.migrate_registers(registers, verbose=verbose)
    migrator.close()

    print(f"\n✅ Миграция завершена успешно!")
    print(f"   База данных: {DB_PATH}")
    print("=" * 60)


if __name__ == '__main__':
    # Проверка аргументов командной строки
    verbose = '--verbose' in sys.argv or '-v' in sys.argv
    main(verbose=verbose)
