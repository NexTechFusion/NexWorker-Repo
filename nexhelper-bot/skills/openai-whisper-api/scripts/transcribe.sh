#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  transcribe.sh <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt "hint"] [--json]

Environment:
  USE_OPENROUTER=1       Route via OpenRouter instead of OpenAI
  OPENROUTER_API_KEY     API key for OpenRouter (required if USE_OPENROUTER=1)
  OPENAI_API_KEY         API key for OpenAI (fallback or primary)
EOF
  exit 2
}

if [[ "${1:-}" == "" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

in="${1:-}"
shift || true

model="whisper-1"
out=""
language=""
prompt=""
response_format="text"

# OpenRouter support
use_openrouter="${USE_OPENROUTER:-0}"
api_base="https://api.openai.com"
api_key="${OPENAI_API_KEY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      model="${2:-}"
      shift 2
      ;;
    --out)
      out="${2:-}"
      shift 2
      ;;
    --language)
      language="${2:-}"
      shift 2
      ;;
    --prompt)
      prompt="${2:-}"
      shift 2
      ;;
    --json)
      response_format="json"
      shift 1
      ;;
    --openrouter)
      use_openrouter=1
      shift 1
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      ;;
  esac
done

# Configure for OpenRouter if enabled
if [[ "$use_openrouter" == "1" ]]; then
  api_base="https://openrouter.ai/api/v1"
  api_key="${OPENROUTER_API_KEY:-}"
  
  # Map model names for OpenRouter
  case "$model" in
    whisper-1)
      model="openai/whisper-large-v3-turbo"
      ;;
  esac
  
  if [[ "$api_key" == "" ]]; then
    echo "Missing OPENROUTER_API_KEY (required when USE_OPENROUTER=1)" >&2
    exit 1
  fi
fi

if [[ ! -f "$in" ]]; then
  echo "File not found: $in" >&2
  exit 1
fi

if [[ "$api_key" == "" ]]; then
  echo "Missing API key: set OPENAI_API_KEY or OPENROUTER_API_KEY" >&2
  exit 1
fi

if [[ "$out" == "" ]]; then
  base="${in%.*}"
  if [[ "$response_format" == "json" ]]; then
    out="${base}.json"
  else
    out="${base}.txt"
  fi
fi

mkdir -p "$(dirname "$out")"

curl -sS "${api_base}/v1/audio/transcriptions" \
  -H "Authorization: Bearer $api_key" \
  -H "Accept: application/json" \
  -F "file=@${in}" \
  -F "model=${model}" \
  -F "response_format=${response_format}" \
  ${language:+-F "language=${language}"} \
  ${prompt:+-F "prompt=${prompt}"} \
  >"$out"

echo "$out"
