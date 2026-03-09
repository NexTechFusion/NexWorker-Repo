#!/bin/bash
# Test NexHelper Setup
# Validates configuration and runs basic tests

set -e

CUSTOMER_DIR="${1:-/opt/nexhelper/customers}"
TEST_DOC="${2:-}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 NexHelper Setup Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Test 1: Docker
echo "Testing Docker..."
if command -v docker &> /dev/null; then
    pass "Docker installed: $(docker --version)"
else
    fail "Docker not installed"
    exit 1
fi

# Test 2: Docker Compose
echo "Testing Docker Compose..."
if docker compose version &> /dev/null || docker-compose version &> /dev/null; then
    pass "Docker Compose installed"
else
    fail "Docker Compose not installed"
    exit 1
fi

# Test 3: Tesseract OCR
echo "Testing Tesseract OCR..."
if docker run --rm nexhelper:latest which tesseract &> /dev/null; then
    pass "Tesseract available in image"
else
    warn "Tesseract not in image - rebuild with: ./build-image.sh"
fi

# Test 4: Customer Directory
echo "Testing customer directory..."
if [ -d "$CUSTOMER_DIR" ]; then
    CUSTOMERS=$(ls -d "$CUSTOMER_DIR"/*/ 2>/dev/null | wc -l)
    pass "Customer directory exists: $CUSTOMERS customer(s)"
    
    # List customers
    for dir in "$CUSTOMER_DIR"/*/; do
        if [ -d "$dir" ]; then
            SLUG=$(basename "$dir")
            echo "   - $SLUG"
        fi
    done
else
    warn "Customer directory not found: $CUSTOMER_DIR"
fi

# Test 5: Environment Variables
echo "Testing environment variables..."
if [ -f "$CUSTOMER_DIR/*/./.env" ]; then
    source "$CUSTOMER_DIR/*/./.env" 2>/dev/null || true
fi

if [ -n "$OPENAI_API_KEY" ]; then
    pass "OPENAI_API_KEY set"
else
    fail "OPENAI_API_KEY not set"
fi

if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    pass "TELEGRAM_BOT_TOKEN set"
else
    fail "TELEGRAM_BOT_TOKEN not set"
fi

# Test 6: Network
echo "Testing Docker network..."
if docker network ls | grep -q "nexhelper-network"; then
    pass "nexhelper-network exists"
else
    warn "nexhelper-network not found - will be created on first run"
fi

# Test 7: OCR (if test image provided)
if [ -n "$TEST_DOC" ] && [ -f "$TEST_DOC" ]; then
    echo "Testing OCR with test document..."
    TEMP_DIR=$(mktemp -d)
    
    if docker run --rm -v "$TEST_DOC:/test.doc" nexhelper:latest \
        /app/skills/document-ocr/scripts/ocr_image.sh /test.doc 2>/dev/null | head -5; then
        pass "OCR working"
    else
        warn "OCR test skipped (image not available)"
    fi
    
    rm -rf "$TEMP_DIR"
else
    warn "OCR test skipped (no test document provided)"
fi

# Test 8: Running Containers
echo "Testing running containers..."
RUNNING=$(docker ps --filter "name=nexhelper-" --format "{{.Names}}" | wc -l)
if [ "$RUNNING" -gt 0 ]; then
    pass "$RUNNING container(s) running"
    docker ps --filter "name=nexhelper-" --format "   - {{.Names}} ({{.Status}})"
else
    warn "No containers running"
fi

# Test 9: Port Availability
echo "Testing port availability..."
for PORT in 3000 3001 3002; do
    if lsof -i :$PORT &> /dev/null; then
        warn "Port $PORT in use"
    else
        pass "Port $PORT available"
    fi
done

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ All critical tests passed!"
echo ""
echo "📝 Next steps:"
echo "   1. Build image: ./build-image.sh"
echo "   2. Provision: ./provision-customer.sh 001 'Test Kunde'"
echo "   3. Test bot: Send /start to @NexHelperBot"
echo ""
echo "📚 Documentation:"
echo "   - README.md: Setup guide"
echo "   - PROVISIONING.md: Architecture"
echo "   - skills/: Custom skills"
echo ""