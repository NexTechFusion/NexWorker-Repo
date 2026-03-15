#!/bin/bash
# NexHelper First-Time Setup
# Run this once to prepare the system for customer provisioning

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NexHelper System Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first:"
    echo "   curl -fsSL https://get.docker.com | sh"
    exit 1
fi
echo "✅ Docker installed"

# Check Docker Compose
if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
    echo "❌ Docker Compose not found. Please install it."
    exit 1
fi
echo "✅ Docker Compose installed"

# Check for API key
ACTIVE_API_KEY="${OPENROUTER_API_KEY:-${OPENAI_API_KEY:-}}"
if [ -z "$ACTIVE_API_KEY" ]; then
    echo ""
    echo "⚠️  OPENROUTER_API_KEY (or OPENAI_API_KEY) not set"
    echo "   You'll need this to provision customers."
    echo "   Set it: export OPENROUTER_API_KEY=your-key"
    echo "   Legacy fallback: export OPENAI_API_KEY=your-key"
    echo "   Optional for OpenAI-compatible clients: export OPENAI_BASE_URL=https://openrouter.ai/api/v1"
fi

# Create base directory
BASE_DIR="${BASE_DIR:-/opt/nexhelper/customers}"
echo ""
echo "📁 Creating base directory: $BASE_DIR"
mkdir -p "$BASE_DIR"

# Create Docker network
echo "🌐 Creating Docker network..."
docker network create nexhelper-network 2>/dev/null || true

# Build Docker image if needed
echo ""
echo "🐳 Checking for nexhelper Docker image..."
if ! docker image inspect nexhelper:latest &> /dev/null; then
    echo "⚠️  nexhelper:latest image not found"
    echo ""
    read -p "Build it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        cd "$SCRIPT_DIR"
        ./build-image.sh latest
    fi
else
    echo "✅ nexhelper:latest image available"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 To provision a customer:"
echo ""
echo "   # Telegram bot"
echo "   export OPENROUTER_API_KEY=your-key"
echo "   export OPENAI_BASE_URL=https://openrouter.ai/api/v1"
echo "   export USE_OPENROUTER=1"
echo "   ./provision-customer.sh 001 'Acme GmbH' --telegram '123:ABC'"
echo ""
echo "   # WhatsApp"
echo "   ./provision-customer.sh 002 'Müller Bau' --whatsapp"
echo ""
echo "🔧 Prerequisites:"
echo ""
echo "   For Telegram:"
echo "   1. Open Telegram"
echo "   2. Chat with @BotFather"
echo "   3. Run /newbot"
echo "   4. Copy the token"
echo ""
echo "   For WhatsApp:"
echo "   1. Have a phone with WhatsApp ready"
echo "   2. You'll scan a QR code after provisioning"
echo ""
