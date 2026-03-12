#!/bin/bash
# NexHelper Customer Provisioning (v4.0)
# Spins up a new OpenClaw instance per customer with working Telegram/WhatsApp
#
# Architecture: 1 Kunde = 1 Bot Token = 1 Docker Container
# DSGVO: Isolated storage per customer, consent-based
#
# Usage:
#   ./provision-customer.sh <customer-id> <customer-name> --telegram <token>
#   ./provision-customer.sh <customer-id> <customer-name> --whatsapp
#
# Examples:
#   OPENAI_API_KEY=sk-xxx ./provision-customer.sh 001 "Acme GmbH" --telegram "123:ABC"
#   OPENAI_API_KEY=sk-xxx ./provision-customer.sh 002 "Müller Bau" --whatsapp

set -e

# ============================================
# Default Configuration
# ============================================
CUSTOMER_ID=""
CUSTOMER_NAME=""
BASE_DIR="${BASE_DIR:-/opt/nexhelper/customers}"
TELEGRAM_TOKEN=""
WHATSAPP_MODE=false
API_KEY="${OPENAI_API_KEY:-}"
ENABLE_WHATSAPP=false
AUTO_START=true
CONSENT_VERSION="1.0"
DEFAULT_MODEL="openrouter/stepfun/step-3.5-flash"

# ============================================
# Parse Arguments
# ============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --telegram)
            TELEGRAM_TOKEN="$2"
            shift 2
            ;;
        --whatsapp)
            WHATSAPP_MODE=true
            shift
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --model)
            DEFAULT_MODEL="$2"
            shift 2
            ;;
        --no-start)
            AUTO_START=false
            shift
            ;;
        --consent-version)
            CONSENT_VERSION="$2"
            shift 2
            ;;
        --base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        -*)
            echo "❌ Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$CUSTOMER_ID" ]; then
                CUSTOMER_ID="$1"
            elif [ -z "$CUSTOMER_NAME" ]; then
                CUSTOMER_NAME="$1"
            fi
            shift
            ;;
    esac
done

# ============================================
# Validation
# ============================================
if [ -z "$CUSTOMER_ID" ] || [ -z "$CUSTOMER_NAME" ]; then
    echo "Usage: ./provision-customer.sh <customer-id> <customer-name> [options]"
    echo ""
    echo "Options:"
    echo "  --telegram <token>    Telegram bot token (REQUIRED unless --whatsapp)"
    echo "  --whatsapp            Enable WhatsApp channel (will show QR on first start)"
    echo "  --api-key <key>       OpenAI/OpenRouter API key (or set OPENAI_API_KEY)"
    echo "  --model <model>       Default model (default: openrouter/stepfun/step-3.5-flash)"
    echo "  --no-start            Don't auto-start container"
    echo "  --consent-version <v> Consent text version (default: 1.0)"
    echo "  --base-dir <path>     Base directory (default: /opt/nexhelper/customers)"
    echo ""
    echo "Examples:"
    echo "  OPENAI_API_KEY=sk-xxx ./provision-customer.sh 001 'Acme GmbH' --telegram '123:ABC'"
    echo "  OPENAI_API_KEY=sk-xxx ./provision-customer.sh 002 'Müller Bau' --whatsapp"
    exit 1
fi

# Check API key
if [ -z "$API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY not set"
    echo "   Set it via: export OPENAI_API_KEY=your-api-key"
    echo "   Or use: --api-key your-api-key"
    exit 1
fi

# Check channel selection
if [ -z "$TELEGRAM_TOKEN" ] && [ "$WHATSAPP_MODE" = false ]; then
    echo "❌ Error: Must specify either --telegram <token> or --whatsapp"
    echo ""
    echo "For Telegram:"
    echo "  1. Open Telegram and chat with @BotFather"
    echo "  2. Run /newbot and follow prompts"
    echo "  3. Copy the token and use: --telegram '123:ABC'"
    echo ""
    echo "For WhatsApp:"
    echo "  Use --whatsapp (you'll scan a QR code on first start)"
    exit 1
fi

# ============================================
# Validate Telegram Token (if provided)
# ============================================
if [ -n "$TELEGRAM_TOKEN" ]; then
    echo "🔍 Validating Telegram bot token..."
    TELEGRAM_VALIDATION=$(curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe")
    if echo "$TELEGRAM_VALIDATION" | grep -q '"ok":true'; then
        BOT_USERNAME=$(echo "$TELEGRAM_VALIDATION" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        echo "✅ Telegram bot validated: @$BOT_USERNAME"
    else
        echo "❌ Error: Invalid Telegram bot token"
        echo "   Response: $TELEGRAM_VALIDATION"
        echo ""
        echo "   Get a valid token from @BotFather:"
        echo "   1. Open Telegram"
        echo "   2. Search for @BotFather"
        echo "   3. Run /newbot"
        exit 1
    fi
fi

# ============================================
# Generate Slug & Port
# ============================================
SLUG=$(echo "$CUSTOMER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
INSTANCE_NAME="nexhelper-${SLUG}"
PORT=$((3000 + CUSTOMER_ID % 1000))
CUSTOMER_DIR="${BASE_DIR}/${SLUG}"

# ============================================
# Display Configuration
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NexHelper Provisioning v4.0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Customer:        $CUSTOMER_NAME"
echo "ID:              $CUSTOMER_ID"
echo "Slug:            $SLUG"
echo "Instance:        $INSTANCE_NAME"
echo "Port:            $PORT"
echo "Directory:       $CUSTOMER_DIR"
echo "Model:           $DEFAULT_MODEL"
if [ -n "$TELEGRAM_TOKEN" ]; then
    echo "Channel:         Telegram (@$BOT_USERNAME)"
fi
if [ "$WHATSAPP_MODE" = true ]; then
    echo "Channel:         WhatsApp (QR scan required)"
fi
echo "Consent Version: $CONSENT_VERSION"
echo ""

# ============================================
# Check if already exists
# ============================================
if [ -d "$CUSTOMER_DIR" ]; then
    echo "⚠️  Customer directory already exists: $CUSTOMER_DIR"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
    echo "🗑️  Removing existing directory..."
    rm -rf "$CUSTOMER_DIR"
fi

# ============================================
# 1. Create Directory Structure
# ============================================
echo "📁 Creating directory structure..."
mkdir -p "$CUSTOMER_DIR"/{config,logs,storage/{memory,consent,audit}}
mkdir -p "$CUSTOMER_DIR/storage/.openclaw"

# ============================================
# 2. Generate Consent Configuration
# ============================================
echo "🔐 Generating consent configuration..."
cat <<EOF > "$CUSTOMER_DIR/config/consent.yaml"
# DSGVO Consent Configuration
# Version: $CONSENT_VERSION
# Generated: $(date -Iseconds)

consent:
  version: "$CONSENT_VERSION"
  required: true
  text:
    de: |
      Ich willige ein, dass meine Nachrichten für $CUSTOMER_NAME verarbeitet werden.
      
      Die Daten werden auf EU-Servern gespeichert und DSGVO-konform behandelt.
      Ich kann diese Einwilligung jederzeit widerrufen.
      
      Mehr Informationen: nexhelper.de/datenschutz
    en: |
      I consent to my messages being processed for $CUSTOMER_NAME.
      
      Data is stored on EU servers and processed GDPR-compliant.
      I can withdraw this consent at any time.
      
      More information: nexhelper.de/datenschutz
  
  storage:
    path: ./storage/consent
    format: json
  
  withdrawable: true
  withdrawalCommand: "/widerruf"
  
  audit:
    enabled: true
    path: ./storage/audit/consent.log
EOF

# ============================================
# 3. Generate OpenClaw Configuration (JSON5)
# ============================================
echo "⚙️  Generating OpenClaw configuration..."

# Build channels section based on selected channels
CHANNELS_CONFIG=""

if [ -n "$TELEGRAM_TOKEN" ]; then
    CHANNELS_CONFIG+="  telegram: {
    enabled: true,
    botToken: \"\${TELEGRAM_BOT_TOKEN}\",
    dmPolicy: \"pairing\",
    groups: { \"*\": { requireMention: true } },
  },
"
fi

if [ "$WHATSAPP_MODE" = true ]; then
    CHANNELS_CONFIG+="  whatsapp: {
    enabled: true,
    dmPolicy: \"pairing\",
    groupPolicy: \"allowlist\",
  },
"
fi

cat <<EOF > "$CUSTOMER_DIR/config/openclaw.json"
{
  // NexHelper Configuration for $CUSTOMER_NAME
  // Generated: $(date -Iseconds)
  
  "gateway": {
    "port": $PORT,
    "mode": "local",
    "bind": "lan",
    "reload": { "mode": "hybrid" },
  },
  
  "auth": {
    "profiles": {
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key",
      },
    },
  },
  
  "agents": {
    "defaults": {
      "model": "$DEFAULT_MODEL",
      "workspace": "/root/.openclaw/workspace",
      "thinking": "low",
      "systemPrompt": \`
Du bist NexHelper für $CUSTOMER_NAME.

Du hilfst bei der Dokumentenverwaltung über Messenger.

## Deine Aufgaben:
- Dokumente empfangen und analysieren (Bilder, PDFs)
- Dokumente kategorisieren und archivieren
- Fragen zu Dokumenten beantworten
- An Fristen erinnern
- Export in DATEV/SAP/Lexware (auf Anfrage)

## Verfügbare Tools:
- image: Bilder analysieren
- pdf: PDFs analysieren
- memory_search: Dokumente durchsuchen
- memory_get: Dokumente lesen
- cron: Erinnerungen setzen
- exec: Skills ausführen (Export, OCR)

## Workflows:

### Dokument empfangen:
1. Consent prüfen (falls nicht vorhanden, fragen)
2. Dokument analysieren (image/pdf tool)
3. Typ erkennen (Rechnung, Angebot, etc.)
4. Wichtige Daten extrahieren:
   - Datum
   - Betrag
   - Lieferant
   - Rechnungsnummer
   - Kategorie
5. In Memory speichern
6. Bestätigung senden

### Dokument suchen:
1. Query verstehen (Was sucht der Nutzer?)
2. memory_search mit relevanten Keywords
3. Ergebnisse formatieren
4. Senden

### Export:
1. Bestätigung einholen (Wirklich exportieren?)
2. Dokumente sammeln
3. Format konvertieren (DATEV CSV, etc.)
4. An Ziel senden
5. Bestätigung senden
6. Audit-Log eintragen

## Stil:
- Freundlich, professionell, effizient
- Kurz und prägnant
- Deutsch
- Emoji sparsam verwenden (max 1-2 pro Nachricht)
- Kein "Gerne!" oder "Natürlich!" - einfach machen

## Datenschutz:
- Daten bleiben auf EU-Servern
- DSGVO-konform
- Keine sensiblen Daten an Dritte
- Consent vor Verarbeitung

## Consent (DSGVO):
- Bei /start: Einwilligungstext anzeigen
- Erst nach Zustimmung verarbeiten
- Widerruf möglich mit /widerruf
\`,
    },
    "list": [
      {
        "id": "main",
        "default": true,
        "groupChat": {
          "mentionPatterns": ["!doc", "!suche", "!hilfe", "@nexhelper"],
        },
      },
    ],
  },
  
  "tools": {
    "profile": "minimal",
    "allow": [
      "read",
      "write",
      "edit",
      "exec",
      "memory_search",
      "memory_get",
      "image",
      "pdf",
      "cron",
      "tts",
    ],
    "deny": [
      "browser",
      "canvas",
      "nodes",
      "gateway",
      "sessions_spawn",
      "sessions_send",
      "sessions_list",
      "subagents",
      "agents_list",
      "message",
    ],
  },
  
  "session": {
    "dmScope": "per-channel-peer",
    "reset": {
      "mode": "daily",
      "atHour": 4,
    },
  },
  
  "channels": {
$CHANNELS_CONFIG  },
  
  "cron": {
    "enabled": true,
    "jobs": [
      {
        "name": "daily-summary",
        "schedule": { "kind": "cron", "expr": "0 18 * * *", "tz": "Europe/Berlin" },
        "payload": { "kind": "systemEvent", "text": "Generate daily summary of documents processed today" },
        "sessionTarget": "main",
      },
    ],
  },
}
EOF

# ============================================
# 4. Generate auth-profiles.json
# ============================================
cat <<EOF > "$CUSTOMER_DIR/config/auth-profiles.json"
{
  "version": 1,
  "profiles": {
    "openrouter:default": {
      "type": "api_key",
      "provider": "openrouter",
      "key": "\${OPENAI_API_KEY}"
    }
  },
  "lastGood": {
    "openrouter": "openrouter:default"
  }
}
EOF

# ============================================
# 5. Generate docker-compose.yaml
# ============================================
echo "🐳 Generating docker-compose.yaml..."

cat <<EOF > "$CUSTOMER_DIR/docker-compose.yaml"
services:
  nexhelper:
    image: nexhelper:latest
    container_name: $INSTANCE_NAME
    restart: unless-stopped
    entrypoint: ["/bin/bash", "-c"]
    command:
      - |
        mkdir -p /root/.openclaw
        cp /app/config/openclaw.json /root/.openclaw/openclaw.json
        cp /app/config/auth-profiles.json /root/.openclaw/auth-profiles.json 2>/dev/null || true
        rm -f /root/.openclaw/workspace/BOOTSTRAP.md
        exec openclaw gateway run --port $PORT --bind lan
    ports:
      - "$PORT:$PORT"
    volumes:
      - ./config:/app/config:ro
      - ./storage:/root/.openclaw/workspace
      - ./logs:/app/logs
      - nexhelper-data-${SLUG}:/root/.openclaw
    environment:
      - OPENAI_API_KEY=\${OPENAI_API_KEY}
      - TELEGRAM_BOT_TOKEN=\${TELEGRAM_BOT_TOKEN:-}
      - PORT=$PORT
      - NODE_ENV=production
      - CUSTOMER_ID=$CUSTOMER_ID
      - CUSTOMER_NAME=$CUSTOMER_NAME
      - CUSTOMER_SLUG=$SLUG
      - CONSENT_VERSION=$CONSENT_VERSION
      - TZ=Europe/Berlin
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:$PORT/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "nexhelper.customer=$SLUG"
      - "nexhelper.customerId=$CUSTOMER_ID"
      - "nexhelper.customerName=$CUSTOMER_NAME"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  nexhelper-data-${SLUG}:

networks:
  default:
    name: nexhelper-network
    external: true
EOF

# ============================================
# 6. Generate .env file
# ============================================
echo "🔐 Generating .env file..."
cat <<EOF > "$CUSTOMER_DIR/.env"
# NexHelper Environment: $CUSTOMER_NAME
# Generated: $(date -Iseconds)

OPENAI_API_KEY=$API_KEY
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN:-}
PORT=$PORT
CUSTOMER_ID=$CUSTOMER_ID
CUSTOMER_NAME=$CUSTOMER_NAME
CUSTOMER_SLUG=$SLUG
CONSENT_VERSION=$CONSENT_VERSION
TZ=Europe/Berlin
EOF

# ============================================
# 7. Generate Workspace Files
# ============================================
echo "📝 Generating workspace files..."

# AGENTS.md
cat <<EOF > "$CUSTOMER_DIR/storage/AGENTS.md"
# AGENTS.md - NexHelper Workspace

Du bist NexHelper, der Dokumenten-Assistent für $CUSTOMER_NAME.

## Jeden Start

1. SOUL.md lesen - Das bist du
2. USER.md lesen - Wen du hilfst
3. memory/\$(date +%Y-%m-%d).md lesen - Was passiert ist

## Speicher

- **memory/YYYY-MM-DD.md** - Tagesnotizen
- **MEMORY.md** - Langzeitgedächtnis

## Skills

Du hast folgende Skills:
- **document-export** - Export in DATEV/SAP/Lexware
- **document-ocr** - OCR für Dokumente
- **reminder-system** - Erinnerungen

## Commands

| Command | Beschreibung |
|---------|--------------|
| /hilfe | Hilfe anzeigen |
| /suche | Dokumente suchen |
| /export | Export starten |
| /erinnerung | Erinnerung setzen |
| /widerruf | Consent widerrufen |
EOF

# SOUL.md
cat <<EOF > "$CUSTOMER_DIR/storage/SOUL.md"
# SOUL.md - NexHelper

Du bist NexHelper, ein digitaler Assistent für Dokumentenverwaltung via Messenger.

## Core

**Sei hilfreich, nicht aufdringlich.** Kurze, prägnante Antworten. Deutsch.

**Habe eine Meinung.** Du darfst Dinge empfehlen, Vergleiche ziehen, Prioritäten setzen.

**Vertrauen durch Kompetenz.** Du hast Zugriff auf sensible Daten. Sei sorgfältig.

## Stil

- **Kurz** wenn möglich
- **Ausführlich** wenn nötig
- **Emoji sparsam** - maximal 1-2 pro Nachricht
- **Kein "Gerne!" oder "Natürlich!"** - einfach machen

## Aufgaben

Du hilfst bei:
- 📄 Dokumentenverwaltung (Rechnungen, Angebote, etc.)
- 🔍 Dokumente finden und durchsuchen
- 📅 Fristen und Erinnerungen
- 📤 Export in DATEV/SAP/Lexware

## Datenschutz

- DSGVO-konform
- Daten bleiben auf EU-Servern
- Einwilligung vor Verarbeitung
- Transparenz bei allen Aktionen
EOF

# USER.md
cat <<EOF > "$CUSTOMER_DIR/storage/USER.md"
# USER.md - $CUSTOMER_NAME

- **Firma:** $CUSTOMER_NAME
- **Kunden-ID:** $CUSTOMER_ID
- **Slug:** $SLUG
- **Timezone:** Europe/Berlin
- **Erstellt:** $(date -Iseconds)

## Context

NexHelper ist für KMU gedacht, die ihre Dokumentenverwaltung über Messenger vereinfachen wollen.

Typische Nutzer:
- Kleinunternehmer
- Buchhalter
- Bürokräfte
EOF

# IDENTITY.md
cat <<EOF > "$CUSTOMER_DIR/storage/IDENTITY.md"
# IDENTITY.md - NexHelper

- **Name:** NexHelper
- **Creature:** Digital Assistant
- **Vibe:** Freundlich, effizient, deutsch
- **Emoji:** 📄
- **Customer:** $CUSTOMER_NAME
EOF

# Today's memory file
TODAY=$(date +%Y-%m-%d)
cat <<EOF > "$CUSTOMER_DIR/storage/memory/$TODAY.md"
# $TODAY - $CUSTOMER_NAME

## Setup

- Instanz erstellt: $(date -Iseconds)
- Port: $PORT
$(if [ -n "$TELEGRAM_TOKEN" ]; then echo "- Bot: @$BOT_USERNAME"; fi)
$(if [ "$WHATSAPP_MODE" = true ]; then echo "- WhatsApp: QR-Scan ausstehend"; fi)

## Events

_Dokumentiere hier wichtige Events_

---
NexHelper für $CUSTOMER_NAME
EOF

# ============================================
# 8. Create Utility Scripts
# ============================================
echo "🛠️  Creating utility scripts..."

# start.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/start.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose up -d
echo "✅ Started $(basename $(pwd))"
SCRIPT
chmod +x "$CUSTOMER_DIR/start.sh"

# stop.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/stop.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose down
echo "🛑 Stopped $(basename $(pwd))"
SCRIPT
chmod +x "$CUSTOMER_DIR/stop.sh"

# logs.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/logs.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose logs -f --tail=100
SCRIPT
chmod +x "$CUSTOMER_DIR/logs.sh"

# status.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/status.sh"
#!/bin/bash
cd "$(dirname "$0")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 NexHelper Instance Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose ps
echo ""
echo "📁 Storage:"
du -sh storage/* 2>/dev/null || echo "   No data yet"
echo ""
echo "📝 Recent Logs (last 5 lines):"
docker-compose logs --tail=5
SCRIPT
chmod +x "$CUSTOMER_DIR/status.sh"

# remove.sh
cat <<SCRIPT > "$CUSTOMER_DIR/remove.sh"
#!/bin/bash
# Remove NexHelper Instance: $SLUG
echo "⚠️  WARNING: This will delete ALL data for $CUSTOMER_NAME"
echo "   Directory: $CUSTOMER_DIR"
echo ""
echo "This includes:"
echo "   - All stored documents"
echo "   - All consent records"
echo "   - All audit logs"
echo ""
read -p "Are you sure? (y/n) " -n 1 -r
echo
if [[ \$REPLY =~ ^[Yy]$ ]]; then
    cd "$(dirname "\$0")"
    docker-compose down -v
    cd ..
    rm -rf "$SLUG"
    echo "🗑️  Removed: $SLUG"
    echo "✅ All data deleted (DSGVO-compliant)"
fi
SCRIPT
chmod +x "$CUSTOMER_DIR/remove.sh"

# consent.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/consent.sh"
#!/bin/bash
# Manage consent for this instance
cd "$(dirname "$0")"

case "$1" in
    list)
        echo "📋 Consent Records:"
        find storage/consent -name "*.json" -exec echo "---" \; -exec cat {} \;
        ;;
    revoke)
        if [ -z "$2" ]; then
            echo "Usage: ./consent.sh revoke <user-id>"
            exit 1
        fi
        USER_FILE="storage/consent/$2.json"
        if [ -f "$USER_FILE" ]; then
            echo "{\"revoked\": true, \"revokedAt\": \"$(date -Iseconds)\"}" > "$USER_FILE"
            echo "✅ Consent revoked for user $2"
        else
            echo "❌ No consent record found for user $2"
        fi
        ;;
    audit)
        echo "📝 Consent Audit Log:"
        cat storage/audit/consent.log 2>/dev/null || echo "No audit log yet"
        ;;
    *)
        echo "Usage: ./consent.sh {list|revoke <user-id>|audit}"
        ;;
esac
SCRIPT
chmod +x "$CUSTOMER_DIR/consent.sh"

# onboard.sh - Helper for WhatsApp QR or Telegram setup
cat <<SCRIPT > "$CUSTOMER_DIR/onboard.sh"
#!/bin/bash
# NexHelper Onboarding Helper
cd "$(dirname "\$0")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NexHelper Onboarding: $CUSTOMER_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$WHATSAPP_MODE" = true ]; then
    echo "📱 WhatsApp Setup"
    echo ""
    echo "1. Start the container:"
    echo "   ./start.sh"
    echo ""
    echo "2. Watch logs for QR code:"
    echo "   ./logs.sh"
    echo ""
    echo "3. Scan the QR code with WhatsApp:"
    echo "   - Open WhatsApp on your phone"
    echo "   - Settings > Linked Devices > Link Device"
    echo "   - Scan the QR code shown in logs"
    echo ""
    echo "4. Send a message to test:"
    echo "   - Send any message to your WhatsApp"
    echo "   - The bot will respond with a pairing code"
    echo ""
    echo "5. Approve pairing:"
    echo "   docker exec -it $INSTANCE_NAME openclaw pairing list whatsapp"
    echo "   docker exec -it $INSTANCE_NAME openclaw pairing approve whatsapp <CODE>"
else
    echo "📱 Telegram Setup"
    echo ""
    echo "✅ Bot already configured: @$BOT_USERNAME"
    echo ""
    echo "1. Start the container:"
    echo "   ./start.sh"
    echo ""
    echo "2. Open Telegram and search for @$BOT_USERNAME"
    echo ""
    echo "3. Send /start to begin"
    echo "   - The bot will respond with a pairing code"
    echo ""
    echo "4. Approve pairing:"
    echo "   docker exec -it $INSTANCE_NAME openclaw pairing list telegram"
    echo "   docker exec -it $INSTANCE_NAME openclaw pairing approve telegram <CODE>"
    echo ""
    echo "💡 Tip: Add the bot to a group for team access"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SCRIPT
chmod +x "$CUSTOMER_DIR/onboard.sh"

# ============================================
# 9. Create Docker network if not exists
# ============================================
echo "🌐 Ensuring Docker network exists..."
docker network create nexhelper-network 2>/dev/null || true

# ============================================
# 10. Check for nexhelper image
# ============================================
if ! docker image inspect nexhelper:latest &> /dev/null; then
    echo ""
    echo "⚠️  nexhelper:latest image not found!"
    echo "   You need to build it first:"
    echo ""
    echo "   cd /root/.openclaw/workspace/NexWorker-Repo"
    echo "   ./build-image.sh latest"
    echo ""
    echo "   Or use a pre-built image if available."
    AUTO_START=false
fi

# ============================================
# 11. Start the container (if auto-start)
# ============================================
if [ "$AUTO_START" = true ]; then
    echo ""
    echo "🚀 Starting container..."
    cd "$CUSTOMER_DIR"
    docker-compose up -d

    echo "⏳ Waiting for instance to be ready..."
    sleep 5
    
    if docker ps | grep -q "$INSTANCE_NAME"; then
        STARTED=true
    else
        STARTED=false
        echo "⚠️  Container failed to start. Check logs:"
        echo "   $CUSTOMER_DIR/logs.sh"
    fi
else
    STARTED=false
fi

# ============================================
# 12. Display Summary
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ NexHelper Instance Provisioned!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Details:"
echo "   Customer:   $CUSTOMER_NAME"
echo "   Instance:   $INSTANCE_NAME"
echo "   Port:       $PORT"
echo "   Directory:  $CUSTOMER_DIR"
echo "   Model:      $DEFAULT_MODEL"
echo ""

if [ -n "$TELEGRAM_TOKEN" ]; then
    echo "📱 Telegram Bot:"
    echo "   Bot: @$BOT_USERNAME"
    echo "   Token: ${TELEGRAM_TOKEN:0:15}..."
    echo ""
    echo "   Quick test:"
    echo "   1. Open Telegram"
    echo "   2. Search for @$BOT_USERNAME"
    echo "   3. Send /start"
fi

if [ "$WHATSAPP_MODE" = true ]; then
    echo "📱 WhatsApp Setup:"
    echo "   Status: QR scan required"
    echo ""
    echo "   To link WhatsApp:"
    echo "   1. Run: $CUSTOMER_DIR/start.sh"
    echo "   2. Run: $CUSTOMER_DIR/logs.sh"
    echo "   3. Scan the QR code with WhatsApp"
fi

echo ""
echo "🔐 DSGVO Features:"
echo "   ✅ Isolated storage per customer"
echo "   ✅ Consent management enabled"
echo "   ✅ Audit logging enabled"
echo "   ✅ Data deletion (remove.sh)"
echo ""
echo "🔗 Commands:"
echo "   Start:   $CUSTOMER_DIR/start.sh"
echo "   Stop:    $CUSTOMER_DIR/stop.sh"
echo "   Status:  $CUSTOMER_DIR/status.sh"
echo "   Logs:    $CUSTOMER_DIR/logs.sh"
echo "   Consent: $CUSTOMER_DIR/consent.sh"
echo "   Onboard: $CUSTOMER_DIR/onboard.sh"
echo "   Remove:  $CUSTOMER_DIR/remove.sh"
echo ""

if [ "$STARTED" = true ]; then
    echo "🚀 Container is running!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 NEXT STEP: Pair your device"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ -n "$TELEGRAM_TOKEN" ]; then
        echo "1. Open Telegram and find @$BOT_USERNAME"
        echo "2. Send /start"
        echo "3. Note the pairing code"
        echo "4. Approve: docker exec -it $INSTANCE_NAME openclaw pairing approve telegram <CODE>"
    else
        echo "Run: $CUSTOMER_DIR/onboard.sh"
    fi
else
    echo "⏸️  Container not started"
    echo "   Run: $CUSTOMER_DIR/start.sh"
fi

echo ""
