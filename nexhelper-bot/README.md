# NexHelper Bot

Messenger-native office assistant for German SMBs: document intake, reminders, search, exports, and auditable workflows — one isolated Docker container per customer.

---

## What It Does

NexHelper runs on top of OpenClaw and is optimized for chat-first operations (Telegram / WhatsApp):

- Receive invoices, quotes, receipts, and any documents from chat (images, PDFs)
- Extract structured fields (supplier, amount, date, invoice number, category)
- Detect duplicates via fingerprint (`number|supplier|amount|date`)
- Soft-delete / restore with RBAC enforcement
- Create and fire time-based reminders without any agent round-trip for low-level ops
- Export accounting data (DATEV CSV, SAP, Lexware)
- Per-tenant storage, audit trails, consent management, and retention controls
- Proactive notifications via `nexhelper-notify` (single / admin-only / broadcast)
- Admin ops reports (JSON + HTML)

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
| Sessions | OpenClaw agent sessions in `/root/.openclaw/agents/main/sessions/` |

### Background job model

High-frequency ops are **native shell loops** inside the container entrypoint — zero LLM tokens consumed:

| Loop | Interval | Purpose |
| --- | --- | --- |
| `nexhelper-reminder-auditor` + `nexhelper-reminder-sync` | 60 s | Scan sessions for missed exec calls; reconcile canonical reminders with cron |
| `nexhelper-reminder due` | 300 s | Mark and deliver due canonical reminders |

Low-frequency, LLM-appropriate jobs are registered as OpenClaw cron jobs on gateway start:

| Cron job | Schedule | Purpose |
| --- | --- | --- |
| `budget-check` | `0 * * * *` (hourly) | Token `nexhelper:event:budget-check` → `nexhelper-entity check` |
| `retention-job` | `0 2 * * *` (2 AM daily) | Token `nexhelper:event:retention` → `nexhelper-retention` |

All cron registrations are **idempotent** (`_nx_ensure_cron` — skips if job name already exists) to prevent duplicate accumulation across container restarts.

### Structured workflow event routing

The workflow router (`nexhelper-workflow`) uses structured token matching first, then legacy substring fallback for backward compatibility:

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
| `skills/document-handler/nexhelper-doc-core.sh` | Pure utility functions (`normalize_float`, `build_fingerprint`) — independently testable |
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
./manage.sh provision 001 "Acme" ...    # Delegate to provision-customer.sh
./manage.sh start nexhelper-acme-001    # Start container
./manage.sh stop  nexhelper-acme-001    # Stop container
```

---

## Quick Start

### 1. Build the image

```bash
docker build -t nexhelper:latest nexhelper-bot/
```

> To always pick up the latest OpenClaw version: `docker build --no-cache -t nexhelper:latest nexhelper-bot/`

### 2. Set your API key

**Gemini (default):**

```bash
export GEMINI_API_KEY="AIza..."
```

> OpenClaw model format for Gemini: `google/gemini-3-flash-preview`. The `google/` prefix is required — bare model names fall back to `anthropic/` incorrectly inside OpenClaw's model router.

**OpenRouter:**

```bash
export AI_PROVIDER=openrouter
export OPENROUTER_API_KEY="sk-or-..."
```

**OpenAI:**

```bash
export AI_PROVIDER=openai
export OPENAI_API_KEY="sk-..."
```

**Custom / any OpenAI-compatible endpoint:**

```bash
export AI_PROVIDER=custom
export AI_API_KEY="your-key"
export AI_BASE_URL="https://your-endpoint/v1"
export DEFAULT_MODEL="provider/model-name"
```

### 3. Provision a customer

**Telegram:**

```bash
./provision-customer.sh 001 "Acme GmbH" --telegram "123456789:ABC-DEF..."
```

**WhatsApp:**

```bash
./provision-customer.sh 002 "Mueller Bau" --whatsapp
```

**With Cloudflare tunnel (opens dashboard immediately after start):**

```bash
./provision-customer.sh 001 "Acme GmbH" --telegram "123:ABC" --cloudflare-tunnel
```

**Full options:**

```text
--telegram <token>       Telegram bot token (required unless --whatsapp)
--whatsapp               Enable WhatsApp channel
--api-key <key>          LLM API key (or set GEMINI_API_KEY / AI_API_KEY)
--model <model>          Override default model
--no-start               Do not auto-start the container
--cloudflare-tunnel      Launch Cloudflare Quick Tunnel after provisioning
--delivery-to <to>       Admin notification target (e.g. telegram:579539601)
--initial-admin <id>     Promote this user ID to admin on first start
--base-dir <path>        Customer directory base (default: /opt/nexhelper/customers)
--consent-version <v>    Consent text version (default: 1.0)
```

### 4. Customer directory layout

Provisioning generates a self-contained customer directory:

```text
/opt/nexhelper/customers/<slug>/
├── docker-compose.yaml
├── .env                      ← API keys, PORT, GATEWAY_TOKEN, etc.
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
├── tunnel.sh                 ← Cloudflare Quick Tunnel + dashboard URL + pairing watcher
├── admin-quickstart.sh       ← Admin verification after pairing
└── remove.sh                 ← Export-first offboarding
```

---

## Cloudflare Quick Tunnel

Expose the OpenClaw dashboard securely over the internet without opening firewall ports:

```bash
cd /opt/nexhelper/customers/<slug>
./tunnel.sh
```

`tunnel.sh` will:

1. Start `cloudflared tunnel --url http://localhost:<PORT>`
2. Wait up to 40 s for the `trycloudflare.com` URL to appear
3. Inject the URL into the container's `openclaw.json` CORS allowlist at runtime
4. Print the full dashboard URL including the auth token:

```text
📋 Open this in your browser:
   https://xyz.trycloudflare.com/?token=b4dc3a8274fe...
```

1. Watch every 5 s for pending device pairing requests and print the approve command

> **Requires:** `cloudflared` CLI installed on the host. Install instructions are shown if missing.

The dashboard token (`GATEWAY_TOKEN`) is a 48-char hex value generated at provisioning time. It is stored in `.env` and baked into `config/openclaw.json` under `gateway.auth.token`. The CORS allowlist pre-permits `*.trycloudflare.com`.

```bash
# Read the token any time:
grep GATEWAY_TOKEN /opt/nexhelper/customers/<slug>/.env
```

---

## Reminder System

Reminders are implemented in three layers:

| Layer | Mechanism | LLM cost |
| --- | --- | --- |
| 1. Direct tool | Agent calls `exec command="nexhelper-set-reminder ..."` | 1 turn (the user's request) |
| 2. Canonical store | `nexhelper-set-reminder` writes JSON record + schedules cron | 0 |
| 3. Ops safety net | `nexhelper-reminder-auditor` + `nexhelper-reminder-sync` in native loops | 0 |

The auditor state cursor is stored at `storage/ops/auditor-cursor` (durable across container restarts). It was previously `/tmp/` which reset on every restart.

---

## Role-Based Access Control

NexHelper enforces a two-tier role model per tenant:

| Role | Permissions |
| --- | --- |
| member (default) | Store, search, list documents; create and delete own reminders |
| admin | All member permissions + delete any document, hard-delete, purge, export, manage RBAC |

Role state is stored in `storage/policy.json` per tenant.

**How a user becomes admin:**

```bash
# Promote (or use --initial-admin at provision time):
docker exec -i nexhelper-<slug> nexhelper-policy add-admin <USER_ID> <PROMOTED_BY>

# Remove:
docker exec -i nexhelper-<slug> nexhelper-policy remove-admin <USER_ID>

# List:
docker exec -i nexhelper-<slug> nexhelper-policy list-admins
```

---

## Observability

### Health check

```bash
docker exec nexhelper-<slug> openclaw health --json
# or from host:
curl -f http://localhost:<PORT>/health
```

### Monitor script

```bash
# Full report
docker exec nexhelper-<slug> sh -lc "nexhelper-monitor report"

# Recent errors only
docker exec nexhelper-<slug> sh -lc "nexhelper-monitor errors"

# Cron job health
docker exec nexhelper-<slug> sh -lc "nexhelper-monitor cron-health"

# Alert if degraded (for host-side monitoring scripts)
docker exec nexhelper-<slug> sh -lc "nexhelper-monitor alert"
```

### Log lookup

```bash
# Container logs
docker logs nexhelper-<slug> --since 1h

# Audit event log
docker exec nexhelper-<slug> cat /root/.openclaw/workspace/storage/audit/events.ndjson | jq -c '.'

# Tool / error diagnostics
docker logs nexhelper-<slug> 2>&1 | grep -E '\[tools\]|\[diagnostic\]'
```

### Admin ops report

```bash
<CUSTOMER_DIR>/report.sh           # JSON
<CUSTOMER_DIR>/report.sh html      # HTML (redirect to .html file)
```

---

## Testing and Quality Gates

### Test suite entry points

| Script | Environment | Coverage |
| --- | --- | --- |
| `tests/regression/full_live_suite.sh` | Ubuntu container (no gateway) | F01–F41 deterministic tests |
| `tests/regression/gateway_session_suite.ps1` | Live provisioned container | End-to-end with real LLM |

### full_live_suite.sh — F01–F41

| Range | Area |
| --- | --- |
| F01–F16 | Core: health, AI classification, document lifecycle, reminder lifecycle, workflow, DATEV, email, migration, retention, path safety, restart semantics, startup gate |
| F17–F25 | Advanced: entity detect/tag/budget, set-reminder wrapper, auditor/sync, error paths, OCR negative-path, cross-script idempotency |
| F26–F30 | RBAC, soft-delete, document retrieve, admin report, notify script |
| F31–F36 | Structured event routing (all 4 tokens + unknown + legacy fallback) |
| F37 | `nexhelper-doc-core.sh` unit (`normalize_float`, fingerprint determinism) |
| F38 | `manage.sh help` command |
| F39 | `nexhelper-monitor errors` JSON output |
| F40 | Auditor cursor written to durable `storage/ops/auditor-cursor` (not `/tmp`) |
| F41 | `provision-customer.sh` generates native loops, not cron, for ops jobs |

Run inside Ubuntu container (no API key needed for most tests):

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

### gateway_session_suite.ps1 — live container tests

```powershell
# Gemini
powershell -ExecutionPolicy Bypass `
  -File nexhelper-bot/tests/regression/gateway_session_suite.ps1 `
  -GeminiApiKey "AIza..."

# OpenRouter
powershell -ExecutionPolicy Bypass `
  -File nexhelper-bot/tests/regression/gateway_session_suite.ps1 `
  -OpenRouterApiKey "sk-or-..."
```

Key assertions:

| Test | Validates |
| --- | --- |
| `provision_customer` | `provision-customer.sh` runs clean |
| `gateway_health` | Container reaches healthy state |
| `runtime_tools_allowlist_clean` | `openclaw.json` has no unknown tool entries |
| `runtime_set_reminder_available` | `nexhelper-set-reminder` on PATH and executable |
| `runtime_log_lookup` | No critical errors in container logs |
| `cron_names_unique` | No duplicate cron job names |
| `cron_daily_summary_absent` | `daily-summary` job not registered by default |
| `cron_startup_jobs_present` | `budget-check` and `retention-job` registered |
| `ops_loops_not_in_cron` | `reminder-auditor` and `check-reminders` absent from cron (native loops) |
| `startup_cron_registered` | Only low-frequency jobs in cron scheduler |
| `structured_event_routing` | All 4 `nexhelper:event:*` tokens route correctly |
| `monitor_available` | `nexhelper-monitor errors` returns valid JSON |
| `agent_reminder_cron_created` | Agent calls `exec` tool (warn-level — residual LLM variability) |

### Smoke on startup

```bash
# Disable startup smoke:
RUN_SMOKE_ON_START=false

# Require smoke to pass before accepting traffic:
SMOKE_REQUIRED_ON_START=true
```

---

## Provider Reference

| `AI_PROVIDER` | Base URL | Model prefix | Auth env var |
| --- | --- | --- | --- |
| `gemini` | `https://generativelanguage.googleapis.com/v1beta/openai` | `google/` | `GEMINI_API_KEY` |
| `openrouter` | `https://openrouter.ai/api/v1` | `openrouter/google/` etc. | `OPENROUTER_API_KEY` |
| `openai` | `https://api.openai.com/v1` | `openai/` | `OPENAI_API_KEY` |
| `custom` | Your `AI_BASE_URL` | As configured | `AI_API_KEY` |

> OpenClaw requires the `provider/model` format. A bare model name (e.g. `gemini-3-flash-preview` without `google/`) is resolved incorrectly to `anthropic/` and will fail with `Unknown model`.

---

## Security and Compliance

| Feature | Detail |
| --- | --- |
| Tenant path guardrails | File operations are sandboxed to `$STORAGE_DIR` |
| Audit logging | Every op written to `storage/audit/events.ndjson` |
| Consent management | Per-user consent gate; revocable via `consent.sh` |
| Retention | Configurable archive (`RETENTION_DAYS`) and purge (`PURGE_DELETED_AFTER_DAYS`) |
| RBAC | `nexhelper-policy` enforces admin / member separation |
| Idempotency | Operation keys stored in `storage/idempotency/` |
| LF line endings | `.gitattributes` enforces LF for all scripts, preventing CRLF-in-container bugs |
| Gateway auth | `GATEWAY_TOKEN` required for dashboard access (48-char hex, per customer) |

---

## Ops Runbook

### Check cron jobs

```bash
docker exec nexhelper-<slug> openclaw cron list --json
```

Expected: only `budget-check` and `retention-job`. `reminder-auditor` and `check-reminders` run as native background loops — they should **not** appear here.

### Repair a cron delivery target

```bash
docker exec nexhelper-<slug> openclaw cron edit --id <JOB_ID> --to telegram:<CHAT_ID>
```

### Verify AI provider routing

```bash
docker exec nexhelper-<slug> sh -lc \
  'env | grep -E "AI_PROVIDER|OPENAI_BASE_URL|GEMINI_API_KEY|OPENROUTER_API_KEY"'
```

### Check OpenClaw version

```bash
# Installed in container:
docker exec nexhelper-<slug> openclaw --version

# Latest on registry:
npm view openclaw version
```

Rebuild to update: `docker build --no-cache -t nexhelper:latest nexhelper-bot/`

### Restart a customer container

```bash
cd /opt/nexhelper/customers/<slug>
docker compose down && docker compose up -d
# or:
./manage.sh stop nexhelper-<slug>
./manage.sh start nexhelper-<slug>
```

---

## Compliance and Offboarding

### Data retention defaults

- Documents older than `RETENTION_DAYS` (default: 365) are archived automatically
- Soft-deleted documents are purged after `PURGE_DELETED_AFTER_DAYS` (default: 30)

### Offboarding

Always use `./remove.sh` — it performs an export-first confirmation:

1. Creates `offboarding-export-<timestamp>/` with `canonical/`, `consent/`, `audit/`, `policy.json`
2. Prompts you to type `DELETE` before removing the container and directory

Manual export without deletion:

```bash
cp -r <CUSTOMER_DIR>/storage/canonical ./backup-$(date +%Y%m%d)
cp -r <CUSTOMER_DIR>/storage/consent   ./backup-$(date +%Y%m%d)
cp -r <CUSTOMER_DIR>/storage/audit     ./backup-$(date +%Y%m%d)
```

### Consent withdrawal

```bash
<CUSTOMER_DIR>/consent.sh revoke <USER_ID>
```

### Audit log retrieval

```bash
docker exec nexhelper-<slug> \
  cat /root/.openclaw/workspace/storage/audit/events.ndjson | jq -c '.'
```

---

## Repo Layout

```text
nexhelper-bot/
├── provision-customer.sh        ← Customer provisioning (all-in-one)
├── manage.sh                    ← Control plane CLI (list/status/logs/monitor/...)
├── Dockerfile
├── .gitattributes               ← LF enforcement for all scripts
├── config/
│   └── config.yaml.template
├── skills/
│   ├── common/
│   │   ├── nexhelper-workflow       ← Event router
│   │   ├── nexhelper-healthcheck
│   │   ├── nexhelper-smoke
│   │   ├── nexhelper-monitor        ← Observability (cron health, errors, alerts)
│   │   ├── nexhelper-policy         ← RBAC
│   │   ├── nexhelper-notify         ← Proactive notifications
│   │   ├── nexhelper-admin-report   ← Ops read model
│   │   ├── nexhelper-retention
│   │   └── nexhelper-migrate
│   ├── classifier/
│   │   └── nexhelper-classify       ← AI intent/entity classification
│   ├── document-handler/
│   │   ├── nexhelper-doc            ← Document CRUD
│   │   └── nexhelper-doc-core.sh    ← Pure utility functions (SRP)
│   ├── document-export/
│   ├── document-ocr/
│   ├── entity-system/
│   │   └── nexhelper-entity
│   └── reminder-system/
│       ├── nexhelper-reminder
│       ├── nexhelper-set-reminder
│       ├── nexhelper-reminder-auditor
│       └── nexhelper-reminder-sync
└── tests/regression/
    ├── full_live_suite.sh           ← F01–F41 deterministic tests
    └── gateway_session_suite.ps1    ← Live end-to-end with real LLM
```

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
| Cloudflare tunnel CORS | pre-permitted | `*.trycloudflare.com` allowlisted in `openclaw.json`; exact URL injected at tunnel start. |
