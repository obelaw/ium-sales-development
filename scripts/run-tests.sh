#!/usr/bin/env bash
set -euo pipefail

# Run PestPHP test suite for ium-sales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/../../ium-sales" && pwd)"

echo "Running PestPHP test suite in: ${MODULE_DIR}"

cd "${MODULE_DIR}"

if [ ! -f "vendor/bin/pest" ]; then
    echo "vendor/bin/pest not found. Running composer dump-autoload..."
    composer dump-autoload
fi

./vendor/bin/pest "$@"
