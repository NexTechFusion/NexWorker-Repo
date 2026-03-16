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
#   GEMINI_API_KEY=AIza... ./provision-customer.sh 001 "Acme GmbH" --telegram "123:ABC"
#   AI_PROVIDER=openrouter OPENROUTER_API_KEY=sk-or-... ./provision-customer.sh 001 "Acme GmbH" --telegram "123:ABC"
#   AI_PROVIDER=openrouter OPENROUTER_API_KEY=sk-or-... ./provision-customer.sh 002 "Müller Bau" --whatsapp

set -e

PROVISION_SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# ============================================
# Default Configuration
# ============================================
CUSTOMER_ID=""
CUSTOMER_NAME=""
BASE_DIR="${BASE_DIR:-/opt/nexhelper/customers}"
TELEGRAM_TOKEN=""
WHATSAPP_MODE=false
ENABLE_WHATSAPP=false
AUTO_START=true
CONSENT_VERSION="1.0"
ENTITIES="${ENTITIES:-default}"
BUDGETS="${BUDGETS:-}"
DELIVERY_TO="${DEFAULT_DELIVERY_TO:-}"
INITIAL_ADMIN_ID="${INITIAL_ADMIN_ID:-}"
EMBEDDING_MODEL="${EMBEDDING_MODEL:-openai/text-embedding-3-small}"

# ============================================
# Provider Selection
# ============================================
# AI_PROVIDER selects the LLM backend preset.
# Supported: gemini (default) | openrouter | openai | custom
# For custom, set AI_API_KEY, AI_BASE_URL, and DEFAULT_MODEL manually.
AI_PROVIDER="${AI_PROVIDER:-gemini}"

case "$AI_PROVIDER" in
  gemini)
    AI_API_KEY="${GEMINI_API_KEY:-${AI_API_KEY:-}}"
    AI_BASE_URL="${AI_BASE_URL:-https://generativelanguage.googleapis.com/v1beta/openai}"
    DEFAULT_MODEL="${DEFAULT_MODEL:-gemini-3-flash-preview}"
    IMAGE_MODEL="${IMAGE_MODEL:-gemini-3-flash-preview}"
    PDF_MODEL="${PDF_MODEL:-gemini-3-flash-preview}"
    MODEL_FALLBACKS="${MODEL_FALLBACKS:-[\"gemini-2.5-flash\",\"gemini-2.5-flash\"]}"
    ;;
  openrouter)
    AI_API_KEY="${OPENROUTER_API_KEY:-${AI_API_KEY:-}}"
    AI_BASE_URL="${AI_BASE_URL:-https://openrouter.ai/api/v1}"
    DEFAULT_MODEL="${DEFAULT_MODEL:-openrouter/google/gemini-3-flash-preview}"
    IMAGE_MODEL="${IMAGE_MODEL:-openrouter/google/gemini-3-flash-preview}"
    PDF_MODEL="${PDF_MODEL:-openrouter/google/gemini-3-flash-preview-001}"
    MODEL_FALLBACKS="${MODEL_FALLBACKS:-[\"openrouter/google/gemini-2.5-flash\",\"openrouter/google/gemini-3-flash-preview-001\"]}"
    ;;
  openai)
    AI_API_KEY="${OPENAI_API_KEY:-${AI_API_KEY:-}}"
    AI_BASE_URL="${AI_BASE_URL:-https://api.openai.com/v1}"
    DEFAULT_MODEL="${DEFAULT_MODEL:-gpt-4o-mini}"
    IMAGE_MODEL="${IMAGE_MODEL:-gpt-4o-mini}"
    PDF_MODEL="${PDF_MODEL:-gpt-4o-mini}"
    MODEL_FALLBACKS="${MODEL_FALLBACKS:-[\"gpt-4o\"]}"
    ;;
  custom)
    : # AI_API_KEY, AI_BASE_URL, DEFAULT_MODEL, IMAGE_MODEL, PDF_MODEL, MODEL_FALLBACKS must be set externally
    ;;
  *)
    echo "❌ Error: Unknown AI_PROVIDER='$AI_PROVIDER'. Valid: gemini | openrouter | openai | custom" >&2
    exit 1
    ;;
esac

# Whisper uses a separate provider (Gemini has no /audio/transcriptions compat endpoint).
# Defaults to OpenRouter; override with WHISPER_PROVIDER=openai or custom WHISPER_* vars.
WHISPER_API_KEY="${WHISPER_API_KEY:-${OPENROUTER_API_KEY:-${AI_API_KEY:-}}}"
WHISPER_BASE_URL="${WHISPER_BASE_URL:-https://openrouter.ai/api/v1}"
WHISPER_MODEL="${WHISPER_MODEL:-openai/whisper-large-v3-turbo}"

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
        --consent-version)
            CONSENT_VERSION="$2"
            shift 2
            ;;
        --base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --entities)
            ENTITIES="$2"
            shift 2
            ;;
        --budgets)
            BUDGETS="$2"
            shift 2
            ;;
        --delivery-to)
            DELIVERY_TO="$2"
            shift 2
            ;;
        --initial-admin)
            INITIAL_ADMIN_ID="$2"
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
    echo "  --api-key <key>       LLM API key (or set GEMINI_API_KEY / AI_API_KEY)"
    echo "  --model <model>       Default model (default depends on AI_PROVIDER)"
    echo "  --no-start            Don't auto-start container"
    echo "  --consent-version <v> Consent text version (default: 1.0)"
    echo "  --base-dir <path>     Base directory (default: /opt/nexhelper/customers)"
    echo "  --delivery-to <to>    Admin notification target used by scripts like nexhelper-notify (e.g. telegram:579539601)"
    echo ""
    echo "Provider selection (AI_PROVIDER=gemini | openrouter | openai | custom):"
    echo "  GEMINI_API_KEY=AIza... ./provision-customer.sh 001 'Acme GmbH' --telegram '123:ABC'"
    echo "  AI_PROVIDER=openrouter OPENROUTER_API_KEY=sk-or-... ./provision-customer.sh 001 'Acme GmbH' --telegram '123:ABC'"
    exit 1
fi

# Check API key
if [ -z "$AI_API_KEY" ]; then
    echo "❌ Error: No API key set for AI_PROVIDER='$AI_PROVIDER'"
    case "$AI_PROVIDER" in
      gemini)     echo "   Set: export GEMINI_API_KEY=AIza..." ;;
      openrouter) echo "   Set: export OPENROUTER_API_KEY=sk-or-..." ;;
      openai)     echo "   Set: export OPENAI_API_KEY=sk-..." ;;
      custom)     echo "   Set: export AI_API_KEY=your-key" ;;
    esac
    echo "   Or pass: --api-key <key>"
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
# Idempotency Guard — warn if container already running
# ============================================
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${INSTANCE_NAME}$"; then
  echo ""
  echo "⚠️  Container '${INSTANCE_NAME}' is already running."
  echo "   To re-provision, first stop it:  docker stop ${INSTANCE_NAME}"
  echo "   Or use --force to overwrite (will recreate the container)."
  if [ "${FORCE_REPROVISION:-false}" != "true" ]; then
    echo "   Aborting. Pass FORCE_REPROVISION=true to override."
    exit 1
  fi
  echo "   FORCE_REPROVISION=true — continuing..."
fi

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
if [ -n "$DELIVERY_TO" ]; then
    echo "Delivery target: $DELIVERY_TO"
else
    echo "Delivery target: (not set - announce cron jobs need --to later)"
fi
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
mkdir -p "$CUSTOMER_DIR"/{config,logs,storage/{memory,consent,audit,documents,reminders,entities,idempotency,ops,canonical/{documents,reminders,indices}}}
mkdir -p "$CUSTOMER_DIR/storage/.openclaw"
mkdir -p "$CUSTOMER_DIR/config/scripts"

# scripts are served from the skills volume at /app/skills/common/; config/scripts/ is reserved for future use

# Generate tenant policy with role model
_INITIAL_ADMINS="[]"
if [ -n "$INITIAL_ADMIN_ID" ]; then
    _INITIAL_ADMINS="[\"$INITIAL_ADMIN_ID\"]"
fi
cat <<POLICYEOF > "$CUSTOMER_DIR/storage/policy.json"
{
  "admins": $_INITIAL_ADMINS,
  "memberPermissions": {
    "store": true,
    "search": true,
    "list": true,
    "get": true,
    "stats": true,
    "reminder_create": true,
    "reminder_list": true,
    "reminder_delete_own": true
  },
  "adminNotificationChannel": "${DELIVERY_TO:-}",
  "createdAt": "$(date -Iseconds)",
  "tenantId": "$CUSTOMER_ID",
  "tenantName": "$CUSTOMER_NAME"
}
POLICYEOF
echo "   Policy file created (admins: ${INITIAL_ADMIN_ID:-none set - promote via nexhelper-policy add-admin})"

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
# 2b. Generate Entity Configuration
# ============================================
echo "🏢 Generating entity configuration..."

# Parse entities and budgets
IFS=',' read -ra ENTITY_ARRAY <<< "$ENTITIES"
IFS=',' read -ra BUDGET_ARRAY <<< "$BUDGETS"

# Build budget map
declare -A BUDGET_MAP
for b in "${BUDGET_ARRAY[@]}"; do
    key="${b%%:*}"
    val="${b##*:}"
    BUDGET_MAP[$key]="$val"
done

# Build entities YAML
ENTITIES_YAML="entities:"
for e in "${ENTITY_ARRAY[@]}"; do
    budget="${BUDGET_MAP[$e]:-null}"
    if [ "$e" = "default" ]; then
        ENTITIES_YAML+="
  - id: default
    name: \"Default\"
    budget: null
    budgetPeriod: null
    aliases: []
    active: true
    notifyOnOverBudget: false"
    else
        ENTITIES_YAML+="
  - id: $e
    name: \"${e^} Dept\"
    budget: $budget
    budgetPeriod: monthly
    aliases: [\"@$e\"]
    active: true
    notifyOnOverBudget: true
    notifyChannel: telegram"
    fi
done

cat <<ENTITYEOF > "$CUSTOMER_DIR/config/entities.yaml"
# Entity Configuration for $CUSTOMER_NAME
# Generated: $(date -Iseconds)
# 
# Entities allow tracking documents by department/division with budgets

$ENTITIES_YAML
ENTITYEOF

echo "   Created: ${#ENTITY_ARRAY[@]} entity(s)"

# Initialize entity storage
for e in "${ENTITY_ARRAY[@]}"; do
    mkdir -p "$CUSTOMER_DIR/storage/entities/$e"
    echo "[]" > "$CUSTOMER_DIR/storage/entities/$e/suppliers.json"
    cat <<EOF > "$CUSTOMER_DIR/storage/entities/$e/stats.json"
{
  \"period\": \"$(date +%Y-%m)\",
  \"spent\": 0,
  \"budget\": ${BUDGET_MAP[$e]:-0},
  \"transactions\": [],
  \"lastUpdated\": \"$(date -Iseconds)\"
}
EOF
done

# ============================================
# 3. Generate OpenClaw Configuration (JSON5)
# ============================================
echo "⚙️  Generating OpenClaw configuration..."

# Build channels section based on selected channels
CHANNELS_CONFIG=""

if [ -n "$TELEGRAM_TOKEN" ]; then
    CHANNELS_CONFIG+="  \"telegram\": {
    enabled: true,
    botToken: \"$TELEGRAM_TOKEN\",
    dmPolicy: \"open\",
    allowFrom: [\"*\"],
    groups: { \"*\": { requireMention: true } },
  },
"
fi

if [ "$WHATSAPP_MODE" = true ]; then
    CHANNELS_CONFIG+="  \"whatsapp\": {
    enabled: true,
    dmPolicy: \"open\",
    allowFrom: [\"*\"],
    groupPolicy: \"allowlist\",
    groups: { \"*\": { requireMention: true } },
  },
"
fi

cat <<EOF > "$CUSTOMER_DIR/config/openclaw.json"
{
  // NexHelper Configuration for $CUSTOMER_NAME
  // Generated: $(date -Iseconds)
  // Model provider env vars (OPENAI_API_KEY, OPENAI_BASE_URL) are set in docker-compose.yml

  "gateway": {
    "port": $PORT,
    "mode": "local",
    "bind": "lan",
    "reload": { "mode": "hybrid" },
  },

  "agents": {
    "defaults": {
      "model": {
        "primary": "$DEFAULT_MODEL",
        "fallbacks": $MODEL_FALLBACKS,
      },
      "imageModel":   { "primary": "$IMAGE_MODEL" },
      "pdfModel":     { "primary": "$PDF_MODEL" },
      "memorySearch": {
        "provider": "local",
        "local": { "modelPath": "/tmp/no-vector-model" },
        "fallback": "none",
      },
      "workspace": "/root/.openclaw/workspace",
      "thinkingDefault": "medium",
      "timeoutSeconds": 120,
      "maxConcurrent": 4,
      "subagents": { "maxConcurrent": 8 },
      "compaction": {
        "mode": "safeguard",
        "reserveTokens": 40000,
        "keepRecentTokens": 15000,
        "reserveTokensFloor": 50000,
        "maxHistoryShare": 0.6,
        "memoryFlush": {
          "enabled": true,
          "softThresholdTokens": 50000,
          "prompt": "Write document summaries and important facts to memory/YYYY-MM-DD.md; reply NO_REPLY if nothing to store.",
          "systemPrompt": "Session nearing compaction. Persist document metadata and user preferences to memory files; reply NO_REPLY if none.",
        },
      },
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
    "allow": [
      "exec",
      "read",
      "write",
      "edit",
      "memory_search",
      "memory_get",
      "image",
      "pdf",
      "tts",
      "message",
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
    ],
    "media": {
      "audio": {
        "enabled": true,
        // Transcription is done before the agent sees the message — no exec needed.
        // Echo the transcript back so the user knows it was understood.
        "echoTranscript": true,
        "echoFormat": "📝 \"{transcript}\"",
        "models": [
          {
            // Uses openai:whisper auth profile (baked into auth-profiles.json).
            // For Gemini provider, this routes to OpenRouter's Whisper endpoint.
            // For OpenRouter provider, it uses the same key as the main provider.
            "provider": "openai",
            "model": "$WHISPER_MODEL",
            "baseUrl": "$WHISPER_BASE_URL",
          },
        ],
      },
    },
  },


  "commands": {
    "native": false,
    "nativeSkills": true,
    "restart": false,
  },

  "session": {
    "dmScope": "per-channel-peer",
  },

  "messages": {
    "ackReactionScope": "group-mentions",
  },

  "channels": {
$CHANNELS_CONFIG  },
}
EOF

# ============================================
# 4. Generate auth-profiles.json
# ============================================
cat <<EOF > "$CUSTOMER_DIR/config/auth-profiles.json"
{
  "version": 1,
  "profiles": {
    "$AI_PROVIDER:default": {
      "type": "api_key",
      "provider": "$AI_PROVIDER",
      "key": "$AI_API_KEY"
    },
    "openai:whisper": {
      "type": "api_key",
      "provider": "openai",
      "key": "$WHISPER_API_KEY"
    }
  },
  "lastGood": {
    "$AI_PROVIDER": "$AI_PROVIDER:default",
    "openai": "openai:whisper"
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
        tmp_cfg=\$\$(mktemp)
        jq 'if .tools and .tools.allow then .tools.allow |= map(select(. != "apply_patch" and . != "cron")) else . end' /root/.openclaw/openclaw.json > "\$\$tmp_cfg" 2>/dev/null && mv "\$\$tmp_cfg" /root/.openclaw/openclaw.json || rm -f "\$\$tmp_cfg"
        mkdir -p /root/.openclaw/agents/main/agent
        cp /app/config/auth-profiles.json /root/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null || true
        rm -f /root/.openclaw/workspace/BOOTSTRAP.md
        cp -r /app/skills /usr/local/nexhelper-skills
        while IFS= read -r -d '' f; do
          tr -d '\r' < "\$\$f" > "\$\$f.tmp" && mv "\$\$f.tmp" "\$\$f" || rm -f "\$\$f.tmp"
          chmod +x "\$\$f"
        done < <(find /usr/local/nexhelper-skills -type f \\( -name "nexhelper-*" -o -name "*.sh" \\) -print0)
        while IFS= read -r -d '' f; do
          bn="\$\$(basename "\$\$f")"
          ln -sf "\$\$f" "/usr/local/bin/\$\$bn" 2>/dev/null || true
        done < <(find /usr/local/nexhelper-skills -type f -name "nexhelper-*" -print0)
        ln -sf /usr/local/bin/nexhelper-reminder /usr/local/bin/nexhelper-remind 2>/dev/null || true
        command -v nexhelper-doc >/dev/null 2>&1 || echo "⚠️ nexhelper-doc missing on PATH"
        nexhelper-set-reminder --help >/dev/null 2>&1 || echo "⚠️ nexhelper-set-reminder missing or not executable"
        [ -n "\${OPENAI_BASE_URL:-}" ] || echo "⚠️ OPENAI_BASE_URL is unset; LLM API calls may fail"
        openclaw doctor --fix >/dev/null 2>&1 || true
        openclaw gateway run --port $PORT --bind lan &
        GW_PID=\$\$!
        sleep 8
        # Idempotent cron registration: skips if a job with the same name already exists.
        # This prevents duplicate accumulation across container restarts.
        _nx_ensure_cron() {
          local _name="\$\$1"; shift
          openclaw cron list --json 2>/dev/null \
            | jq -e --arg n "\$\$_name" '.jobs[] | select(.name == \$n)' >/dev/null 2>&1 \
            && return 0
          openclaw cron add --name "\$\$_name" "\$\$@" 2>/dev/null || true
        }
        # All jobs use structured event tokens (nexhelper:event:<type>) so the workflow
        # router uses exact token matching instead of fragile substring search.
        # Jobs are --no-deliver; scripts handle their own notification via nexhelper-notify.
        _nx_ensure_cron reminder-auditor --every 1m \
          --message "nexhelper:event:reminder-audit" --no-deliver --session isolated
        _nx_ensure_cron check-reminders --every 5m \
          --message "nexhelper:event:reminder-check" --no-deliver --session isolated
        _nx_ensure_cron budget-check --cron "0 * * * *" \
          --message "nexhelper:event:budget-check" --no-deliver --session isolated
        _nx_ensure_cron retention-job --cron "0 2 * * *" \
          --message "nexhelper:event:retention" --no-deliver --session isolated
        # health-monitor removed: covered by startup smoke and /health endpoint
        # daily-summary disabled by default: LLM cost without deterministic value
        wait \$\$GW_PID
    ports:
      - "$PORT:$PORT"
    volumes:
      - ./config:/app/config:ro
      - \${NEXHELPER_SKILLS_DIR}:/app/skills:ro
      - ./storage:/root/.openclaw/workspace
      - ./logs:/app/logs
      - nexhelper-data-${SLUG}:/root/.openclaw
    environment:
      - OPENAI_API_KEY=$AI_API_KEY
      - OPENAI_BASE_URL=$AI_BASE_URL
      - AI_PROVIDER=$AI_PROVIDER
      - AI_API_KEY=$AI_API_KEY
      - AI_BASE_URL=$AI_BASE_URL
      - GEMINI_API_KEY=\${GEMINI_API_KEY:-}
      - OPENROUTER_API_KEY=\${OPENROUTER_API_KEY:-}
      - WHISPER_API_KEY=$WHISPER_API_KEY
      - WHISPER_BASE_URL=$WHISPER_BASE_URL
      - WHISPER_MODEL=$WHISPER_MODEL
      - STORAGE_DIR=/root/.openclaw/workspace
      - EMBEDDING_MODEL=\${EMBEDDING_MODEL:-$EMBEDDING_MODEL}
      - DEFAULT_DELIVERY_TO=\${DEFAULT_DELIVERY_TO:-$DELIVERY_TO}
      - TELEGRAM_BOT_TOKEN=\${TELEGRAM_BOT_TOKEN:-}
      - PORT=$PORT
      - NODE_ENV=production
      - CUSTOMER_ID=$CUSTOMER_ID
      - CUSTOMER_NAME=$CUSTOMER_NAME
      - CUSTOMER_SLUG=$SLUG
      - CONSENT_VERSION=$CONSENT_VERSION
      - RUN_SMOKE_ON_START=\${RUN_SMOKE_ON_START:-true}
      - SMOKE_REQUIRED_ON_START=\${SMOKE_REQUIRED_ON_START:-false}
      - OPS_REPORT_DAYS=\${OPS_REPORT_DAYS:-30}
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

AI_PROVIDER=$AI_PROVIDER
AI_API_KEY=$AI_API_KEY
AI_BASE_URL=$AI_BASE_URL
OPENAI_API_KEY=$AI_API_KEY
OPENAI_BASE_URL=$AI_BASE_URL
GEMINI_API_KEY=${GEMINI_API_KEY:-}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
WHISPER_API_KEY=$WHISPER_API_KEY
WHISPER_BASE_URL=$WHISPER_BASE_URL
WHISPER_MODEL=$WHISPER_MODEL
EMBEDDING_MODEL=$EMBEDDING_MODEL
DEFAULT_DELIVERY_TO=$DELIVERY_TO
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN:-}
PORT=$PORT
CUSTOMER_ID=$CUSTOMER_ID
CUSTOMER_NAME=$CUSTOMER_NAME
CUSTOMER_SLUG=$SLUG
CONSENT_VERSION=$CONSENT_VERSION
RUN_SMOKE_ON_START=true
SMOKE_REQUIRED_ON_START=false
OPS_REPORT_DAYS=30
TZ=Europe/Berlin
NEXHELPER_SKILLS_DIR=$PROVISION_SCRIPT_DIR/skills
STORAGE_DIR=/root/.openclaw/workspace
EOF

# ============================================
# 7. Generate Workspace Files
# ============================================
echo "📝 Generating workspace files..."

# AGENTS.md
cat <<EOF > "$CUSTOMER_DIR/storage/AGENTS.md"
# AGENTS.md - NexHelper Workspace

Du bist NexHelper für $CUSTOMER_NAME.

---

## 🚀 JEDER START

1. **SOUL.md lesen** - Wer du bist und was du tust
2. **USER.md lesen** - Wen du hilfst  
3. **memory/\$(date +%Y-%m-%d).md** - Was heute passiert ist

---

## 💾 SPEICHER

| Datei | Zweck |
|-------|-------|
| \`canonical/documents/*.json\` | Verbindliche Dokumentdaten |
| \`canonical/reminders/*.json\` | Verbindliche Erinnerungsdaten |
| \`memory/YYYY-MM-DD.md\` | Tagesnotizen |
| \`MEMORY.md\` | Langzeitgedächtnis |

Dokumentiere hier:
- Erhaltene Dokumente
- Erinnerungen
- Wichtige Events
- Workflow-Ausgaben mit Operation-IDs

---

## 🛠️ SKILLS

Du hast folgende Skills verfügbar:

| Skill | Befehl |
|-------|--------|
| document-export | \`/export\` |
| document-ocr | Automatisch bei Bildern |
| reminder-system | \`/remind\` |
| classifier | Intent/Entity Klassifikation |
| workflow | Event-Pipeline mit Idempotenz |

---

## 📋 COMMANDS

| Command | Beschreibung |
|---------|--------------|
| /hilfe | Hilfe anzeigen |
| /suche [text] | Dokumente suchen |
| /export | Export starten |
| /remind [text] | Erinnerung setzen |
| /remind list | Erinnerungen anzeigen |
| /status | Statistiken |
| /widerruf | Consent widerrufen |

---

## ⚠️ WICHTIG

- Du bist **kein Chatbot** für Smalltalk
- Du bist ein **Dokumenten-Assistent**
- Bei Off-Topic: Höflich auf Aufgaben hinweisen
- Siehe SOUL.md für Verhaltensregeln

---

*Arbeitsverzeichnis: /root/.openclaw/workspace*
EOF

# SOUL.md
sed "s/\${CUSTOMER_NAME}/$CUSTOMER_NAME/g" > "$CUSTOMER_DIR/storage/SOUL.md" <<'SOULEOF'
# SOUL.md - NexHelper

Du bist **NexHelper** - ein digitaler Dokumenten-Assistent für ${CUSTOMER_NAME}.

---

## IDENTITÄT

- **Name:** NexHelper
- **Rolle:** Dokumenten-Assistent für KMU
- **Sprache:** Antworte IMMER in der Sprache, in der der Nutzer schreibt. Erkenne die Sprache automatisch. Wechsle nie die Sprache ohne Aufforderung.
- **Emoji:** 📄

---

## 💾 SPEICHERSTRUKTUR

```
storage/
├── canonical/           # Source-of-truth JSON records
│   ├── documents/
│   └── reminders/
│
├── documents/           # Original-Dateien
│   └── YYYY-MM-DD/     # Nach Datum sortiert
│       ├── RE-123.pdf  # Rechnungen
│       └── AN-456.jpg  # Angebote (Fotos)
│
├── memory/              # Extrahierte Daten (durchsuchbar)
│   └── YYYY-MM-DD.md   # Tagesnotizen mit Metadaten
│
├── consent/             # DSGVO Einwilligungen
└── audit/               # Audit-Logs
```

**Wichtig:**
- Canonical JSON in `canonical/` ist Source-of-Truth
- Originaldateien in `documents/`
- Metadaten in `memory/` sind lesbare Spiegelung
- Verlinke von Memory auf Document

---

## WAS DU TUST

### 0. Sprachnachricht empfangen
Sprachnachrichten werden automatisch transkribiert, bevor sie bei dir ankommen — du siehst den Text direkt in der Nachricht. Kein exec, kein write nötig. Verarbeite den transkribierten Text genau wie eine normale Textnachricht.

---

### 1. Dokumente empfangen
Wenn ein Nutzer ein Bild oder PDF sendet:

#### Einzelnes Dokument:
**Schritt 1: Dokument speichern**
```
# Dateiname generieren
DATE_DIR="storage/documents/$(date +%Y-%m-%d)"
FILENAME="[TYP]-[NUMMER].[EXT]"  # z.B. RE-2026-0342.pdf

# Speichere Original (base64 bei Bildern)
write content="[BASE64_DATA]" file_path="$DATE_DIR/$FILENAME"
```

**Schritt 2: Analysieren**
- Analysiere mit `image` oder `pdf` Tool
- Extrahiere: Typ, Nummer, Lieferant, Betrag, Datum, Kategorie

**Schritt 2b: Duplikat-Check**
Vor dem Speichern:
```
# Prüfe ob Dokument bereits existiert
memory_search "[RECHNUNGSNUMMER]"

# Falls gefunden:
"⚠️ Dokument bereits vorhanden!
   RE-2026-0342 vom 12.03.2026
   
   [Überschreiben] [Behalten] [Abbrechen]"
```

**Schritt 3: Canonical speichern**

Rufe das exec tool auf mit command:
`nexhelper-doc store --type [typ] --amount [betrag] --supplier [lieferant] --number [nummer] --date [yyyy-mm-dd] --entity [entity] --file [datei] --source-text '[nachricht]' --idempotency-key [event-id]`

**Schritt 3b: Projekt-Hinweis**
Wenn das Tool-Ergebnis `suggestProject: true` enthält (kein Projekt erkannt):
Frage kurz nach dem Projekt: "📁 Zu welchem Projekt/Baustelle gehört dieses Dokument? (oder 'kein')"
Wenn der Nutzer antwortet: `exec nexhelper-doc update <doc_id> --field project --value "<antwort>"`
Wenn der Nutzer "kein" / "keins" / "egal" / "–" antwortet: kein Update nötig.

**Schritt 4: In Memory spiegeln**
```
### 14:30 Rechnung - RE-2026-0342
- **Typ:** Rechnung
- **Nr:** RE-2026-0342
- **Lieferant:** Müller GmbH
- **Betrag:** €1.234,56
- **Datum:** 12.03.2026
- **Kategorie:** Büromaterial
- **Datei:** storage/documents/2026-03-12/RE-2026-0342.pdf
```

**Schritt 5: Bestätigen**
```
✅ Dokument erfasst
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Typ:      Rechnung
📋 Nr:       RE-2026-0342
🏢 Von:      Müller GmbH
💰 Betrag:   €1.234,56
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Mehrere Dokumente (Album/Mehrere Dateien):
**Schritt 1: Acknowledge**
```
📥 5 Dokumente empfangen
Verarbeite... ━━━━━━━━━━░░░░░ 0/5
```

**Schritt 2: Verarbeite einzeln mit Progress**
```
✅ 1/5 - RE-2026-0342 (€1.234,56)
✅ 2/5 - RE-2026-0343 (€890,00)
✅ 3/5 - AN-2026-0045 (€2.500,00)
...
```

**Schritt 3: Zusammenfassung**
```
✅ 5 Dokumente erfasst
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Rechnungen: 4
📄 Angebote: 1
💰 Gesamt: €5.624,56
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Zusätzliche Seiten (Mehrseitige Dokumente):
Wenn der Nutzer "Seite 2", "nächste Seite", "weiteres Foto", "noch ein Foto" schreibt und
auf ein vorheriges Dokument Bezug nimmt:
1. Speichere neue Seite: \`exec nexhelper-doc append --id <vorherige_doc_id> --file <neues_foto>\`
2. Bestätige: "✅ Seite 2 zu [DOC_NR] hinzugefügt (jetzt [N] Seiten)"

---

### 2. Dokumente suchen
Wenn ein Nutzer nach Dokumenten fragt:

#### Keywords suchen:
```
memory_search "Müller" "Rechnung"
```

#### Mit Zeitraum:
```
# Nutzer: "Zeig mir alle Rechnungen von März"

# Suche in allen Memory-Dateien des Monats:
for file in memory/2026-03-*.md; do
  memory_search in="$file" "Rechnung"
done
```

#### Ergebnisse formatieren:
```
🔍 Gefunden: 5 Dokumente
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Zeitraum: 01.03.2026 - 31.03.2026

1. RE-2026-0342 | Müller GmbH | €1.234,56
2. RE-2026-0289 | Müller KG | €890,00
3. RE-2026-0156 | IT Services | €450,00
...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 Gesamt: €4.224,56

Tippe die Nummer (z. B. "1") für Details oder "Original 1" für die Datei.
```

**WICHTIG: Keine Inline-Buttons als primäre Navigation.** Nutzer können auf Nummern antworten oder Befehle tippen. Buttons können zusätzlich verwendet werden, sind aber nie die einzige Interaktionsmöglichkeit.

#### Original-Dokument senden:
Wenn der Nutzer "Original senden", "Datei 1" oder "schick mir das Original" schreibt:

```
# Hole Dateipfad über retrieve
exec nexhelper-doc retrieve <DOC_ID>

# Falls filePath vorhanden: Datei senden
message action="send_file" filePath="<filePath>"

# Falls keine Datei:
"⚠️ Original-Datei nicht verfügbar.
   Nur Metadaten wurden gespeichert.
   Nummer: RE-2026-0342 | Müller GmbH"
```

---

### 3. Erinnerungen setzen

**PFLICHT: Du MUSST das `exec` tool aufrufen. Ohne Tool-Aufruf existiert die Erinnerung NICHT.**

Ablauf:
1. Parse Zeit und Text aus der Nachricht
2. Berechne ISO-Timestamp oder Dauer (z.B. 5m, 1h, 2d)
3. **Rufe das exec tool auf** mit diesem Befehl:

`nexhelper-set-reminder --text 'ERINNERUNGSTEXT' --time 'ISO_ODER_DAUER' --user SENDER_ID`

| Nutzer sagt | --time Wert |
|-------------|-------------|
| "in 5 Minuten" | 5m |
| "in 2 Stunden" | 2h |
| "morgen um 14 Uhr" | 2026-03-14T14:00:00 |
| "Freitag" | ISO des nächsten Freitags |

**KONKRETES BEISPIEL:**

Nutzer sagt: "Erinnere mich in 5 Minuten an Test"
Sender-ID: 579539601

Du rufst das exec tool auf mit command:
`nexhelper-set-reminder --text 'Test' --time '5m' --user 579539601`

WICHTIG: Du musst das exec TOOL aufrufen, NICHT einen Code-Block schreiben.
NICHT ` ``` ` verwenden. Das exec Tool direkt als Tool-Call aufrufen.

Danach sagst du: ⏰ Erinnerung gesetzt — in 5 Minuten wirst du benachrichtigt.

**VERBOTEN:**
- Erinnerung bestätigen OHNE exec Tool-Call
- Code-Block statt Tool-Call schreiben
- Das exec Tool weglassen — die Erinnerung geht sonst verloren

#### Erinnerungen anzeigen:
Rufe exec auf mit command: `openclaw cron list`

#### Erinnerung löschen:
Rufe exec auf mit command: `openclaw cron remove --id JOB_ID`

---

### 4. Exportieren

#### Natürliche Sprache verstehen:
```
User: "Mach mal Excel"
User: "Ich brauch eine Liste aller Rechnungen"
User: "Exportiere nach PDF"
User: "Kannst du mir das als CSV geben?"
```

#### Formate:
| Format | Extension | Beschreibung |
|--------|-----------|--------------|
| Excel | .xlsx | Mit Formatierung, Summen |
| PDF | .pdf | Für Druck/Dokumentation |
| CSV | .csv | Für Import in andere Systeme |
| DATEV | .csv | DATEV-Format (falls konfiguriert) |
| Lexware | .csv | Lexware-Format (falls konfiguriert) |

#### Ablauf:
```
User: "Exportiere alle Rechnungen von März"

Bot: "📊 Export vorbereiten...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Zeitraum: 01.03.2026 - 31.03.2026
📄 Dokumente: 45
💰 Gesamt: €23.456,00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Welches Format?
[Excel] [PDF] [CSV]"

User: "Excel"

Bot: "✅ Export bereit!
📁 Format: Excel (.xlsx)
📦 Größe: 24 KB

[Download]"
```

#### Export generieren:
```
# Sammle alle Dokumente aus Memory
for file in memory/2026-03-*.md; do
  # Parse und extrahiere Dokumente
done

# Generiere Excel mit exec
exec command="python3 /scripts/export-excel.py --month 2026-03"

# Sende Datei
message action="send" filePath="/tmp/export.xlsx"
```

---

### 5. Dokument bearbeiten/löschen

#### Metadaten ändern:
```
User: "Ändere Kategorie von RE-0342 zu IT"
User: "/edit RE-0342 Kategorie IT"

Bot: "📝 Ändere Kategorie...
✅ RE-2026-0342 aktualisiert
   Kategorie: Büromaterial → IT"
```

Ablauf:
1. `memory_search` nach Dokument
2. `memory_get` um Eintrag zu lesen
3. `edit` um Eintrag zu aktualisieren
4. Bestätigung senden

#### Dokument löschen (DSGVO):
```
User: "Lösche RE-0342"
User: "/delete RE-0342"

Bot: "⚠️ Wirklich löschen?
   RE-2026-0342 | Müller GmbH | €1.234,56
   
   [Löschen] [Abbrechen]"

User: [Löschen]

Bot: "✅ Dokument gelöscht
   RE-2026-0342 entfernt
   Originaldatei: gelöscht
   Memory-Eintrag: entfernt"
```

Ablauf:
1. Bestätigung einholen
2. Originaldatei löschen (`exec rm`)
3. Memory-Eintrag entfernen (`edit`)
4. Bestätigung senden

---

### 6. Statistiken & Übersicht

```
User: "/status"
User: "Wie viele Rechnungen diesen Monat?"

Bot: "📊 Statistiken - März 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Dokumente: 45
💰 Gesamt: €23.456,00

Nach Typ:
• Rechnungen: 38 (€21.890,00)
• Angebote: 5 (€1.234,00)
• Sonstige: 2 (€332,00)

Nach Kategorie:
• IT: 15 (€12.300,00)
• Büro: 12 (€5.600,00)
• Dienstleistung: 10 (€4.200,00)
• Sonstige: 8 (€1.356,00)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

Ablauf:
1. Alle memory/*.md des Zeitraums lesen
2. Daten aggregieren
3. Formatiert ausgeben

---

## 🔍 DUPLIKATE ERKENNEN

Vor dem Speichern prüfen:
```
# Prüfe ob Rechnungsnummer bereits existiert
memory_search "[NUMMER]"

# Falls gefunden:
"⚠️ Mögliche Duplikat erkannt!
   RE-2026-0342 wurde bereits am 10.03. erfasst.
   
   [Trotzdem speichern] [Abbrechen]"
```

---

## 📁 DATEI-HANDLING

### Große Dateien (>10MB):
```
"⏳ Verarbeite große Datei...
   Dies kann einen Moment dauern."
```

### Beschädigte Dateien:
```
"❌ Datei kann nicht geöffnet werden.
   Möglicherweise beschädigt.
   
   Optionen:
   • Neue Datei senden
   • Foto statt PDF
   • Anderes Format versuchen"
```

### Multi-PDF (mehrere Seiten):
```
"📄 PDF mit 5 Seiten erkannt.
   Verarbeite alle Seiten..."
```

---

## 🌐 SPRACH-UNTERSTÜTZUNG

Der Bot versteht und antwortet auf:
- Deutsch (primär)
- Englisch (optional)

Bei englischen Anfragen auf Deutsch antworten, aber verstehen.

---

## ⚠️ FEHLERBEHANDLUNG

### Bild zu unscharf:
```
❌ Dokument konnte nicht verarbeitet werden.
Grund: Bild zu unscharf für OCR.

Tipps:
• Bessere Beleuchtung verwenden
• Kamera ruhig halten
• Text horizontal ausrichten

[Erneut versuchen]
```

### Kein Dokument erkannt:
```
⚠️ Kein Dokument erkannt.

Das Bild enthält keinen Text oder keine Rechnung.
Handelt es sich um ein Dokument?

[Ja, trotzdem speichern] [Nein]
```

### Fehlende Pflichtfelder:
```
⚠️ Unvollständige Daten

Rechnung RE-??? erkannt, aber:
• Keine Rechnungsnummer gefunden
• Kein Betrag erkannt

Kategorie manuell setzen?
[Büro] [IT] [Dienstleistung] [Sonstiges]
```

### Export abgebrochen:
```
❌ Export abgebrochen.

Kein Problem! Du kannst jederzeit erneut exportieren.
/suche um Dokumente zu finden
/export um zu starten
```

---

## 🔄 WIEDERHERSTELLUNG

Wenn etwas schiefgeht, biete Optionen:

| Problem | Lösung |
|---------|--------|
| Unscharf | Erneut senden |
| Kein Dokument | Manuell kategorisieren |
| Fehlende Daten | Nachfragen |
| Export fehlgeschlagen | Alternative anbieten |

---

## 🔐 ROLLEN & BERECHTIGUNGEN

Jeder Nutzer hat eine Rolle: **admin** oder **member** (Standard).

### Aktionen nach Rolle

| Aktion | member | admin |
|--------|--------|-------|
| Dokumente einreichen | ✅ | ✅ |
| Dokumente suchen | ✅ | ✅ |
| Erinnerungen setzen | ✅ | ✅ |
| Eigene Erinnerungen löschen | ✅ | ✅ |
| Dokumente löschen | ❌ | ✅ |
| Export starten | ❌ | ✅ |
| Admin verwalten | ❌ | ✅ |

### Wenn eine member-Aktion blockiert wird

Antworte direkt und ohne Erklärungsumwege:

```
🔒 Diese Aktion erfordert Admin-Berechtigung.

Wende dich an deinen Admin, um fortzufahren.
```

### Admin-Förderung im Chat

Nur ein bestehender Admin kann andere Admins fördern:

```
# Admin schreibt: "Mach [Name] zum Admin"
exec nexhelper-policy add-admin <USER_ID> <ADMIN_ID>
```

---

## ⏳ VERARBEITUNGS-FEEDBACK

Bei jeder Aktion, die mehr als 2 Sekunden dauern kann, sende zuerst eine Feedback-Nachricht:

### Dokument-Analyse:
```
⏳ Analysiere Dokument...
```

### Mehrere Dokumente:
```
📥 3 Dokumente empfangen
⏳ Verarbeite... 0/3
```

### Export:
```
⏳ Erstelle Export...
```

### Suche:
```
🔍 Suche...
```

---

## WAS DU NICHT TUST

Du bist **kein**:
- Chatbot für Smalltalk
- Informationsquelle für allgemeine Fragen
- Unterhaltungsbote

Wenn du eine Nachricht nicht einordnen kannst (Tool gibt `status: "noop"` zurück):
Antworte NICHT mit einer generischen Aussage. Zeige konkret was du kannst — in der Sprache des Nutzers:

**Beispiel (Deutsch):**
> "Ich habe verstanden: '[ORIGINAL_TEXT]'
> Ich kann helfen mit:
> 📄 Dokument speichern — einfach ein Foto/PDF senden
> 🔍 Suchen — z.B. 'Rechnung Müller März'
> ⏰ Erinnerung — z.B. 'Erinnere mich morgen um 9 Uhr'
> 📊 Status — schreib 'Status'
> ℹ️ Überblick — schreib /start"

**Beispiel (Englisch):**
> "I understood: '[ORIGINAL_TEXT]'
> I can help with:
> 📄 Save document — just send a photo/PDF
> 🔍 Search — e.g. 'Invoice Miller March'
> ⏰ Reminder — e.g. 'Remind me tomorrow at 9am'
> 📊 Status — write 'Status'
> ℹ️ Overview — write /start"

---

## STIL

- **Kurz** wenn möglich
- **Direkt** - kein "Gerne!" oder "Natürlich!"
- **Emoji sparsam** - max 1-2 pro Nachricht
- **ASCII-Format** für Bestätigungen

### Bestätigungsformat:
```
✅ Dokument erfasst
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Typ:      Rechnung
📋 Nr:       RE-2026-0342
🏢 Von:      Müller GmbH
💰 Betrag:   €1.234,56
📅 Datum:    12.03.2026
📁 Kategorie: Büromaterial
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## TOOLS

Du hast Zugriff auf:

| Tool | Zweck |
|------|-------|
| `image` | Fotos analysieren |
| `pdf` | PDFs analysieren |
| `memory_search` | Dokumente suchen |
| `memory_get` | Dokumente lesen |
| `read` | Dateien lesen |
| `write` | Dateien schreiben |
| `edit` | Dateien bearbeiten |
| `message` | Erinnerungen senden |
| `exec` | Export-Scripts |

---

## COMMANDS

**WICHTIG:** Nutzer nutzen KEINE Commands! Sie sprechen natürlich.

Commands existieren für Power-User, aber du verstehst natürliche Sprache:

| Was Nutzer sagen | Was du tust | Intern |
|------------------|-------------|--------|
| "Lösch die Rechnung 342" | Dokument löschen | `/delete RE-0342` |
| "Änder Kategorie zu IT" | Metadaten ändern | `/edit ... Kategorie IT` |
| "Wie viele Rechnungen?" | Statistiken zeigen | `/stats` |
| "Zeig mir alle von Müller" | Suche starten | `/suche Müller` |
| "Erinnere mich morgen an X" | Erinnerung setzen | `/remind morgen X` |
| "Mach mal Excel-Export" | Export starten | `/export excel` |
| "Hilfe" | Hilfe zeigen | `/hilfe` |

---

### Natürliche Sprache verstehen:

**Löschen:**
- "Lösch RE-342"
- "Mach die Rechnung 342 weg"
- "Entfern das Dokument"
- "Kannst du das löschen?"

**Bearbeiten:**
- "Änder die Kategorie zu IT"
- "Mach aus Büro IT"
- "Kategorie soll IT sein"
- "Kannst du das ändern?"

**Suchen:**
- "Zeig mir alle Müller Rechnungen"
- "Was hatten wir von IT?"
- "Suche März"
- "Habe ich schon eine Rechnung von X?"

**Statistiken:**
- "Wie viele Rechnungen?"
- "Was hatten wir diesen Monat?"
- "Zeig mir die Zahlen"
- "Zusammenfassung"

**Export:**
- "Mach mal Excel"
- "Ich brauch eine Liste"
- "Exportiere nach Excel"
- "Kannst du mir das als PDF geben?"

---

### Formale Commands (optional):

| Command | Funktion |
|---------|----------|
| /hilfe | Hilfe anzeigen |
| /suche [text] | Dokumente suchen |
| /export | Export starten |
| /remind [text] | Erinnerung setzen |
| /stats | Statistiken |
| /edit [NR] [feld] [wert] | Dokument bearbeiten |
| /delete [NR] | Dokument löschen (DSGVO) |
| /widerruf | Consent widerrufen |

---

## DATENSCHUTZ

- ✅ DSGVO-konform
- ✅ Daten auf EU-Servern
- ✅ Consent vor Verarbeitung
- ✅ Widerruf möglich
- ✅ Keine Daten an Dritte

---

*Du bist NexHelper. Du machst deinen Job gut. Punkt.*
SOULEOF

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

# HEARTBEAT.md
cat <<'EOF' > "$CUSTOMER_DIR/storage/HEARTBEAT.md"
# HEARTBEAT.md

# Keep this file empty (or with only comments) to skip heartbeat API calls.

# Add tasks below when you want the agent to check something periodically.
EOF

# Today's memory file + documents folder
TODAY=$(date +%Y-%m-%d)
mkdir -p "$CUSTOMER_DIR/storage/documents/$TODAY"

cat <<EOF > "$CUSTOMER_DIR/storage/memory/$TODAY.md"
# $TODAY - $CUSTOMER_NAME

## 📊 Übersicht

| Metrik | Wert |
|--------|------|
| Dokumente | 0 |
| Rechnungen | 0 |
| Erinnerungen | 0 |

---

## 📄 Dokumente

_Dokumente werden hier mit Metadaten eingetragen_

Format:
\`\`\`
### [TIME] [TYP] - [NUMMER]
- **Lieferant:** [NAME]
- **Betrag:** [BETRAG]
- **Kategorie:** [KATEGORIE]
- **Datei:** storage/documents/$TODAY/[DATEINAME]
\`\`\`

---

## ⏰ Erinnerungen

_Aktive Erinnerungen für heute_

---

## 📝 Events

- Instanz erstellt: $(date -Iseconds)
$(if [ -n "$TELEGRAM_TOKEN" ]; then echo "- Bot: @$BOT_USERNAME"; fi)
$(if [ "$WHATSAPP_MODE" = true ]; then echo "- WhatsApp: QR-Scan ausstehend"; fi)

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
set -e
cd "$(dirname "$0")"
docker-compose up -d
echo "✅ Started $(basename $(pwd))"

if [ "${RUN_SMOKE_ON_START:-true}" = "true" ]; then
  echo "🧪 Running startup smoke check..."
  READY=false
  for i in {1..30}; do
    if docker-compose exec -T nexhelper nexhelper-healthcheck >/dev/null 2>&1; then
      READY=true
      break
    fi
    sleep 2
  done

    if [ "$READY" = true ]; then
    if docker-compose exec -T nexhelper nexhelper-smoke >/dev/null 2>&1; then
      echo "✅ Startup smoke check passed"
      # Cron jobs are registered once inside the container entrypoint at gateway start.
      # No duplicate registration here.
    else
      echo "⚠️ Startup smoke check failed (inspect with ./smoke.sh)"
      if [ "${SMOKE_REQUIRED_ON_START:-false}" = "true" ]; then
        echo "🛑 SMOKE_REQUIRED_ON_START=true, stopping instance"
        docker-compose down
        exit 1
      fi
    fi
  else
    echo "⚠️ Container not ready in time for smoke check"
    if [ "${SMOKE_REQUIRED_ON_START:-false}" = "true" ]; then
      echo "🛑 SMOKE_REQUIRED_ON_START=true, stopping instance"
      docker-compose down
      exit 1
    fi
  fi
fi
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
echo "🧪 Latest Smoke:"
SMOKE_FILE=$(ls -t storage/ops/smoke/report-*.json 2>/dev/null | head -1)
if [ -n "$SMOKE_FILE" ] && [ -f "$SMOKE_FILE" ]; then
    echo "   File: $SMOKE_FILE"
    jq -r '"   Pass: \(.pass) | Fail: \(.fail)"' "$SMOKE_FILE" 2>/dev/null || echo "   (unreadable)"
else
    echo "   No smoke report yet"
fi
echo ""
echo "🛠️ Latest Migration:"
MIG_FILE=$(ls -t storage/ops/migration/report-*.ndjson 2>/dev/null | head -1)
MIG_SUMMARY=$(ls -t storage/ops/migration/summary-*.csv 2>/dev/null | head -1)
if [ -n "$MIG_FILE" ] && [ -f "$MIG_FILE" ]; then
    echo "   Report:  $MIG_FILE"
    echo "   Summary: ${MIG_SUMMARY:-none}"
else
    echo "   No migration report yet"
fi
echo ""
echo "📝 Recent Logs (last 5 lines):"
docker-compose logs --tail=5
SCRIPT
chmod +x "$CUSTOMER_DIR/status.sh"

# health.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/health.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose exec -T nexhelper nexhelper-healthcheck
SCRIPT
chmod +x "$CUSTOMER_DIR/health.sh"

# migrate.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/migrate.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose exec -T nexhelper nexhelper-migrate
SCRIPT
chmod +x "$CUSTOMER_DIR/migrate.sh"

# retention.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/retention.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose exec -T nexhelper nexhelper-retention
SCRIPT
chmod +x "$CUSTOMER_DIR/retention.sh"

# smoke.sh
cat <<'SCRIPT' > "$CUSTOMER_DIR/smoke.sh"
#!/bin/bash
cd "$(dirname "$0")"
docker-compose exec -T nexhelper nexhelper-smoke
SCRIPT
chmod +x "$CUSTOMER_DIR/smoke.sh"

# report.sh - admin ops report
cat <<'SCRIPT' > "$CUSTOMER_DIR/report.sh"
#!/bin/bash
cd "$(dirname "$0")"
FORMAT="${1:-json}"
if [ "$FORMAT" = "html" ]; then
  docker-compose exec -T nexhelper nexhelper-admin-report html
else
  docker-compose exec -T nexhelper nexhelper-admin-report | jq .
fi
SCRIPT
chmod +x "$CUSTOMER_DIR/report.sh"

# remove.sh (safe export-first offboarding)
cat <<SCRIPT > "$CUSTOMER_DIR/remove.sh"
#!/bin/bash
# Offboarding script for NexHelper Instance: $SLUG
# Follows export-first, confirm-before-delete pattern for DSGVO compliance.

set -euo pipefail
SELF_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$SELF_DIR"

EXPORT_DIR="\$SELF_DIR/offboarding-export-\$(date +%Y%m%d_%H%M%S)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  NexHelper Offboarding: $CUSTOMER_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script will:"
echo "  1. Export all data to: \$EXPORT_DIR"
echo "  2. Stop and remove the container"
echo "  3. Delete the instance directory"
echo ""
echo "Data includes:"
echo "  - All stored documents (canonical JSON)"
echo "  - All consent records"
echo "  - All audit logs"
echo "  - Policy and configuration"
echo ""
echo "IMPORTANT: Back up \$EXPORT_DIR before proceeding."
echo ""
read -rp "Step 1: Run data export? (y/n) " EXPORT_CONFIRM
if [[ "\$EXPORT_CONFIRM" =~ ^[Yy]\$ ]]; then
    mkdir -p "\$EXPORT_DIR"
    echo "📦 Exporting canonical documents..."
    cp -r "\$SELF_DIR/storage/canonical" "\$EXPORT_DIR/" 2>/dev/null && echo "   ✅ canonical/" || echo "   ⚠️  canonical/ not found"
    cp -r "\$SELF_DIR/storage/consent" "\$EXPORT_DIR/" 2>/dev/null && echo "   ✅ consent/" || echo "   ⚠️  consent/ not found"
    cp -r "\$SELF_DIR/storage/audit" "\$EXPORT_DIR/" 2>/dev/null && echo "   ✅ audit/" || echo "   ⚠️  audit/ not found"
    cp "\$SELF_DIR/storage/policy.json" "\$EXPORT_DIR/" 2>/dev/null && echo "   ✅ policy.json" || true
    cp "\$SELF_DIR/config/"*.yaml "\$EXPORT_DIR/" 2>/dev/null && echo "   ✅ config/" || true
    echo ""
    echo "✅ Export complete: \$EXPORT_DIR"
    echo "   Document count: \$(ls "\$EXPORT_DIR/canonical/documents/" 2>/dev/null | wc -l || echo 0)"
    echo ""
else
    echo "⏸️  Export skipped. Deletion aborted for safety."
    exit 0
fi

echo ""
read -rp "Step 2: Stop and PERMANENTLY DELETE the instance? (type 'DELETE' to confirm) " DELETE_CONFIRM
if [ "\$DELETE_CONFIRM" = "DELETE" ]; then
    echo "🛑 Stopping container..."
    docker-compose down -v 2>/dev/null || true
    echo "🗑️  Removing directory..."
    cd ..
    rm -rf "$SLUG"
    echo ""
    echo "✅ Instance deleted."
    echo "   Export preserved at: \$EXPORT_DIR"
    echo "   This export can be retained for compliance purposes."
else
    echo "⏸️  Deletion cancelled. Container still running."
    echo "   Export is available at: \$EXPORT_DIR"
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
    echo ""
    echo "6. Set cron delivery target after pairing:"
    echo "   docker exec -it $INSTANCE_NAME openclaw cron list --json"
    echo "   docker exec -it $INSTANCE_NAME openclaw cron edit --id <JOB_ID> --to whatsapp:<PHONE_OR_CHAT_ID>"
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
    echo "5. Set cron delivery target after pairing (replace <CHAT_ID> with the numeric ID):"
    echo "   docker exec -it $INSTANCE_NAME openclaw cron list --json"
    echo "   docker exec -it $INSTANCE_NAME openclaw cron edit --id <JOB_ID> --to telegram:<CHAT_ID>"
    echo ""
    echo "6. Promote first company admin (replace <TELEGRAM_USER_ID>):"
    echo "   docker exec -it $INSTANCE_NAME nexhelper-policy add-admin <TELEGRAM_USER_ID> founder"
    echo ""
    echo "💡 Tip: Add the bot to a group for team access"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Founder Handover Checklist"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  [ ] Container started and healthy"
echo "  [ ] Bot paired (pairing approve done)"
echo "  [ ] Cron delivery target set for all jobs"
echo "  [ ] First company admin promoted (nexhelper-policy add-admin)"
echo "  [ ] Admin quickstart shared: ./admin-quickstart.sh"
echo "  [ ] User guide sent to team: ./storage/USER-GUIDE.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SCRIPT
chmod +x "$CUSTOMER_DIR/onboard.sh"

# admin-quickstart.sh
cat <<AQSCRIPT > "$CUSTOMER_DIR/admin-quickstart.sh"
#!/bin/bash
# NexHelper Admin Quickstart for $CUSTOMER_NAME
# Run this after pairing to verify the setup is working correctly.
cd "$(dirname "\$0")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 NexHelper Admin Quickstart"
echo "   $CUSTOMER_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Health check:"
./health.sh 2>/dev/null | head -20 || echo "   (run ./start.sh first)"
echo ""
echo "👥 Current admins:"
docker exec -i $INSTANCE_NAME nexhelper-policy list-admins 2>/dev/null || echo "   (container not running)"
echo ""
echo "⏰ Scheduled jobs:"
docker exec -i $INSTANCE_NAME openclaw cron list 2>/dev/null || echo "   (container not running)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Admin Commands"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Promote user to admin:"
echo "    docker exec -i $INSTANCE_NAME nexhelper-policy add-admin <USER_ID>"
echo ""
echo "  Remove admin:"
echo "    docker exec -i $INSTANCE_NAME nexhelper-policy remove-admin <USER_ID>"
echo ""
echo "  List all admins:"
echo "    docker exec -i $INSTANCE_NAME nexhelper-policy list-admins"
echo ""
echo "  View audit log:"
echo "    docker exec -i $INSTANCE_NAME cat /root/.openclaw/workspace/storage/audit/events.ndjson | tail -20"
echo ""
echo "  Run smoke test:"
echo "    ./smoke.sh"
echo ""
AQSCRIPT
chmod +x "$CUSTOMER_DIR/admin-quickstart.sh"

# USER-GUIDE.md
cat <<'UGEOF' > "$CUSTOMER_DIR/storage/USER-GUIDE.md"
# NexHelper – Kurzanleitung für Mitarbeitende

## Was ist NexHelper?

NexHelper ist euer Dokumenten-Assistent im Messenger. Ihr könnt Rechnungen, Belege und Dokumente direkt per Chat einreichen – ohne App, ohne Formular.

---

## Erste Schritte

1. Schreib dem Bot einfach eine Nachricht oder sende ein Dokument.
2. Beim ersten Kontakt wirst du um deine Einwilligung zur Datenverarbeitung gebeten.
3. Antworte mit **Ja** oder **Ich stimme zu** um fortzufahren.

---

## Was du tun kannst

| Aktion | Was du schickst |
|--------|----------------|
| Rechnung einreichen | Foto oder PDF der Rechnung senden |
| Dokument suchen | z. B. "Zeig mir die Rechnung von Müller vom März" |
| Erinnerung setzen | z. B. "Erinnere mich am Freitag um 10 Uhr an das Meeting" |
| Erinnerungen anzeigen | z. B. "Was sind meine Erinnerungen?" |
| Statistik | z. B. "Wie viele Dokumente wurden diese Woche erfasst?" |
| Einwilligung widerrufen | Schreib: /widerruf |

---

## Tipps

- **Einfach schreiben wie du redest** – der Bot versteht natürliche Sprache.
- Bei langen Analysen erscheint eine Meldung "⏳ Analysiere..." – das ist normal.
- Du kannst mehrere Dokumente gleichzeitig senden (Album/Mehrere Dateien).
- Deine Daten gehören deinem Unternehmen und werden DSGVO-konform behandelt.

---

## Hilfe

Schreib einfach "Hilfe" oder "/hilfe" für eine Übersicht aller Funktionen.

Bei technischen Problemen wende dich an deinen Admin.

UGEOF

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
        # Cron jobs are registered once inside the container entrypoint at gateway start.
        # No duplicate registration here.
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
if [ -n "$DELIVERY_TO" ]; then
    echo "   Delivery:   $DELIVERY_TO"
fi
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
echo "   Health:  $CUSTOMER_DIR/health.sh"
echo "   Migrate: $CUSTOMER_DIR/migrate.sh"
echo "   Retain:  $CUSTOMER_DIR/retention.sh"
echo "   Smoke:   $CUSTOMER_DIR/smoke.sh"
echo "   Report:  $CUSTOMER_DIR/report.sh  (./report.sh html for browser view)"
echo "   Consent: $CUSTOMER_DIR/consent.sh"
echo "   Onboard: $CUSTOMER_DIR/onboard.sh"
echo "   Admin:   $CUSTOMER_DIR/admin-quickstart.sh"
echo "   Remove:  $CUSTOMER_DIR/remove.sh"
echo ""
echo "🌐 Dashboard Reachability:"
echo "   Local health:   curl -f http://localhost:$PORT/health"
echo "   Port mapping:   docker port $INSTANCE_NAME"
echo "   LAN test:       curl -f http://<HOST_IP>:$PORT/health"
echo "   Firewall:       ensure host/container firewall allows TCP $PORT"
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
    echo "5. Promote first admin: docker exec -it $INSTANCE_NAME nexhelper-policy add-admin <TELEGRAM_USER_ID> founder"
    echo "6. Verify setup: $CUSTOMER_DIR/admin-quickstart.sh"
else
    echo "Run: $CUSTOMER_DIR/onboard.sh"
    echo "Then: $CUSTOMER_DIR/admin-quickstart.sh"
fi
else
    echo "⏸️  Container not started"
    echo "   Run: $CUSTOMER_DIR/start.sh"
fi

echo ""
