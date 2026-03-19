#!/bin/bash
# NexImo Customer Provisioning
# Spins up a new OpenClaw instance per user with working Telegram/WhatsApp
#
# Architecture: 1 User = 1 Bot Token = 1 Docker Container
# DSGVO: Isolated storage per user, consent-based
#
# Usage:
#   ./provision-customer.sh <customer-id> <customer-name> --telegram <token>
#
# Examples:
#   GEMINI_API_KEY=AIza... ./provision-customer.sh 001 "Berlin Hunter" --telegram "123:ABC"

set -e

PROVISION_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# ============================================
# Default Configuration
# ============================================
CUSTOMER_ID=""
CUSTOMER_NAME=""
BASE_DIR="${BASE_DIR:-/opt/neximo/customers}"
TELEGRAM_TOKEN=""
WHATSAPP_MODE=false
AUTO_START=true
FORCE_OVERWRITE=false
GATEWAY_TOKEN="${GATEWAY_TOKEN:-$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c 48 || openssl rand -hex 24)}"

# AI Provider
AI_PROVIDER="${AI_PROVIDER:-gemini}"

case "$AI_PROVIDER" in
  gemini)
    AI_API_KEY="${GEMINI_API_KEY:-${AI_API_KEY:-}}"
    AI_BASE_URL="${AI_BASE_URL:-https://generativelanguage.googleapis.com/v1beta/openai}"
    DEFAULT_MODEL="${DEFAULT_MODEL:-google/gemini-3-flash-preview}"
    OPENCLAW_PROVIDER="google"
    ;;
  openrouter)
    AI_API_KEY="${OPENROUTER_API_KEY:-${AI_API_KEY:-}}"
    AI_BASE_URL="${AI_BASE_URL:-https://openrouter.ai/api/v1}"
    DEFAULT_MODEL="${DEFAULT_MODEL:-openrouter/google/gemini-3-flash-preview}"
    OPENCLAW_PROVIDER="openrouter"
    ;;
  openai)
    AI_API_KEY="${OPENAI_API_KEY:-${AI_API_KEY:-}}"
    AI_BASE_URL="${AI_BASE_URL:-https://api.openai.com/v1}"
    DEFAULT_MODEL="${DEFAULT_MODEL:-gpt-4o-mini}"
    OPENCLAW_PROVIDER="openai"
    ;;
  *)
    echo "❌ Unknown AI_PROVIDER: $AI_PROVIDER" >&2
    exit 1
    ;;
esac

# Scanner config
NXIMO_SCAN_INTERVAL="${NXIMO_SCAN_INTERVAL:-300}"

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
      AI_API_KEY="$2"
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
    --base-dir)
      BASE_DIR="$2"
      shift 2
      ;;
    --force)
      FORCE_OVERWRITE=true
      shift
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
  echo "❌ Usage: $0 <customer-id> <customer-name> [--telegram <token>] [--whatsapp] [--api-key <key>]"
  exit 1
fi

if [ -z "$TELEGRAM_TOKEN" ] && [ "$WHATSAPP_MODE" = false ]; then
  echo "❌ Error: At least one messaging channel is required (--telegram or --whatsapp)"
  exit 1
fi

if [ -z "$AI_API_KEY" ]; then
  echo "❌ Error: AI API key required. Set GEMINI_API_KEY, OPENROUTER_API_KEY, or use --api-key"
  exit 1
fi

# ============================================
# Create Customer Directory
# ============================================
SLUG="$(echo "$CUSTOMER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')"
CUSTOMER_DIR="$BASE_DIR/neximo-${SLUG}-${CUSTOMER_ID}"
PORT=$((3000 + CUSTOMER_ID))

if [ -d "$CUSTOMER_DIR" ] && [ "$FORCE_OVERWRITE" = false ]; then
  echo "❌ Customer directory exists: $CUSTOMER_DIR"
  echo "   Use --force to overwrite"
  exit 1
fi

mkdir -p "$CUSTOMER_DIR"/{config,storage,scripts}

echo "📦 Provisioning customer: $CUSTOMER_NAME"
echo "   Directory: $CUSTOMER_DIR"
echo "   Port: $PORT"

# ============================================
# Generate OpenClaw Config
# ============================================
cat > "$CUSTOMER_DIR/config/openclaw.json" << OPENCLAW_CONFIG
{
  "meta": {
    "customerName": "$CUSTOMER_NAME",
    "customerId": "$CUSTOMER_ID",
    "provisionedAt": "$(date -Iseconds)"
  },
  "agents": {
    "defaults": {
      "model": "$DEFAULT_MODEL",
      "workspace": "$CUSTOMER_DIR/storage",
      "memorySearch": {
        "enabled": false
      },
      "compaction": {
        "mode": "safeguard"
      }
    },
    "list": [
      {
        "id": "main",
        "groupChat": {
          "mentionPatterns": ["/.*/i"]
        }
      }
    ]
  },
  "channels": {
    "telegram": {
      "enabled": $([ -n "$TELEGRAM_TOKEN" ] && echo 'true' || echo 'false'),
      "botToken": "${TELEGRAM_TOKEN:-}",
      "groups": {
        "*": {
          "requireMention": false
        }
      },
      "allowFrom": ["*"],
      "groupPolicy": "open",
      "streaming": "partial"
    }
  },
  "gateway": {
    "port": 19123,
    "auth": {
      "mode": "token",
      "token": "$GATEWAY_TOKEN"
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true
  }
}
OPENCLAW_CONFIG

echo "✅ Generated openclaw.json"

# ============================================
# Generate Auth Profiles
# ============================================
cat > "$CUSTOMER_DIR/config/auth-profiles.json" << AUTH_CONFIG
{
  "${OPENCLAW_PROVIDER}:default": {
    "provider": "${OPENCLAW_PROVIDER}",
    "mode": "api_key",
    "apiKey": "${AI_API_KEY}",
    "baseUrl": "${AI_BASE_URL}"
  }
}
AUTH_CONFIG

echo "✅ Generated auth-profiles.json"

# ============================================
# Generate Docker Compose
# ============================================
cat > "$CUSTOMER_DIR/docker-compose.yaml" << COMPOSE_CONFIG
version: '3.8'
services:
  neximo:
    image: neximo:latest
    container_name: neximo-${SLUG}-${CUSTOMER_ID}
    restart: unless-stopped
    ports:
      - "${PORT}:19123"
    volumes:
      - ./config:/app/config:ro
      - ./storage:/data/storage
    environment:
      - NXIMO_STORAGE_DIR=/data/storage
      - NXIMO_SCAN_INTERVAL=${NXIMO_SCAN_INTERVAL}
      - NXIMO_SCANNER_ENABLED=true
      - OPENAI_API_KEY=${AI_API_KEY}
      - GEMINI_API_KEY=${AI_API_KEY}
      - OPENROUTER_API_KEY=${AI_API_KEY}
      - OPENAI_BASE_URL=${AI_BASE_URL}
      - AI_PROVIDER=${AI_PROVIDER}
      - GATEWAY_TOKEN=${GATEWAY_TOKEN}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:19123/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
COMPOSE_CONFIG

echo "✅ Generated docker-compose.yaml"

# ============================================
# Generate .env
# ============================================
cat > "$CUSTOMER_DIR/.env" << ENV_CONFIG
# NexImo Customer: ${CUSTOMER_NAME}
# Generated: $(date -Iseconds)

CUSTOMER_ID=${CUSTOMER_ID}
CUSTOMER_NAME="${CUSTOMER_NAME}"
PORT=${PORT}

# AI Provider
AI_PROVIDER=${AI_PROVIDER}
AI_API_KEY=${AI_API_KEY}
AI_BASE_URL=${AI_BASE_URL}
DEFAULT_MODEL=${DEFAULT_MODEL}

# Gateway
GATEWAY_TOKEN=${GATEWAY_TOKEN}

# Scanner
NXIMO_SCAN_INTERVAL=${NXIMO_SCAN_INTERVAL}
NXIMO_SCANNER_ENABLED=true
ENV_CONFIG

echo "✅ Generated .env"

# ============================================
# Generate Helper Scripts
# ============================================
cat > "$CUSTOMER_DIR/scripts/start.sh" << 'SCRIPT'
#!/bin/bash
cd "$(dirname "$0")/.."
docker compose up -d
echo "Started neximo-$(basename $(dirname $(pwd)))"
SCRIPT
chmod +x "$CUSTOMER_DIR/scripts/start.sh"

cat > "$CUSTOMER_DIR/scripts/stop.sh" << 'SCRIPT'
#!/bin/bash
cd "$(dirname "$0")/.."
docker compose down
echo "Stopped neximo-$(basename $(dirname $(pwd)))"
SCRIPT
chmod +x "$CUSTOMER_DIR/scripts/stop.sh"

cat > "$CUSTOMER_DIR/scripts/status.sh" << 'SCRIPT'
#!/bin/bash
cd "$(dirname "$0")/.."
docker compose ps
echo ""
curl -s http://localhost:${PORT:-3001}/health | jq . 2>/dev/null || echo "Gateway not responding"
SCRIPT
chmod +x "$CUSTOMER_DIR/scripts/status.sh"

cat > "$CUSTOMER_DIR/scripts/logs.sh" << 'SCRIPT'
#!/bin/bash
cd "$(dirname "$0")/.."
docker compose logs -f --tail 100
SCRIPT
chmod +x "$CUSTOMER_DIR/scripts/logs.sh"

echo "✅ Generated helper scripts"

# ============================================
# Build Image (if needed)
# ============================================
if ! docker images neximo:latest --format '{{.ID}}' | grep -q .; then
  echo "🔨 Building neximo:latest image..."
  docker build -t neximo:latest "$PROVISION_DIR"
fi

# ============================================
# Start Container
# ============================================
if [ "$AUTO_START" = true ]; then
  echo "🚀 Starting container..."
  cd "$CUSTOMER_DIR"
  docker compose up -d
  
  echo ""
  echo "⏳ Waiting for gateway to be ready..."
  sleep 10
  
  # Health check
  for i in {1..30}; do
    if curl -sf "http://localhost:${PORT}/health" > /dev/null 2>&1; then
      echo "✅ Gateway is healthy!"
      break
    fi
    echo "   Attempt $i/30..."
    sleep 2
  done
fi

# ============================================
# Summary
# ============================================
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎉 NexImo Customer Provisioned Successfully!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "   Customer:   $CUSTOMER_NAME"
echo "   ID:         $CUSTOMER_ID"
echo "   Directory:  $CUSTOMER_DIR"
echo "   Port:       $PORT"
echo ""
echo "   Gateway:    http://localhost:${PORT}"
echo "   Dashboard:  http://localhost:${PORT}/dashboard"
echo "   Token:      ${GATEWAY_TOKEN:0:12}..."
echo ""
echo "Commands:"
echo "   Start:   $CUSTOMER_DIR/scripts/start.sh"
echo "   Stop:    $CUSTOMER_DIR/scripts/stop.sh"
echo "   Status:  $CUSTOMER_DIR/scripts/status.sh"
echo "   Logs:    $CUSTOMER_DIR/scripts/logs.sh"
echo ""
echo "═══════════════════════════════════════════════════════════"
