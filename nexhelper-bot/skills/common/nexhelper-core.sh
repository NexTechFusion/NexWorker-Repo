#!/bin/bash

set -euo pipefail

NX_STORAGE_DIR="${STORAGE_DIR:-/root/.openclaw/workspace/storage}"
NX_CANONICAL_DIR="$NX_STORAGE_DIR/canonical"
NX_DOCS_DIR="$NX_CANONICAL_DIR/documents"
NX_REMINDERS_DIR="$NX_CANONICAL_DIR/reminders"
NX_AUDIT_DIR="$NX_STORAGE_DIR/audit"
NX_IDEMPOTENCY_DIR="$NX_STORAGE_DIR/idempotency"
NX_OPS_DIR="$NX_STORAGE_DIR/ops"
NX_INDICES_DIR="$NX_CANONICAL_DIR/indices"

nx_now_iso() {
  date -Iseconds
}

nx_op_id() {
  local prefix="${1:-op}"
  printf "%s_%s_%s\n" "$prefix" "$(date +%s)" "$RANDOM"
}

nx_realpath() {
  realpath -m "$1"
}

nx_require_tenant_path() {
  local input_path="$1"
  local target
  target="$(nx_realpath "$input_path")"
  local root
  root="$(nx_realpath "$NX_STORAGE_DIR")"
  case "$target" in
    "$root"/*) ;;
    *)
      echo "Path outside tenant storage is not allowed: $input_path" >&2
      return 1
      ;;
  esac
}

nx_init_dirs() {
  mkdir -p "$NX_DOCS_DIR" "$NX_REMINDERS_DIR" "$NX_AUDIT_DIR" "$NX_IDEMPOTENCY_DIR" "$NX_OPS_DIR" "$NX_INDICES_DIR"
  nx_require_tenant_path "$NX_DOCS_DIR"
  nx_require_tenant_path "$NX_REMINDERS_DIR"
  nx_require_tenant_path "$NX_AUDIT_DIR"
  nx_require_tenant_path "$NX_IDEMPOTENCY_DIR"
  nx_require_tenant_path "$NX_OPS_DIR"
  nx_require_tenant_path "$NX_INDICES_DIR"
}

nx_append_json_line() {
  local file_path="$1"
  local json_payload="$2"
  nx_require_tenant_path "$file_path"
  mkdir -p "$(dirname "$file_path")"
  printf "%s\n" "$json_payload" >> "$file_path"
}

nx_log_event() {
  local event_name="$1"
  local op_id="$2"
  local status="$3"
  local detail_json="${4-}"
  if [ -z "$detail_json" ]; then
    detail_json="{}"
  fi
  local safe_details
  if safe_details="$(printf "%s" "$detail_json" | jq -c . 2>/dev/null)"; then
    :
  else
    safe_details="{}"
  fi
  local payload
  payload="$(jq -c -n \
    --arg ts "$(nx_now_iso)" \
    --arg event "$event_name" \
    --arg opId "$op_id" \
    --arg status "$status" \
    --argjson details "$safe_details" \
    '{timestamp:$ts,event:$event,opId:$opId,status:$status,details:$details}')"
  nx_append_json_line "$NX_AUDIT_DIR/events.ndjson" "$payload"
}

nx_hash_file() {
  local file_path="$1"
  if [ -f "$file_path" ]; then
    sha256sum "$file_path" | awk '{print $1}'
  else
    echo ""
  fi
}

nx_idempotency_has() {
  local key="$1"
  [ -f "$NX_IDEMPOTENCY_DIR/$key.json" ]
}

nx_idempotency_get() {
  local key="$1"
  cat "$NX_IDEMPOTENCY_DIR/$key.json"
}

nx_idempotency_put() {
  local key="$1"
  local payload="$2"
  local file="$NX_IDEMPOTENCY_DIR/$key.json"
  nx_require_tenant_path "$file"
  printf "%s\n" "$payload" > "$file"
}

nx_doc_path_by_id() {
  local doc_id="$1"
  echo "$NX_DOCS_DIR/$doc_id.json"
}

nx_doc_exists() {
  local doc_id="$1"
  [ -f "$(nx_doc_path_by_id "$doc_id")" ]
}

nx_write_doc_json() {
  local doc_id="$1"
  local payload="$2"
  local file
  file="$(nx_doc_path_by_id "$doc_id")"
  nx_require_tenant_path "$file"
  printf "%s\n" "$payload" > "$file"
}

nx_load_doc_json() {
  local doc_id="$1"
  local file
  file="$(nx_doc_path_by_id "$doc_id")"
  if [ -f "$file" ]; then
    cat "$file"
  else
    echo "{}"
  fi
}

nx_list_doc_files() {
  ls "$NX_DOCS_DIR"/*.json 2>/dev/null || true
}

nx_reminder_path_by_id() {
  local reminder_id="$1"
  echo "$NX_REMINDERS_DIR/$reminder_id.json"
}

nx_write_reminder_json() {
  local reminder_id="$1"
  local payload="$2"
  local file
  file="$(nx_reminder_path_by_id "$reminder_id")"
  nx_require_tenant_path "$file"
  printf "%s\n" "$payload" > "$file"
}

nx_load_reminder_json() {
  local reminder_id="$1"
  local file
  file="$(nx_reminder_path_by_id "$reminder_id")"
  if [ -f "$file" ]; then
    cat "$file"
  else
    echo "{}"
  fi
}

nx_list_reminder_files() {
  ls "$NX_REMINDERS_DIR"/*.json 2>/dev/null || true
}

nx_date_ymd_from_compact() {
  local compact="$1"
  if [[ "$compact" =~ ^[0-9]{8}$ ]]; then
    printf "%s-%s-%s\n" "${compact:0:4}" "${compact:4:2}" "${compact:6:2}"
  else
    echo "$compact"
  fi
}

nx_within_date_range() {
  local value="$1"
  local from="$2"
  local to="$3"
  if [ -n "$from" ] && [ "$value" \< "$from" ]; then
    return 1
  fi
  if [ -n "$to" ] && [ "$value" \> "$to" ]; then
    return 1
  fi
  return 0
}
