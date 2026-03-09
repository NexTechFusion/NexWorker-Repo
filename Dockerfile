# NexHelper Docker Image

FROM openclaw/openclaw:latest

LABEL maintainer="NexTech Fusion"
LABEL description="NexHelper - Messenger-native document management for KMU"
LABEL version="2.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
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
    # Email utilities
    sendmail \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /app/skills /app/exports /app/storage/{memory,consent,audit}

# Copy skills
COPY skills/ /app/skills/

# Make scripts executable
RUN find /app/skills -name "*.sh" -exec chmod +x {} \;

# Copy config template
COPY config/config.yaml.template /app/config/config.yaml.template

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# Default environment
ENV NODE_ENV=production \
    TESSDATA_PREFIX=/usr/share/tesseract-ocr/5/tessdata

# Working directory
WORKDIR /app

# Entrypoint
ENTRYPOINT ["openclaw", "gateway", "start", "--config", "/app/config/config.yaml"]