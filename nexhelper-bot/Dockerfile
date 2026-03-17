# NexHelper Docker Image
# Based on Node.js with OpenClaw installed

FROM node:22-bookworm-slim

LABEL maintainer="NexTech Fusion"
LABEL description="NexHelper - Messenger-native document management for KMU"
LABEL version="2.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    python3 \
    tesseract-ocr \
    tesseract-ocr-deu \
    tesseract-ocr-eng \
    tesseract-ocr-fra \
    poppler-utils \
    jq \
    curl \
    wget \
    sendmail \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Fix execute permissions on OpenClaw's bundled skill scripts — npm strips +x bits.
RUN find /usr/local/lib/node_modules/openclaw -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Build and install whisper-cli (whisper.cpp) for local audio transcription.
# Static link so the binary has no runtime .so dependency — no library install needed.
# WHISPER_CPP_MODEL env var in the container points at the mounted model file.
RUN git clone --depth=1 https://github.com/ggerganov/whisper.cpp.git /tmp/whisper.cpp \
    && cmake -S /tmp/whisper.cpp -B /tmp/whisper.cpp/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_METAL=OFF \
        -DWHISPER_BUILD_TESTS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
    && cmake --build /tmp/whisper.cpp/build --config Release --target whisper-cli -j$(nproc) \
    && cp /tmp/whisper.cpp/build/bin/whisper-cli /usr/local/bin/ \
    && rm -rf /tmp/whisper.cpp

# Create app directory
WORKDIR /app

# Create directories
RUN mkdir -p /app/config /app/skills /app/exports /app/storage/{memory,consent,audit} /app/logs /root/.openclaw

# Copy skills
COPY skills/ /app/skills/

# Copy config
COPY config/openclaw.json /root/.openclaw/openclaw.json

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