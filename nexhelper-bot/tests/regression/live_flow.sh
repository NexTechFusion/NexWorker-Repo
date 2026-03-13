#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [ -n "${OPENROUTER_API_KEY:-}" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  export OPENAI_API_KEY="$OPENROUTER_API_KEY"
fi
if [ -n "${OPENROUTER_BASE_URL:-}" ] && [ -z "${OPENAI_BASE_URL:-}" ]; then
  export OPENAI_BASE_URL="$OPENROUTER_BASE_URL"
fi

if [ -z "${OPENROUTER_API_KEY:-${OPENAI_API_KEY:-}}" ]; then
  echo '{"error":"OPENROUTER_API_KEY/OPENAI_API_KEY missing"}'
  exit 1
fi

mkdir -p "$ROOT_DIR/config"
cat > "$ROOT_DIR/config/entities.yaml" <<'EOF'
entities:
  - id: default
    name: "Default"
    budget: null
    budgetPeriod: null
    aliases: []
    active: true
    notifyOnOverBudget: false
  - id: marketing
    name: "Marketing Dept"
    budget: 5000
    budgetPeriod: monthly
    aliases: ["@marketing","marketing"]
    active: true
    notifyOnOverBudget: true
EOF

export CONFIG_DIR="$ROOT_DIR/config"
export STORAGE_DIR="${STORAGE_DIR:-$ROOT_DIR/.tmp/live/storage}"
mkdir -p "$STORAGE_DIR"

run_id="$(date +%s)"
doc_number="RE-LIVE-${run_id}"
doc_key="live_doc_${run_id}"
rem_key="live_rem_${run_id}"

intent="$(bash "$ROOT_DIR/skills/classifier/nexhelper-classify" intent --text "Erinnere mich morgen um 14 Uhr an Meeting mit Mueller")"
entity="$(bash "$ROOT_DIR/skills/classifier/nexhelper-classify" entity --text "Rechnung fuer Marketing" --entities-json '["default","marketing"]')"

store="$(bash "$ROOT_DIR/skills/document-handler/nexhelper-doc" store \
  --type rechnung \
  --amount 199.99 \
  --supplier "Mueller GmbH" \
  --number "$doc_number" \
  --date 2026-03-13 \
  --entity default \
  --category "Buero" \
  --source-text "Rechnung fuer Marketing" \
  --idempotency-key "$doc_key")"

search="$(bash "$ROOT_DIR/skills/document-handler/nexhelper-doc" search --query "Marketing Rechnung" --semantic true --limit 5)"

reminder="$(bash "$ROOT_DIR/skills/reminder-system/nexhelper-reminder" create \
  --user live_user \
  --text "Meeting mit Mueller" \
  --datetime "2000-01-01T00:00:00Z" \
  --idempotency-key "$rem_key")"

system_event="$(bash "$ROOT_DIR/skills/common/nexhelper-workflow" run --event-json '{"id":"live_evt_1","kind":"systemEvent","text":"Check due reminders and send notifications idempotent"}')"
message_event="$(bash "$ROOT_DIR/skills/common/nexhelper-workflow" run --event-json '{"id":"live_evt_2","kind":"message","text":"Suche Marketing Rechnung"}')"

jq -c -n \
  --argjson intent "$intent" \
  --argjson entity "$entity" \
  --argjson store "$store" \
  --argjson search "$search" \
  --argjson reminder "$reminder" \
  --argjson systemEvent "$system_event" \
  --argjson messageEvent "$message_event" \
  '{
    intent:$intent,
    entity:$entity,
    storeStatus:$store.status,
    docId:($store.document.id // null),
    searchCount:($search | length),
    reminderStatus:$reminder.status,
    systemEventResult:$systemEvent.result,
    messageEventResultType:($messageEvent.result | type),
    messageEventIntent:(
      if ($messageEvent.result | type) == "object" then ($messageEvent.result.intent // null)
      elif ($messageEvent.result | type) == "array" then (($messageEvent.result[0].intent) // null)
      else null end
    )
  }'
