#!/bin/bash
# NexHelper Customer Provisioning (v1.0)
# Spins up a new OpenClaw instance per customer
#
# Architecture: Docker per Kunde, Shared Telegram Bot with Router
#
# Usage:
#   ./provision-customer.sh <customer-id> <customer-name> <telegram-token>
#
# Example:
#   ./provision-customer.sh 001 "Acme GmbH"
#
# Note: Telegram token is shared across all customers (router-based)

set -e

# ============================================
# Configuration
# ============================================
CUSTOMER_ID=$1
CUSTOMER_NAME=$2
BASE_DIR="${BASE_DIR:-/opt/nexhelper/customers}"
SHARED_TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
SHARED_API_KEY="${OPENAI_API_KEY:-}"

# ============================================
# Validation
# ============================================
if [ -z "$CUSTOMER_ID" ] || [ -z "$CUSTOMER_NAME" ]; then
    echo "Usage: ./provision-customer.sh <customer-id> <customer-name>"
    echo ""
    echo "Environment Variables:"
    echo "  TELEGRAM_BOT_TOKEN  - Shared Telegram bot token (required)"
    echo "  OPENAI_API_KEY      - OpenAI/OpenRouter API key (required)"
    echo "  BASE_DIR            - Base directory for customers (default: /opt/nexhelper/customers)"
    echo ""
    echo "Example:"
    echo "  TELEGRAM_BOT_TOKEN=123:ABC OPENAI_API_KEY=sk-xxx ./provision-customer.sh 001 'Acme GmbH'"
    exit 1
fi

if [ -z "$SHARED_TELEGRAM_TOKEN" ]; then
    echo "❌ Error: TELEGRAM_BOT_TOKEN not set"
    echo "   Set it via: export TELEGRAM_BOT_TOKEN=your-bot-token"
    exit 1
fi

if [ -z "$SHARED_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY not set"
    echo "   Set it via: export OPENAI_API_KEY=your-api-key"
    exit 1
fi

# ============================================
# Generate Slug & Port
# ============================================
SLUG=$(echo "$CUSTOMER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
INSTANCE_NAME="nexhelper-${SLUG}"
PORT=$((3000 + CUSTOMER_ID % 1000))
CUSTOMER_DIR="${BASE_DIR}/${SLUG}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NexHelper Provisioning"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Customer:    $CUSTOMER_NAME"
echo "ID:          $CUSTOMER_ID"
echo "Slug:        $SLUG"
echo "Instance:    $INSTANCE_NAME"
echo "Port:        $PORT"
echo "Directory:   $CUSTOMER_DIR"
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
mkdir -p "$CUSTOMER_DIR"/{config,logs,storage/memory}

# ============================================
# 2. Generate config.yaml
# ============================================
echo "⚙️  Generating config.yaml..."
cat <<EOF > "$CUSTOMER_DIR/config/config.yaml"
# NexHelper Instance: $CUSTOMER_NAME
# Generated: $(date -Iseconds)

customer:
  id: "$CUSTOMER_ID"
  name: "$CUSTOMER_NAME"
  slug: "$SLUG"

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

channels:
  telegram:
    token: "\${TELEGRAM_BOT_TOKEN}"
    enabled: true
    groupChat:
      mentionPatterns: ["!doc", "!suche", "!hilfe"]

memory:
  path: ./storage/memory
  autoArchive: true

# Routing for shared bot (handled by router instance)
routing:
  tenantId: "$SLUG"
EOF

# ============================================
# 3. Generate docker-compose.yaml
# ============================================
echo "🐳 Generating docker-compose.yaml..."
cat <<EOF > "$CUSTOMER_DIR/docker-compose.yaml"
version: '3.8'

services:
  nexhelper:
    image: openclaw/openclaw:latest
    container_name: $INSTANCE_NAME
    restart: unless-stopped
    ports:
      - "$PORT:$PORT"
    volumes:
      - ./config:/app/config
      - ./storage:/app/storage
      - ./logs:/app/logs
    environment:
      - OPENAI_API_KEY=\${OPENAI_API_KEY}
      - TELEGRAM_BOT_TOKEN=\${TELEGRAM_BOT_TOKEN}
      - PORT=$PORT
      - NODE_ENV=production
    command: openclaw gateway start --config /app/config/config.yaml
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
# 4. Generate .env file
# ============================================
echo "🔐 Generating .env file..."
cat <<EOF > "$CUSTOMER_DIR/.env"
# NexHelper Environment: $CUSTOMER_NAME
# Generated: $(date -Iseconds)

OPENAI_API_KEY=$SHARED_API_KEY
TELEGRAM_BOT_TOKEN=$SHARED_TELEGRAM_TOKEN
PORT=$PORT
CUSTOMER_ID=$CUSTOMER_ID
CUSTOMER_NAME=$CUSTOMER_NAME
CUSTOMER_SLUG=$SLUG
EOF

# ============================================
# 5. Create utility scripts
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

# Remove script
cat <<SCRIPT > "$CUSTOMER_DIR/remove.sh"
#!/bin/bash
# Remove NexHelper Instance: $SLUG
echo "⚠️  WARNING: This will delete ALL data for $CUSTOMER_NAME"
echo "   Directory: $CUSTOMER_DIR"
read -p "Are you sure? (y/n) " -n 1 -r
echo
if [[ \$REPLY =~ ^[Yy]$ ]]; then
    cd "$(dirname "\$0")"
    docker-compose down -v
    cd ..
    rm -rf "$SLUG"
    echo "🗑️  Removed: $SLUG"
fi
SCRIPT
chmod +x "$CUSTOMER_DIR/remove.sh"

# ============================================
# 6. Create network if not exists
# ============================================
echo "🌐 Ensuring Docker network exists..."
docker network create nexhelper-network 2>/dev/null || true

# ============================================
# 7. Start the container
# ============================================
echo ""
echo "🚀 Starting container..."
cd "$CUSTOMER_DIR"
docker-compose up -d

# ============================================
# 8. Wait for health check
# ============================================
echo "⏳ Waiting for instance to be ready..."
sleep 5

# Check if container is running
if docker ps | grep -q "$INSTANCE_NAME"; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ SUCCESS: NexHelper Instance Ready!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Details:"
    echo "   Customer:   $CUSTOMER_NAME"
    echo "   Instance:   $INSTANCE_NAME"
    echo "   Port:       $PORT"
    echo "   Directory:  $CUSTOMER_DIR"
    echo ""
    echo "🔗 Commands:"
    echo "   Start:   $CUSTOMER_DIR/start.sh"
    echo "   Stop:    $CUSTOMER_DIR/stop.sh"
    echo "   Logs:    $CUSTOMER_DIR/logs.sh"
    echo "   Remove:  $CUSTOMER_DIR/remove.sh"
    echo ""
    echo "📱 Telegram:"
    echo "   Bot: @NexHelperBot"
    echo "   Router will direct messages to this instance"
    echo ""
else
    echo "❌ Error: Container failed to start"
    echo "   Check logs: docker logs $INSTANCE_NAME"
    exit 1
fi
