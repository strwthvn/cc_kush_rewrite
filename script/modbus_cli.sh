#!/bin/bash
# Modbus Register CLI Manager - Launcher Script
# Запуск интерактивного терминального приложения для управления БД

set -e

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/modbus_cli.py"
VENV_DIR="${SCRIPT_DIR}/../venv"

# Цвета для вывода
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

# Функция вывода ошибки
error() {
    echo -e "${COLOR_RED}❌ Ошибка: $1${COLOR_RESET}" >&2
    exit 1
}

# Функция вывода предупреждения
warning() {
    echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"
}

# Функция вывода успеха
success() {
    echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"
}

# Проверка наличия Python скрипта
if [ ! -f "$PYTHON_SCRIPT" ]; then
    error "Python скрипт не найден: $PYTHON_SCRIPT"
fi

# Проверка наличия Python 3
if ! command -v python3 &> /dev/null; then
    error "Python 3 не установлен. Установите: sudo apt-get install python3"
fi

# Проверка виртуального окружения
if [ -d "$VENV_DIR" ]; then
    success "Использование виртуального окружения: $VENV_DIR"

    # Активация виртуального окружения
    source "${VENV_DIR}/bin/activate"

    # Проверка наличия openpyxl
    if ! python3 -c "import openpyxl" 2>/dev/null; then
        warning "Библиотека openpyxl не установлена в venv"
        echo "Установка openpyxl..."
        pip install openpyxl || error "Не удалось установить openpyxl"
    fi

    # Запуск скрипта в venv
    python3 "$PYTHON_SCRIPT"
else
    warning "Виртуальное окружение не найдено: $VENV_DIR"
    echo "Использование системного Python..."

    # Проверка наличия openpyxl в системе
    if ! python3 -c "import openpyxl" 2>/dev/null; then
        warning "Библиотека openpyxl не установлена"
        echo "Для корректной работы экспорта установите:"
        echo "  pip3 install openpyxl"
        echo ""
    fi

    # Запуск скрипта с системным Python
    python3 "$PYTHON_SCRIPT"
fi
