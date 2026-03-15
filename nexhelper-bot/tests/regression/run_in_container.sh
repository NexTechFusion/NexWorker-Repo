#!/bin/bash
# Wrapper to strip CRLF from mounted scripts and run the test suite
set -e
find /nexhelper-bot/skills -type f \( -name "*.sh" -o -name "nexhelper-*" \) -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
sed -i 's/\r$//' /nexhelper-bot/tests/regression/full_live_suite.sh 2>/dev/null || true
exec bash /nexhelper-bot/tests/regression/full_live_suite.sh "$@"
