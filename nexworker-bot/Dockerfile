# NexWorker Docker Image
# Based on Node.js with OpenClaw installed

FROM node:22-bookworm-slim

LABEL maintainer="NexTech Fusion"
LABEL description="NexWorker - Baustellen-Assistent mit RAG Wissensbasis"
LABEL version="1.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    tesseract-ocr \
    tesseract-ocr-deu \
    tesseract-ocr-eng \
    poppler-utils \
    jq \
    curl \
    wget \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Fix execute permissions on OpenClaw's bundled skill scripts
RUN find /usr/local/lib/node_modules/openclaw -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Install Python dependencies for RAG
RUN pip3 install --no-cache-dir lancedb sentence-transformers pypdf pyarrow --break-system-packages

# Create app directory
WORKDIR /app

# Create directories
RUN mkdir -p /app/config /app/skills /app/storage/{wissensbasis,lancedb,memory} /app/logs /root/.openclaw

# Copy skills
COPY skills/ /app/skills/

# Copy RAG script
COPY nexworker_rag.py /app/

# Copy config
COPY config/openclaw.json /root/.openclaw/openclaw.json

# Fix line endings and permissions
RUN find /app -type f \( -name "*.sh" -o -name "nexworker-*" \) -exec sed -i 's/\r$//' {} \; \
 && find /app -type f \( -name "*.sh" -o -name "nexworker-*" \) -exec chmod +x {} \; \
 && chmod +x /app/nexworker_rag.py

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# Default environment
ENV NODE_ENV=production \
    PYTHONUNBUFFERED=1

# Expose default port
EXPOSE ${PORT:-3000}

# Entrypoint
ENTRYPOINT ["openclaw"]
CMD ["gateway", "run"]