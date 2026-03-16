#!/bin/bash
# nexhelper-doc-core.sh — Pure utility layer for document operations.
# Responsible for: float normalization, fingerprinting, duplicate detection, entity resolution.
# No side effects. Safe to source independently for unit testing.
# Requires: nexhelper-core.sh sourced by the caller, ENTITIES_SCRIPT and CLASSIFIER_SCRIPT set.

normalize_float() {
  local value="${1:-0}"
  LC_ALL=C awk -v n="$value" 'BEGIN {printf "%.2f", n+0}'
}

# Deterministic fingerprint from document fields. Lowercased for resilience to casing differences.
build_fingerprint() {
  local number="$1"
  local supplier="$2"
  local amount="$3"
  local doc_date="$4"
  printf "%s|%s|%s|%s" "${number,,}" "${supplier,,}" "$amount" "$doc_date" | sha256sum | awk '{print $1}'
}

# Check all active documents for a duplicate by fingerprint, file hash, or document number.
# Returns the matching document JSON or empty object.
find_duplicate() {
  local fingerprint="$1"
  local file_hash="$2"
  local doc_number="${3:-}"
  local path
  for path in $(nx_list_doc_files); do
    local candidate
    candidate="$(cat "$path")"
    if [ "$(echo "$candidate" | jq -r '.status')" != "active" ]; then
      continue
    fi
    local same_fp same_file_hash same_number
    same_fp="$(echo "$candidate" | jq -r --arg fp "$fingerprint" '.fingerprint == $fp')"
    same_file_hash="$(echo "$candidate" | jq -r --arg fh "$file_hash" '.fileHash == $fh and $fh != ""')"
    same_number="$(echo "$candidate" | jq -r --arg n "$doc_number" '.number == $n and $n != ""')"
    if [ "$same_fp" = "true" ] || [ "$same_file_hash" = "true" ] || [ "$same_number" = "true" ]; then
      echo "$candidate"
      return 0
    fi
  done
  echo "{}"
}

# Resolve which entity a document belongs to.
# Returns the explicit entity if provided, otherwise uses AI classifier on source_text.
resolve_entity() {
  local entity="$1"
  local source_text="$2"
  if [ -n "$entity" ] && [ "$entity" != "default" ]; then
    echo "$entity"
    return
  fi
  if [ -z "$source_text" ]; then
    echo "default"
    return
  fi
  local entities_json
  entities_json="$("$ENTITIES_SCRIPT" list-json)"
  "$CLASSIFIER_SCRIPT" entity --text "$source_text" --entities-json "$entities_json" \
    | jq -r '.entity // "default"'
}
