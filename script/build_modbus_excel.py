r"""
Скрипт для создания Excel-файла с картой Modbus регистров

Как запустить в виртуальном окружении:

1. Создать venv:
   python3 -m venv venv

2. Активировать venv:
   - Linux/Mac:
     source venv/bin/activate
   - Windows:
     venv\Scripts\activate

3. Установить зависимости:
   pip install pandas xlsxwriter openpyxl

4. Запустить скрипт из корня проекта:
   python3 script/build_modbus_excel.py
"""

import json
import pandas as pd
import xlsxwriter
from pathlib import Path

# ==== 1. Загружаем JSON ====
# Определяем пути относительно расположения скрипта
script_dir = Path(__file__).parent
project_dir = script_dir.parent
json_path = script_dir / "modbus_map.json"

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# ==== 2. Подготовка данных ====
df_holding = pd.DataFrame(data["holding_registers"]["registers"])
df_input = pd.DataFrame(data["input_registers"]["registers"])

# ==== 3. Создание Excel с форматированием ====
excel_path = project_dir / "MODBUS_MAP.xlsx"
with pd.ExcelWriter(excel_path, engine="xlsxwriter") as writer:
    workbook = writer.book

    # ---------- Форматы ----------
    header_format = workbook.add_format({
        "bold": True,
        "bg_color": "#4472C4",
        "font_color": "white",
        "border": 1,
        "align": "center",
        "valign": "vcenter"
    })

    cell_format = workbook.add_format({
        "border": 1,
        "valign": "vcenter"
    })

    alternate_format = workbook.add_format({
        "border": 1,
        "bg_color": "#F2F2F2",
        "valign": "vcenter"
    })

    # ---------- Функция записи листа ----------
    def write_sheet(df, sheet_name):
        df.to_excel(writer, sheet_name=sheet_name, index=False, startrow=1)

        sheet = writer.sheets[sheet_name]

        # Заголовки
        for col_num, value in enumerate(df.columns.values):
            sheet.write(0, col_num, value, header_format)

        # Форматирование строк
        for row in range(len(df)):
            fmt = alternate_format if row % 2 else cell_format
            sheet.set_row(row + 1, 18, fmt)

        # Автофильтр
        sheet.autofilter(0, 0, len(df), len(df.columns) - 1)

        # Автоширина
        for idx, col in enumerate(df):
            max_len = max(df[col].astype(str).map(len).max(), len(col)) + 2
            sheet.set_column(idx, idx, max_len)

        # Фиксация строки заголовков
        sheet.freeze_panes(1, 0)

    # ---------- Запись листов ----------
    write_sheet(df_holding, "Holding Registers")
    write_sheet(df_input, "Input Registers")

print(f"Готово! Создан файл {excel_path}")
