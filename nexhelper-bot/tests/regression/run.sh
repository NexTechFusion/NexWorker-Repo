#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC_SCRIPT="$ROOT_DIR/skills/document-handler/nexhelper-doc"
REMINDER_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-reminder"
ENTITY_SCRIPT="$ROOT_DIR/skills/entity-system/nexhelper-entity"
HEALTH_SCRIPT="$ROOT_DIR/skills/common/nexhelper-healthcheck"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/.tmp/regression}"
STORAGE_DIR="$TMP_DIR/storage"
export STORAGE_DIR

mkdir -p "$TMP_DIR"
rm -rf "$STORAGE_DIR"
mkdir -p "$STORAGE_DIR"

pass=0
fail=0
results="[]"

assert_true() {
  local name="$1"
  local expr="$2"
  if eval "$expr"; then
    pass=$((pass+1))
    results="$(echo "$results" | jq -c --arg n "$name" '. + [{name:$n,status:"pass"}]')"
  else
    fail=$((fail+1))
    results="$(echo "$results" | jq -c --arg n "$name" '. + [{name:$n,status:"fail"}]')"
  fi
}

doc_store="$("$DOC_SCRIPT" store --type rechnung --amount 120.50 --supplier "Müller GmbH" --number RE-1 --date 2026-03-12 --entity default --source-text "Rechnung für default" --idempotency-key evt_1)"
doc_id="$(echo "$doc_store" | jq -r '.document.id // empty')"
assert_true "store_document_returns_id" "[ -n \"$doc_id\" ]"

dupe="$("$DOC_SCRIPT" store --type rechnung --amount 120.50 --supplier "Müller GmbH" --number RE-1 --date 2026-03-12 --entity default --source-text \"Rechnung für default\")"
assert_true "duplicate_detection" "[ \"$(echo \"$dupe\" | jq -r '.status')\" = \"duplicate\" ]"

search="$("$DOC_SCRIPT" search --query Müller --limit 5)"
assert_true "search_returns_document" "[ \"$(echo \"$search\" | jq 'length')\" -ge 1 ]"

del="$("$DOC_SCRIPT" delete "$doc_id" --reason test)"
assert_true "soft_delete_status" "[ \"$(echo \"$del\" | jq -r '.status')\" = \"deleted\" ]"

restore="$("$DOC_SCRIPT" restore "$doc_id")"
assert_true "restore_status" "[ \"$(echo \"$restore\" | jq -r '.status')\" = \"restored\" ]"

rem="$("$REMINDER_SCRIPT" create --user u1 --text test --datetime 2000-01-01T00:00:00Z --idempotency-key rem_evt_1)"
rem_id="$(echo "$rem" | jq -r '.reminder.id')"
assert_true "create_reminder" "[ -n \"$rem_id\" ]"

due="$("$REMINDER_SCRIPT" due)"
assert_true "due_reminder_delivery" "[ \"$(echo \"$due\" | jq 'length')\" -ge 1 ]"

entities="$("$ENTITY_SCRIPT" list-json)"
assert_true "entity_list_json" "[ \"$(echo \"$entities\" | jq -r 'type')\" = \"array\" ]"

health="$("$HEALTH_SCRIPT")"
assert_true "healthcheck_json" "[ \"$(echo \"$health\" | jq -r '.status')\" != \"\" ]"

summary="$(jq -c -n --argjson pass "$pass" --argjson fail "$fail" --argjson results "$results" \
  '{pass:$pass,fail:$fail,results:$results}')"
echo "$summary"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
