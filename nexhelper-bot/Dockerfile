# NexHelper Docker Image
# Based on Node.js with OpenClaw installed

FROM node:22-bookworm-slim

LABEL maintainer="NexTech Fusion"
LABEL description="NexHelper - Messenger-native document management for KMU"
LABEL version="2.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    python3 \
    # OCR dependencies
    tesseract-ocr \
    tesseract-ocr-deu \
    tesseract-ocr-eng \
    tesseract-ocr-fra \
    # PDF processing
    poppler-utils \
    # JSON processing
    jq \
    # HTTP client
    curl \
    wget \
    # Email utilities
    sendmail \
    # Git (for updates)
    git \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Create app directory
WORKDIR /app

# Create directories
RUN mkdir -p /app/config /app/skills /app/exports /app/storage/{memory,consent,audit} /app/logs

# Copy skills
COPY skills/ /app/skills/

# Fix CRLF line endings, make executable, and symlink to PATH
RUN find /app/skills -type f \( -name "*.sh" -o -name "nexhelper-*" \) -exec sed -i 's/\r$//' {} \; \
 && find /app/skills \( -name "*.sh" -o -name "nexhelper-*" \) -exec chmod +x {} \; \
 && find /app/skills -type f \( -name "nexhelper-*" -o -path "*/scripts/*.sh" \) \
      -exec bash -c 'ln -sf "$1" "/usr/local/bin/$(basename "$1")"' _ {} \; \
 && ln -sf /usr/local/bin/nexhelper-reminder /usr/local/bin/nexhelper-remind 2>/dev/null || true \
 && command -v nexhelper-doc >/dev/null \
 && nexhelper-set-reminder --help >/dev/null 2>&1 || true

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# Default environment
ENV NODE_ENV=production \
    TESSDATA_PREFIX=/usr/share/tesseract-ocr/5/tessdata

# Expose default port
EXPOSE ${PORT:-3000}

# Entrypoint - use docker-compose command override or default
# Config is loaded from /root/.openclaw/openclaw.json by the container's entrypoint script
ENTRYPOINT ["openclaw"]
CMD ["gateway", "run"]