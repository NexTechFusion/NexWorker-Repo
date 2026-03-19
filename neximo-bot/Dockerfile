# NexImo Bot - Messenger-native apartment hunter for Germany
# Based on OpenClaw

FROM node:22-bookworm-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    bc \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install camoufox for web scraping (anti-detect browser)
RUN curl -fsSL https://cdn.jsdelivr.net/gh/nicepkg/camoufox-js/scripts/install.sh | bash

# Install OpenClaw
RUN npm install -g openclaw@latest

# Create app directories
WORKDIR /app
RUN mkdir -p /app/skills /app/config /data

# Copy skills
COPY skills/ /app/sills/
RUN find /app/skills -type f -name "*.sh" -exec chmod +x {} \;
RUN find /app/skills -type f -name "neximo-*" -exec chmod +x {} \;

# Copy config templates
COPY config/ /app/config/

# Entry point script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment
ENV NXIMO_STORAGE_DIR=/data/storage \
    NXIMO_SCAN_INTERVAL=300 \
    NODE_ENV=production

# Expose gateway port
EXPOSE 19123

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:19123/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["openclaw", "gateway", "start", "--daemon"]
