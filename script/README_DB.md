# База данных Modbus регистров

Система управления картой Modbus регистров для промышленной системы управления на базе SQLite.

## Обзор

Эта база данных автоматически синхронизируется с актуальным кодом PLC (`FC_ModbusToSCADA.st`) и предоставляет удобные инструменты для:
- 🔍 Поиска регистров по переменной, адресу, секции
- 📊 Анализа использования адресного пространства
- 📄 Экспорта документации в JSON и Excel форматы
- ✅ Контроля конфликтов адресов

## Структура файлов

```
script/
├── db/
│   ├── schema.sql                  # SQL схема БД (5 таблиц + 2 представления)
│   ├── modbus_registers.db         # SQLite БД (генерируется)
│   └── queries.sql                 # Готовые SQL запросы
├── migrate_from_fc.py              # Парсер FC_ModbusToSCADA.st → DB
├── export_to_json.py               # Экспорт DB → JSON
├── export_to_excel.py              # Экспорт DB → Excel
├── modbus_map.json                 # JSON карта (генерируется)
├── modbus_map.xlsx                 # Excel таблица (генерируется)
└── README_DB.md                    # Эта документация
```

## Быстрый старт

### 1. Создание базы данных

Выполните миграцию из кода PLC:

```bash
cd /path/to/newProject/script
python3 migrate_from_fc.py
```

**Результат:**
```
============================================================
Modbus Register Migration Tool
============================================================

📄 Парсинг файла: FC_ModbusToSCADA.st
   Найдено секций: 21
   Найдено регистров: 358

💾 Миграция в базу данных...
✅ База данных создана: db/modbus_registers.db
✅ Мигрировано секций: 21
✅ Вставлено регистров: 358

✅ Миграция завершена успешно!
============================================================
```

### 2. Экспорт документации

#### JSON формат
```bash
python3 export_to_json.py
```

Создаёт файл `modbus_map.json` в формате:
```json
{
  "holding_registers": {
    "description": "Holding Registers (SCADA → PLC)",
    "registers": [
      {
        "section": "Уставки ЧРП (30-59)",
        "address": "32-33",
        "data_type": "REAL",
        "variable": "VFD_FREQUENCY_MAX",
        "description": ""
      }
    ]
  }
}
```

#### Excel формат
```bash
python3 export_to_excel.py
```

**Требования:** `pip install openpyxl` или `apt install python3-openpyxl`

Создаёт файл `modbus_map.xlsx` с листами:
- **Статистика** - сводная информация
- **Holding Registers** - уставки и команды (SCADA → PLC)
- **Input Registers** - данные мониторинга (PLC → SCADA)
- **Резервы** - свободные диапазоны адресов

## Схема базы данных

### Таблицы

#### 1. `register_types` - Типы Modbus регистров
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PK | Идентификатор |
| name | TEXT | `holding_registers` или `input_registers` |
| direction | TEXT | `read`, `write`, `read/write` |
| description_ru | TEXT | Описание на русском |

#### 2. `data_types` - Типы данных PLC (IEC 61131-3)
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PK | Идентификатор |
| name | TEXT | `BOOL`, `REAL`, `INT`, `UINT`, `TIME`, `WORD`, `DINT` |
| register_count | INTEGER | Количество регистров (0 для BOOL, 1 для INT, 2 для REAL) |
| supports_bit_packing | BOOLEAN | Поддержка побитовой упаковки (только BOOL) |

#### 3. `sections` - Секции оборудования
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PK | Идентификатор |
| register_type_id | INTEGER FK | Тип регистра |
| name | TEXT | Название секции (например, "Уставки ЧРП (30-59)") |
| start_register | INTEGER | Начальный адрес |
| end_register | INTEGER | Конечный адрес |
| description | TEXT | Описание |

#### 4. `registers` - Основная таблица регистров
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PK | Идентификатор |
| register_type_id | INTEGER FK | Тип регистра |
| section_id | INTEGER FK | Секция |
| register_address | INTEGER | Адрес регистра (0-65535) |
| bit_index | INTEGER | Индекс бита (0-15, только для BOOL) |
| data_type_id | INTEGER FK | Тип данных |
| variable_name | TEXT | Имя переменной в PLC |
| description | TEXT | Описание |
| is_reserved | BOOLEAN | Зарезервирован для будущего |
| created_at | TIMESTAMP | Дата создания |
| updated_at | TIMESTAMP | Дата обновления |

**Уникальное ограничение:** `(register_type_id, register_address, bit_index)`

#### 5. `register_gaps` - Резервы для расширения
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PK | Идентификатор |
| register_type_id | INTEGER FK | Тип регистра |
| start_register | INTEGER | Начало диапазона |
| end_register | INTEGER | Конец диапазона |
| purpose | TEXT | Назначение резерва |

### Представления (Views)

#### `v_registers_full` - Полная информация о регистрах
Объединяет данные из всех таблиц с форматированным адресом:
- BOOL: `"0.5"` (регистр.бит)
- REAL/TIME: `"32-33"` (2 регистра)
- INT/WORD: `"50"` (1 регистр)

#### `v_sections_stats` - Статистика по секциям
Подсчитывает количество регистров каждого типа в секции.

## Примеры использования

### Поиск регистров

#### 1. Найти регистр по переменной PLC
```sql
SELECT * FROM v_registers_full
WHERE variable_name = 'VFD_FREQUENCY_MAX';
```

#### 2. Найти все регистры в секции
```sql
SELECT address_formatted, data_type, variable_name
FROM v_registers_full
WHERE section LIKE '%Уставки ЧРП%'
ORDER BY register_address;
```

#### 3. Найти все BOOL биты в регистре 0
```sql
SELECT bit_index, variable_name
FROM v_registers_full
WHERE register_type = 'holding_registers'
  AND data_type = 'BOOL'
  AND register_address = 0
ORDER BY bit_index;
```

#### 4. Поиск по части имени переменной
```sql
SELECT register_type, address_formatted, variable_name
FROM v_registers_full
WHERE variable_name LIKE '%FREQUENCY%';
```

### Статистика

#### 5. Общая статистика
```sql
SELECT
    'Всего регистров' AS параметр,
    COUNT(*) AS значение
FROM registers;
```

#### 6. Распределение по типам данных
```sql
SELECT
    dt.name AS тип_данных,
    COUNT(*) AS количество
FROM registers r
JOIN data_types dt ON r.data_type_id = dt.id
GROUP BY dt.name
ORDER BY количество DESC;
```

#### 7. Топ-10 секций
```sql
SELECT
    s.name AS секция,
    COUNT(*) AS количество_регистров
FROM registers r
JOIN sections s ON r.section_id = s.id
GROUP BY s.name
ORDER BY количество_регистров DESC
LIMIT 10;
```

### Анализ использования адресов

#### 8. Занятость секций
```sql
SELECT
    s.name,
    (s.end_register - s.start_register + 1) AS всего_адресов,
    COUNT(DISTINCT r.register_address) AS занято_адресов
FROM sections s
LEFT JOIN registers r ON s.id = r.section_id
GROUP BY s.id;
```

#### 9. Найти свободные адреса в диапазоне
```sql
WITH RECURSIVE
    all_addresses(addr) AS (
        SELECT 0
        UNION ALL
        SELECT addr + 1 FROM all_addresses WHERE addr < 29
    ),
    used_addresses AS (
        SELECT DISTINCT register_address
        FROM registers
        WHERE register_address BETWEEN 0 AND 29
    )
SELECT addr AS свободный_адрес
FROM all_addresses
WHERE addr NOT IN (SELECT register_address FROM used_addresses);
```

### Добавление регистров

#### 10. Добавить новый BOOL регистр
```sql
INSERT INTO registers (
    register_type_id,
    section_id,
    register_address,
    bit_index,
    data_type_id,
    variable_name,
    description
) VALUES (
    1,                          -- holding_registers
    2,                          -- section_id (получить из SELECT id FROM sections WHERE...)
    5,                          -- адрес регистра
    7,                          -- бит 7
    1,                          -- BOOL
    'NEW_COMMAND',
    'Новая команда'
);
```

#### 11. Добавить новый REAL регистр
```sql
INSERT INTO registers (
    register_type_id,
    section_id,
    register_address,
    bit_index,
    data_type_id,
    variable_name,
    description
) VALUES (
    1,                          -- holding_registers
    2,                          -- section_id
    50,                         -- адрес регистра (займёт 50-51)
    NULL,                       -- bit_index не используется для REAL
    2,                          -- REAL
    'NEW_SETPOINT',
    'Новая уставка'
);
```

### Проверка конфликтов

#### 12. Найти дубликаты адресов
```sql
SELECT
    register_type,
    register_address,
    bit_index,
    COUNT(*) AS дубликаты,
    GROUP_CONCAT(variable_name, '; ') AS переменные
FROM v_registers_full
GROUP BY register_type, register_address, bit_index
HAVING COUNT(*) > 1;
```

## Работа с готовыми запросами

Файл `db/queries.sql` содержит набор готовых запросов. Использование:

```bash
# Интерактивный режим
sqlite3 db/modbus_registers.db
.read queries.sql

# Или напрямую
sqlite3 db/modbus_registers.db < db/queries.sql
```

**Включённые запросы:**
- Поиск по переменной
- Регистры в секции
- BOOL биты в регистре
- Статистика по типам
- Занятость секций
- Свободные адреса
- Проверка дубликатов
- Экспорт в CSV

## Workflow разработки

### Добавление нового тэга

**Вариант 1: Прямое добавление в код**
1. Добавить вызов `FC_ModbusRead/Write` в `POUs/FC_ModbusToSCADA.st`
2. Запустить миграцию: `python3 migrate_from_fc.py`
3. Обновить документацию: `python3 export_to_json.py && python3 export_to_excel.py`

**Вариант 2: Прямое добавление в БД** (для планирования)
1. Добавить регистр в БД через SQL (см. примеры выше)
2. Экспортировать документацию
3. Позднее реализовать в коде PLC

### Обновление существующего тэга

```sql
UPDATE registers
SET description = 'Новое описание'
WHERE variable_name = 'VFD_FREQUENCY_MAX';
```

### Удаление тэга

```sql
DELETE FROM registers
WHERE variable_name = 'OLD_VARIABLE';
```

### Синхронизация с кодом

Для полной синхронизации с актуальным кодом PLC:
```bash
python3 migrate_from_fc.py    # Пересоздаст БД из FC_ModbusToSCADA.st
python3 export_to_json.py     # Обновит JSON
python3 export_to_excel.py    # Обновит Excel
```

## Установка зависимостей

### Python 3
```bash
# Debian/Ubuntu
sudo apt install python3

# Уже установлен в системе
```

### SQLite3
```bash
# Debian/Ubuntu
sudo apt install sqlite3

# Обычно уже установлен
```

### openpyxl (для Excel экспорта)
```bash
# Вариант 1: Системный пакет
sudo apt install python3-openpyxl

# Вариант 2: Virtual environment
python3 -m venv venv
source venv/bin/activate
pip install openpyxl

# Вариант 3: Пользовательская установка (если разрешено)
pip install --user openpyxl
```

## Резервное копирование

### Backup БД
```bash
# Простое копирование файла
cp db/modbus_registers.db db/modbus_registers_backup_$(date +%Y%m%d).db

# Или через SQLite dump
sqlite3 db/modbus_registers.db .dump > db/backup.sql
```

### Восстановление
```bash
# Из файла
cp db/modbus_registers_backup_20251212.db db/modbus_registers.db

# Из dump
sqlite3 db/modbus_registers.db < db/backup.sql
```

## Решение проблем

### БД не создаётся
```bash
# Проверить права на запись
ls -la db/

# Удалить старую БД и пересоздать
rm db/modbus_registers.db
python3 migrate_from_fc.py
```

### Ошибки парсинга FC_ModbusToSCADA.st
```bash
# Проверить путь к файлу
ls -la ../POUs/FC_ModbusToSCADA.st

# Проверить кодировку
file ../POUs/FC_ModbusToSCADA.st
```

### Excel экспорт не работает
```bash
# Установить openpyxl
sudo apt install python3-openpyxl

# Или использовать только JSON экспорт
python3 export_to_json.py
```

## Дополнительная информация

### Связанные документы
- [MODBUS_MAP.md](../MODBUS_MAP.md) - Полная карта регистров
- [CLAUDE.md](../CLAUDE.md) - Архитектура проекта
- [README.md](../README.md) - Общая документация

### Контакты
При возникновении вопросов или предложений по улучшению системы - создайте issue или pull request в репозитории проекта.

---

**Версия:** 1.0
**Дата создания:** 2025-12-12
**Автор:** Claude Code
