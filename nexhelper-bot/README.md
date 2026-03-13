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
- Canonical data under `storage/canonical`ppppppppystemEvent` flows
98iokjm n 
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
                                                                                                                                                                                                                                                                                                                                                                                                                                             