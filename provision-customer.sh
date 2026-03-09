#!/bin/bash
# NexHelper Customer Provisioning (v3.0)
# Spins up a new OpenClaw instance per customer
#
# Architecture: 1 Kunde = 1 Bot Token = 1 Docker Container
# DSGVO: Isolated storage per customer, consent-based
#
# Usage:
#   ./provision-customer.sh <customer-id> <customer-name> --bot-token <token>
#
# Example:
#   OPENAI_API_KEY=sk-xxx ./provision-customer.sh 001 "Acme GmbH" --bot-token "123:ABC"

set -e

# ============================================
# Default Configuration
# ============================================
CUSTOMER_ID=""
CUSTOMER_NAME=""
BASE_DIR="${BASE_DIR:-/opt/nexhelper/customers}"
BOT_TOKEN=""
API_KEY="${OPENAI_API_KEY:-}"
ENABLE_WHATSAPP=false
AUTO_START=true
CONSENT_VERSION="1.0"

# ============================================
# Parse Arguments
# ============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --bot-token)
            BOT_TOKEN="$2"
            shift 2
            ;;
        --whatsapp)
            ENABLE_WHATSAPP=true
            shift
            ;;
        --no-start)
            AUTO_START=false
            shift
            ;;
        --consent-version)
            CONSENT_VERSION="$2"
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
    echo "Usage: ./provision-customer.sh <customer-id> <customer-name> --bot-token <token>"
    echo ""
    echo "Options:"
    echo "  --bot-token <token>       Telegram bot token (REQUIRED)"
    echo "  --whatsapp                Enable WhatsApp channel"
    echo "  --no-start                Don't auto-start container"
    echo "  --consent-version <ver>   Consent text version (default: 1.0)"
    echo ""
    echo "Environment Variables:"
    echo "  OPENAI_API_KEY      OpenAI/OpenRouter API key (required)"
    echo "  BASE_DIR            Base directory (default: /opt/nexhelper/customers)"
    echo ""
    echo "Example:"
    echo "  OPENAI_API_KEY=sk-xxx ./provision-customer.sh 001 'Acme GmbH' --bot-token '123:ABC'"
    exit 1
fi

# Check API key
if [ -z "$API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY not set"
    echo "   Set it via: export OPENAI_API_KEY=your-api-key"
    exit 1
fi

# Check bot token
if [ -z "$BOT_TOKEN" ]; then
    echo "❌ Error: --bot-token is required"
    echo "   Create a bot via @BotFather in Telegram"
    echo "   Then: ./provision-customer.sh 001 'Kunde' --bot-token '123:ABC'"
    exit 1
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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NexHelper Provisioning v3.0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Customer:        $CUSTOMER_NAME"
echo "ID:              $CUSTOMER_ID"
echo "Slug:            $SLUG"
echo "Instance:        $INSTANCE_NAME"
echo "Port:            $PORT"
echo "Directory:       $CUSTOMER_DIR"
echo "Bot Token:       ${BOT_TOKEN:0:10}..."
echo "WhatsApp:        $([ "$ENABLE_WHATSAPP" = true ] && echo "enabled" || echo "disabled")"
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
# 3. Generate OpenClaw config
# ============================================
echo "⚙️  Generating OpenClaw config..."

# openclaw.json - Main config
cat <<EOF > "$CUSTOMER_DIR/config/openclaw.json"
{
  "auth": {
    "profiles": {
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": "openrouter/stepfun/step-3.5-flash",
      "workspace": "/root/.openclaw/workspace"
    }
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
      "tts"
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
      "message"
    ]
  },
  "commands": {
    "native": false,
    "nativeSkills": false,
    "restart": false,
    "ownerDisplay": "hash"
  },
  "gateway": {
    "port": $PORT,
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "nexhelper-${SLUG}-$(echo $CUSTOMER_ID | sha256sum | cut -c1-16)"
    }
  }
}
EOF

# auth-profiles.json - API keys
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
# 4. Generate docker-compose.yaml
# ============================================
echo "🐳 Generating docker-compose.yaml..."

WHATSAPP_ENV=""
if [ "$ENABLE_WHATSAPP" = true ]; then
    WHATSAPP_ENV="
      - WHATSAPP_TOKEN=\${WHATSAPP_TOKEN:-}
      - WHATSAPP_PHONE_NUMBER=\${WHATSAPP_PHONE_NUMBER:-}
"
fi

cat <<EOF > "$CUSTOMER_DIR/docker-compose.yaml"
services:
  nexhelper:
    image: nexhelper:latest
    container_name: $INSTANCE_NAME
    restart: unless-stopped
    entrypoint: ["/bin/bash", "-c", "mkdir -p /root/.openclaw/agents/main/agent && cp /app/config/openclaw.json /root/.openclaw/openclaw.json && cp /app/config/auth-profiles.json /root/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null || true && rm -f /root/.openclaw/workspace/BOOTSTRAP.md && exec openclaw gateway run --port $PORT --bind lan"]
    ports:
      - "$PORT:$PORT"
    volumes:
      - ./config:/app/config
      - ./storage:/root/.openclaw/workspace
      - ./logs:/app/logs
    environment:
      - OPENAI_API_KEY=\${OPENAI_API_KEY}
      - TELEGRAM_BOT_TOKEN=\${TELEGRAM_BOT_TOKEN}
      - PORT=$PORT
      - NODE_ENV=production
      - CUSTOMER_ID=$CUSTOMER_ID
      - CUSTOMER_SLUG=$SLUG
      - CONSENT_VERSION=$CONSENT_VERSION$WHATSAPP_ENV
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

networks:
  default:
    name: nexhelper-network
    external: true
EOF

# ============================================
# 5. Generate .env file
# ============================================
echo "🔐 Generating .env file..."
cat <<EOF > "$CUSTOMER_DIR/.env"
# NexHelper Environment: $CUSTOMER_NAME
# Generated: $(date -Iseconds)

OPENAI_API_KEY=$API_KEY
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
PORT=$PORT
CUSTOMER_ID=$CUSTOMER_ID
CUSTOMER_NAME=$CUSTOMER_NAME
CUSTOMER_SLUG=$SLUG
CONSENT_VERSION=$CONSENT_VERSION
EOF

if [ "$ENABLE_WHATSAPP" = true ]; then
    echo "WHATSAPP_TOKEN=" >> "$CUSTOMER_DIR/.env"
    echo "WHATSAPP_PHONE_NUMBER=" >> "$CUSTOMER_DIR/.env"
fi

# ============================================
# 6. Generate Workspace Files
# ============================================
echo "📝 Generating workspace files..."

mkdir -p "$CUSTOMER_DIR/storage/memory"

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
- **email-sender** - E-Mails senden
- **reminder-system** - Erinnerungen

## Commands

| Command | Beschreibung |
|---------|--------------|
| /hilfe | Hilfe anzeigen |
| /suche | Dokumente suchen |
| /export | Export starten |
| /erinnerung | Erinnerung setzen |
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

## Events

_Dokumentiere hier wichtige Events_

---
NexHelper für $CUSTOMER_NAME
EOF

# ============================================
# 7. Create utility scripts
# ============================================

cat <<'SCRIPT' > "$CUSTOMER_DIR/start.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose up -d
echo "✅ Started $(basename $(pwd))"
SCRIPT
chmod +x "$CUSTOMER_DIR/start.sh"

cat <<'SCRIPT' > "$CUSTOMER_DIR/stop.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose down
echo "🛑 Stopped $(basename $(pwd))"
SCRIPT
chmod +x "$CUSTOMER_DIR/stop.sh"

cat <<'SCRIPT' > "$CUSTOMER_DIR/logs.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose logs -f --tail=100
SCRIPT
chmod +x "$CUSTOMER_DIR/logs.sh"

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

# ============================================
# 8. Create network if not exists
# ============================================
echo "🌐 Ensuring Docker network exists..."
docker network create nexhelper-network 2>/dev/null || true

# ============================================
# 9. Check for nexhelper image
# ============================================
if ! docker image inspect nexhelper:latest &> /dev/null; then
    echo ""
    echo "⚠️  nexhelper:latest image not found!"
    echo "   Building image first..."
    echo ""
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/build-image.sh" ]; then
        "$SCRIPT_DIR/build-image.sh" latest
    else
        echo "❌ build-image.sh not found"
        echo "   Run: ./build-image.sh"
        exit 1
    fi
fi

# ============================================
# 10. Start the container (if auto-start)
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
    fi
else
    STARTED=false
fi

# ============================================
# 11. Display Summary
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
echo ""
echo "📱 Telegram Bot:"
echo "   Token: ${BOT_TOKEN:0:15}..."
echo "   Setup via @BotFather"
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
echo "   Remove:  $CUSTOMER_DIR/remove.sh"
echo ""

if [ "$STARTED" = true ]; then
    echo "🚀 Container is running!"
    echo ""
    echo "📱 Test your bot:"
    echo "   1. Open Telegram"
    echo "   2. Search for your bot (from @BotFather)"
    echo "   3. Send /start"
else
    echo "⏸️  Container not started (--no-start)"
    echo "   Run: $CUSTOMER_DIR/start.sh"
fi