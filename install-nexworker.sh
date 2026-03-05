#!/bin/bash
# NexWorker Installer (v1.0) - Hosted by NexTech Fusion
# This script initializes a new NexWorker instance for a client.

set -e

CLIENT_NAME=$1
IFACE_TOKEN=$2

if [ -z "$CLIENT_NAME" ] || [ -z "$IFACE_TOKEN" ]; then
    echo "Usage: ./install-nexworker.sh <client-slug> <telegram-or-whatsapp-token>"
    exit 1
fi

echo "🚀 Initializing NexWorker for: $CLIENT_NAME"

# 1. Create Workspace
WORK_DIR="nexworker-$CLIENT_NAME"
mkdir -p "$WORK_DIR/memory"
mkdir -p "$WORK_DIR/exports"
cd "$WORK_DIR"

# 2. Pull System Prompt (Local copy)
echo "📝 Fetching NexWorker Brain..."
cat <<EOF > system-prompt.md
$(cat /root/.openclaw/workspace/NexWorker/System-Prompt.md)
EOF

# 3. Generate config.yaml
echo "⚙️ Configuring OpenClaw Gateway..."
cat <<EOF > config.yaml
# NexWorker Client Instance: $CLIENT_NAME
gateway:
  port: 19000
  auth:
    token: "nextech-admin-$(base64 <<< $CLIENT_NAME | cut -c1-8)"

agent:
  systemPrompt: |
$(sed 's/^/    /' system-prompt.md)

channels:
  telegram:
    token: "$IFACE_TOKEN"
    enabled: true

# Database Auto-Logging
memory:
  path: "./memory"
  autoArchive: true
EOF

# 4. Create the 'Welcome' Script
cat <<EOF > welcome.sh
#!/bin/bash
echo "Moin! 🏗️ Ich bin **NexWorker**, dein neuer digitaler Bauhelfer. Ab sofort kannst du mir einfach hier im Chat alles zur Baustelle schicken. Keine Zettel, kein Stress. Viel Erfolg heute! 👍"
EOF
chmod +x welcome.sh

# 5. Setup empty SQLite DB for structured logs
echo "🗄️ Initializing Local Matrix..."
sqlite3 nexworker.db "CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY, project TEXT, worker TEXT, activity TEXT, material TEXT, duration REAL, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);"

echo "✅ NexWorker Instance '$CLIENT_NAME' is ready!"
echo "👉 Start it with: openclaw gateway start --config ./config.yaml"
echo "👉 Add your bot to the group and it will listen as 'The Hidden Professional'."
