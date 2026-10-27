#!/usr/bin/env bash
set -euo pipefail

# Obelawium Sales & Order Management System (Sales / OMS)
# Repository: https://github.com/obelaw/ium-sales

REPO_URL="https://github.com/obelaw/ium-sales"
TARGET_DIR="${1:-.}"

echo "=========================================================="
echo " Running PestPHP Test Suite"
echo " Repository: ${REPO_URL}"
echo " Directory:  ${TARGET_DIR}"
echo "=========================================================="

cd "${TARGET_DIR}"

if [ ! -f "composer.json" ]; then
    echo "Error: composer.json not found in ${TARGET_DIR}."
    echo "Please run this script inside the repository: ${REPO_URL}"
    exit 1
fi

if command -v cmd.exe &> /dev/null && [ -f "vendor/bin/pest.bat" ]; then
    cmd.exe /c "vendor\\bin\\pest.bat" "${@:2}"
elif [ -f "vendor/bin/pest" ]; then
    ./vendor/bin/pest "${@:2}"
else
    composer dump-autoload
    ./vendor/bin/pest "${@:2}"
fi
