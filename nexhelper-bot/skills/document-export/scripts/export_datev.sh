#!/bin/bash
# DATEV Export Script
# Generates DATEV-compatible CSV files for import
#
# Usage: ./export_datev.sh <customer-dir> [date-from] [date-to]
#
# Output: EXTF_Buchungsstapel.csv

set -e

CUSTOMER_DIR="${1:-.}"
DATE_FROM="${2:-$(date -d '30 days ago' +%Y%m%d)}"
DATE_TO="${3:-$(date +%Y%m%d)}"
OUTPUT_DIR="${CUSTOMER_DIR}/exports/datev"

# Load config
source "${CUSTOMER_DIR}/.env" 2>/dev/null || true

# DATEV Config
BERATER_NR="${DATEV_BERATER_NR:-100000}"
MANDANTEN_NR="${DATEV_MANDANTEN_NR:-100}"
SACHKONTENLAENGE="${DATEV_SACHKONTENLAENGE:-4}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 DATEV Export"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Customer:   ${CUSTOMER_NAME:-Unknown}"
echo "Period:     ${DATE_FROM} - ${DATE_TO}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Find documents in memory
MEMORY_DIR="${CUSTOMER_DIR}/storage/memory"
DOCUMENTS=$(find "${MEMORY_DIR}" -name "*.json" -newermt "${DATE_FROM}" ! -newermt "${DATE_TO} 23:59:59" 2>/dev/null | head -100)

if [ -z "$DOCUMENTS" ]; then
    echo "⚠️  No documents found in period"
    exit 0
fi

DOC_COUNT=$(echo "$DOCUMENTS" | wc -l)
echo "Found: ${DOC_COUNT} documents"
echo ""

# Generate DATEV CSV Header
OUTPUT_FILE="${OUTPUT_DIR}/EXTF_Buchungsstapel_$(date +%Y%m%d_%H%M%S).csv"

cat > "$OUTPUT_FILE" << EOF
EXTF;510;DATEV Buchungsstapel;${BERATER_NR};${MANDANTEN_NR};${DATE_FROM};${DATE_TO};;;${SACHKONTENLAENGE};0
EOF

# Process each document
BOOKING_COUNT=0
TOTAL_AMOUNT=0

echo "$DOCUMENTS" | while read -r DOC; do
    # Extract document data
    if [ -f "$DOC" ]; then
        DOC_DATA=$(cat "$DOC" 2>/dev/null || echo "{}")
        
        # Parse JSON (requires jq)
        DOC_DATE=$(echo "$DOC_DATA" | jq -r '.date // empty' 2>/dev/null || echo "")
        DOC_AMOUNT=$(echo "$DOC_DATA" | jq -r '.amount // 0' 2>/dev/null || echo "0")
        DOC_VENDOR=$(echo "$DOC_DATA" | jq -r '.vendor // "Unbekannt"' 2>/dev/null | cut -c1-30)
        DOC_TYPE=$(echo "$DOC_DATA" | jq -r '.type // "Rechnung"' 2>/dev/null || echo "Rechnung")
        DOC_INVOICE=$(echo "$DOC_DATA" | jq -r '.invoiceNumber // empty' 2>/dev/null || echo "")
        
        if [ -n "$DOC_DATE" ] && [ "$DOC_AMOUNT" != "0" ]; then
            # Format date for DATEV (DD.MM.YYYY)
            DOC_DATE_FORMATTED=$(date -d "$DOC_DATE" +%d.%m.%Y 2>/dev/null || echo "$DOC_DATE")
            
            # Determine account (simplified)
            case "$DOC_TYPE" in
                *Rechnung*|*Invoice*)
                    KONTO=1400  # Verbindlichkeiten
                    GEGENKONTO=6000  # Betriebsausgaben
                    ;;
                *Gutschrift*|*Credit*)
                    KONTO=1200  # Forderungen
                    GEGENKONTO=8400  # Erlöse
                    ;;
                *)
                    KONTO=1400
                    GEGENKONTO=6000
                    ;;
            esac
            
            # Generate booking line
            # Format: Umsatz (ohne Vorzeichen);Soll/Haben;Konto;Gegenkonto;Belegdatum;Belegfeld 1;Belegfeld 2;Buchungstext
            echo "${DOC_AMOUNT};S;${KONTO};${GEGENKONTO};${DOC_DATE_FORMATTED};${DOC_INVOICE};${DOC_VENDOR};${DOC_TYPE}" >> "$OUTPUT_FILE"
            
            BOOKING_COUNT=$((BOOKING_COUNT + 1))
            TOTAL_AMOUNT=$(echo "$TOTAL_AMOUNT + $DOC_AMOUNT" | bc 2>/dev/null || echo "$TOTAL_AMOUNT")
        fi
    fi
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DATEV Export Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📄 Output File:"
echo "   ${OUTPUT_FILE}"
echo ""
echo "📊 Statistics:"
echo "   Bookings:     ${BOOKING_COUNT}"
echo "   Total Amount: €${TOTAL_AMOUNT}"
echo ""
echo "📥 Import in DATEV:"
echo "   1. Open DATEV Unternehmen online"
echo "   2. Import → Buchungsstapel"
echo "   3. Select file: ${OUTPUT_FILE}"
echo ""

# Audit log
AUDIT_LOG="${CUSTOMER_DIR}/storage/audit/export.log"
echo "$(date -Iseconds) | DATEV export | ${BOOKING_COUNT} bookings | ${OUTPUT_FILE}" >> "$AUDIT_LOG"
