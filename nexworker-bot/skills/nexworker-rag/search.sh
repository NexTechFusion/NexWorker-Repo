#!/bin/bash
# NexWorker RAG - Such-Tool für Agent
# Usage: nexworker-rag-search "frage"

QUERY="${1:-}"
TOP_K="${2:-3}"

if [ -z "$QUERY" ]; then
    echo "Usage: nexworker-rag-search \"frage\" [top-k]"
    exit 1
fi

cd /root/.openclaw/nexworker-demogmbh-bot
python3 nexworker_rag.py search --query "$QUERY" --top-k $TOP_K 2>&1
