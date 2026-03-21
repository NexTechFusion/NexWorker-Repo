#!/bin/bash
# nexworker-voice - Sprach-als-Text Transkription mit whisper.cpp
# Usage: nexworker-voice transcribe <audio_file>

set -e

COMMAND="${1:-}"
AUDIO_FILE="${2:-}"

# Pfade
MODEL_PATH="${WHISPER_CPP_MODEL:-/models/ggml-base.bin}"

usage() {
    echo "nexworker-voice - Sprach-als-Text Transkription"
    echo ""
    echo "Usage:"
    echo "  nexworker-voice transcribe <audio_file>"
    echo ""
    echo "Environment:"
    echo "  WHISPER_CPP_MODEL  Pfad zum whisper Model (default: /models/ggml-base.bin)"
}

transcribe() {
    if [ -z "$AUDIO_FILE" ]; then
        echo "Error: Keine Audio-Datei angegeben"
        usage
        exit 1
    fi
    
    if [ ! -f "$AUDIO_FILE" ]; then
        echo "Error: Datei nicht gefunden: $AUDIO_FILE"
        exit 1
    fi
    
    # Prüfe ob whisper-cli existiert
    if ! command -v whisper-cli &> /dev/null; then
        echo "Error: whisper-cli nicht gefunden"
        exit 1
    fi
    
    # Transkribiere
    echo "Transkribiere: $AUDIO_FILE"
    whisper-cli \
        -m "$MODEL_PATH" \
        -f "$AUDIO_FILE" \
        -otxt \
        --no-timestamps
}

case "$COMMAND" in
    transcribe)
        transcribe
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "nexworker-voice: Unbekannter Befehl '$COMMAND'"
        usage
        exit 1
        ;;
esac
