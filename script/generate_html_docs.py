#!/usr/bin/env python3
"""
Генерация HTML документации Modbus регистров для GitHub Pages
GitHub Dark Theme с адаптивной мобильной версией
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

    # Генерируем HTML с GitHub Dark Theme
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
        /* GitHub Dark Theme */
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: #0d1117;
            min-height: 100vh;
            padding: 20px;
            color: #c9d1d9;
        }}

        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: #161b22;
            border-radius: 12px;
            border: 1px solid #30363d;
            box-shadow: 0 8px 24px rgba(0,0,0,0.5);
            overflow: hidden;
        }}

        header {{
            background: #161b22;
            border-bottom: 1px solid #30363d;
            color: #c9d1d9;
            padding: 30px;
            text-align: center;
        }}

        header h1 {{
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 700;
            color: #58a6ff;
        }}

        header p {{
            font-size: 1.1em;
            color: #8b949e;
        }}

        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #0d1117;
        }}

        .stat-card {{
            background: #161b22;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #30363d;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
            border-left: 4px solid #1f6feb;
        }}

        .stat-card h3 {{
            color: #58a6ff;
            font-size: 0.9em;
            text-transform: uppercase;
            margin-bottom: 10px;
            font-weight: 600;
        }}

        .stat-card .number {{
            font-size: 2em;
            font-weight: bold;
            color: #c9d1d9;
        }}

        .stat-card .label {{
            color: #8b949e;
            font-size: 0.9em;
            margin-top: 5px;
        }}

        .content {{
            padding: 30px;
            background: #0d1117;
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
            color: #8b949e;
            font-size: 0.9em;
        }}

        .filter-group select {{
            padding: 8px 12px;
            border: 1px solid #30363d;
            border-radius: 6px;
            font-size: 1em;
            cursor: pointer;
            transition: border-color 0.3s, background-color 0.3s;
            background: #161b22;
            color: #c9d1d9;
        }}

        .filter-group select:focus {{
            outline: none;
            border-color: #58a6ff;
            background: #0d1117;
        }}

        .filter-group select:hover {{
            background: #0d1117;
        }}

        /* DataTables Overrides for Dark Theme */
        table.dataTable {{
            border-collapse: collapse;
            width: 100%;
            font-size: 0.9em;
            background: #161b22;
            color: #c9d1d9;
        }}

        table.dataTable thead th {{
            background: #21262d;
            color: #c9d1d9;
            font-weight: 600;
            padding: 12px 8px;
            text-align: left;
            border-bottom: 1px solid #30363d;
        }}

        table.dataTable tbody td {{
            padding: 10px 8px;
            border-bottom: 1px solid #21262d;
            background: #0d1117;
            color: #c9d1d9;
        }}

        table.dataTable tbody tr {{
            background: #0d1117;
        }}

        table.dataTable tbody tr:hover {{
            background: #161b22 !important;
        }}

        table.dataTable.stripe tbody tr.odd,
        table.dataTable.display tbody tr.odd {{
            background: #0d1117;
        }}

        table.dataTable.stripe tbody tr.even,
        table.dataTable.display tbody tr.even {{
            background: #161b22;
        }}

        /* DataTables Search Box */
        .dataTables_wrapper .dataTables_filter input {{
            background: #161b22;
            border: 1px solid #30363d;
            color: #c9d1d9;
            padding: 6px 12px;
            border-radius: 6px;
        }}

        .dataTables_wrapper .dataTables_filter input:focus {{
            outline: none;
            border-color: #58a6ff;
        }}

        /* DataTables Info and Pagination */
        .dataTables_wrapper .dataTables_info,
        .dataTables_wrapper .dataTables_length,
        .dataTables_wrapper .dataTables_filter {{
            color: #8b949e;
        }}

        .dataTables_wrapper .dataTables_length select {{
            background: #161b22;
            border: 1px solid #30363d;
            color: #c9d1d9;
            padding: 4px 8px;
            border-radius: 6px;
        }}

        .dataTables_wrapper .dataTables_paginate .paginate_button {{
            background: #161b22;
            border: 1px solid #30363d;
            color: #c9d1d9 !important;
            border-radius: 6px;
            padding: 6px 12px;
            margin: 0 2px;
        }}

        .dataTables_wrapper .dataTables_paginate .paginate_button:hover {{
            background: #21262d !important;
            border-color: #58a6ff !important;
            color: #58a6ff !important;
        }}

        .dataTables_wrapper .dataTables_paginate .paginate_button.current {{
            background: #1f6feb !important;
            border-color: #1f6feb !important;
            color: #ffffff !important;
        }}

        .dataTables_wrapper .dataTables_paginate .paginate_button.disabled {{
            color: #484f58 !important;
        }}

        .badge {{
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: 600;
        }}

        .badge-holding {{
            background: #1f6feb33;
            color: #58a6ff;
            border: 1px solid #1f6feb;
        }}

        .badge-input {{
            background: #2ea04333;
            color: #3fb950;
            border: 1px solid #2ea043;
        }}

        .badge-bool {{
            background: #d2930033;
            color: #f0883e;
            border: 1px solid #d29300;
        }}

        .badge-real {{
            background: #a371f733;
            color: #bc8cff;
            border: 1px solid #a371f7;
        }}

        .badge-int {{
            background: #388bfd33;
            color: #58a6ff;
            border: 1px solid #388bfd;
        }}

        .badge-reserved {{
            background: #da364633;
            color: #f85149;
            border: 1px solid #da3646;
        }}

        footer {{
            text-align: center;
            padding: 20px;
            background: #161b22;
            border-top: 1px solid #30363d;
            color: #8b949e;
            font-size: 0.9em;
        }}

        .var-name {{
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            color: #79c0ff;
            background: #161b22;
            padding: 2px 6px;
            border-radius: 3px;
        }}

        .dt-buttons {{
            margin-bottom: 15px;
        }}

        .dt-button {{
            background: #238636 !important;
            color: white !important;
            border: 1px solid #2ea043 !important;
            padding: 8px 16px !important;
            border-radius: 6px !important;
            margin-right: 10px !important;
            cursor: pointer !important;
            font-weight: 600 !important;
        }}

        .dt-button:hover {{
            background: #2ea043 !important;
        }}

        /* Mobile-specific styles */
        .table-wrapper {{
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
        }}

        /* Responsive Design - Mobile First */
        @media screen and (max-width: 768px) {{
            body {{
                padding: 10px;
            }}

            .container {{
                border-radius: 8px;
            }}

            header {{
                padding: 20px 15px;
            }}

            header h1 {{
                font-size: 1.8em;
                margin-bottom: 8px;
            }}

            header p {{
                font-size: 0.95em;
            }}

            /* Stats cards - stack vertically on mobile */
            .stats {{
                grid-template-columns: 1fr;
                padding: 15px;
                gap: 12px;
            }}

            .stat-card {{
                padding: 15px;
            }}

            .stat-card .number {{
                font-size: 1.8em;
            }}

            /* Content area */
            .content {{
                padding: 15px;
            }}

            /* Filters - stack vertically */
            .filters {{
                flex-direction: column;
                gap: 12px;
            }}

            .filter-group {{
                width: 100%;
            }}

            .filter-group select {{
                width: 100%;
                padding: 12px 16px;
                font-size: 16px; /* Prevent zoom on iOS */
                min-height: 44px; /* Touch-friendly size */
            }}

            /* DataTables controls */
            .dataTables_wrapper .dataTables_length,
            .dataTables_wrapper .dataTables_filter {{
                float: none !important;
                text-align: left;
                margin-bottom: 12px;
            }}

            .dataTables_wrapper .dataTables_filter input {{
                width: 100% !important;
                max-width: none !important;
                margin-left: 0 !important;
                margin-top: 8px;
                padding: 12px 16px;
                font-size: 16px; /* Prevent zoom on iOS */
                min-height: 44px; /* Touch-friendly */
            }}

            .dataTables_wrapper .dataTables_length select {{
                padding: 8px 12px;
                font-size: 16px;
                min-height: 40px;
            }}

            /* Table - horizontal scroll */
            .table-wrapper {{
                margin: 0 -15px;
                padding: 0 15px;
            }}

            table.dataTable {{
                font-size: 0.85em;
                min-width: 600px; /* Force horizontal scroll */
            }}

            table.dataTable thead th {{
                padding: 10px 6px;
                font-size: 0.85em;
                white-space: nowrap;
            }}

            table.dataTable tbody td {{
                padding: 10px 6px;
                white-space: nowrap;
            }}

            /* Make important columns visible */
            table.dataTable tbody td:nth-child(3),
            table.dataTable tbody td:nth-child(5) {{
                font-weight: 600;
            }}

            /* Pagination - more compact */
            .dataTables_wrapper .dataTables_paginate {{
                float: none !important;
                text-align: center;
                margin-top: 15px;
            }}

            .dataTables_wrapper .dataTables_paginate .paginate_button {{
                padding: 10px 14px;
                margin: 0 1px;
                font-size: 14px;
                min-width: 44px; /* Touch-friendly */
            }}

            .dataTables_wrapper .dataTables_info {{
                float: none !important;
                text-align: center;
                padding-top: 12px;
            }}

            /* Buttons */
            .dt-buttons {{
                display: flex;
                flex-direction: column;
                gap: 8px;
                margin-bottom: 12px;
            }}

            .dt-button {{
                margin-right: 0 !important;
                width: 100%;
                padding: 12px 16px !important;
                min-height: 44px;
            }}

            /* Badges - slightly smaller */
            .badge {{
                font-size: 0.75em;
                padding: 3px 6px;
            }}

            /* Variable names - wrap on mobile */
            .var-name {{
                font-size: 0.8em;
                word-break: break-all;
            }}

            /* Footer */
            footer {{
                padding: 15px;
                font-size: 0.85em;
            }}
        }}

        /* Tablet styles */
        @media screen and (min-width: 769px) and (max-width: 1024px) {{
            .container {{
                max-width: 95%;
            }}

            .stats {{
                grid-template-columns: repeat(2, 1fr);
            }}

            header h1 {{
                font-size: 2.2em;
            }}

            table.dataTable {{
                font-size: 0.85em;
            }}
        }}

        /* Small mobile devices */
        @media screen and (max-width: 480px) {{
            header h1 {{
                font-size: 1.5em;
            }}

            header p {{
                font-size: 0.9em;
            }}

            .stat-card .number {{
                font-size: 1.6em;
            }}

            table.dataTable {{
                font-size: 0.8em;
            }}

            .dataTables_wrapper .dataTables_paginate .paginate_button {{
                padding: 8px 10px;
                font-size: 12px;
                min-width: 40px;
            }}
        }}

        /* Landscape mode on mobile */
        @media screen and (max-width: 768px) and (orientation: landscape) {{
            header {{
                padding: 15px;
            }}

            header h1 {{
                font-size: 1.6em;
            }}

            .stats {{
                grid-template-columns: repeat(3, 1fr);
                padding: 12px;
            }}

            .stat-card {{
                padding: 12px;
            }}
        }}

        /* Touch device improvements */
        @media (hover: none) and (pointer: coarse) {{
            /* Increase touch targets */
            .filter-group select,
            .dataTables_wrapper .dataTables_filter input,
            .dt-button,
            .dataTables_wrapper .dataTables_paginate .paginate_button {{
                min-height: 44px;
                -webkit-tap-highlight-color: rgba(88, 166, 255, 0.2);
            }}

            /* Remove hover effects on touch devices */
            table.dataTable tbody tr:hover {{
                background: inherit !important;
            }}

            /* Add active/pressed state instead */
            table.dataTable tbody tr:active {{
                background: #161b22 !important;
            }}

            .dt-button:active {{
                transform: scale(0.98);
            }}

            .paginate_button:active {{
                transform: scale(0.95);
            }}
        }}

        /* High DPI displays */
        @media (-webkit-min-device-pixel-ratio: 2), (min-resolution: 192dpi) {{
            table.dataTable thead th,
            table.dataTable tbody td {{
                border-width: 0.5px;
            }}
        }}

        /* Accessibility - Reduce motion */
        @media (prefers-reduced-motion: reduce) {{
            * {{
                animation: none !important;
                transition: none !important;
            }}
        }}

        /* Print styles */
        @media print {{
            body {{
                background: white;
                padding: 0;
            }}

            .container {{
                box-shadow: none;
                border: none;
            }}

            .stats,
            .filters,
            .dt-buttons,
            .dataTables_wrapper .dataTables_length,
            .dataTables_wrapper .dataTables_filter,
            .dataTables_wrapper .dataTables_paginate {{
                display: none;
            }}

            table.dataTable {{
                border: 1px solid #000;
            }}

            table.dataTable thead th {{
                background: #f0f0f0 !important;
                color: #000 !important;
                border: 1px solid #000 !important;
            }}

            table.dataTable tbody td {{
                color: #000 !important;
                background: white !important;
                border: 1px solid #000 !important;
            }}
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

            <div class="table-wrapper">
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
        </div>

        <footer>
            <p>🤖 Автоматически сгенерировано из базы данных Modbus регистров</p>
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
                        render: function(data, type) {{
                            // Для экспорта возвращаем текст, для отображения - HTML
                            if (type === 'export') {{
                                return data === 'holding_registers' ? 'HOLDING' : 'INPUT';
                            }}
                            const badgeClass = data === 'holding_registers' ? 'badge-holding' : 'badge-input';
                            const label = data === 'holding_registers' ? 'HOLDING' : 'INPUT';
                            return `<span class="badge ${{badgeClass}}">${{label}}</span>`;
                        }}
                    }},
                    {{ data: 'section' }},
                    {{ data: 'address_formatted' }},
                    {{
                        data: 'data_type',
                        render: function(data, type) {{
                            // Для экспорта возвращаем только текст
                            if (type === 'export') {{
                                return data;
                            }}
                            let badgeClass = 'badge-int';
                            if (data === 'BOOL') badgeClass = 'badge-bool';
                            else if (data === 'REAL' || data === 'TIME') badgeClass = 'badge-real';
                            return `<span class="badge ${{badgeClass}}">${{data}}</span>`;
                        }}
                    }},
                    {{
                        data: 'variable_name',
                        render: function(data, type, row) {{
                            // Для экспорта возвращаем имя переменной или RESERVED
                            if (type === 'export') {{
                                return row.is_reserved ? 'RESERVED' : data;
                            }}
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
                        filename: 'modbus_registers',
                        title: 'Modbus Register Map',
                        exportOptions: {{
                            columns: ':visible',
                            modifier: {{
                                search: 'applied',
                                order: 'applied'
                            }}
                        }},
                        customize: function(xlsx) {{
                            // Дополнительная настройка Excel файла (опционально)
                        }}
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
