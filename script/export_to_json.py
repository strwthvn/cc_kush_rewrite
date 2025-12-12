#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modbus Register JSON Exporter
==============================
Экспортирует данные из SQLite БД в JSON формат (modbus_map.json).

Использование:
    python3 export_to_json.py

Автор: Claude Code
Дата: 2025-12-12
"""

import json
import sqlite3
from pathlib import Path
from typing import Dict, List, Any


# Пути к файлам
SCRIPT_DIR = Path(__file__).parent
DB_PATH = SCRIPT_DIR / 'db' / 'modbus_registers.db'
JSON_OUTPUT_PATH = SCRIPT_DIR / 'modbus_map.json'


class JSONExporter:
    """Экспорт данных из БД в JSON"""

    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row  # Доступ к колонкам по имени

    def export(self) -> Dict[str, Any]:
        """Экспортировать данные в JSON структуру"""
        result = {}

        # Получить все типы регистров
        cursor = self.conn.cursor()
        cursor.execute("SELECT id, name, description_ru FROM register_types ORDER BY id")
        register_types = cursor.fetchall()

        for reg_type in register_types:
            type_id = reg_type['id']
            type_name = reg_type['name']
            type_desc = reg_type['description_ru']

            # Получить все регистры этого типа
            cursor.execute("""
                SELECT
                    s.name AS section,
                    r.register_address,
                    r.bit_index,
                    dt.name AS data_type,
                    dt.register_count,
                    r.variable_name,
                    r.description
                FROM registers r
                JOIN data_types dt ON r.data_type_id = dt.id
                JOIN sections s ON r.section_id = s.id
                WHERE r.register_type_id = ?
                ORDER BY r.register_address, r.bit_index
            """, (type_id,))

            registers = []
            for row in cursor.fetchall():
                # Форматировать адрес
                if row['data_type'] == 'BOOL':
                    address = f"{row['register_address']}.{row['bit_index']}"
                elif row['register_count'] == 2:
                    address = f"{row['register_address']}-{row['register_address'] + 1}"
                else:
                    address = str(row['register_address'])

                register_entry = {
                    "section": row['section'],
                    "address": address,
                    "data_type": row['data_type'],
                    "variable": row['variable_name'],
                    "description": row['description'] or ""
                }
                registers.append(register_entry)

            result[type_name] = {
                "description": type_desc,
                "registers": registers
            }

        return result

    def close(self):
        """Закрыть соединение с БД"""
        self.conn.close()


def main():
    """Главная функция"""
    print("=" * 60)
    print("Modbus Register JSON Exporter")
    print("=" * 60)

    # Проверка наличия БД
    if not DB_PATH.exists():
        print(f"❌ База данных не найдена: {DB_PATH}")
        print("   Сначала выполните: python3 migrate_from_fc.py")
        return

    # Экспорт данных
    print(f"\n📤 Экспорт из базы данных: {DB_PATH.name}")
    exporter = JSONExporter(DB_PATH)
    data = exporter.export()
    exporter.close()

    # Подсчёт статистики
    total_registers = sum(len(rt['registers']) for rt in data.values())
    print(f"   Экспортировано регистров: {total_registers}")

    # Сохранить в JSON
    print(f"\n💾 Сохранение в файл: {JSON_OUTPUT_PATH.name}")
    with open(JSON_OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Экспорт завершён успешно!")
    print(f"   Файл: {JSON_OUTPUT_PATH}")
    print("=" * 60)


if __name__ == '__main__':
    main()
