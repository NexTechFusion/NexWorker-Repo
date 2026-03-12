# NexHelper Customer Provisioning

**DSGVO-konforme Kunden-Provisioning für NexHelper**

---

## 🏗️ Architektur

```
                        ┌→ Docker: nexhelper-acme
                        │   └── OpenClaw Instance
                        │   └── Isolated Storage ✅
                        │   └── Consent Management ✅
                        │   └── Telegram/WhatsApp Channel
                        │
Customer Bot ───────────┼→ Docker: nexhelper-mueller
                        │   └── OpenClaw Instance
                        │   └── Isolated Storage ✅
                        │   └── Consent Management ✅
                        │   └── Telegram/WhatsApp Channel
                        │
                        └→ Docker: nexhelper-...
```

---

## ✨ Features

| Feature | Standard | Notes |
|---------|----------|-------|
| OpenClaw Instance | ✅ Pro Kunde | Isolated Docker container |
| Isolated Storage | ✅ DSGVO-konform | File-based, no shared DB |
| Consent Management | ✅ Automatisch | DSGVO Art. 7 |
| Audit Logging | ✅ DSGVO Art. 30 | All events logged |
| Telegram Bot | ✅ Per customer | Dedicated bot per instance |
| WhatsApp | ✅ Per customer | QR-code pairing |

---

## 🚀 Quick Start

### 1. First-Time Setup

```bash
# Clone and setup
cd NexWorker-Repo
./setup-nexhelper.sh

# Set API key
export OPENAI_API_KEY="sk-or-..."  # OpenRouter recommended
```

### 2. Create a Telegram Bot

1. Open Telegram
2. Search for **@BotFather**
3. Run `/newbot`
4. Follow prompts and copy the token

### 3. Provision a Customer

```bash
# Telegram bot
./provision-customer.sh 001 "Acme GmbH" --telegram "123456789:ABC-DEF..."

# WhatsApp (scan QR after start)
./provision-customer.sh 002 "Müller Bau" --whatsapp

# Custom model
./provision-customer.sh 003 "Test AG" --telegram "123:ABC" --model "openrouter/anthropic/claude-sonnet-4"
```

### 4. Complete Pairing

**Telegram:**
1. Open your bot in Telegram
2. Send `/start`
3. Note the pairing code
4. Approve: `docker exec -it nexhelper-<slug> openclaw pairing approve telegram <CODE>`

**WhatsApp:**
1. Run `./logs.sh` in the customer directory
2. Scan the QR code with WhatsApp
3. Send any message
4. Approve pairing as above

---

## 📁 Verzeichnisstruktur

```
/opt/nexhelper/customers/acme-gmbh/
├── config/
│   ├── config.yaml        # OpenClaw Konfiguration
│   └── consent.yaml       # DSGVO Consent Konfiguration
├── storage/
│   ├── memory/            # Kundendaten (isoliert)
│   ├── consent/           # Consent-Einträge
│   └── audit/             # Audit-Logs
├── logs/                  # Container Logs
├── docker-compose.yaml    # Docker Konfiguration
├── .env                   # Umgebungsvariablen
├── start.sh               # Starten
├── stop.sh                # Stoppen
├── status.sh              # Status
├── logs.sh                # Logs anzeigen
├── consent.sh             # Consent verwalten
└── remove.sh              # Löschen (DSGVO)
```

---

## 🔐 DSGVO-Features

### 1. Daten-Isolierung

- ✅ Jeder Kunde hat **eigenen Docker Container**
- ✅ Jeder Kunde hat **eigenen Storage**
- ✅ Keine Shared Database
- ✅ Physische Trennung der Daten

### 2. Consent Management

```bash
# Consent-Einträge anzeigen
./consent.sh list

# Consent widerrufen
./consent.sh revoke 12345678

# Audit-Log anzeigen
./consent.sh audit
```

### 3. Audit Logging

- Alle Events werden geloggt: `message`, `consent`, `access`
- DSGVO Art. 30 konform
- Löschbar bei Kundenentfernung

### 4. Datenlöschung

```bash
# Komplette Löschung (DSGVO "Recht auf Vergessenwerden")
./remove.sh
```

---

## 📱 Bot-Optionen

### Shared Bot (Standard)

```
@NexHelperBot → Router → Kunden-Instance
```

**Vorteile:**
- Ein Bot für alle Kunden
- Einfaches Onboarding
- Zentrale Wartung

**Consent-Flow:**
```
User: /start
Bot:  "Willkommen! Dieser Bot wird von mehreren 
      Unternehmen genutzt.
      
      Für welches Unternehmen arbeiten Sie?
      [Acme GmbH] [Müller Bau] [Anderes]
      
      Ich stimme der Datenverarbeitung zu.
      [✅ Ja] [❌ Nein]"
```

### Dedicated Bot (Optional)

```bash
# Eigener Bot pro Kunde
./provision-customer.sh 001 "Acme GmbH" \
  --dedicated-bot "789:XYZ..."
```

**Vorteile:**
- Volle Isolation (DSGVO-optimal)
- Kunde kann Bot anpassen
- Keine Cross-Talk-Gefahr

**Erstellung:**
1. BotFather öffnen
2. `/newbot`
3. Token erhalten
4. In Script einfügen

---

## 💬 WhatsApp (Optional)

```bash
# Mit WhatsApp aktivieren
./provision-customer.sh 001 "Acme GmbH" --whatsapp

# Dann in .env konfigurieren:
WHATSAPP_TOKEN=your-token
WHATSAPP_PHONE_NUMBER=+491701234567
```

**Provider:**
- Twilio
- MessageBird
- 360dialog

---

## 🛠️ Verwaltung

### Instance starten/stoppen

```bash
cd /opt/nexhelper/customers/acme-gmbh

./start.sh     # Starten
./stop.sh      # Stoppen
./status.sh    # Status
./logs.sh      # Logs
```

### Alle Kunden auflisten

```bash
ls /opt/nexhelper/customers/
```

### Docker-Container anzeigen

```bash
docker ps | grep nexhelper
```

---

## 📊 Monitoring

### Resource Usage

```bash
# Container-Statistiken
docker stats nexhelper-acme-gmbh

# Storage-Verbrauch
du -sh /opt/nexhelper/customers/*/storage
```

### Logs

```bash
# Container Logs
docker logs nexhelper-acme-gmbh

# Audit Logs
cat /opt/nexhelper/customers/acme-gmbh/storage/audit/consent.log
```

---

## 📈 Pricing-Impact

| Plan | Preis | Kosten | Marge | Docs | Nutzer |
|------|-------|--------|-------|------|--------|
| Solo | €19 | ~€4 | 79% | 100 | 1 |
| Team | €49 | ~€12 | 76% | 500 | 5 |
| Business | €99 | ~€25 | 75% | 2000 | ∞ |

**Kosten pro Kunde:** €0.65-1.00 (Shared VPS)

---

## 🔒 Security

- ✅ Docker Network Isolation
- ✅ Keine Shared Database
- ✅ Consent-Validierung bei jeder Nachricht
- ✅ Audit-Trail für alle Events
- ✅ DSGVO-konforme Löschung

---

## 📚 Dokumentation

- `PROVISIONING.md` - Architektur & technische Details
- `consent.yaml` - Consent-Konfiguration
- `config.yaml` - OpenClaw Konfiguration

---

## 🆘 Troubleshooting

### Container startet nicht

```bash
# Logs prüfen
docker logs nexhelper-acme-gmbh

# Port prüfen
lsof -i :3001

# Netzwerk prüfen
docker network ls | grep nexhelper
```

### Telegram reagiert nicht

```bash
# Bot Token prüfen
curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"

# Container Status
docker ps | grep nexhelper
```

### Consent funktioniert nicht

```bash
# Consent-Dateien prüfen
ls -la storage/consent/

# Audit-Log prüfen
cat storage/audit/consent.log
```

---

## 📄 Lizenz

Proprietary - NexTech Fusion

---

## 📞 Support

- GitHub: https://github.com/NexTechFusion/NexWorker-Repo
- Website: https://nexhelper.de
