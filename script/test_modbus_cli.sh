#!/bin/bash
# Автоматизированный тест Modbus CLI
# Проверка основных компонентов и зависимостей

# НЕ используем set -e, чтобы продолжить тесты при ошибках

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Счётчики
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Функции для вывода
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${BLUE}  $1${RESET}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${RESET}\n"
}

test_pass() {
    echo -e "${GREEN}✅ PASS:${RESET} $1"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
}

test_fail() {
    echo -e "${RED}❌ FAIL:${RESET} $1"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
}

test_warn() {
    echo -e "${YELLOW}⚠️  WARN:${RESET} $1"
}

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_PATH="${SCRIPT_DIR}/db/modbus_registers.db"
PYTHON_SCRIPT="${SCRIPT_DIR}/modbus_cli.py"
SH_SCRIPT="${SCRIPT_DIR}/modbus_cli.sh"
EXPORT_SCRIPT="${SCRIPT_DIR}/export_to_excel.py"
VENV_DIR="${SCRIPT_DIR}/../venv"

print_header "MODBUS CLI AUTOMATED TEST SUITE"

echo "Директория тестов: $SCRIPT_DIR"
echo ""

# ========================================================================
# ТЕСТ 1: Проверка файлов
# ========================================================================
print_header "ТЕСТ 1: Проверка наличия файлов"

if [ -f "$DB_PATH" ]; then
    test_pass "База данных существует: db/modbus_registers.db"
else
    test_fail "База данных не найдена: $DB_PATH"
fi

if [ -f "$PYTHON_SCRIPT" ]; then
    test_pass "CLI скрипт существует: modbus_cli.py"
else
    test_fail "CLI скрипт не найден: $PYTHON_SCRIPT"
fi

if [ -x "$SH_SCRIPT" ]; then
    test_pass "Shell launcher существует и исполняемый: modbus_cli.sh"
else
    test_fail "Shell launcher не найден или не исполняемый: $SH_SCRIPT"
fi

if [ -f "$EXPORT_SCRIPT" ]; then
    test_pass "Скрипт экспорта существует: export_to_excel.py"
else
    test_fail "Скрипт экспорта не найден: $EXPORT_SCRIPT"
fi

# ========================================================================
# ТЕСТ 2: Проверка Python и зависимостей
# ========================================================================
print_header "ТЕСТ 2: Проверка Python и библиотек"

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    test_pass "Python 3 установлен: $PYTHON_VERSION"
else
    test_fail "Python 3 не установлен"
fi

if python3 -c "import sqlite3" 2>/dev/null; then
    test_pass "Модуль sqlite3 доступен"
else
    test_fail "Модуль sqlite3 не доступен"
fi

if python3 -c "import openpyxl" 2>/dev/null; then
    test_pass "Модуль openpyxl установлен"
else
    test_warn "Модуль openpyxl не установлен (требуется для экспорта в Excel)"
fi

# ========================================================================
# ТЕСТ 3: Проверка базы данных
# ========================================================================
print_header "ТЕСТ 3: Проверка структуры базы данных"

if [ -f "$DB_PATH" ]; then
    # Проверка таблиц
    TABLES=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null)

    if echo "$TABLES" | grep -q "registers"; then
        test_pass "Таблица 'registers' существует"
    else
        test_fail "Таблица 'registers' не найдена"
    fi

    if echo "$TABLES" | grep -q "sections"; then
        test_pass "Таблица 'sections' существует"
    else
        test_fail "Таблица 'sections' не найдена"
    fi

    if echo "$TABLES" | grep -q "data_types"; then
        test_pass "Таблица 'data_types' существует"
    else
        test_fail "Таблица 'data_types' не найдена"
    fi

    if echo "$TABLES" | grep -q "register_types"; then
        test_pass "Таблица 'register_types' существует"
    else
        test_fail "Таблица 'register_types' не найдена"
    fi

    # Проверка данных
    REG_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM registers;" 2>/dev/null)
    if [ "$REG_COUNT" -gt 0 ]; then
        test_pass "Регистры в БД: $REG_COUNT записей"
    else
        test_fail "Регистры не найдены в БД"
    fi

    SECTION_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sections;" 2>/dev/null)
    if [ "$SECTION_COUNT" -gt 0 ]; then
        test_pass "Секции в БД: $SECTION_COUNT записей"
    else
        test_fail "Секции не найдены в БД"
    fi
fi

# ========================================================================
# ТЕСТ 4: Проверка синтаксиса Python скриптов
# ========================================================================
print_header "ТЕСТ 4: Проверка синтаксиса Python скриптов"

if python3 -m py_compile "$PYTHON_SCRIPT" 2>/dev/null; then
    test_pass "modbus_cli.py: синтаксис корректен"
else
    test_fail "modbus_cli.py: ошибка синтаксиса"
fi

if python3 -m py_compile "$EXPORT_SCRIPT" 2>/dev/null; then
    test_pass "export_to_excel.py: синтаксис корректен"
else
    test_fail "export_to_excel.py: ошибка синтаксиса"
fi

# ========================================================================
# ТЕСТ 5: Проверка функций БД
# ========================================================================
print_header "ТЕСТ 5: Проверка функций базы данных"

if [ -f "$DB_PATH" ]; then
    # Проверка статистики по типам регистров
    HOLDING_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM registers r JOIN register_types rt ON r.register_type_id = rt.id WHERE rt.name = 'holding_registers';" 2>/dev/null)
    INPUT_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM registers r JOIN register_types rt ON r.register_type_id = rt.id WHERE rt.name = 'input_registers';" 2>/dev/null)

    if [ "$HOLDING_COUNT" -gt 0 ]; then
        test_pass "Holding Registers: $HOLDING_COUNT записей"
    else
        test_fail "Holding Registers: нет записей"
    fi

    if [ "$INPUT_COUNT" -gt 0 ]; then
        test_pass "Input Registers: $INPUT_COUNT записей"
    else
        test_fail "Input Registers: нет записей"
    fi

    # Проверка типов данных
    BOOL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM registers r JOIN data_types dt ON r.data_type_id = dt.id WHERE dt.name = 'BOOL';" 2>/dev/null)
    REAL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM registers r JOIN data_types dt ON r.data_type_id = dt.id WHERE dt.name = 'REAL';" 2>/dev/null)

    if [ "$BOOL_COUNT" -gt 0 ]; then
        test_pass "BOOL регистры: $BOOL_COUNT записей"
    else
        test_fail "BOOL регистры: нет записей"
    fi

    if [ "$REAL_COUNT" -gt 0 ]; then
        test_pass "REAL регистры: $REAL_COUNT записей"
    else
        test_fail "REAL регистры: нет записей"
    fi
fi

# ========================================================================
# ТЕСТ 6: Проверка экспорта в Excel (если установлен openpyxl)
# ========================================================================
print_header "ТЕСТ 6: Проверка экспорта в Excel"

if python3 -c "import openpyxl" 2>/dev/null; then
    # Удалить старый файл экспорта
    rm -f "${SCRIPT_DIR}/modbus_map.xlsx"

    # Запустить экспорт
    if python3 "$EXPORT_SCRIPT" > /dev/null 2>&1; then
        test_pass "Экспорт выполнен без ошибок"

        if [ -f "${SCRIPT_DIR}/modbus_map.xlsx" ]; then
            FILE_SIZE=$(ls -lh "${SCRIPT_DIR}/modbus_map.xlsx" | awk '{print $5}')
            test_pass "Excel файл создан: modbus_map.xlsx ($FILE_SIZE)"
        else
            test_fail "Excel файл не создан"
        fi
    else
        test_fail "Ошибка при экспорте"
    fi
else
    test_warn "Экспорт пропущен: openpyxl не установлен"
fi

# ========================================================================
# ТЕСТ 7: Проверка документации
# ========================================================================
print_header "ТЕСТ 7: Проверка документации"

if [ -f "${SCRIPT_DIR}/README_CLI.md" ]; then
    test_pass "Документация существует: README_CLI.md"
else
    test_fail "Документация не найдена: README_CLI.md"
fi

if [ -f "${SCRIPT_DIR}/QUICKSTART.md" ]; then
    test_pass "Краткое руководство существует: QUICKSTART.md"
else
    test_fail "Краткое руководство не найдено: QUICKSTART.md"
fi

if [ -f "${SCRIPT_DIR}/test_cli_usage.md" ]; then
    test_pass "Тестовые сценарии существуют: test_cli_usage.md"
else
    test_fail "Тестовые сценарии не найдены: test_cli_usage.md"
fi

# ========================================================================
# ТЕСТ 8: Проверка прав доступа
# ========================================================================
print_header "ТЕСТ 8: Проверка прав доступа"

if [ -x "$SH_SCRIPT" ]; then
    test_pass "modbus_cli.sh имеет права на выполнение"
else
    test_fail "modbus_cli.sh не имеет прав на выполнение"
fi

if [ -r "$DB_PATH" ]; then
    test_pass "База данных доступна для чтения"
else
    test_fail "База данных недоступна для чтения"
fi

if [ -w "$DB_PATH" ]; then
    test_pass "База данных доступна для записи"
else
    test_fail "База данных недоступна для записи"
fi

# ========================================================================
# РЕЗУЛЬТАТЫ
# ========================================================================
print_header "РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ"

echo "Всего тестов:     $TESTS_TOTAL"
echo -e "${GREEN}Успешно:          $TESTS_PASSED${RESET}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Провалено:        $TESTS_FAILED${RESET}"
else
    echo -e "${GREEN}Провалено:        $TESTS_FAILED${RESET}"
fi

PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
echo "Успешность:       $PASS_RATE%"

echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║                 ВСЕ ТЕСТЫ ПРОЙДЕНЫ!                      ║${RESET}"
    echo -e "${GREEN}║         Приложение готово к использованию               ║${RESET}"
    echo -e "${GREEN}║                                                          ║${RESET}"
    echo -e "${GREEN}║  Запуск: ./modbus_cli.sh                                 ║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║             НЕКОТОРЫЕ ТЕСТЫ ПРОВАЛЕНЫ!                  ║${RESET}"
    echo -e "${RED}║      Исправьте ошибки перед использованием               ║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
    exit 1
fi
