-- =====================================================
-- SQLite Schema for Modbus Register Database
-- =====================================================
-- Версия: 1.0
-- Создано: 2025-12-12
-- Описание: База данных для управления картой Modbus регистров
--           промышленной системы управления

-- =====================================================
-- СПРАВОЧНЫЕ ТАБЛИЦЫ
-- =====================================================

-- Типы Modbus регистров
CREATE TABLE register_types (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('read', 'write', 'read/write')),
    description_ru TEXT
);

-- Типы данных PLC (IEC 61131-3)
CREATE TABLE data_types (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    register_count INTEGER NOT NULL CHECK (register_count >= 0),
    supports_bit_packing BOOLEAN NOT NULL CHECK (supports_bit_packing IN (0, 1)),
    CONSTRAINT check_bit_packing CHECK (
        (supports_bit_packing = 1 AND register_count = 0) OR
        (supports_bit_packing = 0 AND register_count > 0)
    )
);

-- =====================================================
-- ОСНОВНЫЕ ТАБЛИЦЫ
-- =====================================================

-- Секции оборудования
CREATE TABLE sections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    register_type_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    start_register INTEGER NOT NULL CHECK (start_register >= 0),
    end_register INTEGER NOT NULL CHECK (end_register >= start_register),
    description TEXT,
    FOREIGN KEY (register_type_id) REFERENCES register_types(id) ON DELETE CASCADE,
    CONSTRAINT unique_section_name UNIQUE (register_type_id, name)
);

-- Основная таблица регистров
CREATE TABLE registers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    register_type_id INTEGER NOT NULL,
    section_id INTEGER NOT NULL,
    register_address INTEGER NOT NULL CHECK (register_address >= 0),
    bit_index INTEGER CHECK (bit_index IS NULL OR (bit_index >= 0 AND bit_index <= 15)),
    data_type_id INTEGER NOT NULL,
    variable_name TEXT NOT NULL,
    description TEXT,
    is_reserved BOOLEAN DEFAULT 0 CHECK (is_reserved IN (0, 1)),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (register_type_id) REFERENCES register_types(id) ON DELETE CASCADE,
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE,
    FOREIGN KEY (data_type_id) REFERENCES data_types(id) ON DELETE RESTRICT,
    CONSTRAINT unique_register_address UNIQUE(register_type_id, register_address, bit_index),
    CONSTRAINT check_bool_bit_index CHECK (
        (data_type_id = 1 AND bit_index IS NOT NULL) OR
        (data_type_id != 1 AND bit_index IS NULL)
    )
);

-- Зарезервированные диапазоны для будущего расширения
CREATE TABLE register_gaps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    register_type_id INTEGER NOT NULL,
    start_register INTEGER NOT NULL CHECK (start_register >= 0),
    end_register INTEGER NOT NULL CHECK (end_register >= start_register),
    purpose TEXT,
    FOREIGN KEY (register_type_id) REFERENCES register_types(id) ON DELETE CASCADE
);

-- =====================================================
-- ИНДЕКСЫ ДЛЯ БЫСТРОГО ПОИСКА
-- =====================================================

CREATE INDEX idx_registers_variable ON registers(variable_name);
CREATE INDEX idx_registers_section ON registers(section_id);
CREATE INDEX idx_registers_address ON registers(register_type_id, register_address);
CREATE INDEX idx_registers_data_type ON registers(data_type_id);
CREATE INDEX idx_sections_range ON sections(register_type_id, start_register, end_register);
CREATE INDEX idx_sections_type ON sections(register_type_id);

-- =====================================================
-- ТРИГГЕРЫ ДЛЯ АВТОМАТИЧЕСКОГО ОБНОВЛЕНИЯ
-- =====================================================

-- Автоматическое обновление метки времени updated_at
CREATE TRIGGER update_registers_timestamp
AFTER UPDATE ON registers
FOR EACH ROW
BEGIN
    UPDATE registers SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- =====================================================
-- ЗАПОЛНЕНИЕ СПРАВОЧНИКОВ
-- =====================================================

-- Типы Modbus регистров
INSERT INTO register_types (id, name, direction, description_ru) VALUES
    (1, 'holding_registers', 'read', 'Holding Registers (SCADA → PLC) - Уставки и команды'),
    (2, 'input_registers', 'write', 'Input Registers (PLC → SCADA) - Данные мониторинга');

-- Типы данных PLC (IEC 61131-3 Structured Text)
INSERT INTO data_types (id, name, register_count, supports_bit_packing) VALUES
    (1, 'BOOL', 0, 1),      -- Побитовая упаковка в регистры (0-15 бит)
    (2, 'REAL', 2, 0),      -- 32-bit float: 2 регистра (IEEE 754)
    (3, 'INT', 1, 0),       -- 16-bit signed integer: 1 регистр
    (4, 'UINT', 1, 0),      -- 16-bit unsigned integer: 1 регистр
    (5, 'TIME', 2, 0),      -- 32-bit time: 2 регистра (конвертируется через REAL)
    (6, 'WORD', 1, 0),      -- 16-bit bit string: 1 регистр
    (7, 'DINT', 2, 0);      -- 32-bit signed integer: 2 регистра

-- =====================================================
-- ПРЕДСТАВЛЕНИЯ (VIEWS) ДЛЯ УДОБНОГО ДОСТУПА
-- =====================================================

-- Полная информация о регистрах с развернутыми названиями
CREATE VIEW v_registers_full AS
SELECT
    r.id,
    rt.name AS register_type,
    rt.description_ru AS register_type_desc,
    s.name AS section,
    r.register_address,
    r.bit_index,
    CASE
        WHEN dt.name = 'BOOL' THEN printf('%d.%d', r.register_address, r.bit_index)
        WHEN dt.register_count = 2 THEN printf('%d-%d', r.register_address, r.register_address + 1)
        ELSE CAST(r.register_address AS TEXT)
    END AS address_formatted,
    dt.name AS data_type,
    r.variable_name,
    r.description,
    r.is_reserved,
    r.created_at,
    r.updated_at
FROM registers r
JOIN register_types rt ON r.register_type_id = rt.id
JOIN data_types dt ON r.data_type_id = dt.id
JOIN sections s ON r.section_id = s.id;

-- Статистика по секциям
CREATE VIEW v_sections_stats AS
SELECT
    s.id,
    rt.name AS register_type,
    s.name AS section,
    s.start_register,
    s.end_register,
    (s.end_register - s.start_register + 1) AS total_registers,
    COUNT(DISTINCT r.register_address) AS used_registers,
    COUNT(r.id) AS total_entries,
    SUM(CASE WHEN dt.name = 'BOOL' THEN 1 ELSE 0 END) AS bool_count,
    SUM(CASE WHEN dt.name = 'REAL' THEN 1 ELSE 0 END) AS real_count,
    SUM(CASE WHEN dt.name IN ('INT', 'UINT', 'WORD') THEN 1 ELSE 0 END) AS int_count
FROM sections s
JOIN register_types rt ON s.register_type_id = rt.id
LEFT JOIN registers r ON s.id = r.section_id
LEFT JOIN data_types dt ON r.data_type_id = dt.id
GROUP BY s.id;

-- =====================================================
-- КОНЕЦ СХЕМЫ
-- =====================================================
