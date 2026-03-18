# NexHelper Bot

Messenger-native office assistant for German SMBs: document intake, reminders, search, exports, and auditable workflows — one isolated Docker container per customer.

---

## What It Does

NexHelper runs on top of OpenClaw and is optimized for chat-first operations (Telegram / WhatsApp):

- Receive invoices, quotes, receipts, and any documents from chat (images, PDFs)
- Extract structured fields (supplier, amount, date, invoice number, category)
- Detect duplicates via fingerprint (`number|supplier|amount|date`)
- Soft-delete / restore with RBAC enforcement
- Transcribe voice notes locally via `whisper-cli` (no cloud dependency)
- Create and fire time-based reminders without any agent round-trip for low-level ops
- Export accounting data (DATEV CSV, SAP, Lexware)
- Per-tenant storage, audit trails, consent management, and retention controls
- Proactive notifications via `nexhelper-notify` (single / admin-only / broadcast)
- Admin ops reports (JSON + HTML)
- **User Memory**: Per-user session history & facts storage for context between chats

---

## Quick Start

### 1. Build the image

```bash
cd nexhelper-bot/
docker build -t nexhelper:latest .
```

> To always pick up the latest OpenClaw version: `docker build --no-cache -t nexhelper:latest .`

### 2. Provision a customer

Run `provision-customer.sh` from inside `nexhelper-bot/`. Pass your API key and bot token inline:

**Gemini + Telegram (most common):**

```bash
GEMINI_API_KEY="AIza..." \
BASE_DIR="$(pwd)/customers" \
bash provision-customer.sh 001 "Acme GmbH" \
  --telegram "123456789:ABC-DEF..." \
  --delivery-to "telegram:YOUR_CHAT_ID"
```

**OpenRouter + Telegram:**

```bash
AI_PROVIDER=openrouter \
OPENROUTER_API_KEY="sk-or-..." \
BASE_DIR="$(pwd)/customers" \
bash provision-customer.sh 001 "Acme GmbH" \
  --telegram "123456789:ABC-DEF..."
```

**OpenAI + Telegram:**

```bash
AI_PROVIDER=openai \
OPENAI_API_KEY="sk-..." \
BASE_DIR="$(pwd)/customers" \
bash provision-customer.sh 001 "Acme GmbH" \
  --telegram "123456789:ABC-DEF..."
```

**With WhatsApp (QR scan required on first start):**

```bash
GEMINI_API_KEY="AIza..." \
BASE_DIR="$(pwd)/customers" \
bash provision-customer.sh 002 "Mueller Bau" \
  --telegram "123456789:ABC-DEF..." \
  --whatsapp \
  --delivery-to "whatsapp:+49..."
```

> **`BASE_DIR`** controls where customer directories are created. Defaults to `/opt/nexhelper/customers`. Set it to `$(pwd)/customers` to keep everything inside the repo during development.

> **Audio transcription (whisper-cli):** The script automatically downloads `ggml-medium.bin` (~1.5 GB) to `WHISPER_MODEL_DIR` (default: `/opt/whisper-models`, override on Windows: `WHISPER_MODEL_DIR=$HOME/whisper-models`). The model is shared across all customer containers on the same host — downloaded once, mounted read-only into each container.

### 3. What happens

```
provision-customer.sh
  ├── Validates Telegram token
  ├── Creates customers/<slug>/
  │   ├── config/openclaw.json       ← Agent config
  │   ├── config/auth-profiles.json  ← API key bindings
  │   ├── docker-compose.yaml
  │   └── .env
  ├── Downloads ggml-medium.bin if not present (non-openai providers)
  ├── Starts the container (unless --no-start)
  └── Runs startup smoke check
```

The container is named `nexhelper-<slug>` and bound to port `3000 + <customer-id>` (e.g. `001` → `3001`).

### 4. All provisioning options

```text
Arguments:
  <id>                     Numeric customer ID (e.g. 001). Port = 3000 + id.
  <name>                   Customer display name (quoted if spaces)

Options:
  --telegram <token>       Telegram bot token (required unless --whatsapp only)
  --whatsapp               Enable WhatsApp channel (QR scan on first start)
  --delivery-to <target>   Admin notification target: telegram:<id> or whatsapp:<number>
  --initial-admin <id>     Promote this user to admin on first start
  --api-key <key>          LLM API key (or set GEMINI_API_KEY / AI_API_KEY env var)
  --model <model>          Override default model
  --no-start               Generate files only; do not start the container
  --base-dir <path>        Customer directory base (default: /opt/nexhelper/customers)
  --consent-version <v>    Consent text version (default: 1.0)
  --force                  Overwrite existing customer directory in-place

Environment variables:
  AI_PROVIDER              gemini (default) | openrouter | openai | custom
  GEMINI_API_KEY           Gemini API key (picked up automatically when AI_PROVIDER=gemini)
  OPENROUTER_API_KEY       OpenRouter API key
  OPENAI_API_KEY           OpenAI API key
  WHISPER_MODEL_DIR        Host path for whisper model files (default: /opt/whisper-models)
  WHISPER_CPP_MODEL        Container path to model file (default: /models/ggml-medium.bin)
```

---

## Audio / Voice Notes

NexHelper transcribes voice messages before the agent sees them. The transcript is echoed back to the user and used as the message body so slash commands still work.

### How it works

| Provider | Transcription method |
| --- | --- |
| `openai` | Auto-detection — picks up the OpenAI key and uses `gpt-4o-mini-transcribe` directly |
| `gemini` / `openrouter` / `custom` | Local `whisper-cli` (whisper.cpp) with `ggml-medium.bin` mounted at `/models` |

### Model

`ggml-large-v3-turbo.bin` (1.6 GB) — best accuracy, multilingual, optimised for speed (faster than large-v3 at near-identical quality).

The model lives on the host at `WHISPER_MODEL_DIR` and is mounted read-only into every container as `/models`. All customers on the same host share one copy.

### First-time setup

The provisioning script downloads the model automatically if not already present:

```bash
# Manual download (if you prefer to pre-stage it):
WHISPER_MODEL_DIR=$HOME/whisper-models
mkdir -p $WHISPER_MODEL_DIR
curl -L -o $WHISPER_MODEL_DIR/ggml-medium.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin"
```

### Swapping the model

Override `WHISPER_CPP_MODEL` at provision time (or in the customer's `.env` after the fact):

```bash
WHISPER_CPP_MODEL=/models/ggml-large-v3-turbo.bin \
bash provision-customer.sh 001 "Acme GmbH" --telegram "..."
```

> `whisper-cli` must be installed inside `nexhelper:latest` for non-openai providers. The binary is bundled with a tiny fallback model; `WHISPER_CPP_MODEL` points it at the better mounted model.

---

## Provider Reference

| `AI_PROVIDER` | Base URL | Model prefix | Auth env var |
| --- | --- | --- | --- |
| `gemini` | `https://generativelanguage.googleapis.com/v1beta/openai` | `google/` | `GEMINI_API_KEY` |
| `openrouter` | `https://openrouter.ai/api/v1` | `openrouter/google/` etc. | `OPENROUTER_API_KEY` |
| `openai` | `https://api.openai.com/v1` | `openai/` | `OPENAI_API_KEY` |
| `custom` | Your `AI_BASE_URL` | As configured | `AI_API_KEY` |

> OpenClaw requires the `provider/model` format. A bare model name (e.g. `gemini-3-flash-preview` without `google/`) resolves incorrectly to `anthropic/` and will fail with `Unknown model`.

---

## Customer Directory Layout

Provisioning generates a self-contained directory per customer:

```text
customers/<slug>/
├── docker-compose.yaml
├── .env                      ← API keys, PORT, GATEWAY_TOKEN, WHISPER_CPP_MODEL
├── config/
│   ├── openclaw.json         ← Agent config (model, tools, CORS, auth token)
│   └── auth-profiles.json    ← Provider API key bindings
├── storage/                  ← Persisted data (mounted into container)
│   ├── canonical/
│   │   ├── documents/        ← Source-of-truth document records
│   │   └── reminders/        ← Source-of-truth reminder records
│   ├── ops/
│   │   └── auditor-cursor    ← Durable auditor position (survives restarts)
│   ├── consent/
│   ├── audit/
│   └── idempotency/
├── start.sh
├── stop.sh
├── status.sh
├── logs.sh
├── health.sh
├── smoke.sh
├── report.sh                 ← JSON ops report (./report.sh html for browser)
├── migrate.sh
├── retention.sh
├── consent.sh
├── onboard.sh                ← Founder handover guide
├── admin-quickstart.sh       ← Admin verification after pairing
└── remove.sh                 ← Export-first offboarding
```

---

## Architecture

### Tenant isolation

```text
1 customer  →  1 bot token  →  1 Docker container  →  1 storage root
```

| Layer | Detail |
| --- | --- |
| Container | `nexhelper:latest` image, `docker compose` per customer |
| Storage | `storage/canonical/{documents,reminders}/` — source of truth |
| Config | `config/openclaw.json` + `config/auth-profiles.json` |
| Skills | Mounted read-only at `/app/skills`, CRLF-fixed and symlinked at startup |
| Whisper model | Mounted read-only at `/models` from host `WHISPER_MODEL_DIR` |
| Sessions | OpenClaw agent sessions in `/root/.openclaw/agents/main/sessions/` |

### Background job model

High-frequency ops are **native shell loops** inside the container entrypoint — zero LLM tokens consumed:

| Loop | Interval | Purpose |
| --- | --- | --- |
| `nexhelper-reminder-auditor` + `nexhelper-reminder-sync` | 60 s | Scan sessions for missed exec calls; reconcile canonical reminders with cron |
| `nexhelper-reminder due` | 300 s | Mark and deliver due canonical reminders |

Only one low-frequency job runs as a scheduled OpenClaw cron:

| Cron job | Schedule | Purpose |
| --- | --- | --- |
| `retention-job` | `0 2 * * *` (2 AM daily) | Token `nexhelper:event:retention` → `nexhelper-retention` (DSGVO compliance) |

The cron registration is **idempotent** (`_nx_ensure_cron` — skips if job name already exists) to prevent duplicate accumulation across container restarts.

> **budget-check removed from cron.** It was consuming 24 LLM turns/day without ever notifying anyone (`--no-deliver` + no `nexhelper-notify` call). Budget threshold alerts now fire **reactively** inside `nexhelper-doc` the moment a `rechnung` document is stored and a budget entity is updated — zero scheduled LLM cost.

### Structured workflow event routing

```text
nexhelper:event:reminder-audit  →  reminder_due handler
nexhelper:event:budget-check    →  budget_check handler
nexhelper:event:retention       →  retention handler
nexhelper:event:health-check    →  health_monitor handler
```

### Primary skills

| Script | Purpose |
| --- | --- |
| `skills/document-handler/nexhelper-doc` | Document intake, dedup, CRUD, DATEV export |
| `skills/document-handler/nexhelper-doc-core.sh` | Pure utility functions (`normalize_float`, `build_fingerprint`) |
| `skills/reminder-system/nexhelper-reminder` | Canonical reminder CRUD |
| `skills/reminder-system/nexhelper-set-reminder` | Atomic wrapper: create canonical record + schedule cron |
| `skills/reminder-system/nexhelper-reminder-auditor` | Scan sessions for text-based exec calls, execute missed commands |
| `skills/reminder-system/nexhelper-reminder-sync` | Reconcile canonical reminders → cron schedule |
| `skills/common/nexhelper-workflow` | Event router (structured tokens + legacy fallback) |
| `skills/common/nexhelper-healthcheck` | Full liveness check (API key, provider reachability) |
| `skills/common/nexhelper-smoke` | Post-startup smoke test |
| `skills/common/nexhelper-monitor` | Observability report (cron health, recent errors, alerts) |
| `skills/common/nexhelper-policy` | Tenant RBAC (admin / member) |
| `skills/common/nexhelper-notify` | Audience-aware proactive notifications |
| `skills/common/nexhelper-admin-report` | Ops read model (JSON + HTML) |
| `skills/common/nexhelper-retention` | Document retention and purge |
| `skills/common/nexhelper-migrate` | Storage schema migration |
| `skills/entity-system/nexhelper-entity` | Budget entities and spend tracking |
| `skills/classifier/nexhelper-classify` | AI-based intent / entity classification (no regex) |
| `skills/document-ocr/scripts/ocr_image.sh` | Tesseract OCR for images |
| `skills/document-ocr/scripts/ocr_pdf.sh` | Tesseract OCR for PDFs |
| `skills/document-export/scripts/export_datev.sh` | DATEV CSV export |
| `skills/document-export/scripts/send_email.sh` | SMTP delivery |

### Control plane

`manage.sh` is a host-side CLI for operating multiple customer instances:

```bash
./manage.sh list                        # All instances with health
./manage.sh status nexhelper-acme-001   # One instance detail
./manage.sh logs   nexhelper-acme-001   # Tail logs
./manage.sh crons  nexhelper-acme-001   # List cron jobs
./manage.sh monitor nexhelper-acme-001  # Run nexhelper-monitor
./manage.sh summary                     # Aggregate health (JSON)
./manage.sh start nexhelper-acme-001    # Start container
./manage.sh stop  nexhelper-acme-001    # Stop container
```

---

## Reminder System

| Layer | Mechanism | LLM cost |
| --- | --- | --- |
| 1. Direct tool | Agent calls `exec command="nexhelper-set-reminder ..."` | 1 turn (the user's request) |
| 2. Canonical store | `nexhelper-set-reminder` writes JSON record + schedules cron | 0 |
| 3. Ops safety net | `nexhelper-reminder-auditor` + `nexhelper-reminder-sync` in native loops | 0 |

The auditor state cursor is stored at `storage/ops/auditor-cursor` (durable across container restarts).

---

## Role-Based Access Control

| Role | Permissions |
| --- | --- |
| member (default) | Store, search, list documents; create and delete own reminders |
| admin | All member permissions + delete any document, hard-delete, purge, export, manage RBAC |

```bash
# Promote a user (or use --initial-admin at provision time):
docker exec -i nexhelper-<slug> nexhelper-policy add-admin <USER_ID> <PROMOTED_BY>

# Remove:
docker exec -i nexhelper-<slug> nexhelper-policy remove-admin <USER_ID>

# List:
docker exec -i nexhelper-<slug> nexhelper-policy list-admins
```

---

## Observability

```bash
# Health endpoint
curl -f http://localhost:<PORT>/health

# Full monitor report
docker exec nexhelper-<slug> sh -lc "nexhelper-monitor report"

# Recent errors only
docker exec nexhelper-<slug> sh -lc "nexhelper-monitor errors"

# Container logs
docker logs nexhelper-<slug> --since 1h

# Audit event log
docker exec nexhelper-<slug> cat /root/.openclaw/workspace/storage/audit/events.ndjson | jq -c '.'

# Ops report (HTML)
customers/<slug>/report.sh html
```

---

## Testing and Quality Gates

| Script | Environment | Coverage |
| --- | --- | --- |
| `tests/regression/full_live_suite.sh` | Ubuntu container (no gateway) | F01–F41 deterministic tests |
| `tests/regression/gateway_session_suite.ps1` | Live provisioned container | End-to-end with real LLM |

### full_live_suite.sh

```bash
docker run --rm \
  -v "$(pwd)/nexhelper-bot:/workspace" \
  ubuntu:22.04 bash -c "
    apt-get update -qq && apt-get install -y -qq jq bc
    cp -r /workspace /work
    find /work -type f \( -name '*.sh' -o -name 'nexhelper-*' -o -name 'manage.sh' \) \
      -exec sed -i 's/\r$//' {} +
    chmod -R +x /work/skills
    chmod +x /work/tests/regression/full_live_suite.sh /work/manage.sh
    cd /work && bash tests/regression/full_live_suite.sh
  "
```

| Range | Area |
| --- | --- |
| F01–F16 | Core: health, AI classification, document lifecycle, reminder lifecycle, workflow, DATEV, email, migration, retention, path safety, restart semantics, startup gate |
| F17–F25 | Advanced: entity detect/tag/budget, set-reminder wrapper, auditor/sync, error paths, OCR negative-path, cross-script idempotency |
| F26–F30 | RBAC, soft-delete, document retrieve, admin report, notify script |
| F31–F36 | Structured event routing (all 4 tokens + unknown + legacy fallback) |
| F37 | `nexhelper-doc-core.sh` unit (`normalize_float`, fingerprint determinism) |
| F38–F41 | `manage.sh help`, monitor JSON, auditor cursor durability, native ops loops |

### gateway_session_suite.ps1

```powershell
powershell -ExecutionPolicy Bypass `
  -File nexhelper-bot/tests/regression/gateway_session_suite.ps1 `
  -GeminiApiKey "AIza..."
```

---

## Ops Runbook

### Check cron jobs

```bash
docker exec nexhelper-<slug> openclaw cron list --json
```

Expected: only `retention-job`. `reminder-auditor` and `check-reminders` run as native background loops — they should **not** appear here.

### Verify AI provider routing

```bash
docker exec nexhelper-<slug> sh -lc \
  'env | grep -E "AI_PROVIDER|OPENAI_BASE_URL|GEMINI_API_KEY|OPENROUTER_API_KEY|WHISPER_CPP_MODEL"'
```

### Check OpenClaw version

```bash
docker exec nexhelper-<slug> openclaw --version
# Rebuild to update:
docker build --no-cache -t nexhelper:latest nexhelper-bot/
```

### Restart a customer container

```bash
cd customers/<slug>
docker compose down && docker compose up -d
```

---

## Security and Compliance

| Feature | Detail |
| --- | --- |
| Tenant path guardrails | File operations are sandboxed to `$STORAGE_DIR` |
| Audit logging | Every op written to `storage/audit/events.ndjson` |
| Consent management | Per-user consent gate; revocable via `consent.sh` |
| Retention | Configurable archive (`RETENTION_DAYS`) and purge (`PURGE_DELETED_AFTER_DAYS`) |
| RBAC | `nexhelper-policy` enforces admin / member separation |
| Audio transcription | Runs locally via `whisper-cli` — voice data never leaves the host for non-openai providers |
| Idempotency | Operation keys stored in `storage/idempotency/` |
| LF line endings | `.gitattributes` enforces LF for all scripts, preventing CRLF-in-container bugs |
| Gateway auth | `GATEWAY_TOKEN` required for dashboard access (48-char hex, per customer) |

### Offboarding

Always use `./remove.sh` — it performs an export-first confirmation before deleting anything.

```bash
# Manual backup without deletion:
cp -r customers/<slug>/storage/canonical ./backup-$(date +%Y%m%d)
cp -r customers/<slug>/storage/consent   ./backup-$(date +%Y%m%d)
cp -r customers/<slug>/storage/audit     ./backup-$(date +%Y%m%d)

# Consent withdrawal:
customers/<slug>/consent.sh revoke <USER_ID>
```

---

## Repo Layout

```text
nexhelper-bot/
├── provision-customer.sh        ← Customer provisioning (all-in-one)
├── manage.sh                    ← Control plane CLI
├── Dockerfile
├── .gitattributes               ← LF enforcement for all scripts
├── customers/                   ← Generated per-customer directories (git-ignored)
├── skills/
│   ├── common/                  ← nexhelper-workflow, policy, notify, report, retention, migrate
│   ├── classifier/              ← nexhelper-classify (AI intent/entity, no regex)
│   ├── document-handler/        ← nexhelper-doc, nexhelper-doc-core.sh
│   ├── document-export/         ← DATEV CSV, email
│   ├── document-ocr/            ← Tesseract OCR (image + PDF)
│   ├── entity-system/           ← nexhelper-entity (budgets, spend tracking)
│   └── reminder-system/         ← nexhelper-reminder, set-reminder, auditor, sync
└── tests/regression/
    ├── full_live_suite.sh        ← F01–F41 deterministic tests (no API key needed)
    └── gateway_session_suite.ps1 ← Live end-to-end with real LLM
```

---

## Updating a Running Instance

When you change skills, configs, or the provision template and need to push those changes to an already-running customer container.

### Skills updated (IMPORTANT: requires down/up, not just restart)

Skills are mounted read-only at `/app/skills/`, but the container's entrypoint **copies** them to `/usr/local/nexhelper-skills/` at startup. This means:

- `docker compose restart` → **NOT sufficient** (uses old copied version)
- `docker compose down && docker compose up -d` → **Required** for skills changes

```bash
cd /opt/nexhelper/customers/<slug>
docker compose down && docker compose up -d
```

> **Why?** The entrypoint runs `cp -r /app/skills /usr/local/nexhelper-skills` once at container start. A restart doesn't re-trigger the copy.

### Config changes (openclaw.json, auth-profiles.json)

Config files are also mounted from `config/`. A restart is sufficient:

```bash
cd customers/<slug>
docker compose restart
```

The docker-compose entrypoint applies a runtime `jq` patch on every start (tool allowlist cleanup, `commands.text = false`, etc.), so config-level fixes take effect automatically.

### Full reprovision (docker-compose.yaml or .env changed)

When you change environment variables, port mappings, volume mounts, or the entrypoint script itself, you need a full down/up cycle:

```bash
cd customers/<slug>
docker compose down && docker compose up -d
```

### Updating the OpenClaw base image

Rebuild the image and recreate:

```bash
docker build --no-cache -t nexhelper:latest nexhelper-bot/
cd customers/<slug>
docker compose down && docker compose up -d
```

### Pushing to a remote VPS

If you develop locally and deploy to a VPS:

```bash
# 1. Push changes to git
git add -A && git commit -m "fix: ..." && git push

# 2. On the VPS: pull and update
cd /path/to/NexWorker-Repo/nexhelper-bot
git pull
cd customers/<slug>

# For skills changes (reminder-system, document-handler, etc.):
docker compose down && docker compose up -d

# For config-only changes (openclaw.json, auth-profiles.json):
docker compose restart

# For docker-compose.yaml or .env changes:
docker compose down && docker compose up -d
```

### Clearing stale OpenClaw state

If the Gateway cached bad config in its Docker volume (e.g. old `commands` settings), remove the volume and recreate:

```bash
cd customers/<slug>
docker compose down
docker volume rm <slug>_nexhelper-data-<slug>   # check name with: docker volume ls --filter name=<slug>
docker compose up -d
```

> **Warning:** This wipes OpenClaw's internal state (session history, cron jobs, device pairings). Customer data in `storage/` is safe — it's a bind mount, not a Docker volume.

---

## Known Edges

| Area | Status | Notes |
| --- | --- | --- |
| `agent_reminder_cron_created` | warn | LLM prompt compliance gap — agent sometimes describes instead of calling `exec`. The ops loop safety net catches these. |
| Email delivery (F11) | skip | Requires a live Python SMTP mock server; skipped in container test runs. |
| AI classification (F02/F03) | skip | Requires API key; skipped in offline test runs. |
| Gemini model prefix | required | `google/gemini-3-flash-preview` — bare name falls to `anthropic/` inside OpenClaw. |
| Auditor cursor | durable since v4 | Previously `/tmp/` (lost on restart); now `storage/ops/auditor-cursor`. |
| Native ops loops | zero LLM cost | `reminder-auditor` and `check-reminders` run as shell loops, not cron. |
| CRLF on Windows | enforced | `.gitattributes` + container startup `tr -d '\r'` eliminates shebang corruption. |
| whisper-cli on Windows | path issue | Default `WHISPER_MODEL_DIR=/opt/whisper-models` requires sudo on Git Bash. Override: `WHISPER_MODEL_DIR=$HOME/whisper-models`. |
| OpenClaw CLI WebSocket | varies by host | `openclaw cron add/list` may time out on some deployments (WS handshake failure on `127.0.0.1:3434`). `nexhelper-set-reminder` tries CLI first, falls back to direct `jobs.json` write. Check `createdVia` in output: `cli` = healthy, `file` = fallback active. |
| `/status` command leak | fixed | OpenClaw's built-in `/status` inline shortcut exposed internals to users. Fix: `commands.text = false` in `openclaw.json` + runtime `jq` patch in entrypoint. User-facing stats command renamed to `/stats`. |
| Multi-channel reminders | fixed | When both Telegram and WhatsApp are configured, `--channel` must be explicit. `nexhelper-set-reminder` auto-detects from user ID format (`+` prefix → WhatsApp, numeric → Telegram). |
