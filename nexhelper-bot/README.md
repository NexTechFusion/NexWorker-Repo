# NexHelper Bot

**Messenger-native document management for German KMU**

---

## What is NexHelper?

NexHelper is a Telegram/WhatsApp bot that helps small businesses manage documents:
- 📄 Receive and categorize documents (invoices, quotes, etc.)
- 🔍 Search and find documents
- 📅 Reminders for deadlines
- 📤 Export to DATEV/SAP/Lexware

All DSGVO-compliant, hosted on EU servers.

---

## Quick Start

### 1. First-Time Setup

```bash
cd nexhelper-bot
./setup-nexhelper.sh
```

### 2. Get a Telegram Bot Token

1. Open Telegram
2. Chat with **@BotFather**
3. Run `/newbot`
4. Follow prompts, copy the token

### 3. Provision a Customer

```bash
export OPENAI_API_KEY="sk-or-..."  # OpenRouter key

# Telegram bot
./provision-customer.sh 001 "Acme GmbH" --telegram "123456789:ABC-DEF..."

# WhatsApp (scan QR after start)
./provision-customer.sh 002 "Müller Bau" --whatsapp
```

### 4. Pair Your Device

**Telegram:**
1. Open your bot in Telegram
2. Send `/start`
3. Note the pairing code
4. Approve: `docker exec -it nexhelper-<slug> openclaw pairing approve telegram <CODE>`

**WhatsApp:**
1. Run `./logs.sh` in the customer directory
2. Scan the QR code
3. Send a message, then approve pairing

---

## Directory Structure

```
nexhelper-bot/
├── provision-customer.sh   # Main provisioning script
├── setup-nexhelper.sh      # First-time setup
├── build-image.sh          # Build Docker image
├── Dockerfile              # NexHelper container
├── config/                 # Config templates
├── skills/                 # Document export, OCR, etc.
└── landing/                # Landing page (Astro)
```

---

## Architecture

Each customer gets:
- **Dedicated Docker container** (isolated)
- **Dedicated storage** (DSGVO-compliant)
- **Dedicated bot** (Telegram) or linked WhatsApp

```
Customer 1 → nexhelper-acme-gmbh (port 3001)
Customer 2 → nexhelper-mueller-bau (port 3002)
...
```

---

## DSGVO Features

- ✅ Isolated storage per customer
- ✅ Consent management (Art. 7 DSGVO)
- ✅ Audit logging (Art. 30 DSGVO)
- ✅ Right to deletion (Art. 17 DSGVO) via `remove.sh`
- ✅ EU-hosted (Hetzner)

---

## Management

```bash
# After provisioning, manage via:
/opt/nexhelper/customers/<slug>/start.sh
/opt/nexhelper/customers/<slug>/stop.sh
/opt/nexhelper/customers/<slug>/status.sh
/opt/nexhelper/customers/<slug>/logs.sh
/opt/nexhelper/customers/<slug>/consent.sh
/opt/nexhelper/customers/<slug>/remove.sh
```

---

## Pricing (Suggested)

| Plan | Price | Docs | Users |
|------|-------|------|-------|
| Solo | €19/mo | 100 | 1 |
| Team | €49/mo | 500 | 5 |
| Business | €99/mo | ∞ | ∞ |

Cost per customer: ~€0.65-1.00 (Hetzner CX31)

---

## Support

- Website: https://nexhelper.de
- Email: support@nexhelper.de