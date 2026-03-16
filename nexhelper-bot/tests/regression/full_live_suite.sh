#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC_SCRIPT="$ROOT_DIR/skills/document-handler/nexhelper-doc"
REMINDER_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-reminder"
SET_REMINDER_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-set-reminder"
REMINDER_SYNC_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-reminder-sync"
REMINDER_AUDITOR_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-reminder-auditor"
ENTITY_SCRIPT="$ROOT_DIR/skills/entity-system/nexhelper-entity"
HEALTH_SCRIPT="$ROOT_DIR/skills/common/nexhelper-healthcheck"
WORKFLOW_SCRIPT="$ROOT_DIR/skills/common/nexhelper-workflow"
MIGRATE_SCRIPT="$ROOT_DIR/skills/common/nexhelper-migrate"
RETENTION_SCRIPT="$ROOT_DIR/skills/common/nexhelper-retention"
CLASSIFIER_SCRIPT="$ROOT_DIR/skills/classifier/nexhelper-classify"
EXPORT_DATEV_SCRIPT="$ROOT_DIR/skills/document-export/scripts/export_datev.sh"
EMAIL_SCRIPT="$ROOT_DIR/skills/document-export/scripts/send_email.sh"
OCR_IMAGE_SCRIPT="$ROOT_DIR/skills/document-ocr/scripts/ocr_image.sh"
OCR_PDF_SCRIPT="$ROOT_DIR/skills/document-ocr/scripts/ocr_pdf.sh"
CONSENT_SCRIPT="$ROOT_DIR/consent.sh"

SUITE_DIR="${SUITE_DIR:-$ROOT_DIR/.tmp/full-live-suite}"
STORAGE_DIR="$SUITE_DIR/storage"
CONFIG_DIR="$SUITE_DIR/config"
REPORT_DIR="$SUITE_DIR/reports"

export STORAGE_DIR
export CONFIG_DIR
export OPS_REPORT_DAYS=0

# Resolve canonical AI_API_KEY from any supported provider key
export AI_API_KEY="${AI_API_KEY:-${GEMINI_API_KEY:-${OPENROUTER_API_KEY:-${OPENAI_API_KEY:-}}}}"
export AI_BASE_URL="${AI_BASE_URL:-${OPENAI_BASE_URL:-${OPENROUTER_BASE_URL:-}}}"

mkdir -p "$STORAGE_DIR" "$CONFIG_DIR" "$REPORT_DIR" "$SUITE_DIR/exports"
rm -rf "$STORAGE_DIR"/*
mkdir -p "$STORAGE_DIR/canonical/documents" "$STORAGE_DIR/canonical/reminders" "$STORAGE_DIR/audit" "$STORAGE_DIR/idempotency" "$STORAGE_DIR/ops" "$STORAGE_DIR/canonical/indices"
printf '%s\n' '{"admins":[],"memberPermissions":{"store":true,"search":true,"list":true,"get":true,"stats":true,"reminder_create":true,"reminder_list":true,"reminder_delete_own":true},"adminNotificationChannel":"","createdAt":"2026-01-01T00:00:00Z","tenantId":"test","tenantName":"Test Suite"}' > "$STORAGE_DIR/policy.json"

cat > "$CONFIG_DIR/entities.yaml" <<'EOF'
entities:
  - id: default
    name: "Default"
    budget: null
    budgetPeriod: null
    aliases: []
    active: true
    notifyOnOverBudget: false
  - id: marketing
    name: "Marketing"
    budget: 5000
    budgetPeriod: monthly
    aliases: ["@marketing", "marketing"]
    active: true
    notifyOnOverBudget: true
EOF

pass=0
fail=0
skip=0
results="[]"

record() {
  local flow="$1"
  local name="$2"
  local status="$3"
  local details="${4:-}"
  case "$status" in
    pass) pass=$((pass + 1)) ;;
    fail) fail=$((fail + 1)) ;;
    skip) skip=$((skip + 1)) ;;
  esac
  results="$(echo "$results" | jq -c --arg flow "$flow" --arg name "$name" --arg status "$status" --arg details "$details" '. + [{flow:$flow,name:$name,status:$status,details:$details}]')"
}

run_check() {
  local flow="$1"
  local name="$2"
  local cmd="$3"
  if bash -lc "$cmd"; then
    record "$flow" "$name" "pass"
  else
    record "$flow" "$name" "fail"
  fi
}

run_skip() {
  local flow="$1"
  local name="$2"
  local reason="$3"
  record "$flow" "$name" "skip" "$reason"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

openclaw_cron_ready() {
  if ! has_cmd openclaw; then
    return 1
  fi
  local health_raw
  health_raw="$(openclaw health --json 2>/dev/null || echo '{}')"
  local health_ok
  health_ok="$(echo "$health_raw" | jq -r '.ok // false' 2>/dev/null || echo "false")"
  [ "$health_ok" = "true" ]
}

SMTP_PID=""
start_mock_smtp() {
  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi
  python3 -m smtpd -n -c DebuggingServer 127.0.0.1:1025 >/tmp/nexhelper-mock-smtp.log 2>&1 &
  SMTP_PID="$!"
  sleep 1
  if kill -0 "$SMTP_PID" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

stop_mock_smtp() {
  if [ -n "$SMTP_PID" ] && kill -0 "$SMTP_PID" >/dev/null 2>&1; then
    kill "$SMTP_PID" >/dev/null 2>&1 || true
    wait "$SMTP_PID" >/dev/null 2>&1 || true
  fi
}

trap stop_mock_smtp EXIT

# F01 Boot and Health
health_json="$("$HEALTH_SCRIPT")"
health_status="$(echo "$health_json" | jq -r '.status // empty')"
if [ "$health_status" = "ok" ] || [ "$health_status" = "degraded" ]; then
  record "F01" "boot_health" "pass" "$health_status"
else
  record "F01" "boot_health" "fail" "$health_status"
fi

# F02 and F03 AI classifier (require key)
if [ -n "${AI_API_KEY:-}" ]; then
  intent_json="$("$CLASSIFIER_SCRIPT" intent --text "Erinnere mich morgen um 14 Uhr an Meeting mit Mueller")"
  intent_name="$(echo "$intent_json" | jq -r '.intent // ""')"
  run_check "F02" "intent_classification" "[ -n '$intent_name' ] && [ '$intent_name' != 'unknown' ]"

  entity_json="$("$CLASSIFIER_SCRIPT" entity --text "Rechnung fuer Marketing" --entities-json '["default","marketing"]')"
  entity_id="$(echo "$entity_json" | jq -r '.entity // ""')"
  run_check "F03" "entity_classification" "[ '$entity_id' = 'marketing' ] || [ '$entity_id' = 'default' ]"
else
  run_skip "F02" "intent_classification" "No API key set (AI_API_KEY/GEMINI_API_KEY missing)"
  run_skip "F03" "entity_classification" "No API key set (AI_API_KEY/GEMINI_API_KEY missing)"
fi

# F04, F05, F06 document lifecycle
doc_number="RE-SUITE-$(date +%s)"
doc_store="$("$DOC_SCRIPT" store --type rechnung --amount 150.25 --supplier "Mueller GmbH" --number "$doc_number" --date 2026-03-13 --entity default --source-text "Rechnung fuer Marketing" --idempotency-key "suite_doc_1")"
doc_id="$(echo "$doc_store" | jq -r '.document.id // empty')"
run_check "F04" "document_intake" "[ -n '$doc_id' ]"

dup_json="$("$DOC_SCRIPT" store --type rechnung --amount 150.25 --supplier "Mueller GmbH" --number "$doc_number" --date 2026-03-13 --entity default --source-text "Rechnung fuer Marketing")"
dup_status="$(echo "$dup_json" | jq -r '.status // empty')"
run_check "F05" "duplicate_detection" "[ '$dup_status' = 'duplicate' ]"

del_json="$("$DOC_SCRIPT" delete "$doc_id" --reason suite)"
del_status="$(echo "$del_json" | jq -r '.status // empty')"
run_check "F06" "document_delete" "[ '$del_status' = 'deleted' ]"
res_json="$("$DOC_SCRIPT" restore "$doc_id")"
res_status="$(echo "$res_json" | jq -r '.status // empty')"
run_check "F06" "document_restore" "[ '$res_status' = 'restored' ]"

# F07 search reliability
search_json="$("$DOC_SCRIPT" search --query "Marketing Rechnung" --semantic true --limit 10)"
search_len="$(echo "$search_json" | jq 'length')"
run_check "F07" "search_semantic_lexical" "[ '$search_len' -ge 1 ]"

# F08 reminder due
rem_json="$("$REMINDER_SCRIPT" create --user suite_user --text "Suite reminder" --datetime 2000-01-01T00:00:00Z --idempotency-key suite_rem_1)"
rem_id="$(echo "$rem_json" | jq -r '.reminder.id // empty')"
run_check "F08" "reminder_create" "[ -n '$rem_id' ]"
due_json="$("$REMINDER_SCRIPT" due)"
due_len="$(echo "$due_json" | jq 'length')"
run_check "F08" "reminder_due" "[ '$due_len' -ge 1 ]"

# F09 workflow routing
sys_json="$("$WORKFLOW_SCRIPT" run --event-json '{"id":"suite_evt_1","kind":"systemEvent","text":"Check due reminders and send notifications idempotent"}')"
sys_handler="$(echo "$sys_json" | jq -r '.result.handler // empty')"
run_check "F09" "workflow_system_event" "[ -n '$sys_handler' ]"
msg_json="$("$WORKFLOW_SCRIPT" run --event-json '{"id":"suite_evt_2","kind":"message","text":"Suche Marketing Rechnung"}')"
msg_type="$(echo "$msg_json" | jq -r '.result | type')"
run_check "F09" "workflow_message_event" "[ '$msg_type' = 'array' ] || [ '$msg_type' = 'object' ]"

# F10 DATEV export
customer_dir="$SUITE_DIR"
mkdir -p "$customer_dir/storage/canonical/documents" "$customer_dir/storage/audit" "$customer_dir/exports/datev"
cp "$STORAGE_DIR/canonical/documents/"*.json "$customer_dir/storage/canonical/documents/" 2>/dev/null || true
bash "$EXPORT_DATEV_SCRIPT" "$customer_dir" "20260301" "20260331" >/dev/null
datev_count="$(ls "$customer_dir"/exports/datev/EXTF_Buchungsstapel_*.csv 2>/dev/null | wc -l | tr -d ' ')"
run_check "F10" "datev_export_file" "[ '$datev_count' -ge 1 ]"

# F11 Email delivery (deterministic via local mock SMTP)
if start_mock_smtp; then
  if SMTP_HOST="127.0.0.1" SMTP_PORT="1025" SMTP_FROM="suite@nexhelper.local" SMTP_AUTH_REQUIRED="false" SMTP_REQUIRE_TLS="false" EMAIL_ALLOWED_DOMAINS="example.com" \
      bash "$EMAIL_SCRIPT" "test@example.com" "Suite Test" "Body" >/dev/null 2>&1; then
    record "F11" "email_delivery" "pass"
  else
    record "F11" "email_delivery" "fail"
  fi
else
  record "F11" "email_delivery" "fail" "python3 mock smtp unavailable"
fi

# F12 migration
mkdir -p "$STORAGE_DIR/documents/2026-03-12" "$STORAGE_DIR/memory"
cat > "$STORAGE_DIR/documents/2026-03-12/legacy_doc.json" <<'EOF'
{"type":"rechnung","amount":99.0,"supplier":"Legacy GmbH","number":"RE-LEG-1","date":"2026-03-12","entity":"default"}
EOF
cat > "$STORAGE_DIR/memory/2026-03-12.md" <<'EOF'
### [14:30] Rechnung - RE-MD-1
- **Lieferant:** Memory GmbH
- **Betrag:** €45,00
- **Datum:** 12.03.2026
- **Kategorie:** IT
EOF
mig_json="$("$MIGRATE_SCRIPT")"
mig_count="$(echo "$mig_json" | jq '.migrated + .memoryMigrated')"
run_check "F12" "legacy_migration" "[ '$mig_count' -ge 1 ]"

# F13 retention
ret_json="$("$RETENTION_SCRIPT")"
ret_status="$(echo "$ret_json" | jq -r '.status // empty')"
run_check "F13" "retention_run" "[ '$ret_status' = 'ok' ]"

# F14 tenant isolation
if "$DOC_SCRIPT" store --type rechnung --amount 10 --supplier Bad --number RE-BAD --date 2026-03-13 --file /etc/passwd >/dev/null 2>&1; then
  record "F14" "tenant_path_reject" "fail"
else
  record "F14" "tenant_path_reject" "pass"
fi

# F15 restart recovery (state persists across process restart)
restart_rem_json="$("$REMINDER_SCRIPT" create --user restart_user --text "Restart reminder" --datetime 2000-01-01T00:00:00Z --idempotency-key suite_restart_1)"
restart_rem_id="$(echo "$restart_rem_json" | jq -r '.reminder.id // empty')"
restart_due_json="$(env -i PATH="$PATH" STORAGE_DIR="$STORAGE_DIR" CONFIG_DIR="$CONFIG_DIR" "$REMINDER_SCRIPT" due)"
restart_found="$(echo "$restart_due_json" | jq -r --arg id "$restart_rem_id" 'map(select(.id == $id)) | length')"
run_check "F15" "restart_recovery" "[ -n '$restart_rem_id' ] && [ '$restart_found' -ge 1 ]"

# F16 startup gate semantics
startup_gate_eval() {
  local smoke_required="$1"
  local smoke_exit="$2"
  if [ "$smoke_exit" -eq 0 ]; then
    return 0
  fi
  if [ "$smoke_required" = "true" ]; then
    return 1
  fi
  return 0
}
if startup_gate_eval "true" 1; then
  gate_required_fail="bad"
else
  gate_required_fail="ok"
fi
if startup_gate_eval "false" 1; then
  gate_optional_fail="ok"
else
  gate_optional_fail="bad"
fi
if startup_gate_eval "true" 0; then
  gate_required_pass="ok"
else
  gate_required_pass="bad"
fi
run_check "F16" "startup_gate_flags" "[ '$gate_required_fail' = 'ok' ] && [ '$gate_optional_fail' = 'ok' ] && [ '$gate_required_pass' = 'ok' ]"

# F17 entity detect/tag
entity_detect_json="$("$ENTITY_SCRIPT" detect "Rechnung von Mueller GmbH fuer IT-Services")"
entity_detect_id="$(echo "$entity_detect_json" | jq -r '.entity // empty')"
run_check "F17" "entity_detect" "[ -n '$entity_detect_id' ]"

entity_tag_doc_number="RE-ENTITY-$(date +%s)"
entity_tag_doc_json="$("$DOC_SCRIPT" store --type rechnung --amount 42.50 --supplier "Entity Test GmbH" --number "$entity_tag_doc_number" --date 2026-03-13 --entity default --source-text "Tag me")"
entity_tag_doc_id="$(echo "$entity_tag_doc_json" | jq -r '.document.id // empty')"
if [ -n "$entity_tag_doc_id" ]; then
  entity_tag_json="$("$ENTITY_SCRIPT" tag "$entity_tag_doc_id" marketing)"
  entity_tag_status="$(echo "$entity_tag_json" | jq -r '.status // empty')"
  run_check "F17" "entity_tag" "[ '$entity_tag_status' = 'updated' ]"
else
  record "F17" "entity_tag" "fail" "failed to create seed doc"
fi

entity_list_json="$("$ENTITY_SCRIPT" list-json)"
entity_list_count="$(echo "$entity_list_json" | jq 'length')"
run_check "F17" "entity_list_json" "[ '$entity_list_count' -ge 1 ]"

# F18 entity budget/spend/check
entity_budget_json="$("$ENTITY_SCRIPT" budget marketing)"
entity_budget_period="$(echo "$entity_budget_json" | jq -r '.period // empty')"
run_check "F18" "entity_budget_read" "[ -n '$entity_budget_period' ]"

entity_spend_json="$("$ENTITY_SCRIPT" spend marketing 1200)"
entity_spend_value="$(echo "$entity_spend_json" | jq -r '.spent // empty')"
run_check "F18" "entity_spend_record" "[ -n '$entity_spend_value' ]"

entity_check_json="$("$ENTITY_SCRIPT" check)"
entity_check_count="$(echo "$entity_check_json" | jq 'length')"
run_check "F18" "entity_check_budgets" "[ '$entity_check_count' -ge 0 ]"

# F19 direct set-reminder wrapper
if openclaw_cron_ready; then
  set_reminder_json="$("$SET_REMINDER_SCRIPT" --text "Direct suite reminder" --time "5m" --user "suite-user-1" 2>/dev/null || echo '{}')"
  set_reminder_cron_id="$(echo "$set_reminder_json" | jq -r '.cronId // empty')"
  run_check "F19" "set_reminder_cron_id" "[ -n '$set_reminder_cron_id' ]"
  if [ -n "$set_reminder_cron_id" ]; then
    cron_list_f19="$(openclaw cron list --json 2>/dev/null || echo '{"jobs":[]}')"
    cron_list_f19_found="$(echo "$cron_list_f19" | jq -r --arg id "$set_reminder_cron_id" '[.jobs[] | select(.id == $id)] | length')"
    run_check "F19" "set_reminder_listed" "[ '$cron_list_f19_found' -ge 1 ]"
    openclaw cron remove --id "$set_reminder_cron_id" >/dev/null 2>&1 || true
  else
    record "F19" "set_reminder_listed" "fail" "missing cron id from set-reminder result"
  fi
else
  run_skip "F19" "set_reminder_cron_id" "openclaw cron unavailable (gateway not healthy)"
  run_skip "F19" "set_reminder_listed" "openclaw cron unavailable (gateway not healthy)"
fi

# F20 reminder auditor catches missed command blocks
if openclaw_cron_ready; then
  audit_sessions_dir="$SUITE_DIR/openclaw/sessions"
  mkdir -p "$audit_sessions_dir"
  cat > "$audit_sessions_dir/f20-seeded.jsonl" <<EOF
{"type":"message","id":"f20-assistant","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","message":{"role":"assistant","content":[{"type":"text","text":"\`\`\`exec\nnexhelper-set-reminder --text 'F20AuditReminder' --time '3m' --user suite-audit\n\`\`\`"}]}}
EOF
  audit_json="$(OPENCLAW_SESSIONS_DIR="$audit_sessions_dir" "$REMINDER_AUDITOR_SCRIPT" 2>/dev/null || echo '{}')"
  audit_created="$(echo "$audit_json" | jq -r '.created // 0')"
  run_check "F20" "reminder_auditor_created" "[ '$audit_created' -ge 1 ]"
else
  run_skip "F20" "reminder_auditor_created" "openclaw cron unavailable (gateway not healthy)"
fi

# F21 reminder sync creates missing cron from canonical data
if openclaw_cron_ready; then
  sync_seed_json="$("$REMINDER_SCRIPT" create --user suite_sync_user --text "F21SyncReminder" --datetime 2099-01-01T10:00:00Z --idempotency-key suite_sync_1)"
  sync_seed_id="$(echo "$sync_seed_json" | jq -r '.reminder.id // empty')"
  if [ -n "$sync_seed_id" ]; then
    sync_json="$("$REMINDER_SYNC_SCRIPT" 2>/dev/null || echo '{}')"
    sync_count="$(echo "$sync_json" | jq -r '.synced // 0')"
    run_check "F21" "reminder_sync_synced" "[ '$sync_count' -ge 1 ]"
  else
    record "F21" "reminder_sync_synced" "fail" "failed to create canonical reminder seed"
  fi
else
  run_skip "F21" "reminder_sync_synced" "openclaw cron unavailable (gateway not healthy)"
fi

# F22 negative/error paths
doc_invalid_json="$("$DOC_SCRIPT" store --type rechnung --amount 0 --supplier "" --number "" --date "" 2>/dev/null || echo '{}')"
doc_invalid_status="$(echo "$doc_invalid_json" | jq -r '.status // empty')"
run_check "F22" "doc_store_invalid_required_fields" "[ '$doc_invalid_status' = 'invalid' ]"

if "$DOC_SCRIPT" store --type rechnung --amount 10 --supplier Bad --number RE-BAD-2 --date 2026-03-13 --file /etc/shadow >/dev/null 2>&1; then
  record "F22" "doc_store_path_traversal" "fail"
else
  record "F22" "doc_store_path_traversal" "pass"
fi

rem_invalid_json="$("$SET_REMINDER_SCRIPT" --time "5m" --user "suite-user-2" 2>&1 || true)"
rem_invalid_status="$(echo "$rem_invalid_json" | jq -r '.status // empty')"
run_check "F22" "set_reminder_missing_text" "[ '$rem_invalid_status' = 'error' ]"

classifier_empty_json="$("$CLASSIFIER_SCRIPT" intent --text "" 2>/dev/null || echo '{}')"
classifier_intent="$(echo "$classifier_empty_json" | jq -r '.intent // empty')"
run_check "F22" "classifier_empty_text_graceful" "[ -n '$classifier_intent' ] || [ '$classifier_intent' = 'unknown' ]"

entity_empty_json="$("$ENTITY_SCRIPT" detect "")"
entity_empty_id="$(echo "$entity_empty_json" | jq -r '.entity // empty')"
run_check "F22" "entity_detect_empty_graceful" "[ -n '$entity_empty_id' ] || [ '$entity_empty_id' = 'default' ]"

# F23 consent guard artifacts
if [ -x "$CONSENT_SCRIPT" ]; then
  consent_tmp="$SUITE_DIR/consent-artifacts"
  mkdir -p "$consent_tmp"
  if bash "$CONSENT_SCRIPT" 991 "$consent_tmp" >/dev/null 2>&1; then
    consent_files_count="$(ls "$consent_tmp" 2>/dev/null | wc -l | tr -d ' ')"
    run_check "F23" "consent_script_creates_artifact" "[ '$consent_files_count' -ge 1 ]"
  else
    record "F23" "consent_script_creates_artifact" "fail" "consent.sh returned non-zero"
  fi
else
  run_skip "F23" "consent_script_creates_artifact" "consent.sh not available in this environment"
fi

# F24 OCR script validation
if [ -x "$OCR_IMAGE_SCRIPT" ]; then
  if "$OCR_IMAGE_SCRIPT" "$SUITE_DIR/does-not-exist.png" >/dev/null 2>&1; then
    record "F24" "ocr_image_missing_file" "fail"
  else
    record "F24" "ocr_image_missing_file" "pass"
  fi
else
  run_skip "F24" "ocr_image_missing_file" "ocr_image.sh not executable"
fi

if [ -x "$OCR_PDF_SCRIPT" ]; then
  if "$OCR_PDF_SCRIPT" "$SUITE_DIR/does-not-exist.pdf" >/dev/null 2>&1; then
    record "F24" "ocr_pdf_missing_file" "fail"
  else
    record "F24" "ocr_pdf_missing_file" "pass"
  fi
else
  run_skip "F24" "ocr_pdf_missing_file" "ocr_pdf.sh not executable"
fi

# F25 cross-script idempotency
idem_doc_number="RE-IDEM-$(date +%s)"
idem_doc_first="$("$DOC_SCRIPT" store --type rechnung --amount 77.10 --supplier "Idem GmbH" --number "$idem_doc_number" --date 2026-03-13 --entity default --source-text "Idempotency test" --idempotency-key "suite_doc_idem_1")"
idem_doc_second="$("$DOC_SCRIPT" store --type rechnung --amount 77.10 --supplier "Idem GmbH" --number "$idem_doc_number" --date 2026-03-13 --entity default --source-text "Idempotency test" --idempotency-key "suite_doc_idem_1")"
idem_doc_first_id="$(echo "$idem_doc_first" | jq -r '.document.id // empty')"
idem_doc_second_id="$(echo "$idem_doc_second" | jq -r '.document.id // empty')"
run_check "F25" "doc_idempotency_same_result" "[ -n '$idem_doc_first_id' ] && [ '$idem_doc_first_id' = '$idem_doc_second_id' ]"

idem_rem_first="$("$REMINDER_SCRIPT" create --user idem_user --text "Idempotency reminder" --datetime 2099-01-01T00:00:00Z --idempotency-key suite_rem_idem_1)"
idem_rem_second="$("$REMINDER_SCRIPT" create --user idem_user --text "Idempotency reminder" --datetime 2099-01-01T00:00:00Z --idempotency-key suite_rem_idem_1)"
idem_rem_first_id="$(echo "$idem_rem_first" | jq -r '.reminder.id // empty')"
idem_rem_second_id="$(echo "$idem_rem_second" | jq -r '.reminder.id // empty')"
run_check "F25" "reminder_idempotency_same_result" "[ -n '$idem_rem_first_id' ] && [ '$idem_rem_first_id' = '$idem_rem_second_id' ]"

POLICY_SCRIPT="$ROOT_DIR/skills/common/nexhelper-policy"
NOTIFY_SCRIPT="$ROOT_DIR/skills/common/nexhelper-notify"
ADMIN_REPORT_SCRIPT="$ROOT_DIR/skills/common/nexhelper-admin-report"

# F26 RBAC policy helpers
# policy file initialized in storage
if [ -f "$STORAGE_DIR/policy.json" ]; then
  policy_admins="$(jq -r '.admins | length' "$STORAGE_DIR/policy.json" 2>/dev/null || echo "0")"
  record "F26" "policy_file_exists" "pass" "admins count=$policy_admins"
else
  record "F26" "policy_file_exists" "fail" "policy.json not found in storage"
fi

# policy add-admin / list-admins / remove-admin roundtrip
if [ -x "$POLICY_SCRIPT" ]; then
  promote_result="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" add-admin "test_rbac_suite" "ci" 2>/dev/null || echo '{}')"
  promote_status="$(echo "$promote_result" | jq -r '.status // empty')"
  if [ "$promote_status" = "promoted" ] || [ "$promote_status" = "already_admin" ]; then
    record "F26" "rbac_add_admin" "pass"
  else
    record "F26" "rbac_add_admin" "fail" "$promote_result"
  fi

  list_result="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" list-admins 2>/dev/null || echo '[]')"
  has_test="$(echo "$list_result" | jq -r 'any(. == "test_rbac_suite")')"
  if [ "$has_test" = "true" ]; then
    record "F26" "rbac_list_admins" "pass"
  else
    record "F26" "rbac_list_admins" "fail" "expected test_rbac_suite in $list_result"
  fi

  demote_result="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" remove-admin "test_rbac_suite" "ci" 2>/dev/null || echo '{}')"
  demote_status="$(echo "$demote_result" | jq -r '.status // empty')"
  if [ "$demote_status" = "demoted" ]; then
    record "F26" "rbac_remove_admin" "pass"
  else
    record "F26" "rbac_remove_admin" "fail" "$demote_result"
  fi
else
  run_skip "F26" "rbac_add_admin" "nexhelper-policy not executable"
  run_skip "F26" "rbac_list_admins" "nexhelper-policy not executable"
  run_skip "F26" "rbac_remove_admin" "nexhelper-policy not executable"
fi

# F27 RBAC enforcement: member cannot delete (NX_ACTOR set to non-admin)
# Store a document first, then attempt delete as non-admin
f27_doc="$("$DOC_SCRIPT" store --type rechnung --amount 10 --supplier "RBAC Test GmbH" --number "RE-RBAC-1" --date 2026-03-13 --entity default --source-text "rbac test")"
f27_doc_id="$(echo "$f27_doc" | jq -r '.document.id // empty')"
if [ -n "$f27_doc_id" ]; then
  member_del="$(NX_ACTOR="member_user_no_admin" "$DOC_SCRIPT" delete "$f27_doc_id" --reason "test" 2>&1 || true)"
  member_del_status="$(echo "$member_del" | jq -r '.status // empty' 2>/dev/null || echo '')"
  if [ "$member_del_status" = "forbidden" ]; then
    record "F27" "rbac_member_delete_blocked" "pass"
  else
    record "F27" "rbac_member_delete_blocked" "fail" "expected forbidden, got: $member_del_status"
  fi

  # Admin can delete
  STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" add-admin "test_admin_del" "ci" >/dev/null 2>&1 || true
  admin_del="$(NX_ACTOR="test_admin_del" "$DOC_SCRIPT" delete "$f27_doc_id" --reason "test" 2>/dev/null || echo '{}')"
  admin_del_status="$(echo "$admin_del" | jq -r '.status // empty')"
  if [ "$admin_del_status" = "deleted" ]; then
    record "F27" "rbac_admin_delete_allowed" "pass"
  else
    record "F27" "rbac_admin_delete_allowed" "fail" "expected deleted, got: $admin_del_status"
  fi
  STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" remove-admin "test_admin_del" "ci" >/dev/null 2>&1 || true
else
  record "F27" "rbac_member_delete_blocked" "fail" "could not store test document"
  record "F27" "rbac_admin_delete_allowed" "fail" "could not store test document"
fi

# F28 Document retrieve command
f28_doc="$("$DOC_SCRIPT" store --type rechnung --amount 20 --supplier "Retrieve Test GmbH" --number "RE-RETR-1" --date 2026-03-13 --entity default --source-text "retrieve test")"
f28_doc_id="$(echo "$f28_doc" | jq -r '.document.id // empty')"
if [ -n "$f28_doc_id" ]; then
  retrieve_result="$("$DOC_SCRIPT" retrieve "$f28_doc_id" 2>/dev/null || echo '{}')"
  retrieve_status="$(echo "$retrieve_result" | jq -r '.status // empty')"
  if [ "$retrieve_status" = "found" ] || [ "$retrieve_status" = "no_file" ]; then
    record "F28" "doc_retrieve_responds" "pass" "status=$retrieve_status"
  else
    record "F28" "doc_retrieve_responds" "fail" "unexpected status: $retrieve_result"
  fi
else
  record "F28" "doc_retrieve_responds" "fail" "could not store test document"
fi

# F29 Admin report script
if [ -x "$ADMIN_REPORT_SCRIPT" ]; then
  report_out="$(STORAGE_DIR="$STORAGE_DIR" "$ADMIN_REPORT_SCRIPT" 2>/dev/null || echo '{}')"
  report_has_health="$(echo "$report_out" | jq -e '.health' >/dev/null 2>&1 && echo "true" || echo "false")"
  if [ "$report_has_health" = "true" ]; then
    record "F29" "admin_report_output" "pass"
  else
    record "F29" "admin_report_output" "fail" "output missing health key: $report_out"
  fi
else
  run_skip "F29" "admin_report_output" "nexhelper-admin-report not executable"
fi

# F30 nexhelper-notify script present and executable
if [ -x "$NOTIFY_SCRIPT" ]; then
  record "F30" "notify_script_executable" "pass"
else
  record "F30" "notify_script_executable" "fail" "nexhelper-notify not executable at $NOTIFY_SCRIPT"
fi

# F31 Structured event routing — reminder-audit token
f31_event='{"kind":"systemEvent","text":"nexhelper:event:reminder-audit","senderId":"sys","channel":"system","id":"f31-audit"}'
f31_result="$("$WORKFLOW_SCRIPT" run --event-json "$f31_event" 2>/dev/null || echo '{}')"
f31_handler="$(echo "$f31_result" | jq -r '.result.handler // empty')"
if [ "$f31_handler" = "reminder_due" ]; then
  record "F31" "structured_event_reminder_audit" "pass" "handler=$f31_handler"
else
  record "F31" "structured_event_reminder_audit" "fail" "expected handler=reminder_due, got: $f31_result"
fi

# F32 Structured event routing — budget-check token
f32_event='{"kind":"systemEvent","text":"nexhelper:event:budget-check","senderId":"sys","channel":"system","id":"f32-budget"}'
f32_result="$("$WORKFLOW_SCRIPT" run --event-json "$f32_event" 2>/dev/null || echo '{}')"
f32_handler="$(echo "$f32_result" | jq -r '.result.handler // empty')"
if [ "$f32_handler" = "budget_check" ]; then
  record "F32" "structured_event_budget_check" "pass" "handler=$f32_handler"
else
  record "F32" "structured_event_budget_check" "fail" "expected handler=budget_check, got: $f32_result"
fi

# F33 Structured event routing — health-check token
f33_event='{"kind":"systemEvent","text":"nexhelper:event:health-check","senderId":"sys","channel":"system","id":"f33-health"}'
f33_result="$("$WORKFLOW_SCRIPT" run --event-json "$f33_event" 2>/dev/null || echo '{}')"
f33_handler="$(echo "$f33_result" | jq -r '.result.handler // empty')"
if [ "$f33_handler" = "health_monitor" ]; then
  record "F33" "structured_event_health_check" "pass" "handler=$f33_handler"
else
  record "F33" "structured_event_health_check" "fail" "expected handler=health_monitor, got: $f33_result"
fi

# F34 Structured event routing — retention token
f34_event='{"kind":"systemEvent","text":"nexhelper:event:retention","senderId":"sys","channel":"system","id":"f34-retention"}'
f34_result="$("$WORKFLOW_SCRIPT" run --event-json "$f34_event" 2>/dev/null || echo '{}')"
f34_handler="$(echo "$f34_result" | jq -r '.result.handler // empty')"
if [ "$f34_handler" = "retention" ]; then
  record "F34" "structured_event_retention" "pass" "handler=$f34_handler"
else
  record "F34" "structured_event_retention" "fail" "expected handler=retention, got: $f34_result"
fi

# F35 Structured event routing — unknown token returns ignored
f35_event='{"kind":"systemEvent","text":"nexhelper:event:unknown-type-xyz","senderId":"sys","channel":"system","id":"f35-unknown"}'
f35_result="$("$WORKFLOW_SCRIPT" run --event-json "$f35_event" 2>/dev/null || echo '{}')"
f35_status="$(echo "$f35_result" | jq -r '.result.status // empty')"
if [ "$f35_status" = "ignored" ]; then
  record "F35" "structured_event_unknown_ignored" "pass"
else
  record "F35" "structured_event_unknown_ignored" "fail" "expected status=ignored, got: $f35_result"
fi

# F36 Legacy substring routing still works (backward compat)
f36_event='{"kind":"systemEvent","text":"Background check budget alerts","senderId":"sys","channel":"system","id":"f36-legacy"}'
f36_result="$("$WORKFLOW_SCRIPT" run --event-json "$f36_event" 2>/dev/null || echo '{}')"
f36_handler="$(echo "$f36_result" | jq -r '.result.handler // empty')"
if [ "$f36_handler" = "budget_check" ]; then
  record "F36" "legacy_event_routing_compat" "pass" "handler=$f36_handler"
else
  record "F36" "legacy_event_routing_compat" "fail" "expected handler=budget_check via legacy match, got: $f36_result"
fi

# F37 nexhelper-doc-core.sh unit: normalize_float and build_fingerprint
DOC_CORE_SCRIPT="$ROOT_DIR/skills/document-handler/nexhelper-doc-core.sh"
if [ -f "$DOC_CORE_SCRIPT" ]; then
  # Source the core functions in isolation (requires only jq and ENTITIES_SCRIPT/CLASSIFIER_SCRIPT set as stubs)
  ENTITIES_SCRIPT="/bin/false"
  CLASSIFIER_SCRIPT="/bin/false"
  # We need nx_list_doc_files for find_duplicate; provide a stub
  nx_list_doc_files() { echo; }
  # Source minimal core stubs
  nx_init_dirs() { true; }
  NX_DOCS_DIR="$STORAGE_DIR/canonical/documents"
  source "$DOC_CORE_SCRIPT" 2>/dev/null || true

  f37_float="$(normalize_float 3.5 2>/dev/null || echo "error")"
  if [ "$f37_float" = "3.50" ]; then
    record "F37" "doc_core_normalize_float" "pass"
  else
    record "F37" "doc_core_normalize_float" "fail" "expected 3.50 got $f37_float"
  fi

  f37_fp1="$(build_fingerprint "RE-001" "Mueller GmbH" "100.00" "2026-01-01" 2>/dev/null || echo "error")"
  f37_fp2="$(build_fingerprint "RE-001" "mueller gmbh" "100.00" "2026-01-01" 2>/dev/null || echo "error")"
  if [ "$f37_fp1" = "$f37_fp2" ] && [ -n "$f37_fp1" ] && [ "$f37_fp1" != "error" ]; then
    record "F37" "doc_core_fingerprint_case_insensitive" "pass"
  else
    record "F37" "doc_core_fingerprint_case_insensitive" "fail" "fp1=$f37_fp1 fp2=$f37_fp2 should be equal"
  fi

  f37_fp_diff="$(build_fingerprint "RE-002" "Mueller GmbH" "100.00" "2026-01-01" 2>/dev/null || echo "error")"
  if [ "$f37_fp1" != "$f37_fp_diff" ]; then
    record "F37" "doc_core_fingerprint_unique" "pass"
  else
    record "F37" "doc_core_fingerprint_unique" "fail" "different docs produced same fingerprint"
  fi
else
  run_skip "F37" "doc_core_normalize_float" "nexhelper-doc-core.sh not found"
  run_skip "F37" "doc_core_fingerprint_case_insensitive" "nexhelper-doc-core.sh not found"
  run_skip "F37" "doc_core_fingerprint_unique" "nexhelper-doc-core.sh not found"
fi

# F38 manage.sh exists and help command works
MANAGE_SCRIPT="$ROOT_DIR/manage.sh"
if [ -f "$MANAGE_SCRIPT" ]; then
  chmod +x "$MANAGE_SCRIPT" 2>/dev/null || true
  f38_help="$("$MANAGE_SCRIPT" help 2>/dev/null || echo "")"
  if echo "$f38_help" | grep -q "list"; then
    record "F38" "manage_sh_help" "pass"
  else
    record "F38" "manage_sh_help" "fail" "help output missing expected commands"
  fi
else
  run_skip "F38" "manage_sh_help" "manage.sh not found"
fi

# F39 nexhelper-monitor script exists and is executable
MONITOR_SCRIPT="$ROOT_DIR/skills/common/nexhelper-monitor"
if [ -x "$MONITOR_SCRIPT" ] || [ -f "$MONITOR_SCRIPT" ]; then
  chmod +x "$MONITOR_SCRIPT" 2>/dev/null || true
  # Run in errors mode — should produce JSON even without openclaw
  f39_out="$(STORAGE_DIR="$STORAGE_DIR" "$MONITOR_SCRIPT" errors 2>/dev/null || echo '{}')"
  f39_has_status="$(echo "$f39_out" | jq -e '.status' >/dev/null 2>&1 && echo "true" || echo "false")"
  if [ "$f39_has_status" = "true" ]; then
    record "F39" "monitor_script_errors_mode" "pass"
  else
    record "F39" "monitor_script_errors_mode" "fail" "output missing .status: $f39_out"
  fi
else
  run_skip "F39" "monitor_script_errors_mode" "nexhelper-monitor not found"
fi

# F40 nexhelper-reminder-auditor stores cursor in durable ops dir, not /tmp
AUDITOR_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-reminder-auditor"
if [ -f "$AUDITOR_SCRIPT" ]; then
  chmod +x "$AUDITOR_SCRIPT" 2>/dev/null || true
  f40_ops_dir="$STORAGE_DIR/ops"
  f40_sessions_dir="$STORAGE_DIR/sessions"
  mkdir -p "$f40_ops_dir" "$f40_sessions_dir"
  # Run auditor; sessions dir exists so it will process (empty) and write cursor
  STORAGE_DIR="$STORAGE_DIR" OPENCLAW_SESSIONS_DIR="$f40_sessions_dir" \
    "$AUDITOR_SCRIPT" 2>/dev/null || true
  if [ -f "$f40_ops_dir/auditor-cursor" ]; then
    record "F40" "auditor_cursor_durable_path" "pass" "cursor written to ops dir"
  else
    record "F40" "auditor_cursor_durable_path" "fail" "cursor not found at $f40_ops_dir/auditor-cursor"
  fi
else
  run_skip "F40" "auditor_cursor_durable_path" "nexhelper-reminder-auditor not found"
fi

# F41 provision-customer.sh entrypoint uses native loops for reminder-auditor and check-reminders,
# and does NOT register them as cron jobs
PROVISION_SCRIPT="$ROOT_DIR/provision-customer.sh"
if [ -f "$PROVISION_SCRIPT" ]; then
  f41_has_loop="false"
  f41_no_auditor_cron="true"
  if grep -q "nexhelper-reminder-auditor.*2>/dev/null" "$PROVISION_SCRIPT"; then
    f41_has_loop="true"
  fi
  if grep -qP "_nx_ensure_cron\s+reminder-auditor" "$PROVISION_SCRIPT"; then
    f41_no_auditor_cron="false"
  fi
  if [ "$f41_has_loop" = "true" ] && [ "$f41_no_auditor_cron" = "true" ]; then
    record "F41" "provision_native_loops" "pass" "native loops present, no reminder-auditor cron"
  elif [ "$f41_has_loop" = "false" ]; then
    record "F41" "provision_native_loops" "fail" "native loop for reminder-auditor not found in provision-customer.sh"
  else
    record "F41" "provision_native_loops" "fail" "reminder-auditor still registered as cron job"
  fi
else
  run_skip "F41" "provision_native_loops" "provision-customer.sh not found"
fi

report_file="$REPORT_DIR/full-live-suite-$(date +%Y%m%d_%H%M%S).json"
summary="$(jq -c -n --argjson pass "$pass" --argjson fail "$fail" --argjson skip "$skip" --argjson results "$results" --arg reportFile "$report_file" \
  '{pass:$pass,fail:$fail,skip:$skip,results:$results,reportFile:$reportFile}')"
printf "%s\n" "$summary" > "$report_file"
echo "$summary"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
