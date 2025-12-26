#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modbus Register CLI Manager
============================
Интерактивное терминальное приложение для управления базой данных Modbus регистров.

Функции:
- Просмотр регистров (с фильтрацией и поиском)
- Добавление новых регистров
- Редактирование регистров
- Удаление регистров
- Экспорт в Excel
- Статистика по БД

Использование:
    ./modbus_cli.sh
    или
    python3 modbus_cli.py

Требования:
    pip install openpyxl

Автор: Claude Code
Дата: 2025-12-26
"""

import sqlite3
import sys
from pathlib import Path
from typing import Optional, List, Dict, Any
import subprocess
import os


# Пути к файлам
SCRIPT_DIR = Path(__file__).parent
DB_PATH = SCRIPT_DIR / 'db' / 'modbus_registers.db'
EXPORT_SCRIPT = SCRIPT_DIR / 'export_to_excel.py'


class Colors:
    """ANSI цвета для терминала"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class ModbusCLI:
    """Интерактивное CLI для управления Modbus регистрами"""

    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.conn = None
        self.connect_db()

    def connect_db(self):
        """Подключение к базе данных"""
        if not self.db_path.exists():
            print(f"{Colors.FAIL}❌ База данных не найдена: {self.db_path}{Colors.ENDC}")
            print(f"{Colors.WARNING}   Создайте БД с помощью: python3 migrate_from_fc.py{Colors.ENDC}")
            sys.exit(1)

        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        # Включить поддержку внешних ключей
        self.conn.execute("PRAGMA foreign_keys = ON")

    def close_db(self):
        """Закрыть подключение к БД"""
        if self.conn:
            self.conn.close()

    def clear_screen(self):
        """Очистить экран"""
        os.system('clear' if os.name != 'nt' else 'cls')

    def print_header(self, text: str):
        """Печать заголовка"""
        print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 70}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}{text.center(70)}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 70}{Colors.ENDC}\n")

    def print_menu(self, title: str, options: List[str]):
        """Печать меню"""
        print(f"\n{Colors.BOLD}{Colors.OKCYAN}{title}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}{'-' * len(title)}{Colors.ENDC}")
        for i, option in enumerate(options, 1):
            print(f"{Colors.OKBLUE}{i}.{Colors.ENDC} {option}")
        print(f"{Colors.OKBLUE}0.{Colors.ENDC} {Colors.WARNING}Выход{Colors.ENDC}")

    def get_choice(self, max_option: int) -> int:
        """Получить выбор пользователя"""
        while True:
            try:
                choice = input(f"\n{Colors.BOLD}Выберите действие [0-{max_option}]: {Colors.ENDC}").strip()
                choice_int = int(choice)
                if 0 <= choice_int <= max_option:
                    return choice_int
                else:
                    print(f"{Colors.FAIL}❌ Введите число от 0 до {max_option}{Colors.ENDC}")
            except ValueError:
                print(f"{Colors.FAIL}❌ Введите корректное число{Colors.ENDC}")
            except KeyboardInterrupt:
                print(f"\n{Colors.WARNING}Выход...{Colors.ENDC}")
                return 0

    def pause(self):
        """Пауза перед продолжением"""
        input(f"\n{Colors.OKCYAN}Нажмите Enter для продолжения...{Colors.ENDC}")

    # ========================================================================
    # ГЛАВНОЕ МЕНЮ
    # ========================================================================

    def main_menu(self):
        """Главное меню"""
        while True:
            self.clear_screen()
            self.print_header("MODBUS REGISTER DATABASE MANAGER")

            options = [
                "📋 Просмотр регистров",
                "➕ Добавить регистр",
                "✏️  Редактировать регистр",
                "🗑️  Удалить регистр",
                "🔍 Поиск регистров",
                "📊 Статистика БД",
                "📤 Экспорт в Excel",
                "🔧 Управление секциями"
            ]

            self.print_menu("Главное меню", options)
            choice = self.get_choice(len(options))

            if choice == 0:
                self.exit_program()
            elif choice == 1:
                self.view_registers_menu()
            elif choice == 2:
                self.add_register()
            elif choice == 3:
                self.edit_register()
            elif choice == 4:
                self.delete_register()
            elif choice == 5:
                self.search_registers()
            elif choice == 6:
                self.show_statistics()
            elif choice == 7:
                self.export_to_excel()
            elif choice == 8:
                self.sections_menu()

    # ========================================================================
    # ПРОСМОТР РЕГИСТРОВ
    # ========================================================================

    def view_registers_menu(self):
        """Меню просмотра регистров"""
        while True:
            self.clear_screen()
            self.print_header("ПРОСМОТР РЕГИСТРОВ")

            options = [
                "Все регистры",
                "Holding Registers (SCADA → PLC)",
                "Input Registers (PLC → SCADA)",
                "По секции",
                "По типу данных"
            ]

            self.print_menu("Выберите фильтр", options)
            choice = self.get_choice(len(options))

            if choice == 0:
                return
            elif choice == 1:
                self.view_registers()
            elif choice == 2:
                self.view_registers(register_type='holding_registers')
            elif choice == 3:
                self.view_registers(register_type='input_registers')
            elif choice == 4:
                self.view_registers_by_section()
            elif choice == 5:
                self.view_registers_by_datatype()

    def view_registers(self, register_type: Optional[str] = None,
                      section_id: Optional[int] = None,
                      data_type_id: Optional[int] = None,
                      limit: int = 50):
        """Просмотр регистров с фильтрацией"""
        self.clear_screen()

        # Построить запрос
        query = """
            SELECT
                r.id,
                r.register_address,
                r.bit_index,
                dt.name AS data_type,
                r.variable_name,
                r.description,
                s.name AS section,
                rt.name AS register_type
            FROM registers r
            JOIN data_types dt ON r.data_type_id = dt.id
            JOIN sections s ON r.section_id = s.id
            JOIN register_types rt ON r.register_type_id = rt.id
            WHERE 1=1
        """
        params = []

        if register_type:
            query += " AND rt.name = ?"
            params.append(register_type)

        if section_id:
            query += " AND r.section_id = ?"
            params.append(section_id)

        if data_type_id:
            query += " AND r.data_type_id = ?"
            params.append(data_type_id)

        query += " ORDER BY r.register_address, r.bit_index LIMIT ?"
        params.append(limit)

        cursor = self.conn.cursor()
        cursor.execute(query, params)
        rows = cursor.fetchall()

        if not rows:
            print(f"{Colors.WARNING}📭 Регистры не найдены{Colors.ENDC}")
            self.pause()
            return

        # Заголовок таблицы
        title = "ВСЕ РЕГИСТРЫ"
        if register_type == 'holding_registers':
            title = "HOLDING REGISTERS (SCADA → PLC)"
        elif register_type == 'input_registers':
            title = "INPUT REGISTERS (PLC → SCADA)"

        self.print_header(title)
        print(f"{Colors.OKCYAN}Найдено регистров: {len(rows)}{Colors.ENDC}")

        # Печать таблицы
        print(f"\n{Colors.BOLD}{'ID':<5} {'Адрес':<12} {'Тип':<8} {'Переменная':<30} {'Секция':<25}{Colors.ENDC}")
        print(f"{Colors.BOLD}{'-' * 95}{Colors.ENDC}")

        for row in rows:
            # Форматирование адреса
            if row['data_type'] == 'BOOL':
                address = f"{row['register_address']}.{row['bit_index']}"
            else:
                address = str(row['register_address'])

            # Цвет по типу данных
            if row['data_type'] == 'BOOL':
                color = Colors.OKCYAN
            elif row['data_type'] == 'REAL':
                color = Colors.OKGREEN
            else:
                color = Colors.ENDC

            print(f"{color}{row['id']:<5} {address:<12} {row['data_type']:<8} "
                  f"{row['variable_name']:<30} {row['section']:<25}{Colors.ENDC}")

        if len(rows) == limit:
            print(f"\n{Colors.WARNING}⚠️  Показано первых {limit} записей{Colors.ENDC}")

        self.pause()

    def view_registers_by_section(self):
        """Просмотр регистров по секции"""
        sections = self.get_sections()

        if not sections:
            print(f"{Colors.WARNING}📭 Секции не найдены{Colors.ENDC}")
            self.pause()
            return

        self.clear_screen()
        self.print_header("ВЫБОР СЕКЦИИ")

        print(f"\n{Colors.BOLD}{'ID':<5} {'Название секции':<40} {'Диапазон':<15}{Colors.ENDC}")
        print(f"{Colors.BOLD}{'-' * 65}{Colors.ENDC}")

        for i, section in enumerate(sections, 1):
            print(f"{i:<5} {section['name']:<40} {section['start_register']}-{section['end_register']}")

        choice = self.get_choice(len(sections))
        if choice == 0:
            return

        selected = sections[choice - 1]
        self.view_registers(section_id=selected['id'])

    def view_registers_by_datatype(self):
        """Просмотр регистров по типу данных"""
        datatypes = self.get_datatypes()

        self.clear_screen()
        self.print_header("ВЫБОР ТИПА ДАННЫХ")

        for i, dt in enumerate(datatypes, 1):
            print(f"{i}. {dt['name']}")

        choice = self.get_choice(len(datatypes))
        if choice == 0:
            return

        selected = datatypes[choice - 1]
        self.view_registers(data_type_id=selected['id'])

    # ========================================================================
    # ДОБАВЛЕНИЕ РЕГИСТРА
    # ========================================================================

    def add_register(self):
        """Добавить новый регистр"""
        self.clear_screen()
        self.print_header("ДОБАВЛЕНИЕ НОВОГО РЕГИСТРА")

        try:
            # 1. Выбор типа регистра
            register_type_id = self.select_register_type()
            if not register_type_id:
                return

            # 2. Выбор секции
            section_id = self.select_section(register_type_id)
            if not section_id:
                return

            # 3. Выбор типа данных
            data_type_id = self.select_datatype()
            if not data_type_id:
                return

            # Проверка, является ли это BOOL
            cursor = self.conn.cursor()
            cursor.execute("SELECT name FROM data_types WHERE id = ?", (data_type_id,))
            data_type_name = cursor.fetchone()['name']
            is_bool = (data_type_name == 'BOOL')

            # 4. Ввод адреса регистра
            register_address = self.input_int("Введите адрес регистра", min_val=0)
            if register_address is None:
                return

            # 5. Ввод бит-индекса (только для BOOL)
            bit_index = None
            if is_bool:
                bit_index = self.input_int("Введите бит-индекс [0-15]", min_val=0, max_val=15)
                if bit_index is None:
                    return

            # 6. Ввод имени переменной
            variable_name = input(f"{Colors.BOLD}Введите имя переменной PLC: {Colors.ENDC}").strip()
            if not variable_name:
                print(f"{Colors.FAIL}❌ Имя переменной не может быть пустым{Colors.ENDC}")
                self.pause()
                return

            # 7. Ввод описания (опционально)
            description = input(f"{Colors.BOLD}Введите описание (Enter для пропуска): {Colors.ENDC}").strip()
            if not description:
                description = None

            # 8. Вставка в БД
            cursor.execute("""
                INSERT INTO registers (
                    register_type_id, section_id, register_address, bit_index,
                    data_type_id, variable_name, description
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (register_type_id, section_id, register_address, bit_index,
                  data_type_id, variable_name, description))

            self.conn.commit()

            print(f"\n{Colors.OKGREEN}✅ Регистр успешно добавлен!{Colors.ENDC}")
            print(f"{Colors.OKCYAN}   ID: {cursor.lastrowid}{Colors.ENDC}")

        except sqlite3.IntegrityError as e:
            print(f"\n{Colors.FAIL}❌ Ошибка: регистр с таким адресом уже существует{Colors.ENDC}")
            print(f"{Colors.FAIL}   {e}{Colors.ENDC}")
        except Exception as e:
            print(f"\n{Colors.FAIL}❌ Ошибка при добавлении: {e}{Colors.ENDC}")

        self.pause()

    # ========================================================================
    # РЕДАКТИРОВАНИЕ РЕГИСТРА
    # ========================================================================

    def edit_register(self):
        """Редактировать существующий регистр"""
        self.clear_screen()
        self.print_header("РЕДАКТИРОВАНИЕ РЕГИСТРА")

        # Ввод ID регистра
        register_id = self.input_int("Введите ID регистра для редактирования", min_val=1)
        if register_id is None:
            return

        # Получить текущие данные
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT
                r.*,
                dt.name AS data_type,
                s.name AS section,
                rt.name AS register_type
            FROM registers r
            JOIN data_types dt ON r.data_type_id = dt.id
            JOIN sections s ON r.section_id = s.id
            JOIN register_types rt ON r.register_type_id = rt.id
            WHERE r.id = ?
        """, (register_id,))

        register = cursor.fetchone()
        if not register:
            print(f"{Colors.FAIL}❌ Регистр с ID {register_id} не найден{Colors.ENDC}")
            self.pause()
            return

        # Показать текущие данные
        print(f"\n{Colors.BOLD}Текущие данные регистра:{Colors.ENDC}")
        print(f"{Colors.OKCYAN}ID:          {register['id']}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Адрес:       {register['register_address']}"
              f"{f'.{register["bit_index"]}' if register["bit_index"] is not None else ''}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Тип данных:  {register['data_type']}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Переменная:  {register['variable_name']}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Описание:    {register['description'] or '(нет)'}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Секция:      {register['section']}{Colors.ENDC}")

        # Меню редактирования
        print(f"\n{Colors.BOLD}Что изменить?{Colors.ENDC}")
        options = [
            "Имя переменной",
            "Описание",
            "Удалить описание"
        ]

        for i, opt in enumerate(options, 1):
            print(f"{i}. {opt}")

        choice = self.get_choice(len(options))
        if choice == 0:
            return

        try:
            if choice == 1:
                # Изменить имя переменной
                new_name = input(f"{Colors.BOLD}Новое имя переменной [{register['variable_name']}]: {Colors.ENDC}").strip()
                if new_name:
                    cursor.execute("UPDATE registers SET variable_name = ? WHERE id = ?",
                                 (new_name, register_id))
                    self.conn.commit()
                    print(f"{Colors.OKGREEN}✅ Имя переменной обновлено{Colors.ENDC}")

            elif choice == 2:
                # Изменить описание
                new_desc = input(f"{Colors.BOLD}Новое описание [{register['description'] or ''}]: {Colors.ENDC}").strip()
                cursor.execute("UPDATE registers SET description = ? WHERE id = ?",
                             (new_desc if new_desc else None, register_id))
                self.conn.commit()
                print(f"{Colors.OKGREEN}✅ Описание обновлено{Colors.ENDC}")

            elif choice == 3:
                # Удалить описание
                cursor.execute("UPDATE registers SET description = NULL WHERE id = ?", (register_id,))
                self.conn.commit()
                print(f"{Colors.OKGREEN}✅ Описание удалено{Colors.ENDC}")

        except Exception as e:
            print(f"{Colors.FAIL}❌ Ошибка при обновлении: {e}{Colors.ENDC}")

        self.pause()

    # ========================================================================
    # УДАЛЕНИЕ РЕГИСТРА
    # ========================================================================

    def delete_register(self):
        """Удалить регистр"""
        self.clear_screen()
        self.print_header("УДАЛЕНИЕ РЕГИСТРА")

        # Ввод ID регистра
        register_id = self.input_int("Введите ID регистра для удаления", min_val=1)
        if register_id is None:
            return

        # Получить данные регистра
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT
                r.*,
                dt.name AS data_type,
                s.name AS section
            FROM registers r
            JOIN data_types dt ON r.data_type_id = dt.id
            JOIN sections s ON r.section_id = s.id
            WHERE r.id = ?
        """, (register_id,))

        register = cursor.fetchone()
        if not register:
            print(f"{Colors.FAIL}❌ Регистр с ID {register_id} не найден{Colors.ENDC}")
            self.pause()
            return

        # Показать данные
        print(f"\n{Colors.WARNING}⚠️  ВНИМАНИЕ! Вы собираетесь удалить регистр:{Colors.ENDC}")
        print(f"{Colors.OKCYAN}ID:          {register['id']}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Адрес:       {register['register_address']}"
              f"{f'.{register["bit_index"]}' if register["bit_index"] is not None else ''}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Переменная:  {register['variable_name']}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Секция:      {register['section']}{Colors.ENDC}")

        # Подтверждение
        confirm = input(f"\n{Colors.FAIL}{Colors.BOLD}Подтвердите удаление (YES/no): {Colors.ENDC}").strip()
        if confirm.upper() != 'YES':
            print(f"{Colors.WARNING}Удаление отменено{Colors.ENDC}")
            self.pause()
            return

        try:
            cursor.execute("DELETE FROM registers WHERE id = ?", (register_id,))
            self.conn.commit()
            print(f"\n{Colors.OKGREEN}✅ Регистр успешно удалён{Colors.ENDC}")
        except Exception as e:
            print(f"\n{Colors.FAIL}❌ Ошибка при удалении: {e}{Colors.ENDC}")

        self.pause()

    # ========================================================================
    # ПОИСК РЕГИСТРОВ
    # ========================================================================

    def search_registers(self):
        """Поиск регистров"""
        self.clear_screen()
        self.print_header("ПОИСК РЕГИСТРОВ")

        search_term = input(f"{Colors.BOLD}Введите текст для поиска (имя переменной или описание): {Colors.ENDC}").strip()
        if not search_term:
            return

        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT
                r.id,
                r.register_address,
                r.bit_index,
                dt.name AS data_type,
                r.variable_name,
                r.description,
                s.name AS section
            FROM registers r
            JOIN data_types dt ON r.data_type_id = dt.id
            JOIN sections s ON r.section_id = s.id
            WHERE r.variable_name LIKE ? OR r.description LIKE ?
            ORDER BY r.register_address, r.bit_index
            LIMIT 100
        """, (f'%{search_term}%', f'%{search_term}%'))

        rows = cursor.fetchall()

        if not rows:
            print(f"\n{Colors.WARNING}📭 Регистры не найдены{Colors.ENDC}")
            self.pause()
            return

        print(f"\n{Colors.OKGREEN}Найдено регистров: {len(rows)}{Colors.ENDC}")
        print(f"\n{Colors.BOLD}{'ID':<5} {'Адрес':<12} {'Тип':<8} {'Переменная':<30} {'Описание':<30}{Colors.ENDC}")
        print(f"{Colors.BOLD}{'-' * 100}{Colors.ENDC}")

        for row in rows:
            # Форматирование адреса
            if row['data_type'] == 'BOOL':
                address = f"{row['register_address']}.{row['bit_index']}"
            else:
                address = str(row['register_address'])

            desc = (row['description'] or '')[:30]
            print(f"{row['id']:<5} {address:<12} {row['data_type']:<8} "
                  f"{row['variable_name']:<30} {desc:<30}")

        self.pause()

    # ========================================================================
    # СТАТИСТИКА
    # ========================================================================

    def show_statistics(self):
        """Показать статистику БД"""
        self.clear_screen()
        self.print_header("СТАТИСТИКА БАЗЫ ДАННЫХ")

        cursor = self.conn.cursor()

        # Общая статистика
        cursor.execute("SELECT COUNT(*) as count FROM registers")
        total_registers = cursor.fetchone()['count']

        cursor.execute("SELECT COUNT(DISTINCT section_id) as count FROM registers")
        total_sections = cursor.fetchone()['count']

        print(f"{Colors.BOLD}Общая статистика:{Colors.ENDC}")
        print(f"{Colors.OKCYAN}  Всего регистров:  {total_registers}{Colors.ENDC}")
        print(f"{Colors.OKCYAN}  Всего секций:     {total_sections}{Colors.ENDC}")

        # Статистика по типам регистров
        print(f"\n{Colors.BOLD}По типам регистров:{Colors.ENDC}")
        cursor.execute("""
            SELECT rt.name, rt.description_ru, COUNT(*) as count
            FROM registers r
            JOIN register_types rt ON r.register_type_id = rt.id
            GROUP BY rt.name
        """)
        for row in cursor.fetchall():
            print(f"{Colors.OKGREEN}  {row['description_ru']:<30} {row['count']:>5}{Colors.ENDC}")

        # Статистика по типам данных
        print(f"\n{Colors.BOLD}По типам данных:{Colors.ENDC}")
        cursor.execute("""
            SELECT dt.name, COUNT(*) as count
            FROM registers r
            JOIN data_types dt ON r.data_type_id = dt.id
            GROUP BY dt.name
            ORDER BY count DESC
        """)
        for row in cursor.fetchall():
            print(f"{Colors.OKCYAN}  {row['name']:<15} {row['count']:>5}{Colors.ENDC}")

        # Топ секций
        print(f"\n{Colors.BOLD}Топ-10 секций по количеству регистров:{Colors.ENDC}")
        cursor.execute("""
            SELECT s.name, COUNT(*) as count
            FROM registers r
            JOIN sections s ON r.section_id = s.id
            GROUP BY s.name
            ORDER BY count DESC
            LIMIT 10
        """)
        for i, row in enumerate(cursor.fetchall(), 1):
            print(f"{Colors.OKBLUE}  {i:>2}. {row['name']:<45} {row['count']:>5}{Colors.ENDC}")

        self.pause()

    # ========================================================================
    # ЭКСПОРТ В EXCEL
    # ========================================================================

    def export_to_excel(self):
        """Экспорт в Excel"""
        self.clear_screen()
        self.print_header("ЭКСПОРТ В EXCEL")

        if not EXPORT_SCRIPT.exists():
            print(f"{Colors.FAIL}❌ Скрипт экспорта не найден: {EXPORT_SCRIPT}{Colors.ENDC}")
            self.pause()
            return

        print(f"{Colors.OKCYAN}Запуск экспорта в Excel...{Colors.ENDC}\n")

        try:
            result = subprocess.run(
                [sys.executable, str(EXPORT_SCRIPT)],
                cwd=str(SCRIPT_DIR),
                capture_output=False,
                text=True
            )

            if result.returncode == 0:
                print(f"\n{Colors.OKGREEN}✅ Экспорт завершён успешно{Colors.ENDC}")
            else:
                print(f"\n{Colors.FAIL}❌ Ошибка при экспорте (код: {result.returncode}){Colors.ENDC}")

        except Exception as e:
            print(f"{Colors.FAIL}❌ Ошибка: {e}{Colors.ENDC}")

        self.pause()

    # ========================================================================
    # УПРАВЛЕНИЕ СЕКЦИЯМИ
    # ========================================================================

    def sections_menu(self):
        """Меню управления секциями"""
        while True:
            self.clear_screen()
            self.print_header("УПРАВЛЕНИЕ СЕКЦИЯМИ")

            options = [
                "Просмотр всех секций",
                "Добавить секцию",
                "Редактировать секцию",
                "Удалить секцию"
            ]

            self.print_menu("Выберите действие", options)
            choice = self.get_choice(len(options))

            if choice == 0:
                return
            elif choice == 1:
                self.view_sections()
            elif choice == 2:
                self.add_section()
            elif choice == 3:
                self.edit_section()
            elif choice == 4:
                self.delete_section()

    def view_sections(self):
        """Просмотр всех секций"""
        self.clear_screen()
        self.print_header("ВСЕ СЕКЦИИ")

        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT
                s.id,
                s.name,
                s.start_register,
                s.end_register,
                s.description,
                rt.description_ru AS register_type,
                COUNT(r.id) as register_count
            FROM sections s
            JOIN register_types rt ON s.register_type_id = rt.id
            LEFT JOIN registers r ON r.section_id = s.id
            GROUP BY s.id
            ORDER BY s.start_register
        """)

        rows = cursor.fetchall()

        if not rows:
            print(f"{Colors.WARNING}📭 Секции не найдены{Colors.ENDC}")
            self.pause()
            return

        print(f"\n{Colors.BOLD}{'ID':<5} {'Название':<40} {'Диапазон':<15} {'Регистров':<12} {'Тип':<20}{Colors.ENDC}")
        print(f"{Colors.BOLD}{'-' * 95}{Colors.ENDC}")

        for row in rows:
            print(f"{row['id']:<5} {row['name']:<40} "
                  f"{row['start_register']}-{row['end_register']:<10} "
                  f"{row['register_count']:<12} {row['register_type']:<20}")

        self.pause()

    def add_section(self):
        """Добавить новую секцию"""
        self.clear_screen()
        self.print_header("ДОБАВЛЕНИЕ СЕКЦИИ")

        try:
            # Выбор типа регистра
            register_type_id = self.select_register_type()
            if not register_type_id:
                return

            # Ввод имени секции
            name = input(f"{Colors.BOLD}Введите название секции: {Colors.ENDC}").strip()
            if not name:
                print(f"{Colors.FAIL}❌ Название не может быть пустым{Colors.ENDC}")
                self.pause()
                return

            # Ввод диапазона
            start_register = self.input_int("Введите начальный адрес", min_val=0)
            if start_register is None:
                return

            end_register = self.input_int("Введите конечный адрес", min_val=start_register)
            if end_register is None:
                return

            # Описание
            description = input(f"{Colors.BOLD}Введите описание (Enter для пропуска): {Colors.ENDC}").strip()
            if not description:
                description = None

            # Вставка
            cursor = self.conn.cursor()
            cursor.execute("""
                INSERT INTO sections (register_type_id, name, start_register, end_register, description)
                VALUES (?, ?, ?, ?, ?)
            """, (register_type_id, name, start_register, end_register, description))

            self.conn.commit()
            print(f"\n{Colors.OKGREEN}✅ Секция успешно добавлена (ID: {cursor.lastrowid}){Colors.ENDC}")

        except sqlite3.IntegrityError:
            print(f"\n{Colors.FAIL}❌ Секция с таким именем уже существует{Colors.ENDC}")
        except Exception as e:
            print(f"\n{Colors.FAIL}❌ Ошибка: {e}{Colors.ENDC}")

        self.pause()

    def edit_section(self):
        """Редактировать секцию"""
        print(f"{Colors.WARNING}TODO: Реализация редактирования секции{Colors.ENDC}")
        self.pause()

    def delete_section(self):
        """Удалить секцию"""
        self.clear_screen()
        self.print_header("УДАЛЕНИЕ СЕКЦИИ")

        section_id = self.input_int("Введите ID секции для удаления", min_val=1)
        if section_id is None:
            return

        cursor = self.conn.cursor()

        # Проверить, есть ли регистры в секции
        cursor.execute("SELECT COUNT(*) as count FROM registers WHERE section_id = ?", (section_id,))
        count = cursor.fetchone()['count']

        if count > 0:
            print(f"\n{Colors.FAIL}❌ Невозможно удалить секцию: в ней {count} регистров{Colors.ENDC}")
            print(f"{Colors.WARNING}   Сначала удалите все регистры из секции{Colors.ENDC}")
            self.pause()
            return

        # Получить данные секции
        cursor.execute("SELECT * FROM sections WHERE id = ?", (section_id,))
        section = cursor.fetchone()

        if not section:
            print(f"{Colors.FAIL}❌ Секция с ID {section_id} не найдена{Colors.ENDC}")
            self.pause()
            return

        print(f"\n{Colors.WARNING}⚠️  Вы собираетесь удалить секцию:{Colors.ENDC}")
        print(f"{Colors.OKCYAN}  {section['name']} ({section['start_register']}-{section['end_register']}){Colors.ENDC}")

        confirm = input(f"\n{Colors.FAIL}Подтвердите (YES/no): {Colors.ENDC}").strip()
        if confirm.upper() != 'YES':
            print(f"{Colors.WARNING}Удаление отменено{Colors.ENDC}")
            self.pause()
            return

        try:
            cursor.execute("DELETE FROM sections WHERE id = ?", (section_id,))
            self.conn.commit()
            print(f"\n{Colors.OKGREEN}✅ Секция успешно удалена{Colors.ENDC}")
        except Exception as e:
            print(f"\n{Colors.FAIL}❌ Ошибка: {e}{Colors.ENDC}")

        self.pause()

    # ========================================================================
    # ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
    # ========================================================================

    def get_register_types(self) -> List[Dict]:
        """Получить типы регистров"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM register_types ORDER BY id")
        return cursor.fetchall()

    def get_sections(self, register_type_id: Optional[int] = None) -> List[Dict]:
        """Получить секции"""
        cursor = self.conn.cursor()
        if register_type_id:
            cursor.execute("""
                SELECT * FROM sections
                WHERE register_type_id = ?
                ORDER BY start_register
            """, (register_type_id,))
        else:
            cursor.execute("SELECT * FROM sections ORDER BY start_register")
        return cursor.fetchall()

    def get_datatypes(self) -> List[Dict]:
        """Получить типы данных"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM data_types ORDER BY id")
        return cursor.fetchall()

    def select_register_type(self) -> Optional[int]:
        """Выбор типа регистра"""
        register_types = self.get_register_types()

        print(f"\n{Colors.BOLD}Выберите тип регистра:{Colors.ENDC}")
        for i, rt in enumerate(register_types, 1):
            print(f"{i}. {rt['description_ru']} ({rt['name']})")

        choice = self.get_choice(len(register_types))
        if choice == 0:
            return None

        return register_types[choice - 1]['id']

    def select_section(self, register_type_id: int) -> Optional[int]:
        """Выбор секции"""
        sections = self.get_sections(register_type_id)

        if not sections:
            print(f"{Colors.WARNING}❌ Секции не найдены для данного типа регистров{Colors.ENDC}")
            self.pause()
            return None

        print(f"\n{Colors.BOLD}Выберите секцию:{Colors.ENDC}")
        for i, section in enumerate(sections, 1):
            print(f"{i}. {section['name']} ({section['start_register']}-{section['end_register']})")

        choice = self.get_choice(len(sections))
        if choice == 0:
            return None

        return sections[choice - 1]['id']

    def select_datatype(self) -> Optional[int]:
        """Выбор типа данных"""
        datatypes = self.get_datatypes()

        print(f"\n{Colors.BOLD}Выберите тип данных:{Colors.ENDC}")
        for i, dt in enumerate(datatypes, 1):
            print(f"{i}. {dt['name']}")

        choice = self.get_choice(len(datatypes))
        if choice == 0:
            return None

        return datatypes[choice - 1]['id']

    def input_int(self, prompt: str, min_val: Optional[int] = None,
                  max_val: Optional[int] = None) -> Optional[int]:
        """Ввод целого числа с валидацией"""
        while True:
            try:
                value_str = input(f"{Colors.BOLD}{prompt}: {Colors.ENDC}").strip()
                if not value_str:
                    return None

                value = int(value_str)

                if min_val is not None and value < min_val:
                    print(f"{Colors.FAIL}❌ Значение должно быть >= {min_val}{Colors.ENDC}")
                    continue

                if max_val is not None and value > max_val:
                    print(f"{Colors.FAIL}❌ Значение должно быть <= {max_val}{Colors.ENDC}")
                    continue

                return value

            except ValueError:
                print(f"{Colors.FAIL}❌ Введите корректное число{Colors.ENDC}")
            except KeyboardInterrupt:
                print(f"\n{Colors.WARNING}Отмена{Colors.ENDC}")
                return None

    def exit_program(self):
        """Выход из программы"""
        self.clear_screen()
        print(f"\n{Colors.OKGREEN}{'=' * 70}{Colors.ENDC}")
        print(f"{Colors.OKGREEN}Спасибо за использование Modbus Register Manager!{Colors.ENDC}")
        print(f"{Colors.OKGREEN}{'=' * 70}{Colors.ENDC}\n")
        self.close_db()
        sys.exit(0)


# ============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================================================

def main():
    """Главная функция"""
    try:
        cli = ModbusCLI(DB_PATH)
        cli.main_menu()
    except KeyboardInterrupt:
        print(f"\n\n{Colors.WARNING}Программа прервана пользователем{Colors.ENDC}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Colors.FAIL}❌ Критическая ошибка: {e}{Colors.ENDC}")
        sys.exit(1)


if __name__ == '__main__':
    main()
