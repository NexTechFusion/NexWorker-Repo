#!/bin/bash
export OPENCLAW_STATE_DIR=/root/.openclaw-nexworker-demogmbh
export OPENROUTER_API_KEY=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
export TELEGRAM_BOT_TOKEN=8606116891:AAEnKrjvQEGzeL47APZCCi2AJIDZSIZmMdY
cd /root/.openclaw/nexworker-demogmbh-bot
exec openclaw gateway run --port 3006 --bind lan
