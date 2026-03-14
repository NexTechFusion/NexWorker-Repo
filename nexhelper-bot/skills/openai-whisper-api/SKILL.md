---
name: openai-whisper-api
description: Transcribe audio via OpenAI Audio Transcriptions API (Whisper) or OpenRouter.
homepage: https://platform.openai.com/docs/guides/speech-to-text
metadata:
  {
    "openclaw":
      {
        "emoji": "☁️",
        "requires": { "bins": ["curl"], "env": ["OPENAI_API_KEY"] },
        "primaryEnv": "OPENAI_API_KEY",
      },
  }
---

# OpenAI Whisper API (curl)

Transcribe an audio file via OpenAI's `/v1/audio/transcriptions` endpoint or via OpenRouter.

## Quick start

```bash
{baseDir}/scripts/transcribe.sh /path/to/audio.m4a
```

Defaults:

- Model: `whisper-1`
- Output: `<input>.txt`

## OpenRouter Support

Use OpenRouter instead of OpenAI:

```bash
USE_OPENROUTER=1 OPENROUTER_API_KEY=your_key_here {baseDir}/scripts/transcribe.sh /path/to/audio.m4a
```

Or with the flag:

```bash
{baseDir}/scripts/transcribe.sh /path/to/audio.m4a --openrouter
```

OpenRouter uses `openai/whisper-large-v3-turbo` model automatically.

## Useful flags

```bash
{baseDir}/scripts/transcribe.sh /path/to/audio.ogg --model whisper-1 --out /tmp/transcript.txt
{baseDir}/scripts/transcribe.sh /path/to/audio.m4a --language en
{baseDir}/scripts/transcribe.sh /path/to/audio.m4a --prompt "Speaker names: Peter, Daniel"
{baseDir}/scripts/transcribe.sh /path/to/audio.m4a --json --out /tmp/transcript.json
{baseDir}/scripts/transcribe.sh /path/to/audio.m4a --openrouter
```

## API key

Set `OPENAI_API_KEY`, or configure it in `~/.openclaw/openclaw.json`:

```json5
{
  skills: {
    "openai-whisper-api": {
      apiKey: "OPENAI_KEY_HERE",
      openRouterKey: "OPENROUTER_KEY_HERE",  // Optional: for OpenRouter
    },
  },
}
```

For OpenRouter, set `USE_OPENROUTER=1` environment variable or use `--openrouter` flag.
