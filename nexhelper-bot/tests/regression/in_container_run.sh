#!/bin/bash

set -euo pipefail

ROOT_DIR="${1:-/tmp/work}"
cd "$ROOT_DIR"

apt-get update >/dev/null
apt-get install -y jq coreutils curl python3 >/dev/null

mkdir -p "$ROOT_DIR/config"
export CONFIG_DIR="$ROOT_DIR/config"
export STORAGE_DIR="$ROOT_DIR/.tmp/regression/storage"

normalize_file() {
  local f="$1"
  tr -d '\r' < "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
}

for f in $(find "$ROOT_DIR" -type f -name "*.sh"); do
  normalize_file "$f"
done
for f in $(find "$ROOT_DIR" -type f -name "nexhelper-*"); do
  normalize_file "$f"
done
find "$ROOT_DIR" -type f -name "*.sh" -exec chmod +x {} +
find "$ROOT_DIR" -type f -name "nexhelper-*" -exec chmod +x {} +

echo "=== REGRESSION ==="
bash tests/regression/run.sh

echo "=== SMOKE ==="
bash skills/common/nexhelper-smoke

echo "=== FULL LIVE SUITE (F01-F25) ==="
bash tests/regression/full_live_suite.sh
