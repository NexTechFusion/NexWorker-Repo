# NexWorker & NexHelper Repository

**NexTech Fusion product suite**

---

## Products

### 📄 [NexHelper](./nexhelper-bot/)

Messenger-native document management for German KMU.

- Telegram & WhatsApp bots
- Document receipt, categorization, search
- DATEV/SAP/Lexware export
- DSGVO-compliant

**Quick Start:**
```bash
cd nexhelper-bot
./setup-nexhelper.sh
./provision-customer.sh 001 "Acme GmbH" --telegram "YOUR_BOT_TOKEN"
```

→ [Full documentation](./nexhelper-bot/README.md)

---

### 🏗️ NexWorker

Construction site reporting for tradespeople.

- WhatsApp/Telegram reporting
- Photo documentation
- ASCII reports
- Multi-worker support

**Setup:**
```bash
./install-nexworker.sh <client-slug> <telegram-token>
```

---

## Directory Structure

```
NexWorker-Repo/
├── nexhelper-bot/           # NexHelper (document management)
│   ├── provision-customer.sh
│   ├── setup-nexhelper.sh
│   ├── build-image.sh
│   ├── Dockerfile
│   ├── config/
│   ├── skills/
│   └── landing/
│
├── nexworker-landing/       # NexWorker landing page
├── install-nexworker.sh     # NexWorker installer
│
├── docs/                    # Shared documentation
└── README.md                # This file
```

---

## Architecture

| Product | Use Case | Channels |
|---------|----------|----------|
| NexHelper | Document management for KMU | Telegram, WhatsApp |
| NexWorker | Construction site reports | Telegram, WhatsApp |

Both products are built on **OpenClaw** and use Docker for isolated customer deployments.

---

## Development

### Prerequisites

- Docker & Docker Compose
- OpenAI or OpenRouter API key

### Build NexHelper Image

```bash
cd nexhelper-bot
./build-image.sh latest
```

### Provision Customers

```bash
# NexHelper
cd nexhelper-bot
./provision-customer.sh 001 "Acme GmbH" --telegram "TOKEN"

# NexWorker
./install-nexworker.sh acme "TOKEN"
```

---

## License

Proprietary - NexTech Fusion