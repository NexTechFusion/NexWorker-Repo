#!/bin/bash
# NexImo Core - Shared utilities for all NexImo skills
# Part of the NexImo apartment hunter bot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Directory Structure
# ============================================
NXIMO_STORAGE_DIR="${NXIMO_STORAGE_DIR:-$HOME/.neximo/storage}"
NXIMO_PROFILES_DIR="$NXIMO_STORAGE_DIR/profiles"
NXIMO_LISTINGS_DIR="$NXIMO_STORAGE_DIR/listings"
NXIMO_APPLICATIONS_DIR="$NXIMO_STORAGE_DIR/applications"
NXIMO_RESPONSES_DIR="$NXIMO_STORAGE_DIR/responses"
NXIMO_AUDIT_DIR="$NXIMO_STORAGE_DIR/audit"
NXIMO_IDEMPOTENCY_DIR="$NXIMO_STORAGE_DIR/idempotency"

nximo_init_dirs() {
  mkdir -p "$NXIMO_PROFILES_DIR" \
           "$NXIMO_LISTINGS_DIR" \
           "$NXIMO_APPLICATIONS_DIR" \
           "$NXIMO_RESPONSES_DIR" \
           "$NXIMO_AUDIT_DIR" \
           "$NXIMO_IDEMPOTENCY_DIR"
}

# ============================================
# ID Generation
# ============================================
nximo_op_id() {
  local prefix="${1:-op}"
  echo "${prefix}-$(date +%Y%m%d%H%M%S)-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 8 || openssl rand -hex 4)"
}

nximo_now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ============================================
# JSON Helpers
# ============================================
nximo_jq() {
  jq -c "$@"
}

nximo_json_get() {
  local file="$1"
  local path="$2"
  jq -r "$path // empty" "$file" 2>/dev/null || echo ""
}

nximo_json_set() {
  local file="$1"
  local path="$2"
  local value="$3"
  local tmp="${file}.tmp"
  jq --argjson v "$value" "$path = \$v" "$file" > "$tmp" && mv "$tmp" "$file"
}

# ============================================
# Idempotency
# ============================================
nximo_idempotency_key() {
  local op="$1"
  shift
  local data="$*"
  echo "$op:$data" | sha256sum | cut -d' ' -f1
}

nximo_idempotency_has() {
  local key="$1"
  local file="$NXIMO_IDEMPOTENCY_DIR/$key"
  [ -f "$file" ]
}

nximo_idempotency_get() {
  local key="$1"
  local file="$NXIMO_IDEMPOTENCY_DIR/$key"
  cat "$file" 2>/dev/null
}

nximo_idempotency_set() {
  local key="$1"
  local result="$2"
  local file="$NXIMO_IDEMPOTENCY_DIR/$key"
  echo "$result" > "$file"
}

# ============================================
# Audit Logging
# ============================================
nximo_audit() {
  local action="$1"
  local details="$2"
  nximo_init_dirs
  local entry
  entry="$(jq -c -n \
    --arg timestamp "$(nximo_now_iso)" \
    --arg action "$action" \
    --arg details "$details" \
    '{timestamp:$timestamp,action:$action,details:$details}')"
  echo "$entry" >> "$NXIMO_AUDIT_DIR/events.ndjson"
}

# ============================================
# Tenant Path Validation (Security)
# ============================================
nximo_require_tenant_path() {
  local path="$1"
  local resolved
  resolved="$(realpath "$path" 2>/dev/null || echo "$path")"
  case "$resolved" in
    "$NXIMO_STORAGE_DIR"*) return 0 ;;
    *) 
      echo "ERROR: Path outside tenant storage: $path" >&2
      return 1
      ;;
  esac
}

# ============================================
# Hashing
# ============================================
nximo_hash() {
  local data="$1"
  echo -n "$data" | sha256sum | cut -d' ' -f1
}

nximo_hash_file() {
  local file="$1"
  sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || echo ""
}

# ============================================
# HTTP Helpers
# ============================================
nximo_fetch() {
  local url="$1"
  local output="${2:-}"
  if [ -n "$output" ]; then
    curl -sS -L -o "$output" "$url"
  else
    curl -sS -L "$url"
  fi
}

nximo_fetch_json() {
  local url="$1"
  curl -sS -L -H "Accept: application/json" "$url"
}

# ============================================
# Messaging
# ============================================
nximo_notify() {
  local message="$1"
  local channel="${2:-telegram}"
  local chat_id="${3:-$NXIMO_CHAT_ID}"
  
  # This integrates with OpenClaw's message tool
  # In production, this would call the OpenClaw API
  echo "[NOTIFY][$channel] $message"
}

# ============================================
# Date/Time Helpers
# ============================================
nximo_parse_german_date() {
  local date_str="$1"
  # Handle German date formats: "15.03.2026", "15. März 2026", "März 2026"
  date_str=$(echo "$date_str" | sed -E \
    -e 's/Jänner?/January/i' \
    -e 's/Febr?uar?/February/i' \
    -e 's/März?/March/i' \
    -e 's/April?/April/i' \
    -e 's/Mai/May/i' \
    -e 's/Juni?/June/i' \
    -e 's/Juli?/July/i' \
    -e 's/August?/August/i' \
    -e 's/Sept?ember?/September/i' \
    -e 's/Okt?ober?/October/i' \
    -e 's/Nov?ember?/November/i' \
    -e 's/Dez?ember?/December/i' \
    -e 's/([0-9]+)\.([0-9]+)\.([0-9]+)/\2\/\1\/\3/')
  
  date -d "$date_str" +%Y-%m-%d 2>/dev/null || echo ""
}

nximo_format_currency() {
  local amount="$1"
  printf "%.0f €" "$amount"
}

# ============================================
# Listing Helpers
# ============================================
nximo_listing_id() {
  local portal="$1"
  local external_id="$2"
  nximo_hash "$portal:$external_id" | cut -c1-12
}

nximo_listing_file() {
  local listing_id="$1"
  echo "$NXIMO_LISTINGS_DIR/${listing_id}.json"
}

nximo_listing_exists() {
  local listing_id="$1"
  [ -f "$(nximo_listing_file "$listing_id")" ]
}

nximo_listing_save() {
  local listing_json="$1"
  local listing_id
  listing_id=$(echo "$listing_json" | jq -r '.id')
  nximo_init_dirs
  echo "$listing_json" > "$(nximo_listing_file "$listing_id")"
}

nximo_listing_get() {
  local listing_id="$1"
  cat "$(nximo_listing_file "$listing_id")" 2>/dev/null || echo ""
}

# ============================================
# Profile Helpers
# ============================================
nximo_profile_file() {
  local profile_id="$1"
  echo "$NXIMO_PROFILES_DIR/${profile_id}.json"
}

nximo_profile_exists() {
  local profile_id="$1"
  [ -f "$(nximo_profile_file "$profile_id")" ]
}

nximo_profile_save() {
  local profile_json="$1"
  local profile_id
  profile_id=$(echo "$profile_json" | jq -r '.id')
  nximo_init_dirs
  echo "$profile_json" > "$(nximo_profile_file "$profile_id")"
}

nximo_profile_get() {
  local profile_id="$1"
  cat "$(nximo_profile_file "$profile_id")" 2>/dev/null || echo ""
}

nximo_profile_list() {
  nximo_init_dirs
  ls -1 "$NXIMO_PROFILES_DIR"/*.json 2>/dev/null | while read -r f; do
    jq -c '{id,title,active}' "$f" 2>/dev/null
  done
}

# ============================================
# Matching Logic
# ============================================
nximo_matches_criteria() {
  local listing="$1"
  local criteria="$2"
  
  # Price check
  local listing_price
  listing_price=$(echo "$listing" | jq -r '.price // 0')
  local max_price
  max_price=$(echo "$criteria" | jq -r '.budget.max // 999999')
  local min_price
  min_price=$(echo "$criteria" | jq -r '.budget.min // 0')
  
  if [ "$listing_price" -gt "$max_price" ] || [ "$listing_price" -lt "$min_price" ]; then
    return 1
  fi
  
  # Rooms check
  local listing_rooms
  listing_rooms=$(echo "$listing" | jq -r '.rooms // 0')
  local min_rooms
  min_rooms=$(echo "$criteria" | jq -r '.rooms.min // 0')
  local max_rooms
  max_rooms=$(echo "$criteria" | jq -r '.rooms.max // 999')
  
  if [ "$(echo "$listing_rooms < $min_rooms" | bc)" -eq 1 ] || [ "$(echo "$listing_rooms > $max_rooms" | bc)" -eq 1 ]; then
    return 1
  fi
  
  # Size check
  local listing_size
  listing_size=$(echo "$listing" | jq -r '.size // 0')
  local min_size
  min_size=$(echo "$criteria" | jq -r '.size.min // 0')
  local max_size
  max_size=$(echo "$criteria" | jq -r '.size.max // 9999')
  
  if [ "$listing_size" -lt "$min_size" ] || [ "$listing_size" -gt "$max_size" ]; then
    return 1
  fi
  
  # Must-have features
  local must_have
  must_have=$(echo "$criteria" | jq -r '.must_have // [] | @json')
  if [ "$must_have" != "[]" ]; then
    local listing_features
    listing_features=$(echo "$listing" | jq -r '.features // [] | @json')
    echo "$must_have" | jq -r '.[]' | while read -r feature; do
      if ! echo "$listing_features" | jq -e "index(\"$feature\")" > /dev/null 2>&1; then
        return 1
      fi
    done
  fi
  
  return 0
}

# ============================================
# Export for sourcing
# ============================================
export NXIMO_STORAGE_DIR NXIMO_PROFILES_DIR NXIMO_LISTINGS_DIR \
       NXIMO_APPLICATIONS_DIR NXIMO_RESPONSES_DIR NXIMO_AUDIT_DIR
