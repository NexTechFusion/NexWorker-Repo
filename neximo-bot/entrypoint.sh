#!/bin/bash
# NexImo Entrypoint - Container startup script

set -e

echo "=== NexImo Bot Starting ==="

# Initialize directories
export NXIMO_STORAGE_DIR="${NXIMO_STORAGE_DIR:-/data/storage}"
mkdir -p "$NXIMO_STORAGE_DIR"/{profiles,listings,applications,responses,audit,idempotency}

# Fix line endings (CRLF -> LF)
if [ -d "/app/skills" ]; then
    find /app/skills -type f \( -name "*.sh" -o -name "neximo-*" \) -exec sed -i 's/\r$//' {} \;
fi

# Create symlinks for skills
if [ -d "/app/skills" ] && [ ! -d "/usr/local/neximo-skills" ]; then
    cp -r /app/skills /usr/local/neximo-skills
    chmod -R +x /usr/local/neximo-skills
fi

# Add skills to PATH
export PATH="/usr/local/neximo-skills/common:/usr/local/neximo-skills/search:/usr/local/neximo-skills/application:/usr/local/neximo-skills/notify:$PATH"

# Initialize config if not exists
if [ ! -f "/app/config/openclaw.json" ] && [ -f "/app/config/openclaw.json.template" ]; then
    envsubst < /app/config/openclaw.json.template > /app/config/openclaw.json
fi

# Start background scanner loop (if enabled)
if [ "${NXIMO_SCANNER_ENABLED:-true}" = "true" ]; then
    echo "Starting background scanner..."
    nohup neximo-scanner --loop > /var/log/neximo-scanner.log 2>&1 &
fi

echo "=== NexImo Bot Ready ==="

# Execute the command
exec "$@"
