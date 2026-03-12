#!/bin/bash
# Email Sender Script
# Sends documents as email attachments via SMTP
#
# Usage: ./send_email.sh <to> <subject> <body> [attachment]

set -e

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

if [ -z "$TO" ] || [ -z "$SUBJECT" ]; then
    echo "Usage: ./send_email.sh <to> <subject> <body> [attachment]"
    exit 1
fi

if [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASS" ]; then
    echo "❌ SMTP credentials not configured"
    echo "   Set SMTP_HOST, SMTP_USER, SMTP_PASS"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 Sending Email"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "From:    ${FROM}"
echo "To:      ${TO}"
echo "Subject: ${SUBJECT}"
if [ -n "$ATTACHMENT" ] && [ -f "$ATTACHMENT" ]; then
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
        curl -s --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
             --mail-from "${FROM}" \
             --mail-rcpt "${TO}" \
             --upload-file "$TEMP_EMAIL" \
             --user "${SMTP_USER}:${SMTP_PASS}" \
             --ssl-reqd
        
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
        
        curl -s --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
             --mail-from "${FROM}" \
             --mail-rcpt "${TO}" \
             --upload-file "$TEMP_EMAIL" \
             --user "${SMTP_USER}:${SMTP_PASS}" \
             --ssl-reqd
        
        rm -f "$TEMP_EMAIL"
    fi
else
    echo "❌ No email client available (sendmail or curl required)"
    exit 1
fi

echo "✅ Email sent successfully!"
echo ""
