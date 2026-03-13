#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC_SCRIPT="$ROOT_DIR/skills/document-handler/nexhelper-doc"
REMINDER_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-reminder"
ENTITY_SCRIPT="$ROOT_DIR/skills/entity-system/nexhelper-entity"
HEALTH_SCRIPT="$ROOT_DIR/skills/common/nexhelper-healthcheck"

TMP_DIR="${TMP_DIR:-$ROOT_DIR/.tmp/regression-debug}"
STORAGE_DIR="$TMP_DIR/storage"
export STORAGE_DIR

mkdir -p "$TMP_DIR"
rm -rf "$STORAGE_DIR"
mkdir -p "$STORAGE_DIR"

echo "OUT: store"
doc_store="$("$DOC_SCRIPT" store --type rechnung --amount 120.50 --supplier "Mueller GmbH" --number RE-1 --date 2026-03-12 --entity default --source-text "Rechnung fuer default" --idempotency-key evt_1 || true)"
printf '%s\n' "$doc_store"

doc_id="$(echo "$doc_store" | jq -r '.document.id // empty' 2>/dev/null || true)"
echo "DOC_ID=$doc_id"

echo "OUT: duplicate"
dupe="$("$DOC_SCRIPT" store --type rechnung --amount 120.50 --supplier "Mueller GmbH" --number RE-1 --date 2026-03-12 --entity default --source-text "Rechnung fuer default" || true)"
printf '%s\n' "$dupe"

echo "OUT: delete"
del="$("$DOC_SCRIPT" delete "$doc_id" --reason test || true)"
printf '%s\n' "$del"

echo "OUT: restore"
restore="$("$DOC_SCRIPT" restore "$doc_id" || true)"
printf '%s\n' "$restore"

echo "OUT: entity list-json"
entities="$("$ENTITY_SCRIPT" list-json || true)"
printf '%s\n' "$entities"

echo "OUT: health"
health="$("$HEALTH_SCRIPT" || true)"
printf '%s\n' "$health"

echo "OUT: reminder create"
rem="$("$REMINDER_SCRIPT" create --user u1 --text test --datetime 2000-01-01T00:00:00Z --idempotency-key rem_evt_1 || true)"
printf '%s\n' "$rem"
