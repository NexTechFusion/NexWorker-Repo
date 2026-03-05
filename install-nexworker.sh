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

# 3. Generate config.yaml with Hybrid Sync & Multi-User Support
echo "⚙️ Configuring OpenClaw Gateway PRO Setup..."
cat <<EOF > config.yaml
# NexWorker Client Instance: $CLIENT_NAME
gateway:
  port: 19000
  auth:
    token: "nextech-admin-$(base64 <<< $CLIENT_NAME | cut -c1-8)"
  reload:
    mode: "hybrid"

agent:
  systemPrompt: |
$(sed 's/^/    /' system-prompt.md)

session:
  dmScope: "per-channel-peer"  # Recognizes different workers automatically

channels:
  telegram:
    token: "$IFACE_TOKEN"
    enabled: true
    groupChat:
      mentionPatterns: ["!fix", "!status", "Bericht"]

# Database & Sheets Sync (Draft)
# Note: To enable Google Sheets, add credentials to .env
memory:
  path: "./memory"
  autoArchive: true

# Webhook for real-time Sheet Sync (if configured)
# hooks:
#   enabled: true
#   token: "\${SHEETS_WEBHOOK_TOKEN}"
EOF

# 4. Update System-Prompt with ASCII formatting and Auto-Alert Logic
echo "🧠 Refining System Brain for ASCII Output..."
cat <<EOF >> system-prompt.md

## 📊 Visual Output Style (MANDATORY)
Bestätige JEDEN Bericht mit diesem ASCII-Bericht-Format:

\`\`\`text
Bericht erfasst: [PROJEKTNAME]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👷 Wer:     [MONTEUR_NAME]
📍 Ort:      [ETAGE/BEREICH]
🛠️ Arbeit:  [TATIGKEIT_KURZ]
📦 Mat:     [MATERIAL_MENGEN]
⏱️ Zeit:     [STUNDEN]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 Daten wurden ins Büro übertragen.
\`\`\`

## 🔴 Auto-Alert Logic
Wenn der Monteur einen 'Mangel', 'Blocker' oder 'Problem' meldet:
1. Schreibe ⚠️ ACHTUNG: Mangel gemeldet! in den Bericht.
2. Markiere dies im Export-Log als PRIORITÄT 1.
EOF

# 4. Create Utility Scripts (Welcome & Reset)
cat <<EOF > welcome.sh
#!/bin/bash
echo "Moin! 🏗️ Ich bin **NexWorker**, dein digitaler Bauhelfer. Schick mir einen Bericht!"
EOF
chmod +x welcome.sh

cat <<EOF > reset-instance.sh
#!/bin/bash
# NexWorker Reset Script
echo "⚠️ WARNING: This will delete ALL local logs and the database for this client."
read -p "Are you sure? (y/n) " -n 1 -r
echo
if [[ \$REPLY =~ ^[Yy]$ ]]; then
    rm -rf ./memory/*
    rm -f nexworker.db
    echo "✅ Instance reset. Starting fresh."
    sqlite3 nexworker.db "CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY, project TEXT, worker TEXT, activity TEXT, material TEXT, duration REAL, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);"
fi
EOF
chmod +x reset-instance.sh

cat <<EOF > remove-instance.sh
#!/bin/bash
# NexWorker Removal Script
cd ..
CLIENT_DIR="nexworker-\$1"
if [ -d "\$CLIENT_DIR" ]; then
    echo "⚠️ WARNING: Deleting EVERYTHING for client \$1 (Folder: \$CLIENT_DIR)"
    read -p "Confirm total deletion? (y/n) " -n 1 -r
    echo
    if [[ \$REPLY =~ ^[Yy]$ ]]; then
        rm -rf "\$CLIENT_DIR"
        echo "🗑️ Client '\$1' removed permanently."
    fi
else
    echo "❌ Client folder '\$CLIENT_DIR' not found."
fi
EOF
chmod +x remove-instance.sh


# 5. Setup empty SQLite DB for structured logs
echo "🗄️ Initializing Local Matrix..."
sqlite3 nexworker.db "CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY, project TEXT, worker TEXT, activity TEXT, material TEXT, duration REAL, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);"

echo "✅ NexWorker Instance '$CLIENT_NAME' is ready!"
echo "------------------------------------------------------------"
echo "🚀 START COMMAND (Isolated Profile):"
echo "openclaw --profile nexworker-$CLIENT_NAME gateway start --port 19123 --config \$(pwd)/config.yaml"
echo "------------------------------------------------------------"
echo "👉 Add your bot to the group and it will listen as 'The Hidden Professional'."
