#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для конвертации MODBUS_MAP.md в CSV формат
Парсит markdown таблицы и сохраняет в отдельные CSV файлы
"""

import re
import csv
import os
from pathlib import Path


def parse_markdown_table(lines, start_idx):
    """
    Парсит одну markdown таблицу начиная с индекса start_idx
    Возвращает: (headers, rows, next_idx)
    """
    headers = []
    rows = []

    # Найти строку заголовка
    i = start_idx
    while i < len(lines):
        line = lines[i].strip()

        # Пропустить пустые строки
        if not line:
            i += 1
            continue

        # Проверить, является ли это строкой таблицы
        if not line.startswith('|'):
            break

        # Первая строка с | - заголовок
        if not headers:
            headers = [h.strip() for h in line.split('|')[1:-1]]
            i += 1
            continue

        # Вторая строка - разделитель (пропускаем)
        if re.match(r'\|[\s\-:|]+\|', line):
            i += 1
            continue

        # Остальные строки - данные
        row = [cell.strip() for cell in line.split('|')[1:-1]]
        if len(row) == len(headers):
            rows.append(row)

        i += 1

    return headers, rows, i


def extract_section_name(text):
    """Извлекает имя секции из заголовка"""
    # Убрать символы markdown заголовков
    text = re.sub(r'^#+\s*', '', text)
    # Убрать спецсимволы для имени файла
    text = re.sub(r'[^\w\s\-а-яА-Я]', '', text)
    # Заменить пробелы на подчеркивания
    text = text.strip().replace(' ', '_')
    return text


def process_modbus_map(input_file, output_dir):
    """
    Обрабатывает файл MODBUS_MAP.md и создает CSV файлы
    """
    # Создать выходную директорию
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # Прочитать входной файл
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Переменные для отслеживания контекста
    current_main_section = ""
    current_subsection = ""
    table_counter = 0

    i = 0
    while i < len(lines):
        line = lines[i].strip()

        # Отслеживать заголовки разделов
        if line.startswith('## '):
            current_main_section = extract_section_name(line)
            table_counter = 0
        elif line.startswith('### '):
            current_subsection = extract_section_name(line)
            table_counter = 0

        # Найти начало таблицы
        if line.startswith('|') and not re.match(r'\|[\s\-:|]+\|', line):
            # Получить заголовок таблицы (если есть)
            table_title = ""
            if i > 0:
                prev_line = lines[i-1].strip()
                if prev_line.startswith('**') and prev_line.endswith(':**'):
                    table_title = extract_section_name(prev_line)

            # Парсить таблицу
            headers, rows, next_i = parse_markdown_table(lines, i)

            if headers and rows:
                # Сформировать имя файла
                table_counter += 1

                if table_title:
                    filename = f"{current_main_section}_{current_subsection}_{table_title}.csv"
                else:
                    filename = f"{current_main_section}_{current_subsection}_{table_counter:02d}.csv"

                # Очистить имя файла от множественных подчеркиваний
                filename = re.sub(r'_+', '_', filename)
                filename = filename.strip('_')

                # Сохранить в CSV
                csv_path = output_path / filename
                with open(csv_path, 'w', encoding='utf-8', newline='') as csvfile:
                    writer = csv.writer(csvfile)
                    writer.writerow(headers)
                    writer.writerows(rows)

                print(f"✓ Создан: {filename} ({len(rows)} строк)")

            i = next_i
        else:
            i += 1

    # Создать объединенный файл со всеми регистрами
    create_combined_csv(input_file, output_path)


def create_combined_csv(input_file, output_dir):
    """
    Создает объединенный CSV файл со всеми регистрами
    """
    combined_data = []

    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    current_register_type = ""  # Holding или Input
    current_section = ""

    i = 0
    while i < len(lines):
        line = lines[i].strip()

        # Определить тип регистра
        if 'Holding регистры' in line or 'SCADA → PLC' in line:
            current_register_type = "Holding"
        elif 'Input регистры' in line or 'PLC → SCADA' in line:
            current_register_type = "Input"

        # Отслеживать секции
        if line.startswith('###'):
            current_section = line.replace('###', '').strip()

        # Парсить таблицы
        if line.startswith('|') and not re.match(r'\|[\s\-:|]+\|', line):
            headers, rows, next_i = parse_markdown_table(lines, i)

            if headers and rows:
                # Добавить данные с контекстом
                for row in rows:
                    combined_row = [current_register_type, current_section] + row
                    combined_data.append(combined_row)

            i = next_i
        else:
            i += 1

    # Сохранить объединенный файл
    if combined_data:
        csv_path = output_dir / "MODBUS_MAP_FULL.csv"

        # Определить максимальное количество колонок
        max_cols = max(len(row) for row in combined_data)

        # Создать заголовок
        base_headers = ["Тип_регистра", "Секция"]
        data_headers = [f"Колонка_{i+1}" for i in range(max_cols - 2)]
        headers = base_headers + data_headers

        with open(csv_path, 'w', encoding='utf-8', newline='') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(headers)

            # Дополнить строки до одинаковой длины
            for row in combined_data:
                padded_row = row + [''] * (max_cols - len(row))
                writer.writerow(padded_row)

        print(f"\n✓ Создан объединенный файл: MODBUS_MAP_FULL.csv ({len(combined_data)} строк)")


def main():
    """Главная функция"""
    # Пути
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    input_file = project_dir / "MODBUS_MAP.md"
    output_dir = script_dir / "output"

    print("=" * 60)
    print("Конвертация MODBUS_MAP.md → CSV")
    print("=" * 60)
    print(f"Входной файл: {input_file}")
    print(f"Выходная папка: {output_dir}")
    print("-" * 60)

    if not input_file.exists():
        print(f"❌ Ошибка: файл {input_file} не найден!")
        return

    process_modbus_map(input_file, output_dir)

    print("-" * 60)
    print("✓ Конвертация завершена!")
    print(f"📁 Результаты в папке: {output_dir}")
    print("=" * 60)


if __name__ == "__main__":
    main()
