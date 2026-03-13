#!/bin/bash

set -euo pipefail

CUSTOMER_DIR="${1:-.}"
DATE_FROM="${2:-$(date -d '30 days ago' +%Y%m%d)}"
DATE_TO="${3:-$(date +%Y%m%d)}"
OUTPUT_DIR="${CUSTOMER_DIR}/exports/datev"
DATE_FROM_ISO="${DATE_FROM:0:4}-${DATE_FROM:4:2}-${DATE_FROM:6:2}"
DATE_TO_ISO="${DATE_TO:0:4}-${DATE_TO:4:2}-${DATE_TO:6:2}"
DOCS_DIR="${CUSTOMER_DIR}/storage/canonical/documents"
AUDIT_DIR="${CUSTOMER_DIR}/storage/audit"

source "${CUSTOMER_DIR}/.env" 2>/dev/null || true

BERATER_NR="${DATEV_BERATER_NR:-100000}"
MANDANTEN_NR="${DATEV_MANDANTEN_NR:-100}"
SACHKONTENLAENGE="${DATEV_SACHKONTENLAENGE:-4}"
OP_ID="export_$(date +%s)_$RANDOM"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 DATEV Export"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Customer:   ${CUSTOMER_NAME:-Unknown}"
echo "Period:     ${DATE_FROM} - ${DATE_TO}"
echo ""

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${AUDIT_DIR}"

if [ ! -d "${DOCS_DIR}" ]; then
  echo "⚠️  Canonical document store not found: ${DOCS_DIR}"
  exit 0
fi

OUTPUT_FILE="${OUTPUT_DIR}/EXTF_Buchungsstapel_$(date +%Y%m%d_%H%M%S).csv"
ERROR_FILE="${OUTPUT_DIR}/EXTF_Buchungsstapel_errors_$(date +%Y%m%d_%H%M%S).json"

cat > "$OUTPUT_FILE" << EOF
EXTF;510;DATEV Buchungsstapel;${BERATER_NR};${MANDANTEN_NR};${DATE_FROM};${DATE_TO};;;${SACHKONTENLAENGE};0
EOF

BOOKING_COUNT=0
TOTAL_AMOUNT=0
VALIDATION_ERRORS="[]"
DOC_COUNT=0

for DOC in "${DOCS_DIR}"/*.json; do
  [ -f "$DOC" ] || continue
  DOC_COUNT=$((DOC_COUNT + 1))
  DOC_DATA=$(cat "$DOC" 2>/dev/null || echo "{}")

  STATUS=$(echo "$DOC_DATA" | jq -r '.status // "active"')
  DOC_DATE=$(echo "$DOC_DATA" | jq -r '.date // ""')
  DOC_AMOUNT=$(echo "$DOC_DATA" | jq -r '.amount // 0')
  DOC_SUPPLIER=$(echo "$DOC_DATA" | jq -r '.supplier // ""' | cut -c1-30)
  DOC_TYPE=$(echo "$DOC_DATA" | jq -r '.type // ""')
  DOC_NUMBER=$(echo "$DOC_DATA" | jq -r '.number // ""')
  DOC_ID=$(echo "$DOC_DATA" | jq -r '.id // ""')

  if [ "$STATUS" != "active" ]; then
    continue
  fi
  if [ "$DOC_TYPE" != "rechnung" ] && [ "$DOC_TYPE" != "gutschrift" ]; then
    continue
  fi
  if [ -z "$DOC_DATE" ] || [ "$DOC_DATE" \< "$DATE_FROM_ISO" ] || [ "$DOC_DATE" \> "$DATE_TO_ISO" ]; then
    continue
  fi

  ERRORS="[]"
  if [ -z "$DOC_NUMBER" ]; then
    ERRORS=$(echo "$ERRORS" | jq -c '. + ["missing_number"]')
  fi
  if [ -z "$DOC_SUPPLIER" ]; then
    ERRORS=$(echo "$ERRORS" | jq -c '. + ["missing_supplier"]')
  fi
  if [ "$DOC_AMOUNT" = "0" ] || [ "$DOC_AMOUNT" = "0.00" ]; then
    ERRORS=$(echo "$ERRORS" | jq -c '. + ["missing_or_zero_amount"]')
  fi

  if [ "$(echo "$ERRORS" | jq 'length')" -gt 0 ]; then
    VALIDATION_ERRORS=$(echo "$VALIDATION_ERRORS" | jq -c --arg id "$DOC_ID" --arg number "$DOC_NUMBER" --argjson errors "$ERRORS" '. + [{id:$id,number:$number,errors:$errors}]')
    continue
  fi

  DOC_DATE_FORMATTED=$(date -d "$DOC_DATE" +%d.%m.%Y 2>/dev/null || echo "$DOC_DATE")
  case "$DOC_TYPE" in
    rechnung)
      KONTO=1400
      GEGENKONTO=6000
      ;;
    gutschrift)
      KONTO=1200
      GEGENKONTO=8400
      ;;
    *)
      KONTO=1400
      GEGENKONTO=6000
      ;;
  esac

  printf "%s;S;%s;%s;%s;%s;%s;%s\n" "$DOC_AMOUNT" "$KONTO" "$GEGENKONTO" "$DOC_DATE_FORMATTED" "$DOC_NUMBER" "$DOC_SUPPLIER" "$DOC_TYPE" >> "$OUTPUT_FILE"
  BOOKING_COUNT=$((BOOKING_COUNT + 1))
  TOTAL_AMOUNT=$(LC_ALL=C awk -v t="$TOTAL_AMOUNT" -v a="$DOC_AMOUNT" 'BEGIN {printf "%.2f", t+a}')
done

printf "%s\n" "$VALIDATION_ERRORS" > "$ERROR_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DATEV Export Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📄 Output File:"
echo "   ${OUTPUT_FILE}"
echo ""
echo "📊 Statistics:"
echo "   Candidate Docs: ${DOC_COUNT}"
echo "   Bookings:     ${BOOKING_COUNT}"
echo "   Total Amount: €${TOTAL_AMOUNT}"
echo "   Validation:   $(echo "$VALIDATION_ERRORS" | jq 'length') error(s)"
echo ""

jq -c -n \
  --arg timestamp "$(date -Iseconds)" \
  --arg opId "$OP_ID" \
  --arg type "DATEV" \
  --arg output "$OUTPUT_FILE" \
  --arg errors "$ERROR_FILE" \
  --argjson bookings "$BOOKING_COUNT" \
  --argjson total "$TOTAL_AMOUNT" \
  --argjson validationErrorCount "$(echo "$VALIDATION_ERRORS" | jq 'length')" \
  '{timestamp:$timestamp,opId:$opId,event:"export",format:$type,output:$output,errorReport:$errors,bookings:$bookings,total:$total,validationErrorCount:$validationErrorCount}' >> "${AUDIT_DIR}/export.ndjson"
