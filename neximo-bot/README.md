# NexImo Bot

Messenger-native apartment hunter for Germany. Find, apply, and track apartments on WhatsApp/Telegram — powered by OpenClaw.

---

## What It Does

NexImo runs on top of OpenClaw and helps Germans find their dream apartment:

- **Conversational search**: "2-room in Berlin Kreuzberg under €1000 with balcony"
- **Multi-portal scanning**: ImmoScout24, WG-Gesucht, eBay Kleinanzeigen in parallel
- **Auto-apply**: Personalized cover letters sent automatically within minutes
- **Follow-up tracking**: "Did you hear back from the landlord?"
- **Price drop alerts**: "The apartment on X street just dropped €50"
- **Reminder system**: "Viewing appointment on Friday 14:00"

---

## Quick Start

### 1. Build the image

```bash
cd neximo-bot/
docker build -t neximo:latest .
```

### 2. Provision a customer

```bash
GEMINI_API_KEY="AIza..." \
BASE_DIR="$(pwd)/customers" \
bash provision-customer.sh 001 "Berlin Hunter" \
  --telegram "123456789:ABC-DEF..." \
  --delivery-to "telegram:YOUR_CHAT_ID"
```

### 3. User flow

```
User: "Ich suche eine 2-Zimmer Wohnung in Berlin Kreuzberg, max 1000€, Balkon"
Bot: Such läuft... 🔍
Bot: Gefunden: 3 neue Treffer!
     1. 85m², 950€, Balkon, 4. Etage
     2. 70m², 890€, ohne Balkon
     3. 65m², 800€, Dachterrasse
User: "Bewirb dich auf alle"
Bot: ✅ 3 Bewerbungen verschickt!
```

---

## Architecture

### Tenant Isolation

```
1 user → 1 bot token → 1 Docker container → 1 search profile
```

### Background Jobs

| Job | Interval | Purpose |
|-----|----------|---------|
| `neximo-scanner` | 5 min | Scan portals for new listings |
| `neximo-applier` | On-demand | Auto-apply to matched listings |
| `neximo-tracker` | 30 min | Check for responses, price changes |

### Primary Skills

| Script | Purpose |
|--------|---------|
| `skills/search/neximo-search` | Multi-portal search (ImmoScout24, WG-Gesucht, Kleinanzeigen) |
| `skills/search/neximo-scanner` | Background scanner loop |
| `skills/application/neximo-apply` | Auto-apply with personalized cover letters |
| `skills/application/neximo-cover-letter` | German cover letter generator |
| `skills/notify/neximo-alert` | Push notifications for new matches |
| `skills/notify/neximo-tracker` | Follow-up tracking |
| `skills/common/neximo-profile` | User search profile management |
| `skills/common/neximo-core` | Shared utilities |

---

## Supported Portals

| Portal | Search | Auto-Apply | Notes |
|--------|--------|------------|-------|
| ImmoScout24 | ✅ | ✅ | Primary market |
| WG-Gesucht | ✅ | ✅ | Shared flats |
| eBay Kleinanzeigen | ✅ | ⚠️ | Manual contact only |
| Immowelt | 🔄 | 🔄 | Coming soon |

---

## Pricing Model

| Tier | Price | Features |
|------|-------|----------|
| Free | €0 | 3 searches, manual apply |
| Standard | €29/mo | Unlimited searches, 50 auto-applies |
| Premium | €79/mo | Priority (<1 min), negotiation help |

---

## Customer Directory Layout

```
customers/<slug>/
├── docker-compose.yaml
├── .env
├── config/
│   ├── openclaw.json
│   └── auth-profiles.json
├── storage/
│   ├── profiles/           ← Search profiles (location, budget, features)
│   ├── listings/           ← Found listings cache
│   ├── applications/        ← Sent applications
│   ├── responses/           ← Landlord responses
│   └── audit/
└── scripts/
    ├── start.sh
    ├── stop.sh
    └── status.sh
```

---

## Search Profile Schema

```json
{
  "id": "profile-001",
  "userId": "telegram:123456789",
  "active": true,
  "criteria": {
    "location": {
      "city": "Berlin",
      "districts": ["Kreuzberg", "Neukölln", "Friedrichshain"],
      "maxDistance": 10
    },
    "budget": {
      "min": 500,
      "max": 1000
    },
    "rooms": {
      "min": 2,
      "max": 3
    },
    "size": {
      "min": 50,
      "max": 100
    },
    "features": ["balcony", "pets_allowed", "elevator"],
    "must_have": ["balcony"],
    "nice_to_have": ["elevator", "parking"]
  },
  "schedule": {
    "availableFrom": "2026-04-01",
    "flexible": false
  },
  "notification": {
    "channels": ["telegram"],
    "frequency": "instant"
  }
}
```

---

## API Reference

### Search Commands

```bash
# Create search profile
neximo-profile create --city "Berlin" --district "Kreuzberg" --max-price 1000 --rooms 2

# List active profiles
neximo-profile list

# Pause/resume
neximo-profile pause <profile-id>
neximo-profile resume <profile-id>
```

### Application Commands

```bash
# Apply to listing
neximo-apply --listing <url> --profile <profile-id>

# Bulk apply
neximo-apply --all-new --profile <profile-id>

# Check status
neximo-tracker status --application <app-id>
```

---

## German Legal Compliance

- **DSGVO compliant**: All data stays in EU
- **Consent management**: Users can delete their data anytime
- **Application records**: Stored for audit trail
- **Landlord contact**: No spam, rate-limited applications

---

## Development

### Run tests

```bash
./tests/regression/full_live_suite.sh
```

### Add new portal

1. Create `skills/search/neximo-scrape-<portal>.sh`
2. Implement `search()` and `parse()` functions
3. Register in `neximo-scanner`

---

## Roadmap

- [ ] Immowelt integration
- [ ] Price negotiation bot
- [ ] Viewing scheduler
- [ ] Contract review (AI-assisted)
- [ ] Multi-language support (EN/TR for expats)

---

Built with ❤️ by NexTech Fusion
