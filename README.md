# NexHelper Customer Provisioning

**DSGVO-konforme Kunden-Provisioning für NexHelper**

---

## 🏗️ Architektur

```
                        ┌→ Docker: nexhelper-acme
                        │   └── OpenClaw Instance
                        │   └── Isolated Storage ✅
                        │   └── Consent Management ✅
                        │   └── tenant_id: acme
                        │
@NexHelperBot ── Router ─┼→ Docker: nexhelper-mueller
(Shared)                 │   └── OpenClaw Instance
                        │   └── Isolated Storage ✅
                        │   └── Consent Management ✅
                        │   └── tenant_id: mueller
                        │
                        └→ Docker: nexhelper-...
```

---

## ✨ Features

| Feature | Standard | Optional |
|---------|----------|----------|
| OpenClaw Instance | ✅ Pro Kunde | - |
| Isolated Storage | ✅ DSGVO-konform | - |
| Consent Management | ✅ Automatisch | - |
| Audit Logging | ✅ DSGVO Art. 30 | - |
| Shared Bot | ✅ @NexHelperBot | - |
| **Dedicated Bot** | - | 💶 `--dedicated-bot` |
| **WhatsApp** | - | 💶 `--whatsapp` |

---

## 🚀 Quick Start

### Voraussetzungen

```bash
# Docker & Docker Compose installiert
docker --version
docker-compose --version

# Umgebungsvariablen setzen
export TELEGRAM_BOT_TOKEN="123456789:ABC..."  # Shared Bot Token
export OPENAI_API_KEY="sk-..."                 # API Key
```

### Kunden provisionieren

```bash
# Standard (Shared Bot)
./provision-customer.sh 001 "Acme GmbH"

# Mit Dedicated Bot
./provision-customer.sh 001 "Acme GmbH" --dedicated-bot "789:XYZ..."

# Mit WhatsApp
./provision-customer.sh 001 "Acme GmbH" --whatsapp

# Ohne Auto-Start
./provision-customer.sh 001 "Acme GmbH" --no-start
```

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
