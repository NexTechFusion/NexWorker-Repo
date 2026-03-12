#!/bin/bash
# OCR PDF Script
# Extracts text from scanned PDFs using Tesseract OCR
#
# Usage: ./ocr_pdf.sh <pdf-file> [language]

set -e

PDF="${1}"
LANG="${2:-deu+eng}"

if [ -z "$PDF" ] || [ ! -f "$PDF" ]; then
    echo "Usage: ./ocr_pdf.sh <pdf-file> [language]"
    exit 1
fi

# Check dependencies
if ! command -v tesseract &> /dev/null; then
    echo "❌ Tesseract OCR not installed"
    echo "  apt-get install tesseract-ocr tesseract-ocr-deu tesseract-ocr-eng"
    exit 1
fi

if ! command -v pdftoppm &> /dev/null; then
    echo "❌ poppler-utils not installed"
    echo "  apt-get install poppler-utils"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PDF OCR Processing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "File:     ${PDF}"
echo "Language: ${LANG}"
echo ""

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# Get PDF info
PDF_PAGES=$(pdfinfo "${PDF}" 2>/dev/null | grep "Pages:" | awk '{print $2}' || echo "1")
echo "Pages:    ${PDF_PAGES}"
echo ""

# Convert PDF to images (300 DPI for good OCR)
echo "📄 Converting PDF to images..."
pdftoppm -png -r 300 "${PDF}" "${TEMP_DIR}/page"

# OCR each page
PAGE_NUM=0
for PAGE in "${TEMP_DIR}"/page-*.png; do
    if [ -f "$PAGE" ]; then
        PAGE_NUM=$((PAGE_NUM + 1))
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📄 Page ${PAGE_NUM} of ${PDF_PAGES}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        tesseract "${PAGE}" stdout \
            -l "${LANG}" \
            --psm 6 \
            --oem 3 \
            -c preserve_interword_spaces=1 \
            2>/dev/null
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ OCR Complete (${PAGE_NUM} pages)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
