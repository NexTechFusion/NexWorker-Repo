# Skill: document-ocr

OCR (Optical Character Recognition) for scanned documents.

## Description

This skill enables OpenClaw to extract text from images and scanned PDFs using Tesseract OCR, supporting German and English languages.

## Features

- ✅ Extract text from images (JPG, PNG, etc.)
- ✅ Extract text from scanned PDFs
- ✅ Multi-language support (DE/EN)
- ✅ Preprocessing for better accuracy
- ✅ Structured output

## Requirements

```bash
# Install Tesseract OCR
apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-deu \
    tesseract-ocr-eng \
    poppler-utils \
    imagemagick
```

## Actions

### 1. Extract Text from Image

```
User: [sends photo of invoice]
Bot:  "📄 Text extrahiert:
      
      Rechnung Nr. 12345
      Firma: Müller GmbH
      Datum: 09.03.2026
      Betrag: €450,00
      
      Soll ich das Dokument speichern?"
```

### 2. Extract Text from Scanned PDF

```
User: [sends scanned PDF]
Bot:  "📄 PDF analysiert...
      
      Gefundener Text:
      [extrahierter Text]"
```

### 3. Batch OCR

```
User: "Extrahiere Text aus allen gescannten Docs von heute"
Bot:  "🔄 Verarbeite 5 Dokumente..."
```

## Commands

| Command | Description |
|---------|-------------|
| `/ocr [image]` | Extract text from image |
| `/ocr pdf [file]` | Extract text from PDF |
| `/ocr batch [date]` | Process multiple documents |

## Scripts

### `ocr_image.sh`

```bash
#!/bin/bash
# OCR for single image
# Usage: ./ocr_image.sh <image-file> [language]

IMAGE="${1}"
LANG="${2:-deu}"

tesseract "${IMAGE}" stdout -l "${LANG}"
```

### `ocr_pdf.sh`

```bash
#!/bin/bash
# OCR for PDF
# Usage: ./ocr_pdf.sh <pdf-file> [language]

PDF="${1}"
LANG="${2:-deu}"

# Convert PDF to images
pdftoppm -png "${PDF}" /tmp/pdf_page

# OCR each page
for PAGE in /tmp/pdf_page-*.png; do
    tesseract "${PAGE}" stdout -l "${LANG}"
    echo "---PAGE BREAK---"
done

# Cleanup
rm -f /tmp/pdf_page-*.png
```

## Integration with Document Processing

```yaml
workflow:
  1. User sends image/PDF
  2. Check consent
  3. Run OCR
  4. Parse extracted text
  5. Identify document type (invoice, receipt, etc.)
  6. Extract key data (date, amount, vendor)
  7. Store in memory
  8. Confirm to user
```

## Supported Formats

| Format | Support | Notes |
|--------|---------|-------|
| JPG | ✅ | Primary format |
| PNG | ✅ | Primary format |
| PDF (scanned) | ✅ | Converted to images first |
| TIFF | ✅ | Via ImageMagick |
| BMP | ✅ | Via ImageMagick |
| GIF | ⚠️ | First frame only |

## Languages

| Language | Code | Tesseract Package |
|----------|------|-------------------|
| German | `deu` | `tesseract-ocr-deu` |
| English | `eng` | `tesseract-ocr-eng` |
| French | `fra` | `tesseract-ocr-fra` |
| Italian | `ita` | `tesseract-ocr-ita` |
| Spanish | `spa` | `tesseract-ocr-spa` |

## Quality Tips

For best OCR results:

1. **Image quality**: Min. 300 DPI
2. **Contrast**: High contrast black/white
3. **Alignment**: Text should be horizontal
4. **Lighting**: Even lighting, no shadows
5. **Focus**: Sharp image, no blur

## Error Handling

```bash
# Check if Tesseract is installed
if ! command -v tesseract &> /dev/null; then
    echo "❌ Tesseract not installed"
    echo "Run: apt-get install tesseract-ocr tesseract-ocr-deu"
    exit 1
fi

# Check language pack
if ! tesseract --list-langs | grep -q "deu"; then
    echo "⚠️ German language pack not installed"
    echo "Run: apt-get install tesseract-ocr-deu"
fi
```

## Example Output

```
📄 OCR Result:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RECHNUNG Nr. 2026/03/1234

Kunde: NexTech Fusion GmbH
       Musterstraße 123
       12345 Berlin

Datum: 09.03.2026

Position                    Menge    Preis
─────────────────────────────────────────
Beratung                   4 Std    €320,00
Software-Setup             1        €150,00
─────────────────────────────────────────
Summe netto:                        €470,00
MwSt. 19%:                           €89,30
─────────────────────────────────────────
Gesamtbetrag:                       €559,30

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
