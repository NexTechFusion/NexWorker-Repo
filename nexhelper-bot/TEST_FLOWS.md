# NexHelper Test Flows

This document defines the full live-coverage test suite for NexHelper and maps each flow to current runnable scripts.

## Flow Catalog

| Flow ID | Name | Goal | Coverage Type |
| --- | --- | --- | --- |
| F01 | Boot and Health | Validate container starts, health endpoint/tools and required storage paths are available | Smoke |
| F02 | Intent Classification | Validate AI intent classification returns valid structured JSON | Live AI |
| F03 | Entity Classification | Validate entity detection over configured entities | Live AI |
| F04 | Document Intake | Validate canonical document creation and audit logging | Core |
| F05 | Duplicate Detection | Validate idempotency and duplicate prevention | Core |
| F06 | Document Lifecycle | Validate delete, restore, and hard-delete transitions | Core |
| F07 | Search Reliability | Validate lexical + semantic search and token matching behavior | Core/AI |
| F08 | Reminder Due Flow | Validate reminder create and due delivery path | Core |
| F09 | Workflow Routing | Validate message/systemEvent routing + deterministic output | Core |
| F10 | DATEV Export | Validate export generation, deterministic totals, and validation report | Integration |
| F11 | Email Delivery | Validate SMTP send, constraints, and audit trail | Integration |
| F12 | Legacy Migration | Validate JSON + markdown migration into canonical store | Integration |
| F13 | Retention | Validate archive/purge and ops-report cleanup | Integration |
| F14 | Tenant Isolation | Validate path boundary enforcement and rejection of out-of-scope paths | Security |
| F15 | Restart Recovery | Validate reminders and scheduled flows survive restarts | Reliability |
| F16 | Startup Gate Flags | Validate smoke on start and fail-fast startup behavior | Reliability |
| F17 | Telegram E2E | Validate full user-visible flow in Telegram channel | Channel E2E |
| F18 | WhatsApp E2E | Validate full user-visible flow in WhatsApp channel | Channel E2E |

## Execution Tiers

| Tier | Flows | Frequency |
| --- | --- | --- |
| PR Gate | F01, F04, F05, F06, F07, F08, F09, F16 | Every PR |
| Nightly Live | F02, F03, F10, F11, F12, F13, F14, F15 | Nightly |
| Weekly Channel E2E | F17, F18 | Weekly |

## Script Mapping Matrix

| Flow ID | Current Script | Command | Notes |
| --- | --- | --- | --- |
| F01 | `skills/common/nexhelper-smoke` | `bash skills/common/nexhelper-smoke` | Includes health and workflow checks |
| F02 | `skills/classifier/nexhelper-classify` | `bash skills/classifier/nexhelper-classify intent --text "<msg>"` | Requires `OPENROUTER_API_KEY` (or `OPENAI_API_KEY`) |
| F03 | `skills/classifier/nexhelper-classify` | `bash skills/classifier/nexhelper-classify entity --text "<msg>" --entities-json "[...]"` | Requires configured entities |
| F04-F09 | `tests/regression/run.sh` | `bash tests/regression/run.sh` | Core regression suite |
| F10 | `skills/document-export/scripts/export_datev.sh` | `bash skills/document-export/scripts/export_datev.sh <customer_dir> <from> <to>` | Reads canonical docs |
| F11 | `skills/document-export/scripts/send_email.sh` | `bash skills/document-export/scripts/send_email.sh <to> <subject> <body> [attachment]` | Use SMTP test sink for CI |
| F12 | `skills/common/nexhelper-migrate` | `bash skills/common/nexhelper-migrate` | Produces NDJSON + CSV reports |
| F13 | `skills/common/nexhelper-retention` | `bash skills/common/nexhelper-retention` | Includes ops report cleanup |
| F14 | `tests/regression/run.sh` + targeted calls | `bash skills/document-handler/nexhelper-doc store --file <outside-path>` | Should reject with path safety checks |
| F15 | customer scripts | `./stop.sh && ./start.sh && ./smoke.sh` | Validate post-restart reminders/workflows |
| F16 | customer `start.sh` | `RUN_SMOKE_ON_START=true SMOKE_REQUIRED_ON_START=true ./start.sh` | Expected fail if smoke fails |
| F17 | manual Telegram E2E | messaging flow + container logs/status checks | Needs bot token + pairing |
| F18 | manual WhatsApp E2E | messaging flow + container logs/status checks | Needs QR pairing |

## Existing Harness Commands

### Linux Containerized Full Core Validation

```bash
bash tests/regression/in_container_run.sh /tmp/work
```

### Windows + Docker Regression

```powershell
pwsh tests/regression/run.ps1 -CustomerDir "C:\opt\nexhelper\customers\<slug>"
```

### Windows + Docker Smoke

```powershell
pwsh tests/regression/smoke.ps1 -CustomerDir "C:\opt\nexhelper\customers\<slug>"
```

### Live AI Flow (Classifier + Workflow + Canonical Store)

```bash
OPENROUTER_API_KEY=... bash tests/regression/live_flow.sh
```

### Consolidated F01-F16 Suite

```bash
OPENROUTER_API_KEY=... bash tests/regression/full_live_suite.sh
```

This suite includes deterministic checks for:

- F11 via local mock SMTP server
- F15 via restart-style state persistence validation
- F16 via startup gate logic validation

### Gateway Session Simulation (Container + OpenClaw chat)

```powershell
pwsh tests/regression/gateway_session_suite.ps1 -OpenRouterApiKey "<sk-or-...>"
```

This validates a real provisioned customer container with OpenClaw session chat turns (gateway-routed), session persistence, and post-chat smoke.

## Pass Criteria

- PR Gate: all mapped flows green, zero failed checks
- Nightly: all integration/security/reliability flows green, zero silent failures
- Weekly E2E: both messenger channels complete happy path + key failure path
- All runs must produce structured output and report artifacts where applicable

## Reporting Artifacts

- Smoke report: `storage/ops/smoke/report-*.json`
- Migration report: `storage/ops/migration/report-*.ndjson`
- Migration summary: `storage/ops/migration/summary-*.csv`

## Gaps to Close Next

- Add scripted Telegram and WhatsApp E2E drivers for F17-F18 where infra permits
