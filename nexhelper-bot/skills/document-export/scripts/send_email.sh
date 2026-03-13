#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/nexhelper-core.sh"

TO="${1}"
SUBJECT="${2}"
BODY="${3}"
ATTACHMENT="${4:-}"

# Load environment
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"
FROM="${SMTP_FROM:-${SMTP_USER}}"
SMTP_MAX_ATTACHMENT_MB="${SMTP_MAX_ATTACHMENT_MB:-10}"
EMAIL_ALLOWED_DOMAINS="${EMAIL_ALLOWED_DOMAINS:-}"
SMTP_REQUIRE_TLS="${SMTP_REQUIRE_TLS:-true}"
SMTP_AUTH_REQUIRED="${SMTP_AUTH_REQUIRED:-true}"
OP_ID="email_$(date +%s)_$RANDOM"

if [ -z "$TO" ] || [ -z "$SUBJECT" ]; then
    echo "Usage: ./send_email.sh <to> <subject> <body> [attachment]"
    exit 1
fi

if [ "$SMTP_AUTH_REQUIRED" = "true" ]; then
    if [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASS" ]; then
        echo "❌ SMTP credentials not configured"
        echo "   Set SMTP_HOST, SMTP_USER, SMTP_PASS"
        exit 1
    fi
fi

if ! echo "$TO" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
    echo "❌ Invalid recipient email address"
    exit 1
fi

if [ -n "$EMAIL_ALLOWED_DOMAINS" ]; then
    TO_DOMAIN="${TO##*@}"
    DOMAIN_OK="false"
    IFS=',' read -ra ALLOWED <<< "$EMAIL_ALLOWED_DOMAINS"
    for D in "${ALLOWED[@]}"; do
      CLEAN="$(echo "$D" | xargs)"
      if [ "$TO_DOMAIN" = "$CLEAN" ]; then
        DOMAIN_OK="true"
        break
      fi
    done
    if [ "$DOMAIN_OK" != "true" ]; then
      echo "❌ Recipient domain not allowed: $TO_DOMAIN"
      exit 1
    fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 Sending Email"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "From:    ${FROM}"
echo "To:      ${TO}"
echo "Subject: ${SUBJECT}"
if [ -n "$ATTACHMENT" ] && [ -f "$ATTACHMENT" ]; then
    ATTACH_REAL="$(realpath -m "$ATTACHMENT")"
    STORAGE_REAL="$(realpath -m "${STORAGE_DIR:-/root/.openclaw/workspace/storage}")"
    EXPORTS_REAL="$(realpath -m "${CUSTOMER_DIR:-.}/exports")"
    case "$ATTACH_REAL" in
      "$STORAGE_REAL"/*|"$EXPORTS_REAL"/*) ;;
      *)
        echo "❌ Attachment path outside tenant scope"
        exit 1
        ;;
    esac
    SIZE_BYTES=$(wc -c < "$ATTACHMENT")
    MAX_BYTES=$((SMTP_MAX_ATTACHMENT_MB * 1024 * 1024))
    if [ "$SIZE_BYTES" -gt "$MAX_BYTES" ]; then
      echo "❌ Attachment exceeds ${SMTP_MAX_ATTACHMENT_MB}MB limit"
      exit 1
    fi
    echo "Attach:  ${ATTACHMENT}"
fi
echo ""

# Check for sendmail or use curl
if command -v sendmail &> /dev/null; then
    # Use sendmail
    if [ -n "$ATTACHMENT" ] && [ -f "$ATTACHMENT" ]; then
        # With attachment (MIME)
        BOUNDARY="boundary_$(date +%s)"
        (
            echo "From: ${FROM}"
            echo "To: ${TO}"
            echo "Subject: ${SUBJECT}"
            echo "MIME-Version: 1.0"
            echo "Content-Type: multipart/mixed; boundary=\"${BOUNDARY}\""
            echo ""
            echo "--${BOUNDARY}"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo ""
            echo "${BODY}"
            echo ""
            echo "--${BOUNDARY}"
            echo "Content-Type: application/octet-stream"
            echo "Content-Transfer-Encoding: base64"
            echo "Content-Disposition: attachment; filename=\"$(basename "${ATTACHMENT}")\""
            echo ""
            base64 "${ATTACHMENT}"
            echo ""
            echo "--${BOUNDARY}--"
        ) | sendmail -t
    else
        # Plain text
        (
            echo "From: ${FROM}"
            echo "To: ${TO}"
            echo "Subject: ${SUBJECT}"
            echo ""
            echo "${BODY}"
        ) | sendmail -t
    fi
elif command -v curl &> /dev/null; then
    # Use curl with SMTP
    if [ -n "$ATTACHMENT" ] && [ -f "$ATTACHMENT" ]; then
        # Create temp file with full email
        TEMP_EMAIL=$(mktemp)
        BOUNDARY="boundary_$(date +%s)"
        
        (
            echo "From: ${FROM}"
            echo "To: ${TO}"
            echo "Subject: ${SUBJECT}"
            echo "MIME-Version: 1.0"
            echo "Content-Type: multipart/mixed; boundary=\"${BOUNDARY}\""
            echo ""
            echo "--${BOUNDARY}"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo ""
            echo "${BODY}"
            echo ""
            echo "--${BOUNDARY}"
            echo "Content-Type: application/octet-stream"
            echo "Content-Transfer-Encoding: base64"
            echo "Content-Disposition: attachment; filename=\"$(basename "${ATTACHMENT}")\""
            echo ""
            base64 "${ATTACHMENT}"
            echo ""
            echo "--${BOUNDARY}--"
        ) > "$TEMP_EMAIL"
        
        # Send via curl
        CURL_ARGS=( -s --url "smtp://${SMTP_HOST}:${SMTP_PORT}" --mail-from "${FROM}" --mail-rcpt "${TO}" --upload-file "$TEMP_EMAIL" )
        if [ "$SMTP_AUTH_REQUIRED" = "true" ]; then
            CURL_ARGS+=( --user "${SMTP_USER}:${SMTP_PASS}" )
        fi
        if [ "$SMTP_REQUIRE_TLS" = "true" ]; then
            CURL_ARGS+=( --ssl-reqd )
        fi
        curl "${CURL_ARGS[@]}"
        
        rm -f "$TEMP_EMAIL"
    else
        # Plain text via curl
        TEMP_EMAIL=$(mktemp)
        (
            echo "From: ${FROM}"
            echo "To: ${TO}"
            echo "Subject: ${SUBJECT}"
            echo ""
            echo "${BODY}"
        ) > "$TEMP_EMAIL"
        
        CURL_ARGS=( -s --url "smtp://${SMTP_HOST}:${SMTP_PORT}" --mail-from "${FROM}" --mail-rcpt "${TO}" --upload-file "$TEMP_EMAIL" )
        if [ "$SMTP_AUTH_REQUIRED" = "true" ]; then
            CURL_ARGS+=( --user "${SMTP_USER}:${SMTP_PASS}" )
        fi
        if [ "$SMTP_REQUIRE_TLS" = "true" ]; then
            CURL_ARGS+=( --ssl-reqd )
        fi
        curl "${CURL_ARGS[@]}"
        
        rm -f "$TEMP_EMAIL"
    fi
else
    echo "❌ No email client available (sendmail or curl required)"
    exit 1
fi

mkdir -p "$NX_AUDIT_DIR"
jq -c -n \
  --arg timestamp "$(date -Iseconds)" \
  --arg opId "$OP_ID" \
  --arg to "$TO" \
  --arg subject "$SUBJECT" \
  --arg attachment "${ATTACHMENT:-}" \
  '{timestamp:$timestamp,event:"email_send",opId:$opId,to:$to,subject:$subject,attachment:$attachment,status:"sent"}' >> "$NX_AUDIT_DIR/email.ndjson"

echo "✅ Email sent successfully!"
echo ""
