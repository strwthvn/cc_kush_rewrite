#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modbus Register Migration Tool
================================
Парсит файл FC_ModbusToSCADA.st и заполняет SQLite базу данных.

Использование:
    python migrate_from_fc.py

Автор: Claude Code
Дата: 2025-12-12
"""

import re
import sqlite3
import os
from pathlib import Path
from typing import List, Tuple, Optional, Dict

# Пути к файлам
SCRIPT_DIR = Path(__file__).parent
DB_PATH = SCRIPT_DIR / 'db' / 'modbus_registers.db'
SCHEMA_PATH = SCRIPT_DIR / 'db' / 'schema.sql'
FC_MODBUS_PATH = SCRIPT_DIR.parent / 'POUs' / 'FC_ModbusToSCADA.st'


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
        self.description = ''


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

    def migrate_registers(self, registers: List[ModbusRegister]):
        """Мигрировать регистры в БД"""
        cursor = self.conn.cursor()
        inserted_count = 0
        skipped_count = 0

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

    def close(self):
        """Закрыть соединение с БД"""
        if self.conn:
            self.conn.close()


def main():
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
    migrator.migrate_registers(registers)
    migrator.close()

    print(f"\n✅ Миграция завершена успешно!")
    print(f"   База данных: {DB_PATH}")
    print("=" * 60)


if __name__ == '__main__':
    main()
