#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export CONFIG_DIR="${CONFIG_DIR:-$ROOT_DIR/config}"
export STORAGE_DIR="${STORAGE_DIR:-$ROOT_DIR/.tmp/workflow-debug/storage}"

mkdir -p "$STORAGE_DIR"

REMINDER_SCRIPT="$ROOT_DIR/skills/reminder-system/nexhelper-reminder"
WORKFLOW_SCRIPT="$ROOT_DIR/skills/common/nexhelper-workflow"

"$REMINDER_SCRIPT" create --user smoke --text "Smoke reminder" --datetime "2000-01-01T00:00:00Z" --channel telegram --idempotency-key smoke_rem_1 >/dev/null

EVENT_JSON='{"id":"smoke_evt_1","kind":"systemEvent","text":"Check due reminders and send notifications idempotent"}'

echo "EVENT_JSON=$EVENT_JSON"
bash -x "$WORKFLOW_SCRIPT" run --event-json "$EVENT_JSON"
