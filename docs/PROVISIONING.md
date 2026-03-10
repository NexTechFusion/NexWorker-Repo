# NexHelper Provisioning Guide

## Architecture

```
                    ┌→ Docker: nexhelper-acme (Port 3001)
                    │   └── OpenClaw Instance for "Acme GmbH"
                    │
@NexHelperBot ──────┼→ Docker: nexhelper-mueller (Port 3002)
(Telegram)          │   └── OpenClaw Instance for "Müller Bau"
                    │
                    └→ Docker: nexhelper-... (Port 300X)
                        └── OpenClaw Instance for "..."
```

### Key Decisions

1. **Docker per Kunde** - Each customer gets isolated OpenClaw instance
2. **Shared Telegram Bot** - One bot (`@NexHelperBot`) for all customers
3. **Router-based routing** - Messages routed to correct instance via tenant_id
4. **No database per customer** - OpenClaw uses file-based memory (DSGVO compliant)

---

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Environment variables:
  - `TELEGRAM_BOT_TOKEN` - Shared Telegram bot token
  - `OPENAI_API_KEY` - OpenAI or OpenRouter API key

### Provision a Customer

```bash
# Set environment
export TELEGRAM_BOT_TOKEN="123456789:ABC..."
export OPENAI_API_KEY="sk-..."

# Provision
./provision-customer.sh 001 "Acme GmbH"
```

### Manage Instances

```bash
# List all customers
ls /opt/nexhelper/customers/

# Start instance
/opt/nexhelper/customers/acme-gmbh/start.sh

# Stop instance
/opt/nexhelper/customers/acme-gmbh/stop.sh

# View logs
/opt/nexhelper/customers/acme-gmbh/logs.sh

# Remove instance
/opt/nexhelper/customers/acme-gmbh/remove.sh
```

---

## Directory Structure

```
/opt/nexhelper/customers/
├── acme-gmbh/
│   ├── config/
│   │   └── config.yaml      # OpenClaw configuration
│   ├── logs/                 # Container logs
│   ├── storage/
│   │   └── memory/           # Customer memory (DSGVO-isolated)
│   ├── docker-compose.yaml   # Docker configuration
│   ├── .env                  # Environment variables
│   ├── start.sh              # Start script
│   ├── stop.sh               # Stop script
│   ├── logs.sh               # Logs viewer
│   └── remove.sh             # Removal script
├── mueller-bau/
│   └── ...
└── ...
```

---

## Resource Planning

### OpenClaw Resource Usage

| Metric | Value |
|--------|-------|
| CPU (idle) | ~1% |
| RAM per instance | ~150MB |
| RAM with browser | +200-500MB |

### Server Capacity (Hetzner)

| Server | Specs | Customers |
|--------|-------|-----------|
| CX31 | 2 vCPU, 8GB | 10-15 |
| CX41 | 4 vCPU, 16GB | 15-20 |
| CCX23 | 4 vCPU, 16GB (dedicated) | 20-30 |

### Cost per Customer

| Server | Monthly Cost | Customers | Cost/Customer |
|--------|--------------|-----------|---------------|
| CX31 | €9.70 | 10 | €0.97 |
| CX31 | €9.70 | 15 | €0.65 |
| CX41 | €17.00 | 20 | €0.85 |

---

## Telegram Bot Routing

### Flow

```
User sends message to @NexHelperBot
        ↓
Router instance receives message
        ↓
Look up user_id → tenant_id mapping
        ↓
Forward to correct customer instance
        ↓
Customer instance processes and responds
```

### Implementation

The routing is handled by OpenClaw's built-in routing capabilities. Each instance has a `routing.tenantId` in its config.

---

## WhatsApp (Future)

WhatsApp will be offered as an add-on:

- **Option A**: Customer brings own WhatsApp Business number
- **Option B**: Virtual number via Twilio/MessageBird (~€5-15/month)
- **Option C**: Shared WhatsApp number with routing (like Telegram)

---

## Pricing Impact

| Plan | Price | Cost | Margin |
|------|-------|------|--------|
| Solo | €19 | ~€4 | 79% |
| Team | €49 | ~€12 | 76% |
| Business | €99 | ~€25 | 75% |

With shared Telegram bot and Docker-per-customer architecture.

---

## Security & DSGVO

- ✅ Each customer has isolated storage
- ✅ No shared database
- ✅ Docker network isolation
- ✅ EU-based servers (Hetzner)
- ✅ Customer data stays in their instance
- ✅ Easy deletion (remove.sh deletes everything)

---

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs nexhelper-acme-gmbh

# Check if port is in use
lsof -i :3001

# Check Docker network
docker network ls | grep nexhelper
```

### Telegram not responding

```bash
# Verify bot token
echo $TELEGRAM_BOT_TOKEN

# Check if router is running
docker ps | grep router

# Test bot manually
curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"
```

### High resource usage

```bash
# Check container stats
docker stats

# Limit resources (edit docker-compose.yaml)
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
```

---

## TODO

- [ ] Implement router instance for Telegram
- [ ] Add monitoring (Prometheus/Grafana)
- [ ] Auto-scaling based on load
- [ ] Backup automation
- [ ] Customer self-service portal
- [ ] WhatsApp integration
