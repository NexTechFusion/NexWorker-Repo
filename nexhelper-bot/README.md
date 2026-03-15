# NexHelper Bot

Messenger-native office assistant for German SMBs: document intake, reminders, search, exports, and auditable workflows.

## What It Does

NexHelper runs on top of OpenClaw and is optimized for chat-first operations (Telegram/WhatsApp):

- Receive invoices/quotes/receipts from chat
- Extract and store canonical records
- Detect duplicates and support soft-delete/restore
- Create and trigger reminders
- Export accounting data (DATEV + integrations)
- Keep per-tenant storage, audit trails, and retention controls

## Architecture

Each customer is isolated:

- One dedicated Docker container
- One dedicated storage root
- One dedicated OpenClaw workspace/session space
- Canonical data under `storage/canonical` plus auditable `systemEvent` flows
Primary components:

- `skills/document-handler/nexhelper-doc`
- `skills/reminder-system/nexhelper-reminder`
- `skills/reminder-system/nexhelper-set-reminder`
- `skills/common/nexhelper-workflow`
- `skills/common/nexhelper-healthcheck`
- `skills/common/nexhelper-smoke`

## Quick Start

### 1) Initial setup

```bash
cd nexhelper-bot
./setup-nexhelper.sh
```

### 2) Set API key (OpenRouter-first)

```bash
export OPENROUTER_API_KEY="sk-or-..."
export OPENROUTER_BASE_URL="https://openrouter.ai/api/v1"
```

Compatibility fallback still works:

```bash
export OPENAI_API_KEY="$OPENROUTER_API_KEY"
export OPENAI_BASE_URL="$OPENROUTER_BASE_URL"
```

### 3) Provision customer

Telegram:

```bash
./provision-customer.sh 001 "Acme GmbH" --telegram "123456789:ABC-DEF..."
```

WhatsApp:

```bash
./provision-customer.sh 002 "Mueller Bau" --whatsapp
```

### 4) Start and operate

Provisioning outputs scripts in the customer directory:

- `start.sh`
- `stop.sh`
- `status.sh`
- `logs.sh`
- `health.sh`
- `smoke.sh`
- `migrate.sh`
- `retention.sh`
- `consent.sh`
- `remove.sh`

## Testing and Quality Gates

### Regression entry points

- `tests/regression/run.sh` (script-level regression)
- `tests/regression/run.ps1` (Windows + Docker)
- `tests/regression/smoke.ps1`
- `tests/regression/in_container_run.sh` (container orchestration)
- `tests/regression/full_live_suite.sh` (F01-F25)
- `tests/regression/gateway_session_suite.ps1` (live gateway/chat simulation)

### Current suite scope

`full_live_suite.sh` validates:

- F01-F16 core system behavior (health, classifier, document lifecycle, reminder lifecycle, workflow, DATEV/email, migration, retention, path safety, restart semantics, startup gate)
- F17-F25 advanced checks (entity detect/tag/budget, set-reminder wrapper, auditor/sync integration, error paths, OCR negative-path, cross-script idempotency)

`gateway_session_suite.ps1` validates:

- Provisioning + container health
- Multi-turn chat stability
- Direct cron lifecycle
- Agent reminder creation and firing
- Agent doc intake/search/off-topic handling
- Multi-turn context overwrite behavior
- Long-thread continuity edge case
- Session-isolation edge check

### Smoke on startup

`start.sh` supports:

- `RUN_SMOKE_ON_START=false` to disable startup smoke
- `SMOKE_REQUIRED_ON_START=true` to fail startup if smoke fails

## Security and Compliance

- Tenant path guardrails on file operations
- Canonical audit logging for ops and migration
- Retention cleanup via `nexhelper-retention`
- Consent and deletion support (`consent.sh`, `remove.sh`)
- Isolated tenant deployment model

## Ops Runbook (Live Instances)

Use this for already running customer containers where cron delivery or provider wiring is broken.

1. Verify cron jobs and delivery target:

```bash
docker exec -it <container> openclaw cron list --json
```

1. Repair invalid `delivery.to` for each affected job:

```bash
docker exec -it <container> openclaw cron edit --id <JOB_ID> --to telegram:579539601
```

1. Confirm job execution status:

```bash
docker exec -it <container> openclaw cron runs --id <JOB_ID> --limit 5
```

1. Verify OpenRouter-compatible API routing (avoid OpenAI 401 with `sk-or-v1-*`):

```bash
docker exec -it <container> sh -lc 'env | grep -E "OPENAI_BASE_URL|OPENROUTER_API_KEY|USE_OPENROUTER|EMBEDDING_MODEL"'
```

1. Verify dashboard/network reachability:

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
curl -f http://localhost:<PORT>/health
curl -f http://<HOST_IP>:<PORT>/health
```

If localhost works but external host/IP fails, open host/container firewall for TCP `<PORT>`.

## Repo Layout

```text
nexhelper-bot/
├── provision-customer.sh
├── setup-nexhelper.sh
├── build-image.sh
├── Dockerfile
├── config/
├── skills/
│   ├── common/
│   ├── classifier/
│   ├── document-handler/
│   ├── document-export/
│   ├── document-ocr/
│   ├── entity-system/
│   └── reminder-system/
└── tests/regression/
```

## Notes

- OpenRouter is the preferred provider path.
- Reminder reliability is implemented as layered behavior: direct tool execution + canonical reminder storage + sync/audit safety nets.
- Agent behavior checks include deterministic pass/fail for system guarantees and warn-level for residual LLM variability where appropriate.
