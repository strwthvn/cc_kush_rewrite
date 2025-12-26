#!/usr/bin/env python3
"""
Генерация HTML документации Modbus регистров для GitHub Pages
"""

import sqlite3
import json
from pathlib import Path

def generate_html_documentation():
    """Генерирует HTML файл с интерактивной таблицей Modbus регистров"""

    # Путь к БД
    db_path = Path(__file__).parent / 'db' / 'modbus_registers.db'
    output_path = Path(__file__).parent.parent / 'docs' / 'index.html'

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Получаем все регистры с полной информацией
    cursor.execute("""
        SELECT
            rt.name as register_type,
            s.name as section,
            r.register_address,
            r.bit_index,
            CASE
                WHEN dt.name = 'BOOL' THEN printf('%d.%d', r.register_address, r.bit_index)
                WHEN dt.register_count = 2 THEN printf('%d-%d', r.register_address, r.register_address + 1)
                ELSE CAST(r.register_address AS TEXT)
            END AS address_formatted,
            dt.name as data_type,
            r.variable_name,
            r.description,
            r.is_reserved
        FROM registers r
        JOIN register_types rt ON r.register_type_id = rt.id
        JOIN data_types dt ON r.data_type_id = dt.id
        JOIN sections s ON r.section_id = s.id
        ORDER BY rt.id, r.register_address, r.bit_index
    """)

    registers = cursor.fetchall()

    # Преобразуем в JSON для использования в JavaScript
    registers_json = []
    for row in registers:
        registers_json.append({
            'register_type': row[0],
            'section': row[1],
            'register_address': row[2],
            'bit_index': row[3] if row[3] is not None else '',
            'address_formatted': row[4],
            'data_type': row[5],
            'variable_name': row[6],
            'description': row[7] if row[7] else '',
            'is_reserved': bool(row[8])
        })

    # Статистика
    cursor.execute("""
        SELECT
            rt.name,
            COUNT(*) as total,
            SUM(CASE WHEN r.is_reserved = 1 THEN 1 ELSE 0 END) as reserved,
            SUM(CASE WHEN r.description IS NOT NULL AND r.description != '' THEN 1 ELSE 0 END) as with_desc
        FROM registers r
        JOIN register_types rt ON r.register_type_id = rt.id
        GROUP BY rt.name
    """)

    stats_raw = {row[0]: {'total': row[1], 'reserved': row[2], 'with_desc': row[3]}
                 for row in cursor.fetchall()}

    # Нормализуем имена для простоты использования
    stats = {
        'holding': stats_raw.get('holding_registers', {'total': 0, 'reserved': 0, 'with_desc': 0}),
        'input': stats_raw.get('input_registers', {'total': 0, 'reserved': 0, 'with_desc': 0})
    }

    conn.close()

    # Генерируем HTML
    html_content = f"""<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Modbus Register Map - Система управления конвейерами</title>

    <!-- DataTables CSS -->
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/jquery.dataTables.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.dataTables.min.css">

    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }}

        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }}

        header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }}

        header h1 {{
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 700;
        }}

        header p {{
            font-size: 1.1em;
            opacity: 0.9;
        }}

        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }}

        .stat-card {{
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            border-left: 4px solid #667eea;
        }}

        .stat-card h3 {{
            color: #667eea;
            font-size: 0.9em;
            text-transform: uppercase;
            margin-bottom: 10px;
            font-weight: 600;
        }}

        .stat-card .number {{
            font-size: 2em;
            font-weight: bold;
            color: #333;
        }}

        .stat-card .label {{
            color: #666;
            font-size: 0.9em;
            margin-top: 5px;
        }}

        .content {{
            padding: 30px;
        }}

        .filters {{
            margin-bottom: 20px;
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
        }}

        .filter-group {{
            display: flex;
            flex-direction: column;
            gap: 5px;
        }}

        .filter-group label {{
            font-weight: 600;
            color: #555;
            font-size: 0.9em;
        }}

        .filter-group select {{
            padding: 8px 12px;
            border: 2px solid #ddd;
            border-radius: 6px;
            font-size: 1em;
            cursor: pointer;
            transition: border-color 0.3s;
        }}

        .filter-group select:focus {{
            outline: none;
            border-color: #667eea;
        }}

        table.dataTable {{
            border-collapse: collapse;
            width: 100%;
            font-size: 0.9em;
        }}

        table.dataTable thead th {{
            background: #667eea;
            color: white;
            font-weight: 600;
            padding: 12px 8px;
            text-align: left;
        }}

        table.dataTable tbody td {{
            padding: 10px 8px;
            border-bottom: 1px solid #eee;
        }}

        table.dataTable tbody tr:hover {{
            background: #f5f5ff;
        }}

        .badge {{
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: 600;
        }}

        .badge-holding {{
            background: #e3f2fd;
            color: #1976d2;
        }}

        .badge-input {{
            background: #e8f5e9;
            color: #388e3c;
        }}

        .badge-bool {{
            background: #fff3e0;
            color: #f57c00;
        }}

        .badge-real {{
            background: #f3e5f5;
            color: #7b1fa2;
        }}

        .badge-int {{
            background: #e0f2f1;
            color: #00796b;
        }}

        .badge-reserved {{
            background: #ffebee;
            color: #c62828;
        }}

        footer {{
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            color: #666;
            font-size: 0.9em;
        }}

        .var-name {{
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            color: #d73a49;
        }}

        .dt-buttons {{
            margin-bottom: 15px;
        }}

        .dt-button {{
            background: #667eea !important;
            color: white !important;
            border: none !important;
            padding: 8px 16px !important;
            border-radius: 6px !important;
            margin-right: 10px !important;
            cursor: pointer !important;
            font-weight: 600 !important;
        }}

        .dt-button:hover {{
            background: #5568d3 !important;
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📊 Modbus Register Map</h1>
            <p>Система управления конвейерами и бункерами</p>
        </header>

        <div class="stats">
            <div class="stat-card">
                <h3>Holding Registers</h3>
                <div class="number">{stats['holding']['total']}</div>
                <div class="label">С описаниями: {stats['holding']['with_desc']}</div>
            </div>
            <div class="stat-card">
                <h3>Input Registers</h3>
                <div class="number">{stats['input']['total']}</div>
                <div class="label">С описаниями: {stats['input']['with_desc']}</div>
            </div>
            <div class="stat-card">
                <h3>Всего регистров</h3>
                <div class="number">{stats['holding']['total'] + stats['input']['total']}</div>
                <div class="label">Покрытие описаниями: {round((stats['holding']['with_desc'] + stats['input']['with_desc']) / (stats['holding']['total'] + stats['input']['total']) * 100)}%</div>
            </div>
        </div>

        <div class="content">
            <div class="filters">
                <div class="filter-group">
                    <label for="typeFilter">Тип регистра:</label>
                    <select id="typeFilter">
                        <option value="">Все</option>
                        <option value="holding_registers">Holding (SCADA → PLC)</option>
                        <option value="input_registers">Input (PLC → SCADA)</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="dataTypeFilter">Тип данных:</label>
                    <select id="dataTypeFilter">
                        <option value="">Все</option>
                        <option value="BOOL">BOOL</option>
                        <option value="REAL">REAL</option>
                        <option value="INT">INT</option>
                        <option value="UINT">UINT</option>
                        <option value="WORD">WORD</option>
                        <option value="TIME">TIME</option>
                    </select>
                </div>
            </div>

            <table id="registersTable" class="display" style="width:100%">
                <thead>
                    <tr>
                        <th>Тип</th>
                        <th>Секция</th>
                        <th>Адрес</th>
                        <th>Тип данных</th>
                        <th>Переменная</th>
                        <th>Описание</th>
                    </tr>
                </thead>
                <tbody>
                </tbody>
            </table>
        </div>

        <footer>
            <p>🤖 Автоматически сгенерировано из базы данных Modbus регистров</p>
            <p>Последнее обновление: {Path(__file__).parent / 'db' / 'modbus_registers.db'} </p>
        </footer>
    </div>

    <!-- jQuery -->
    <script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>

    <!-- DataTables -->
    <script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>

    <script>
        // Данные регистров
        const registersData = {json.dumps(registers_json, ensure_ascii=False, indent=8)};

        $(document).ready(function() {{
            // Инициализация DataTables
            const table = $('#registersTable').DataTable({{
                data: registersData,
                columns: [
                    {{
                        data: 'register_type',
                        render: function(data) {{
                            const badgeClass = data === 'holding_registers' ? 'badge-holding' : 'badge-input';
                            const label = data === 'holding_registers' ? 'HOLDING' : 'INPUT';
                            return `<span class="badge ${{badgeClass}}">${{label}}</span>`;
                        }}
                    }},
                    {{ data: 'section' }},
                    {{ data: 'address_formatted' }},
                    {{
                        data: 'data_type',
                        render: function(data) {{
                            let badgeClass = 'badge-int';
                            if (data === 'BOOL') badgeClass = 'badge-bool';
                            else if (data === 'REAL' || data === 'TIME') badgeClass = 'badge-real';
                            return `<span class="badge ${{badgeClass}}">${{data}}</span>`;
                        }}
                    }},
                    {{
                        data: 'variable_name',
                        render: function(data, type, row) {{
                            if (row.is_reserved) {{
                                return `<span class="badge badge-reserved">RESERVED</span>`;
                            }}
                            return `<span class="var-name">${{data}}</span>`;
                        }}
                    }},
                    {{ data: 'description' }}
                ],
                pageLength: 25,
                lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "Все"]],
                language: {{
                    url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/ru.json'
                }},
                dom: 'Bfrtip',
                buttons: [
                    {{
                        extend: 'excel',
                        text: '📥 Экспорт в Excel',
                        filename: 'modbus_registers'
                    }},
                    {{
                        text: '🔄 Сбросить фильтры',
                        action: function() {{
                            $('#typeFilter').val('');
                            $('#dataTypeFilter').val('');
                            table.search('').draw();
                        }}
                    }}
                ]
            }});

            // Кастомная функция фильтрации по типу регистра
            $.fn.dataTable.ext.search.push(
                function(settings, data, dataIndex) {{
                    const typeFilter = $('#typeFilter').val();
                    const dataTypeFilter = $('#dataTypeFilter').val();

                    // Получаем исходные данные строки
                    const rowData = table.row(dataIndex).data();

                    // Фильтр по типу регистра
                    if (typeFilter && rowData.register_type !== typeFilter) {{
                        return false;
                    }}

                    // Фильтр по типу данных
                    if (dataTypeFilter && rowData.data_type !== dataTypeFilter) {{
                        return false;
                    }}

                    return true;
                }}
            );

            // Обработчики фильтров
            $('#typeFilter, #dataTypeFilter').on('change', function() {{
                table.draw();
            }});
        }});
    </script>
</body>
</html>"""

    # Сохраняем HTML файл
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(html_content, encoding='utf-8')

    print(f"✅ HTML документация сгенерирована: {output_path}")
    print(f"   - Holding registers: {stats['holding']['total']}")
    print(f"   - Input registers: {stats['input']['total']}")
    print(f"   - Всего: {stats['holding']['total'] + stats['input']['total']}")

if __name__ == '__main__':
    generate_html_documentation()
