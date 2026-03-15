#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC_SCRIPT="$ROOT_DIR/skills/document-handler/nexhelper-doc"
REMINDER_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-reminder"
ENTITY_SCRIPT="$ROOT_DIR/skills/entity-system/nexhelper-entity"
HEALTH_SCRIPT="$ROOT_DIR/skills/common/nexhelper-healthcheck"
POLICY_SCRIPT="$ROOT_DIR/skills/common/nexhelper-policy"
ADMIN_REPORT_SCRIPT="$ROOT_DIR/skills/common/nexhelper-admin-report"
NOTIFY_SCRIPT="$ROOT_DIR/skills/common/nexhelper-notify"
WORKFLOW_SCRIPT="$ROOT_DIR/skills/common/nexhelper-workflow"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/.tmp/regression}"
STORAGE_DIR="$TMP_DIR/storage"
export STORAGE_DIR

mkdir -p "$TMP_DIR"
rm -rf "$STORAGE_DIR"
mkdir -p "$STORAGE_DIR/canonical/documents" "$STORAGE_DIR/canonical/reminders" \
         "$STORAGE_DIR/audit" "$STORAGE_DIR/idempotency" "$STORAGE_DIR/ops/smoke" \
         "$STORAGE_DIR/canonical/indices"

printf '%s\n' '{"admins":[],"memberPermissions":{"store":true,"search":true,"list":true,"get":true,"stats":true,"reminder_create":true,"reminder_list":true,"reminder_delete_own":true},"adminNotificationChannel":"","createdAt":"2026-01-01T00:00:00Z","tenantId":"test","tenantName":"Test Suite"}' \
  > "$STORAGE_DIR/policy.json"

pass=0
fail=0
results="[]"

assert_true() {
  local name="$1"
  local cmd="$2"
  if bash -c "$cmd"; then
    pass=$((pass+1))
    results="$(echo "$results" | jq -c --arg n "$name" '. + [{name:$n,status:"pass"}]')"
  else
    fail=$((fail+1))
    results="$(echo "$results" | jq -c --arg n "$name" '. + [{name:$n,status:"fail"}]')"
  fi
}

assert_json_field() {
  local name="$1"
  local json="$2"
  local field="$3"
  local expected="$4"
  local actual
  actual="$(echo "$json" | jq -r "$field // empty" 2>/dev/null || echo "")"
  if [ "$actual" = "$expected" ]; then
    pass=$((pass+1))
    results="$(echo "$results" | jq -c --arg n "$name" '. + [{name:$n,status:"pass"}]')"
  else
    fail=$((fail+1))
    results="$(echo "$results" | jq -c --arg n "$name" --arg got "$actual" --arg want "$expected" \
      '. + [{name:$n,status:"fail",got:$got,want:$want}]')"
  fi
}

# ── Document lifecycle ───────────────────────────────────────────────────────

doc_store="$("$DOC_SCRIPT" store --type rechnung --amount 120.50 --supplier "Müller GmbH" --number RE-1 --date 2026-03-12 --entity default --source-text "Rechnung für default" --idempotency-key evt_1)"
doc_id="$(echo "$doc_store" | jq -r '.document.id // empty')"
assert_true "store_document_returns_id" "[ -n '$doc_id' ]"

dupe="$("$DOC_SCRIPT" store --type rechnung --amount 120.50 --supplier "Müller GmbH" --number RE-1 --date 2026-03-12 --entity default --source-text "Rechnung für default")"
assert_json_field "duplicate_detection" "$dupe" ".status" "duplicate"

search="$("$DOC_SCRIPT" search --query Müller --limit 5)"
search_len="$(echo "$search" | jq 'length')"
assert_true "search_returns_document" "[ '$search_len' -ge 1 ]"

# ── Document retrieve ────────────────────────────────────────────────────────

retrieve="$("$DOC_SCRIPT" retrieve "$doc_id")"
retrieve_status="$(echo "$retrieve" | jq -r '.status // empty')"
assert_true "retrieve_responds_found_or_no_file" "[ '$retrieve_status' = 'found' ] || [ '$retrieve_status' = 'no_file' ]"

retrieve_has_supplier="$(echo "$retrieve" | jq -r '.supplier // empty')"
assert_true "retrieve_includes_metadata" "[ -n '$retrieve_has_supplier' ]"

retrieve_nf="$("$DOC_SCRIPT" retrieve nonexistent_doc_404)"
assert_json_field "retrieve_nonexistent_returns_not_found" "$retrieve_nf" ".status" "not_found"

# ── RBAC: soft-delete blocked for member ────────────────────────────────────

member_del="$(NX_ACTOR="member_no_admin" "$DOC_SCRIPT" delete "$doc_id" --reason test 2>&1 || true)"
assert_json_field "rbac_member_delete_blocked" "$member_del" ".status" "forbidden"

# ── RBAC: promote to admin, then delete succeeds ────────────────────────────

STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" add-admin "ci_admin_user" "test" >/dev/null
admin_del="$(NX_ACTOR="ci_admin_user" "$DOC_SCRIPT" delete "$doc_id" --reason test)"
assert_json_field "rbac_admin_delete_allowed" "$admin_del" ".status" "deleted"

restore="$("$DOC_SCRIPT" restore "$doc_id")"
assert_json_field "restore_status" "$restore" ".status" "restored"

# ── RBAC: hard-delete blocked for member ────────────────────────────────────

member_hard_del="$(NX_ACTOR="member_no_admin" "$DOC_SCRIPT" hard-delete "$doc_id" 2>&1 || true)"
assert_json_field "rbac_member_hard_delete_blocked" "$member_hard_del" ".status" "forbidden"

# ── RBAC: policy roundtrip ───────────────────────────────────────────────────

promote="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" add-admin "test_promote_u1" "ci")"
assert_json_field "policy_add_admin_status" "$promote" ".status" "promoted"

list_admins="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" list-admins)"
has_promoted="$(echo "$list_admins" | jq -r 'any(. == "test_promote_u1")')"
assert_true "policy_list_admins_contains_user" "[ '$has_promoted' = 'true' ]"

role_check="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" role "test_promote_u1")"
assert_true "policy_role_admin" "[ '$role_check' = 'admin' ]"

demote="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" remove-admin "test_promote_u1" "ci")"
assert_json_field "policy_remove_admin_status" "$demote" ".status" "demoted"

role_after="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" role "test_promote_u1")"
assert_true "policy_role_member_after_demote" "[ '$role_after' = 'member' ]"

promote_again="$(STORAGE_DIR="$STORAGE_DIR" "$POLICY_SCRIPT" add-admin "ci_admin_user" "ci")"
already_admin_status="$(echo "$promote_again" | jq -r '.status // empty')"
assert_true "policy_add_admin_idempotent" "[ '$already_admin_status' = 'promoted' ] || [ '$already_admin_status' = 'already_admin' ]"

# ── Reminders ────────────────────────────────────────────────────────────────

rem="$("$REMINDER_SCRIPT" create --user u1 --text test --datetime 2000-01-01T00:00:00Z --idempotency-key rem_evt_1)"
rem_id="$(echo "$rem" | jq -r '.reminder.id')"
assert_true "create_reminder" "[ -n '$rem_id' ]"

due="$("$REMINDER_SCRIPT" due)"
due_len="$(echo "$due" | jq 'length')"
assert_true "due_reminder_delivery" "[ '$due_len' -ge 1 ]"

# reminder delete: owner can delete own
rem2="$("$REMINDER_SCRIPT" create --user u2 --text "Own reminder" --datetime 2099-01-01T00:00:00Z)"
rem2_id="$(echo "$rem2" | jq -r '.reminder.id')"
own_del="$("$REMINDER_SCRIPT" delete "$rem2_id" --actor u2)"
assert_json_field "reminder_owner_can_delete_own" "$own_del" ".status" "deleted"

# reminder delete: different user blocked (not owner, not admin)
rem3="$("$REMINDER_SCRIPT" create --user u3 --text "Protected reminder" --datetime 2099-01-01T00:00:00Z)"
rem3_id="$(echo "$rem3" | jq -r '.reminder.id')"
other_del="$("$REMINDER_SCRIPT" delete "$rem3_id" --actor other_user 2>&1 || true)"
other_del_status="$(echo "$other_del" | jq -r '.status // empty' 2>/dev/null || echo '')"
assert_true "reminder_other_user_blocked" "[ '$other_del_status' = 'forbidden' ]"

# reminder delete: admin can delete any reminder
admin_rem_del="$(NX_ACTOR="ci_admin_user" "$REMINDER_SCRIPT" delete "$rem3_id" --actor "ci_admin_user")"
assert_json_field "reminder_admin_can_delete_any" "$admin_rem_del" ".status" "deleted"

# ── Entity + Health ──────────────────────────────────────────────────────────

entities="$("$ENTITY_SCRIPT" list-json)"
entities_type="$(echo "$entities" | jq -r 'type')"
assert_true "entity_list_json" "[ '$entities_type' = 'array' ]"

health="$("$HEALTH_SCRIPT")"
health_status="$(echo "$health" | jq -r '.status // empty')"
assert_true "healthcheck_json" "[ '$health_status' != '' ]"

# ── Admin report ─────────────────────────────────────────────────────────────

report="$(STORAGE_DIR="$STORAGE_DIR" "$ADMIN_REPORT_SCRIPT")"
assert_true "admin_report_has_health" "echo '$report' | jq -e '.health' >/dev/null 2>&1"
assert_true "admin_report_has_roles" "echo '$report' | jq -e '.roles.admins' >/dev/null 2>&1"
assert_true "admin_report_has_doc_stats" "echo '$report' | jq -e '.docStats' >/dev/null 2>&1"

# ── nexhelper-notify script present ──────────────────────────────────────────

if [ -x "$NOTIFY_SCRIPT" ]; then
  pass=$((pass+1))
  results="$(echo "$results" | jq -c '. + [{name:"notify_script_executable",status:"pass"}]')"
else
  fail=$((fail+1))
  results="$(echo "$results" | jq -c '. + [{name:"notify_script_executable",status:"fail"}]')"
fi

# ── nexhelper-doc --project store + search ───────────────────────────────────

proj_store="$(STORAGE_DIR="$STORAGE_DIR" "$DOC_SCRIPT" store \
  --type rechnung --amount 250 --supplier "BauStoff AG" \
  --number "BS-2026-001" --date 2026-03-01 \
  --project "BaustelleMusterstr" 2>/dev/null || true)"
assert_true "doc_store_project_field_set" \
  "echo '$proj_store' | jq -e '.document.project == \"BaustelleMusterstr\"' >/dev/null"
assert_true "doc_store_with_project_suggest_false" \
  "echo '$proj_store' | jq -e '.suggestProject == false' >/dev/null"

proj_search="$(STORAGE_DIR="$STORAGE_DIR" "$DOC_SCRIPT" search \
  --project "BaustelleMusterstr" --semantic false 2>/dev/null || true)"
assert_true "doc_search_project_returns_results" \
  "echo '$proj_search' | jq -e '.count > 0' >/dev/null"

proj_search_miss="$(STORAGE_DIR="$STORAGE_DIR" "$DOC_SCRIPT" search \
  --project "NichtVorhandenerProjekt" --semantic false 2>/dev/null || true)"
assert_true "doc_search_project_miss_zero_count" \
  "echo '$proj_search_miss' | jq -e '.count == 0' >/dev/null"

# stats should include byProject field (no userMessage)
proj_stats="$(STORAGE_DIR="$STORAGE_DIR" "$DOC_SCRIPT" stats 2>/dev/null || true)"
assert_true "doc_stats_has_by_project" \
  "echo '$proj_stats' | jq -e '.byProject | type == \"array\"' >/dev/null"
assert_true "doc_stats_no_user_message" \
  "echo '$proj_stats' | jq -e '.userMessage == null' >/dev/null"

# ── suggestProject: true when no --project given ──────────────────────────────

no_proj_store="$(STORAGE_DIR="$STORAGE_DIR" "$DOC_SCRIPT" store \
  --type rechnung --amount 99 --supplier "NoProj GmbH" \
  --number "NP-2026-001" --date 2026-03-10 2>/dev/null || true)"
assert_true "doc_store_no_project_suggest_true" \
  "echo '$no_proj_store' | jq -e '.suggestProject == true' >/dev/null"
assert_true "doc_store_no_user_message" \
  "echo '$no_proj_store' | jq -e '.userMessage == null' >/dev/null"

# ── nexhelper-doc append — multi-page document ───────────────────────────────

append_base="$(STORAGE_DIR="$STORAGE_DIR" "$DOC_SCRIPT" store \
  --type rechnung --amount 300 --supplier "AppendTest GmbH" \
  --number "APP-2026-001" --date 2026-03-15 2>/dev/null || true)"
append_id="$(echo "$append_base" | jq -r '.document.id // empty')"
assert_true "doc_append_base_stored" "[ -n '$append_id' ]"

if [ -n "$append_id" ]; then
  append_result="$(STORAGE_DIR="$STORAGE_DIR" "$DOC_SCRIPT" append \
    --id "$append_id" --file "/tmp/page2_test.jpg" --source-text "Seite 2" 2>/dev/null || true)"
  assert_json_field "doc_append_status" "$append_result" ".status" "appended"
  assert_true "doc_append_returns_doc_id" \
    "echo '$append_result' | jq -e --arg id '$append_id' '.docId == \$id' >/dev/null"
  assert_true "doc_append_revision_incremented" \
    "echo '$append_result' | jq -e '.revision == 2' >/dev/null"
  assert_true "doc_append_total_files" \
    "echo '$append_result' | jq -e '.totalFiles >= 1' >/dev/null"
fi

# ── workflow /start command ───────────────────────────────────────────────────

if [ -x "$WORKFLOW_SCRIPT" ]; then
  start_result="$(STORAGE_DIR="$STORAGE_DIR" "$WORKFLOW_SCRIPT" run \
    --event-json '{"id":"start_unit_test","kind":"message","text":"/start","senderId":"unit_test_user"}' \
    2>/dev/null || true)"
  assert_true "workflow_start_status" \
    "echo '$start_result' | jq -e '.result.status == \"start\"' >/dev/null"
  assert_true "workflow_start_no_user_message" \
    "echo '$start_result' | jq -e '.result.userMessage == null' >/dev/null"
  assert_true "workflow_start_has_user_id" \
    "echo '$start_result' | jq -e '.result.userId == \"unit_test_user\"' >/dev/null"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

summary="$(jq -c -n --argjson pass "$pass" --argjson fail "$fail" --argjson results "$results" \
  '{pass:$pass,fail:$fail,results:$results}')"
echo "$summary"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
