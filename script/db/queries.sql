-- =====================================================
-- Полезные SQL запросы для работы с БД Modbus регистров
-- =====================================================
-- Использование:
--   sqlite3 modbus_registers.db < queries.sql
-- Или интерактивно:
--   sqlite3 modbus_registers.db
--   .read queries.sql

-- =====================================================
-- ПОИСК РЕГИСТРОВ
-- =====================================================

-- 1. Найти регистр по переменной PLC
-- Использование: замените 'VFD_FREQUENCY_MAX' на нужную переменную
.print '=== Поиск по переменной ==='
SELECT
    register_type,
    address_formatted AS адрес,
    data_type AS тип,
    variable_name AS переменная,
    section AS секция,
    description AS описание
FROM v_registers_full
WHERE variable_name LIKE '%VFD_FREQUENCY_MAX%';

-- 2. Найти все регистры в секции
.print ''
.print '=== Регистры в секции "Уставки ЧРП" ==='
SELECT
    address_formatted AS адрес,
    data_type AS тип,
    variable_name AS переменная,
    description AS описание
FROM v_registers_full
WHERE section LIKE '%Уставки ЧРП%'
ORDER BY register_address, bit_index;

-- 3. Найти все BOOL регистры в определённом регистре
.print ''
.print '=== Все BOOL биты в регистре 0 (Holding) ==='
SELECT
    address_formatted AS адрес,
    variable_name AS переменная,
    description AS описание
FROM v_registers_full
WHERE register_type = 'holding_registers'
  AND data_type = 'BOOL'
  AND register_address = 0
ORDER BY bit_index;

-- 4. Найти все регистры по типу данных
.print ''
.print '=== Все REAL регистры ==='
SELECT COUNT(*) AS количество FROM v_registers_full WHERE data_type = 'REAL';

-- 5. Поиск по части имени переменной
.print ''
.print '=== Переменные содержащие "FREQUENCY" ==='
SELECT
    register_type AS тип_регистра,
    address_formatted AS адрес,
    variable_name AS переменная
FROM v_registers_full
WHERE variable_name LIKE '%FREQUENCY%'
ORDER BY register_address;

-- =====================================================
-- СТАТИСТИКА
-- =====================================================

.print ''
.print '=== Общая статистика ==='
SELECT
    'Всего регистров' AS параметр,
    COUNT(*) AS значение
FROM registers
UNION ALL
SELECT
    'Всего секций',
    COUNT(DISTINCT section_id)
FROM registers
UNION ALL
SELECT
    'Holding Registers',
    COUNT(*)
FROM registers r
JOIN register_types rt ON r.register_type_id = rt.id
WHERE rt.name = 'holding_registers'
UNION ALL
SELECT
    'Input Registers',
    COUNT(*)
FROM registers r
JOIN register_types rt ON r.register_type_id = rt.id
WHERE rt.name = 'input_registers';

.print ''
.print '=== Регистры по типам данных ==='
SELECT
    dt.name AS тип_данных,
    COUNT(*) AS количество,
    printf('%.1f%%', COUNT(*) * 100.0 / (SELECT COUNT(*) FROM registers)) AS процент
FROM registers r
JOIN data_types dt ON r.data_type_id = dt.id
GROUP BY dt.name
ORDER BY количество DESC;

.print ''
.print '=== Топ-10 секций по количеству регистров ==='
SELECT
    s.name AS секция,
    COUNT(*) AS количество_регистров,
    SUM(CASE WHEN dt.name = 'BOOL' THEN 1 ELSE 0 END) AS bool,
    SUM(CASE WHEN dt.name = 'REAL' THEN 1 ELSE 0 END) AS real,
    SUM(CASE WHEN dt.name IN ('INT', 'UINT', 'WORD') THEN 1 ELSE 0 END) AS int
FROM registers r
JOIN data_types dt ON r.data_type_id = dt.id
JOIN sections s ON r.section_id = s.id
GROUP BY s.name
ORDER BY количество_регистров DESC
LIMIT 10;

-- =====================================================
-- АНАЛИЗ ИСПОЛЬЗОВАНИЯ АДРЕСОВ
-- =====================================================

.print ''
.print '=== Занятость регистровых адресов (Holding) ==='
SELECT
    s.name AS секция,
    s.start_register AS начало,
    s.end_register AS конец,
    (s.end_register - s.start_register + 1) AS всего_адресов,
    COUNT(DISTINCT r.register_address) AS занято_адресов,
    printf('%.1f%%',
        COUNT(DISTINCT r.register_address) * 100.0 /
        (s.end_register - s.start_register + 1)
    ) AS процент_использования
FROM sections s
JOIN register_types rt ON s.register_type_id = rt.id
LEFT JOIN registers r ON s.id = r.section_id
WHERE rt.name = 'holding_registers'
GROUP BY s.id
ORDER BY s.start_register;

-- 6. Найти свободные адреса в секции
.print ''
.print '=== Свободные адреса в диапазоне 0-29 (Holding) ==='
WITH RECURSIVE
    all_addresses(addr) AS (
        SELECT 0
        UNION ALL
        SELECT addr + 1 FROM all_addresses WHERE addr < 29
    ),
    used_addresses AS (
        SELECT DISTINCT register_address
        FROM registers r
        JOIN register_types rt ON r.register_type_id = rt.id
        WHERE rt.name = 'holding_registers'
          AND register_address BETWEEN 0 AND 29
    )
SELECT addr AS свободный_адрес
FROM all_addresses
WHERE addr NOT IN (SELECT register_address FROM used_addresses)
ORDER BY addr;

-- =====================================================
-- ПРОВЕРКА НА КОНФЛИКТЫ
-- =====================================================

.print ''
.print '=== Проверка на дубликаты адресов ==='
SELECT
    register_type,
    register_address AS адрес,
    bit_index AS бит,
    COUNT(*) AS количество_дубликатов,
    GROUP_CONCAT(variable_name, '; ') AS переменные
FROM v_registers_full
GROUP BY register_type, register_address, bit_index
HAVING COUNT(*) > 1;

-- =====================================================
-- ЭКСПОРТ ДАННЫХ
-- =====================================================

-- 7. Экспорт всех Holding регистров в CSV формат
.print ''
.print '=== Экспорт Holding Registers (CSV) ==='
.mode csv
.headers on
.output holding_registers.csv
SELECT
    address_formatted,
    data_type,
    variable_name,
    description,
    section
FROM v_registers_full
WHERE register_type = 'holding_registers'
ORDER BY register_address, bit_index;
.output stdout
.mode list

.print 'Экспортировано в файл: holding_registers.csv'

-- 8. Экспорт всех Input регистров в CSV формат
.output input_registers.csv
.mode csv
SELECT
    address_formatted,
    data_type,
    variable_name,
    description,
    section
FROM v_registers_full
WHERE register_type = 'input_registers'
ORDER BY register_address, bit_index;
.output stdout
.mode list

.print 'Экспортировано в файл: input_registers.csv'

-- =====================================================
-- СПЕЦИАЛЬНЫЕ ЗАПРОСЫ
-- =====================================================

-- 9. Группировка BOOL регистров по регистровому адресу
.print ''
.print '=== Группировка BOOL по адресам регистров ==='
SELECT
    register_address AS адрес_регистра,
    COUNT(*) AS количество_битов,
    GROUP_CONCAT(
        printf('Bit %d: %s', bit_index, variable_name),
        CHAR(10)
    ) AS биты
FROM v_registers_full
WHERE data_type = 'BOOL' AND register_type = 'holding_registers'
GROUP BY register_address
HAVING COUNT(*) > 1
ORDER BY register_address
LIMIT 5;

-- 10. Поиск "пустых" секций (без регистров)
.print ''
.print '=== Секции без регистров ==='
SELECT
    rt.name AS тип_регистра,
    s.name AS секция,
    s.start_register AS начало,
    s.end_register AS конец
FROM sections s
JOIN register_types rt ON s.register_type_id = rt.id
LEFT JOIN registers r ON s.id = r.section_id
WHERE r.id IS NULL;

-- =====================================================
-- КОНЕЦ ФАЙЛА ЗАПРОСОВ
-- =====================================================
