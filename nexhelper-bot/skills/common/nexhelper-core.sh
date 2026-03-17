#!/bin/bash

set -euo pipefail

NX_STORAGE_DIR="${STORAGE_DIR:-/root/.openclaw/workspace/storage}"
NX_POLICY_FILE="${NX_STORAGE_DIR}/policy.json"
NX_CANONICAL_DIR="$NX_STORAGE_DIR/canonical"
NX_DOCS_DIR="$NX_CANONICAL_DIR/documents"
NX_REMINDERS_DIR="$NX_CANONICAL_DIR/reminders"
NX_AUDIT_DIR="$NX_STORAGE_DIR/audit"
NX_IDEMPOTENCY_DIR="$NX_STORAGE_DIR/idempotency"
NX_OPS_DIR="$NX_STORAGE_DIR/ops"
NX_INDICES_DIR="$NX_CANONICAL_DIR/indices"
NX_METRICS_FILE="$NX_OPS_DIR/metrics.ndjson"

nx_now_iso() {
  date -Iseconds
}

# ─── Metrics ──────────────────────────────────────────────────────────────────

nx_metric_emit() {
  local name="$1"
  local value="$2"
  local tags="${3:-}"
  local payload
  payload="$(jq -c -n \
    --arg ts "$(nx_now_iso)" \
    --arg name "$name" \
    --argjson value "$value" \
    --arg tags "$tags" \
    '{timestamp:$ts,metric:$name,value:$value,tags:$tags}')"
  mkdir -p "$NX_OPS_DIR" 2>/dev/null || true
  printf "%s\n" "$payload" >> "$NX_METRICS_FILE"
}

nx_metric_count() {
  local name="$1"
  local tags="${2:-}"
  nx_metric_emit "$name" 1 "$tags"
}

nx_metric_histogram() {
  local name="$1"
  local value="$2"
  local tags="${3:-}"
  nx_metric_emit "$name" "$value" "$tags"
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

nx_policy_load() {
  if [ -f "$NX_POLICY_FILE" ]; then
    cat "$NX_POLICY_FILE"
  else
    echo '{"admins":[],"memberPermissions":{"store":true,"search":true,"list":true,"get":true,"stats":true,"reminder_create":true,"reminder_list":true,"reminder_delete_own":true},"adminNotificationChannel":"","adminIds":[]}'
  fi
}

nx_role_get() {
  local user_id="$1"
  if [ -z "$user_id" ]; then
    echo "member"
    return
  fi
  local policy
  policy="$(nx_policy_load)"
  local is_admin
  is_admin="$(echo "$policy" | jq -r --arg u "$user_id" '.admins | any(. == $u)')"
  if [ "$is_admin" = "true" ]; then
    echo "admin"
  else
    echo "member"
  fi
}

nx_require_admin() {
  local user_id="$1"
  local action="${2:-action}"
  local role
  role="$(nx_role_get "$user_id")"
  if [ "$role" != "admin" ]; then
    jq -c -n \
      --arg status "forbidden" \
      --arg action "$action" \
      --arg user "$user_id" \
      --arg role "$role" \
      '{status:$status,action:$action,user:$user,role:$role,message:"Diese Aktion erfordert Admin-Berechtigung."}'
    return 1
  fi
  return 0
}

nx_is_admin() {
  local user_id="$1"
  [ "$(nx_role_get "$user_id")" = "admin" ]
}

nx_policy_add_admin() {
  local user_id="$1"
  local promoted_by="${2:-system}"
  local policy
  policy="$(nx_policy_load)"
  local already
  already="$(echo "$policy" | jq -r --arg u "$user_id" '.admins | any(. == $u)')"
  if [ "$already" = "true" ]; then
    jq -c -n --arg u "$user_id" '{status:"already_admin",userId:$u}'
    return
  fi
  mkdir -p "$(dirname "$NX_POLICY_FILE")"
  local updated
  updated="$(echo "$policy" | jq -c --arg u "$user_id" '.admins += [$u]')"
  printf "%s\n" "$updated" > "$NX_POLICY_FILE"
  jq -c -n --arg u "$user_id" --arg by "$promoted_by" '{status:"promoted",userId:$u,promotedBy:$by}'
}

nx_policy_remove_admin() {
  local user_id="$1"
  local demoted_by="${2:-system}"
  local policy
  policy="$(nx_policy_load)"
  mkdir -p "$(dirname "$NX_POLICY_FILE")"
  local updated
  updated="$(echo "$policy" | jq -c --arg u "$user_id" '.admins = [.admins[] | select(. != $u)]')"
  printf "%s\n" "$updated" > "$NX_POLICY_FILE"
  jq -c -n --arg u "$user_id" --arg by "$demoted_by" '{status:"demoted",userId:$u,demotedBy:$by}'
}

nx_policy_list_admins() {
  nx_policy_load | jq -c '.admins'
}

nx_policy_get_admin_ids() {
  nx_policy_load | jq -r '.admins[]' 2>/dev/null || true
}

nx_policy_has_any_admin() {
  local count
  count="$(nx_policy_load | jq '.admins | length')"
  [ "$count" -gt 0 ]
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

# ─── User Registry ────────────────────────────────────────────────────────────
# Persists user_id ↔ username pairs so admins can resolve @username → user_id.
# File: $NX_STORAGE_DIR/users.json  (JSON object keyed by user_id)

NX_USERS_FILE="${NX_STORAGE_DIR}/users.json"

nx_user_load() {
  if [ -f "$NX_USERS_FILE" ]; then
    cat "$NX_USERS_FILE"
  else
    echo '{}'
  fi
}

nx_user_seen() {
  local user_id="$1"
  local username="${2:-}"
  local display_name="${3:-}"
  local users
  users="$(nx_user_load)"
  local now
  now="$(nx_now_iso)"
  local is_new
  is_new="$(echo "$users" | jq -r --arg u "$user_id" 'has($u) | not')"
  local updated
  updated="$(echo "$users" | jq -c \
    --arg u "$user_id" \
    --arg name "$username" \
    --arg display "$display_name" \
    --arg ts "$now" \
    '.[$u] = {userId:$u, username:$name, displayName:$display, lastSeen:$ts} + (if .[$u] then {firstSeen: .[$u].firstSeen} else {firstSeen:$ts} end)')"
  mkdir -p "$(dirname "$NX_USERS_FILE")"
  printf "%s\n" "$updated" > "$NX_USERS_FILE"
  echo "$is_new"
}

nx_user_is_new() {
  local user_id="$1"
  local users
  users="$(nx_user_load)"
  echo "$users" | jq -r --arg u "$user_id" 'has($u) | not'
}

nx_user_find_by_username() {
  local username="$1"
  local clean_name="${username#@}"
  nx_user_load | jq -c --arg n "$clean_name" 'to_entries[] | select(.value.username == $n or .value.displayName == $n) | .value' 2>/dev/null | head -1
}

# ─── Time Parsing Utilities ──────────────────────────────────────────────────

# ─── Multilingual Time Parser ──────────────────────────────────────────────────
# Convert natural language time expressions to absolute ISO timestamp
# Supports: German, English, simple formats (2m, 1h), ISO timestamps
# Handles typos and variations
# Usage: nx_parse_relative_time "in 2 Minuten" -> "2026-03-16T17:07:00Z"
nx_parse_relative_time() {
  local input="$1"
  
  # Empty input
  if [ -z "$input" ]; then
    echo ""
    return 1
  fi
  
  # Normalize: lowercase, trim whitespace, collapse multiple spaces
  local normalized
  normalized=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' ')
  
  # Check if already an ISO timestamp (contains T or starts with date pattern)
  if [[ "$normalized" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]] || [[ "$normalized" =~ T ]]; then
    echo "$input"
    return 0
  fi
  
  local seconds=0
  local found=0
  
  # ─── Simple formats: 2m, 1h, 30s, 1d ────────────────────────────────────────
  if [[ "$normalized" =~ ^([0-9]+)([smhd])$ ]]; then
    local num="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[2]}"
    case "$unit" in
      s) seconds=$num ;;
      m) seconds=$((num * 60)) ;;
      h) seconds=$((num * 3600)) ;;
      d) seconds=$((num * 86400)) ;;
    esac
    found=1
  fi
  
  # ─── Pattern: "in X [unit]" (German/English) ─────────────────────────────────
  if [[ $found -eq 0 ]]; then
    # German: "in 2 minuten", "in 2 minute", "in 2 min", "in einer stunde"
    # English: "in 2 minutes", "in 2 mins", "in an hour", "in 1 hour"
    # Typos: "in 2min", "in2 minuten", "in 2minute"
    
    # Minutes patterns
    if [[ "$normalized" =~ in[[:space:]]*([0-9]+)[[:space:]]*(min|minute|minutes|minuten|minute?n?|mins) ]]; then
      seconds=$((${BASH_REMATCH[1]} * 60))
      found=1
    # Hours patterns
    elif [[ "$normalized" =~ in[[:space:]]*([0-9]+)[[:space:]]*(stunde|stunden|hour|hours|std|h) ]]; then
      seconds=$((${BASH_REMATCH[1]} * 3600))
      found=1
    # Days patterns
    elif [[ "$normalized" =~ in[[:space:]]*([0-9]+)[[:space:]]*(tag|tage|tagen|day|days|d) ]]; then
      seconds=$((${BASH_REMATCH[1]} * 86400))
      found=1
    # Seconds patterns
    elif [[ "$normalized" =~ in[[:space:]]*([0-9]+)[[:space:]]*(sekunde|sekunden|second|seconds|sec|sek|s) ]]; then
      seconds=${BASH_REMATCH[1]}
      found=1
    # "in einer/einem" (German indefinite article)
    elif [[ "$normalized" =~ in[[:space:]]*(einer|einem)[[:space:]]*(stunde|hour) ]]; then
      seconds=3600
      found=1
    elif [[ "$normalized" =~ in[[:space:]]*(einer|einem)[[:space:]]*(minute|min) ]]; then
      seconds=60
      found=1
    # "in an hour", "in a minute" (English)
    elif [[ "$normalized" =~ in[[:space:]]*(an|a)[[:space:]]*hour ]]; then
      seconds=3600
      found=1
    elif [[ "$normalized" =~ in[[:space:]]*(an|a)[[:space:]]*minute ]]; then
      seconds=60
      found=1
    fi
  fi
  
  # ─── Pattern: "X [unit]" without "in" ───────────────────────────────────────
  if [[ $found -eq 0 ]]; then
    if [[ "$normalized" =~ ^([0-9]+)[[:space:]]*(min|minute|minutes|minuten|mins)$ ]]; then
      seconds=$((${BASH_REMATCH[1]} * 60))
      found=1
    elif [[ "$normalized" =~ ^([0-9]+)[[:space:]]*(stunde|stunden|hour|hours|std|h)$ ]]; then
      seconds=$((${BASH_REMATCH[1]} * 3600))
      found=1
    elif [[ "$normalized" =~ ^([0-9]+)[[:space:]]*(tag|tage|tagen|day|days|d)$ ]]; then
      seconds=$((${BASH_REMATCH[1]} * 86400))
      found=1
    elif [[ "$normalized" =~ ^([0-9]+)[[:space:]]*(sekunde|sekunden|second|seconds|sec|sek|s)$ ]]; then
      seconds=${BASH_REMATCH[1]}
      found=1
    fi
  fi
  
  # ─── Special keywords: morgen, übermorgen, tomorrow ─────────────────────────
  if [[ $found -eq 0 ]]; then
    case "$normalized" in
      morgen|tomorrow|tmrw|tmr|tom)
        seconds=86400
        found=1
        ;;
      übermorgen|uebermorgen|ubermorgen|day\ after\ tomorrow|in\ 2\ days|in\ two\ days)
        seconds=$((86400 * 2))
        found=1
        ;;
      heute|today)
        seconds=0
        found=1
        ;;
      "in einer woche"|"in one week"|"in 1 week"|"in einer woche")
        seconds=$((86400 * 7))
        found=1
        ;;
    esac
  fi
  
  # ─── Pattern: "halbe stunde", "half an hour" ────────────────────────────────
  if [[ $found -eq 0 ]]; then
    if [[ "$normalized" =~ (halb|half).*?(stunde|hour) ]]; then
      seconds=1800
      found=1
    elif [[ "$normalized" =~ (viertel|quarter).*?(stunde|hour) ]]; then
      seconds=900
      found=1
    fi
  fi
  
  # ─── Fallback: Could not parse ─────────────────────────────────────────────
  if [[ $found -eq 0 ]]; then
    echo "$input"
    return 1
  fi
  
  # ─── Calculate absolute timestamp ──────────────────────────────────────────
  if [[ $seconds -eq 0 ]]; then
    # "heute" / "today" - return current time
    date -u +"%Y-%m-%dT%H:%M:%SZ"
  elif date -u -d "@$(($(date +%s) + seconds))" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null; then
    return 0
  elif date -u -v+${seconds}S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null; then
    return 0
  else
    echo "$input"
    return 1
  fi
}

# Check if a string looks like a valid ISO timestamp
# Usage: nx_is_iso_timestamp "2026-03-16T17:00:00Z" -> returns 0
nx_is_iso_timestamp() {
  local input="$1"
  [[ "$input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]
}
