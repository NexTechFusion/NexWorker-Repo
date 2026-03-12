#!/bin/bash
# OCR Image Script
# Extracts text from images using Tesseract OCR
#
# Usage: ./ocr_image.sh <image-file> [language]

set -e

IMAGE="${1}"
LANG="${2:-deu+eng}"  # German + English by default

if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
    echo "Usage: ./ocr_image.sh <image-file> [language]"
    echo ""
    echo "Languages: deu (German), eng (English), fra (French), etc."
    echo "Default: deu+eng"
    exit 1
fi

# Check if Tesseract is installed
if ! command -v tesseract &> /dev/null; then
    echo "❌ Tesseract OCR not installed"
    echo ""
    echo "Install with:"
    echo "  apt-get install tesseract-ocr tesseract-ocr-deu tesseract-ocr-eng"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 OCR Processing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "File:     ${IMAGE}"
echo "Language: ${LANG}"
echo ""

# Run Tesseract
# -c preserve_interword_spaces=1 for better formatting
# --psm 6 = Assume a single uniform block of text
# --oem 3 = Use both legacy and LSTM OCR engines

tesseract "${IMAGE}" stdout \
    -l "${LANG}" \
    --psm 6 \
    --oem 3 \
    -c preserve_interword_spaces=1 \
    2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ OCR Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
