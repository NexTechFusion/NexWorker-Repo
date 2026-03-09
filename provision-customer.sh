#!/bin/bash
# NexHelper Customer Provisioning (v2.0)
# Spins up a new OpenClaw instance per customer
#
# Architecture: Docker per Kunde, Shared Telegram Bot with Router
# DSGVO: Consent-based, isolated storage per customer
#
# Usage:
#   ./provision-customer.sh <customer-id> <customer-name> [options]
#
# Options:
#   --dedicated-bot <token>   Use dedicated Telegram bot instead of shared
#   --whatsapp                Enable WhatsApp channel (requires setup)
#   --no-start                Don't auto-start the container
#   --consent-version <ver>   Consent text version (default: 1.0)
#
# Example:
#   TELEGRAM_BOT_TOKEN=123:ABC OPENAI_API_KEY=sk-xxx \
#     ./provision-customer.sh 001 "Acme GmbH"
#
#   # With dedicated bot:
#   ./provision-customer.sh 001 "Acme GmbH" --dedicated-bot "789:XYZ"

set -e

# ============================================
# Default Configuration
# ============================================
CUSTOMER_ID=""
CUSTOMER_NAME=""
BASE_DIR="${BASE_DIR:-/opt/nexhelper/customers}"
SHARED_TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
SHARED_API_KEY="${OPENAI_API_KEY:-}"
DEDICATED_BOT_TOKEN=""
ENABLE_WHATSAPP=false
AUTO_START=true
CONSENT_VERSION="1.0"

# ============================================
# Parse Arguments
# ============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --dedicated-bot)
            DEDICATED_BOT_TOKEN="$2"
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
    echo "Usage: ./provision-customer.sh <customer-id> <customer-name> [options]"
    echo ""
    echo "Options:"
    echo "  --dedicated-bot <token>   Use dedicated Telegram bot"
    echo "  --whatsapp                Enable WhatsApp channel"
    echo "  --no-start                Don't auto-start container"
    echo "  --consent-version <ver>   Consent text version (default: 1.0)"
    echo ""
    echo "Environment Variables:"
    echo "  TELEGRAM_BOT_TOKEN  - Shared Telegram bot token (required if no --dedicated-bot)"
    echo "  OPENAI_API_KEY      - OpenAI/OpenRouter API key (required)"
    echo "  BASE_DIR            - Base directory (default: /opt/nexhelper/customers)"
    echo ""
    echo "Examples:"
    echo "  # Standard (Shared Bot)"
    echo "  TELEGRAM_BOT_TOKEN=123:ABC OPENAI_API_KEY=sk-xxx ./provision-customer.sh 001 'Acme GmbH'"
    echo ""
    echo "  # With dedicated bot"
    echo "  OPENAI_API_KEY=sk-xxx ./provision-customer.sh 001 'Acme GmbH' --dedicated-bot '789:XYZ'"
    exit 1
fi

# Check API key
if [ -z "$SHARED_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY not set"
    echo "   Set it via: export OPENAI_API_KEY=your-api-key"
    exit 1
fi

# Determine which Telegram token to use
if [ -n "$DEDICATED_BOT_TOKEN" ]; then
    TELEGRAM_TOKEN="$DEDICATED_BOT_TOKEN"
    BOT_MODE="dedicated"
elif [ -n "$SHARED_TELEGRAM_TOKEN" ]; then
    TELEGRAM_TOKEN="$SHARED_TELEGRAM_TOKEN"
    BOT_MODE="shared"
else
    echo "❌ Error: No Telegram bot token provided"
    echo "   Set TELEGRAM_BOT_TOKEN or use --dedicated-bot"
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
echo "🚀 NexHelper Provisioning v2.0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Customer:        $CUSTOMER_NAME"
echo "ID:              $CUSTOMER_ID"
echo "Slug:            $SLUG"
echo "Instance:        $INSTANCE_NAME"
echo "Port:            $PORT"
echo "Directory:       $CUSTOMER_DIR"
echo "Bot Mode:        $BOT_MODE"
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
# 3. Generate config.yaml
# ============================================
echo "⚙️  Generating config.yaml..."

# Build WhatsApp config if enabled
WHATSAPP_CONFIG=""
if [ "$ENABLE_WHATSAPP" = true ]; then
    WHATSAPP_CONFIG="
  whatsapp:
    enabled: true
    # Token via environment: WHATSAPP_TOKEN
    # Phone number via environment: WHATSAPP_PHONE_NUMBER
"
fi

# Build routing config based on bot mode
if [ "$BOT_MODE" = "shared" ]; then
    ROUTING_CONFIG="
routing:
  tenantId: \"$SLUG\"
  sharedBot: true
  consentRequired: true
"
else
    ROUTING_CONFIG="
routing:
  tenantId: \"$SLUG\"
  sharedBot: false
  consentRequired: true
"
fi

cat <<EOF > "$CUSTOMER_DIR/config/config.yaml"
# NexHelper Instance: $CUSTOMER_NAME
# Generated: $(date -Iseconds)
# Bot Mode: $BOT_MODE

customer:
  id: "$CUSTOMER_ID"
  name: "$CUSTOMER_NAME"
  slug: "$SLUG"
  createdAt: "$(date -Iseconds)"

gateway:
  port: $PORT
  auth:
    token: "nexhelper-${SLUG}-$(echo $CUSTOMER_ID | sha256sum | cut -c1-16)"

agent:
  model: openrouter/stepfun/step-3.5-flash
  systemPrompt: |
    Du bist NexHelper für $CUSTOMER_NAME.
    
    Du hilfst bei der Dokumentenverwaltung über Messenger.
    
    ## Deine Aufgaben:
    - Dokumente kategorisieren und archivieren
    - Fragen zu Dokumenten beantworten
    - An Dokumente erinnern
    - Mit DATEV/SAP/Lexware integrieren (via Backoffice)
    
    ## Stil:
    - Freundlich, professionell, effizient
    - Kurz und prägnant
    - Deutsch
    
    ## Datenschutz:
    - Daten bleiben auf EU-Servern
    - DSGVO-konform
    - Keine sensiblen Daten an Dritte
    
    ## Consent (DSGVO):
    - Bei /start: Zeige Einwilligungstext
    - Nutzer muss zustimmen bevor Verarbeitung
    - Widerruf möglich mit /widerruf

channels:
  telegram:
    token: "\${TELEGRAM_BOT_TOKEN}"
    enabled: true
    groupChat:
      mentionPatterns: ["!doc", "!suche", "!hilfe"]
$WHATSAPP_CONFIG
memory:
  path: ./storage/memory
  autoArchive: true
$ROUTING_CONFIG
consent:
  configPath: ./config/consent.yaml
  required: true

audit:
  enabled: true
  path: ./storage/audit
  events: ["message", "consent", "access"]
EOF

# ============================================
# 4. Generate docker-compose.yaml
# ============================================
echo "🐳 Generating docker-compose.yaml..."

# Add WhatsApp environment if enabled
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
      - "nexhelper.botMode=$BOT_MODE"
      - "nexhelper.whatsapp=$ENABLE_WHATSAPP"
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
# 4.5 Generate Workspace Files
# ============================================
echo "📝 Generating workspace files..."

# Create memory directory
mkdir -p "$CUSTOMER_DIR/storage/memory"

# AGENTS.md - Workspace instructions
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

## Reaktionen

Reagiere nur wenn:
- Du direkt erwähnt wirst
- Jemand eine Frage hat
- Du echten Mehrwert bieten kannst
EOF

# SOUL.md - Personality
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

# USER.md - Customer info
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

# IDENTITY.md - Bot identity
cat <<EOF > "$CUSTOMER_DIR/storage/IDENTITY.md"
# IDENTITY.md - NexHelper

- **Name:** NexHelper
- **Creature:** Digital Assistant
- **Vibe:** Freundlich, effizient, deutsch
- **Emoji:** 📄
- **Customer:** $CUSTOMER_NAME
EOF

# Create today's memory file
TODAY=$(date +%Y-%m-%d)
cat <<EOF > "$CUSTOMER_DIR/storage/memory/$TODAY.md"
# $TODAY - $CUSTOMER_NAME

## Setup

- Instanz erstellt: $(date -Iseconds)
- Bot Mode: $BOT_MODE
- Port: $PORT

## Events

_Dokumentiere hier wichtige Events_

---
NexHelper für $CUSTOMER_NAME
EOF

# ============================================
# 4. Generate OpenClaw config files
# ============================================
echo "⚙️  Generating OpenClaw config files..."

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
    "profile": "full",
    "allow": ["*"]
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
# 5. Generate docker-compose.yaml
# ============================================
echo "🐳 Generating docker-compose.yaml..."

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
      - "nexhelper.botMode=$BOT_MODE"
      - "nexhelper.whatsapp=$ENABLE_WHATSAPP"
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
# 6. Generate .env file
# ============================================
echo "🔐 Generating .env file..."
cat <<EOF > "$CUSTOMER_DIR/.env"
# NexHelper Environment: $CUSTOMER_NAME
# Generated: $(date -Iseconds)

OPENAI_API_KEY=$SHARED_API_KEY
TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN
PORT=$PORT
CUSTOMER_ID=$CUSTOMER_ID
CUSTOMER_NAME=$CUSTOMER_NAME
CUSTOMER_SLUG=$SLUG
BOT_MODE=$BOT_MODE
CONSENT_VERSION=$CONSENT_VERSION
EOF

if [ "$ENABLE_WHATSAPP" = true ]; then
    echo "WHATSAPP_TOKEN=" >> "$CUSTOMER_DIR/.env"
    echo "WHATSAPP_PHONE_NUMBER=" >> "$CUSTOMER_DIR/.env"
fi

# ============================================
# 6. Create utility scripts
# ============================================

# Start script
cat <<'SCRIPT' > "$CUSTOMER_DIR/start.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose up -d
echo "✅ Started $(basename $(pwd))"
SCRIPT
chmod +x "$CUSTOMER_DIR/start.sh"

# Stop script
cat <<'SCRIPT' > "$CUSTOMER_DIR/stop.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose down
echo "🛑 Stopped $(basename $(pwd))"
SCRIPT
chmod +x "$CUSTOMER_DIR/stop.sh"

# Logs script
cat <<'SCRIPT' > "$CUSTOMER_DIR/logs.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose logs -f --tail=100
SCRIPT
chmod +x "$CUSTOMER_DIR/logs.sh"

# Status script
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

# Remove script
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

# Consent management script
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
# 7. Create network if not exists
# ============================================
echo "🌐 Ensuring Docker network exists..."
docker network create nexhelper-network 2>/dev/null || true

# ============================================
# 7.5 Check for nexhelper image
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
        echo "   Or use: image: openclaw/openclaw:latest"
        exit 1
    fi
fi

# ============================================
# 8. Start the container (if auto-start)
# ============================================
if [ "$AUTO_START" = true ]; then
    echo ""
    echo "🚀 Starting container..."
    cd "$CUSTOMER_DIR"
    docker-compose up -d

    echo "⏳ Waiting for instance to be ready..."
    sleep 5

    # Check if container is running
    if docker ps | grep -q "$INSTANCE_NAME"; then
        STARTED=true
    else
        STARTED=false
    fi
else
    STARTED=false
fi

# ============================================
# 9. Display Summary
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
echo "   Bot Mode:   $BOT_MODE"
echo ""
echo "🔐 DSGVO Features:"
echo "   ✅ Isolated storage per customer"
echo "   ✅ Consent management enabled"
echo "   ✅ Audit logging enabled"
echo "   ✅ Data deletion possible (remove.sh)"
echo ""
echo "🔗 Commands:"
echo "   Start:   $CUSTOMER_DIR/start.sh"
echo "   Stop:    $CUSTOMER_DIR/stop.sh"
echo "   Status:  $CUSTOMER_DIR/status.sh"
echo "   Logs:    $CUSTOMER_DIR/logs.sh"
echo "   Consent: $CUSTOMER_DIR/consent.sh"
echo "   Remove:  $CUSTOMER_DIR/remove.sh"
echo ""

if [ "$BOT_MODE" = "shared" ]; then
    echo "📱 Telegram (Shared Bot):"
    echo "   Bot: @NexHelperBot"
    echo "   Router will direct messages to this instance"
    echo "   Users must consent before processing"
    echo ""
else
    echo "📱 Telegram (Dedicated Bot):"
    echo "   Token: ${DEDICATED_BOT_TOKEN:0:10}..."
    echo "   Users must consent before processing"
    echo ""
fi

if [ "$ENABLE_WHATSAPP" = true ]; then
    echo "📱 WhatsApp:"
    echo "   Configure in .env:"
    echo "   WHATSAPP_TOKEN=your-token"
    echo "   WHATSAPP_PHONE_NUMBER=your-number"
    echo ""
fi

if [ "$STARTED" = true ]; then
    echo "🚀 Container is running!"
else
    echo "⏸️  Container not started (--no-start or manual start required)"
    echo "   Run: $CUSTOMER_DIR/start.sh"
fi
