#!/bin/bash
# NexHelper Router Setup
# Creates the central router instance for shared bot
#
# Usage: ./setup-router.sh [options]
#
# Options:
#   --bot-token <token>   Telegram bot token for shared bot
#   --api-key <key>       OpenRouter API key
#   --port <port>         Port for router (default: 3010)
#
# Example:
#   ./setup-router.sh --bot-token "123:ABC" --api-key "sk-or-v1-xxx"

set -e

# ============================================
# Default Configuration
# ============================================
ROUTER_DIR="${ROUTER_DIR:-/opt/nexhelper/router}"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
API_KEY="${OPENAI_API_KEY:-}"
PORT="${ROUTER_PORT:-3010}"

# ============================================
# Parse Arguments
# ============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --bot-token)
            BOT_TOKEN="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate
if [ -z "$BOT_TOKEN" ]; then
    echo "❌ Error: --bot-token required"
    exit 1
fi

if [ -z "$API_KEY" ]; then
    echo "❌ Error: --api-key required"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NexHelper Router Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Directory: $ROUTER_DIR"
echo "Port:      $PORT"
echo ""

# ============================================
# Create Directory Structure
# ============================================
echo "📁 Creating directory structure..."
mkdir -p "$ROUTER_DIR"/{config,storage/memory,logs}

# ============================================
# Generate Workspace Files
# ============================================
echo "📝 Generating workspace files..."

# AGENTS.md
cat <<EOF > "$ROUTER_DIR/storage/AGENTS.md"
# AGENTS.md - NexHelper Router

Du bist der NexHelper Router - die zentrale Instanz für alle Kunden.

## Aufgaben

- Nachrichten an den richtigen Kunden weiterleiten
- Registrierung neuer Nutzer
- Hilfe und Support

## Routing

Routing-Logik in /root/.openclaw/routing.json:

\`\`\`json
{
  "groupMappings": {
    "-1003640146701": "test-kunde"
  },
  "userMappings": {
    "123456": "test-kunde"
  }
}
\`\`\`

## Commands

| Command | Beschreibung |
|---------|--------------|
| /hilfe | Hilfe anzeigen |
| /register <slug> | Kunde registrieren |
EOF

# SOUL.md
cat <<EOF > "$ROUTER_DIR/storage/SOUL.md"
# SOUL.md - NexHelper Router

Du bist der Router für NexHelper.

## Core

- Freundlich und hilfsbereit
- Deutsch
- Kurz und prägnant

## Stil

- Max 1-2 Emoji pro Nachricht
- Kein "Gerne!" oder "Natürlich!"
- Direkt zur Sache
EOF

# IDENTITY.md
cat <<EOF > "$ROUTER_DIR/storage/IDENTITY.md"
# IDENTITY.md - NexHelper Router

- **Name:** NexHelper Router
- **Creature:** Digital Router
- **Vibe:** Zentral, organisiert
- **Emoji:** 🔀
EOF

# ============================================
# Generate OpenClaw Config
# ============================================
echo "⚙️  Generating OpenClaw config..."

cat <<EOF > "$ROUTER_DIR/config/openclaw.json"
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
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "$BOT_TOKEN",
      "dmPolicy": "open",
      "allowFrom": ["*"],
      "groupPolicy": "open"
    }
  },
  "gateway": {
    "port": $PORT,
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "nexhelper-router-main-token"
    }
  }
}
EOF

cat <<EOF > "$ROUTER_DIR/config/auth-profiles.json"
{
  "version": 1,
  "profiles": {
    "openrouter:default": {
      "type": "api_key",
      "provider": "openrouter",
      "key": "$API_KEY"
    }
  },
  "lastGood": {
    "openrouter": "openrouter:default"
  }
}
EOF

# Routing.json placeholder
cat <<EOF > "$ROUTER_DIR/config/routing.json"
{
  "version": "1.0",
  "customers": {},
  "routing": {
    "defaultCustomer": null,
    "unknownUserPolicy": "reject",
    "registrationCommand": "/register",
    "helpCommand": "/hilfe"
  },
  "userMappings": {},
  "groupMappings": {}
}
EOF

# ============================================
# Generate docker-compose.yaml
# ============================================
echo "🐳 Generating docker-compose.yaml..."

cat <<EOF > "$ROUTER_DIR/docker-compose.yaml"
services:
  nexhelper-router:
    image: nexhelper:latest
    container_name: nexhelper-router
    restart: unless-stopped
    entrypoint: ["/bin/bash", "-c", "mkdir -p /root/.openclaw/agents/main/agent && cp /app/config/openclaw.json /root/.openclaw/openclaw.json && cp /app/config/auth-profiles.json /root/.openclaw/agents/main/agent/auth-profiles.json && cp /app/config/routing.json /root/.openclaw/routing.json && rm -f /root/.openclaw/workspace/BOOTSTRAP.md && exec openclaw gateway run --port $PORT --bind lan"]
    ports:
      - "$PORT:$PORT"
    volumes:
      - ./config:/app/config
      - ./storage:/root/.openclaw/workspace
      - ./logs:/app/logs
    environment:
      - OPENAI_API_KEY=$API_KEY
      - TELEGRAM_BOT_TOKEN=$BOT_TOKEN
      - PORT=$PORT
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:$PORT/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "nexhelper.role=router"
      - "nexhelper.version=1.0"
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
# Create Utility Scripts
# ============================================
cat <<'SCRIPT' > "$ROUTER_DIR/start.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker compose up -d
echo "✅ Router started"
SCRIPT
chmod +x "$ROUTER_DIR/start.sh"

cat <<'SCRIPT' > "$ROUTER_DIR/stop.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker compose down
echo "✅ Router stopped"
SCRIPT
chmod +x "$ROUTER_DIR/stop.sh"

cat <<'SCRIPT' > "$ROUTER_DIR/logs.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker compose logs --tail=50 -f
SCRIPT
chmod +x "$ROUTER_DIR/logs.sh"

# ============================================
# Create Network
# ============================================
echo "🌐 Ensuring Docker network exists..."
docker network create nexhelper-network 2>/dev/null || true

# ============================================
# Done
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ NexHelper Router Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Details:"
echo "   Directory: $ROUTER_DIR"
echo "   Port:      $PORT"
echo ""
echo "🔗 Commands:"
echo "   Start: $ROUTER_DIR/start.sh"
echo "   Stop:  $ROUTER_DIR/stop.sh"
echo "   Logs:  $ROUTER_DIR/logs.sh"
echo ""
echo "📝 Next:"
echo "   1. Start router: $ROUTER_DIR/start.sh"
echo "   2. Add customers: ./provision-customer.sh 001 'Kunde'"
echo "   3. Update routing.json with customer mappings"
echo ""