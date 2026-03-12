# NexHelper Feature Flows

**Complete workflow documentation for all NexHelper features**

---

## Overview

NexHelper is a messenger-native document assistant for German KMU. This document describes all feature flows and how the bot handles each scenario.

---

## Feature Matrix

| Feature | Trigger | Tools Used | Output |
|---------|---------|------------|--------|
| Document Receipt | Image/PDF sent | `image`, `pdf`, `memory` | Stored + Confirmed |
| Document Search | Text query | `memory_search`, `memory_get` | Results list |
| OCR Extraction | Image/PDF | `exec` (ocr scripts) | Extracted text |
| Reminders | Natural language | `cron`, `memory` | Scheduled notification |
| Export (Standard) | `/export` | `exec`, `write` | Excel/PDF/CSV file |
| Export (DATEV) | `/export datev` | `exec`, `write` | DATEV CSV (optional) |
| Email Send | `/email` | `exec` (sendmail) | Sent email |
| Consent | `/start`, `/widerruf` | `memory` | Consent record |

---

## Flow 1: Document Receipt & Processing

### Trigger
User sends an image or PDF via Telegram/WhatsApp

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. USER SENDS DOCUMENT                                      │
│     [Image: invoice_photo.jpg]                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. CONSENT CHECK                                            │
│     Has user consented?                                      │
│     ├─ YES → Continue                                        │
│     └─ NO  → Ask for consent, wait for approval              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. DOCUMENT ANALYSIS                                        │
│     a) Detect type: image or PDF                             │
│     b) Call appropriate tool:                                │
│        - Image → `image` tool (vision model)                 │
│        - PDF  → `pdf` tool (native PDF analysis)             │
│     c) Extract:                                              │
│        - Document type (Rechnung, Angebot, Lieferschein)     │
│        - Date                                                │
│        - Amount                                              │
│        - Vendor/Supplier                                     │
│        - Invoice number                                      │
│        - Line items (if visible)                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. CATEGORIZATION                                           │
│     Auto-categorize based on content:                        │
│     - Rechnung (Invoice)                                     │
│     - Angebot (Quote)                                        │
│     - Lieferschein (Delivery note)                           │
│     - Gutschrift (Credit note)                               │
│     - Quittung (Receipt)                                     │
│     - Sonstiges (Other)                                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  5. STORAGE                                                  │
│     Write to memory:                                         │
│     storage/memory/YYYY-MM-DD.md                             │
│                                                              │
│     Structure:                                               │
│     ```                                                      │
│     ## [TIME] Dokument empfangen                             │
│     - Typ: Rechnung                                          │
│     - Nr: RE-2026-03-123                                     │
│     - Von: Müller GmbH                                       │
│     - Betrag: €450,00                                        │
│     - Datum: 09.03.2026                                      │
│     - Kategorie: Bürobedarf                                  │
│     - Datei: [stored reference]                              │
│     ```                                                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  6. CONFIRMATION                                             │
│     Send user confirmation:                                  │
│                                                              │
│     ✅ Dokument erfasst                                      │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│     📄 Typ:      Rechnung                                    │
│     📋 Nr:       RE-2026-03-123                              │
│     🏢 Von:      Müller GmbH                                 │
│     💰 Betrag:   €450,00                                     │
│     📅 Datum:    09.03.2026                                  │
│     📁 Kategorie: Bürobedarf                                 │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     [Kategorie ändern] [Exportieren]                         │
└─────────────────────────────────────────────────────────────┘
```

### Example Conversation

```
User: [sends photo of invoice]

Bot:  ✅ Dokument erfasst
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      📄 Typ:      Rechnung
      📋 Nr:       RE-2026-0342
      🏢 Von:      Büro Müller KG
      💰 Betrag:   €1.234,56
      📅 Datum:    12.03.2026
      📁 Kategorie: Büromaterial
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      
      Was möchtest du tun?
      [Speichern] [Kategorie ändern] [Löschen]

User: Speichern

Bot:  ✅ Rechnung gespeichert!
      Du hast 23 Dokumente in diesem Monat.
```

---

## Flow 2: Document Search

### Trigger
User asks for a document or uses search command

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. USER QUERY                                               │
│     "Suche alle Rechnungen von Müller"                      │
│     or "/suche Müller Rechnung"                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. QUERY ANALYSIS                                           │
│     Extract search parameters:                               │
│     - Keywords: ["Müller", "Rechnung"]                      │
│     - Date range: (optional)                                 │
│     - Document type: Rechnung (optional)                     │
│     - Amount range: (optional)                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. MEMORY SEARCH                                            │
│     Call `memory_search` with keywords                       │
│     Returns top matches with relevance scores                │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. RESULT FORMATTING                                        │
│     Format results for messenger:                            │
│     - Compact list                                           │
│     - Key info per document                                  │
│     - Total amounts if relevant                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  5. OUTPUT                                                   │
│                                                              │
│     🔍 Gefunden: 3 Dokumente                                 │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     1. RE-2026-0342 | Müller KG | €1.234,56                  │
│        📅 12.03.2026 | Rechnung                              │
│                                                              │
│     2. RE-2026-0289 | Müller KG | €890,00                    │
│        📅 28.02.2026 | Rechnung                              │
│                                                              │
│     3. AN-2026-015 | Müller KG | €2.100,00                   │
│        📅 15.02.2026 | Angebot                               │
│                                                              │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│     💰 Gesamt: €4.224,56                                     │
│                                                              │
│     [Details] [Export] [Neue Suche]                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Flow 3: OCR Extraction

### Trigger
User sends a scanned document or requests OCR

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. DOCUMENT RECEIVED                                        │
│     Image or scanned PDF                                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. DOCUMENT TYPE DETECTION                                  │
│     ├─ Image (JPG/PNG) → Use `image` tool directly           │
│     └─ Scanned PDF → Convert to images first                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. OCR PROCESSING                                           │
│     a) Preprocess image (contrast, rotation)                │
│     b) Run Tesseract OCR with German language pack          │
│     c) Post-process text (clean up, format)                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. DATA EXTRACTION                                          │
│     Parse extracted text for:                                │
│     - Document type                                          │
│     - Key fields (date, amount, vendor)                      │
│     - Line items                                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  5. OUTPUT                                                   │
│                                                              │
│     📄 Text erkannt:                                         │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     RECHNUNG Nr. 2026/03/1234                                │
│                                                              │
│     Kunde: Beispiel GmbH                                     │
│             Musterstraße 123                                 │
│             12345 Berlin                                     │
│                                                              │
│     Datum: 12.03.2026                                        │
│                                                              │
│     Position                    Menge    Preis               │
│     ─────────────────────────────────────────               │
│     Beratung                   4 Std    €320,00             │
│     Software-Setup             1        €150,00             │
│     ─────────────────────────────────────────               │
│     Gesamtbetrag:                       €470,00             │
│                                                              │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     Als Dokument speichern? [Ja] [Nein]                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Flow 4: Reminders

### Trigger
User asks for a reminder in natural language

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. NATURAL LANGUAGE INPUT                                   │
│     "Erinnere mich morgen um 14 Uhr an Meeting mit Müller"  │
│     "Vergiss nicht: Steuererklärung bis 31.03."             │
│     "Weck mich in 2 Stunden"                                │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. TIME PARSING                                             │
│     Extract datetime from natural language:                 │
│                                                              │
│     "morgen um 14 Uhr" → 2026-03-13T14:00:00                │
│     "in 2 Stunden"    → now + 2h                            │
│     "am 31.03."       → 2026-03-31T09:00:00 (default 9h)    │
│     "nächste Woche"   → +7 days                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. CONFIRMATION                                             │
│                                                              │
│     ⏰ Erinnerung erstellen?                                 │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│     📅 Wann:  13.03.2026 um 14:00 Uhr                        │
│     📝 Was:   Meeting mit Müller                             │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     [Bestätigen] [Zeit ändern] [Abbrechen]                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. STORAGE                                                  │
│     Store in memory/reminders.json:                         │
│     {                                                        │
│       "id": "rem_abc123",                                    │
│       "text": "Meeting mit Müller",                          │
│       "datetime": "2026-03-13T14:00:00",                     │
│       "delivered": false                                     │
│     }                                                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  5. CRON SCHEDULING                                          │
│     Use `cron` tool to schedule:                            │
│     - Check every minute for due reminders                  │
│     - Send notification when time reached                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  6. NOTIFICATION (when due)                                  │
│                                                              │
│     ⏰ ERINNERUNG                                            │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│     📝 Meeting mit Müller                                    │
│     📅 Jetzt: 14:00 Uhr                                      │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     [Erledigt] [Verschieben] [Löschen]                      │
└─────────────────────────────────────────────────────────────┘
```

### Natural Language Patterns

```yaml
time_patterns:
  "morgen": "+1d"
  "übermorgen": "+2d"
  "nächste Woche": "+7d"
  "in X Stunden/Stunde": "+Xh"
  "in X Tagen/Tag": "+Xd"
  "am X.Y.": "specific date"
  "um X Uhr": "specific time"
  
date_patterns:
  "heute": "today"
  "diese Woche": "this week"
  "diesen Monat": "this month"
  "Monat Ende": "end of month"
  "Quartals Ende": "end of quarter"
```

---

## Flow 5: Export (Standard: Excel/PDF)

### Trigger
User requests document export

### Available Export Formats

**Standard (always available):**
- **Excel** (.xlsx) - Spreadsheet with all document data
- **PDF** - Document package as PDF
- **CSV** - Simple tabular format

**Optional (requires configuration):**
- **DATEV** - DATEV-CSV for German accounting (needs BeraterNr/MandantenNr)
- **Lexware** - Lexware-compatible CSV (needs configuration)
- **SAP** - SAP XML/IDoc (needs API access)

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. EXPORT REQUEST                                           │
│     "/export"                                                │
│     "Exportiere alle Rechnungen"                            │
│     "Ich brauch eine Excel-Listige"                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. FORMAT SELECTION                                         │
│                                                              │
│     📁 Welches Export-Format?                                │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     [Excel]  [PDF]  [CSV]                                    │
│                                                              │
│     Optional (falls konfiguriert):                           │
│     [DATEV]  [Lexware]  [SAP]                                │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. CHECK OPTIONAL FORMAT                                    │
│     If DATEV/Lexware/SAP requested:                         │
│     ├─ Configured → Continue                                │
│     └─ Not configured → Offer standard format:              │
│                                                              │
│        ⚠️ DATEV nicht konfiguriert.                          │
│                                                              │
│        Stattdessen:                                          │
│        [Excel] [PDF] [CSV]                                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. PARAMETER COLLECTION                                     │
│     Ask for:                                                 │
│     - Date range (default: current month)                    │
│     - Document types (default: all)                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  5. CONFIRMATION                                             │
│                                                              │
│     📊 Export vorbereiten                                    │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│     📁 Format:    Excel (.xlsx)                              │
│     📅 Zeitraum:  01.03.2026 - 31.03.2026                    │
│     📄 Dokumente: 23                                         │
│     💰 Gesamt:    €12.450,00                                 │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     [Exportieren] [Abbrechen]                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  6. FILE GENERATION                                          │
│                                                              │
│     For Excel:                                               │
│     - Create .xlsx with columns:                            │
│       Datum | Nr | Lieferant | Betrag | Kategorie | Typ     │
│     - Include summary sheet with totals                     │
│                                                              │
│     For PDF:                                                 │
│     - Combine all document images                           │
│     - Add summary page at front                             │
│                                                              │
│     For CSV:                                                 │
│     - Simple tabular format                                 │
│     - UTF-8 encoded, German number format                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  7. OUTPUT                                                   │
│                                                              │
│     ✅ Export erstellt!                                      │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│     📁 Datei: export_2026-03.xlsx                            │
│     📊 Größe: 45 KB                                          │
│     📄 Dokumente: 23                                         │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     [Herunterladen] [Per Email] [In Cloud speichern]        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  8. AUDIT LOG                                                │
│     Log export action:                                       │
│     {                                                        │
│       "event": "export",                                     │
│       "format": "excel",                                     │
│       "documents": 23,                                       │
│       "timestamp": "2026-03-12T13:30:00"                     │
│     }                                                        │
└─────────────────────────────────────────────────────────────┘
```

### Excel Export Format

```xlsx
| Datum       | Nr          | Lieferant      | Betrag    | Kategorie    | Typ       |
|-------------|-------------|----------------|-----------|--------------|-----------|
| 12.03.2026  | RE-2026-342 | Müller GmbH    | €1.234,56 | Büromaterial | Rechnung  |
| 11.03.2026  | RE-2026-341 | IT Services    | €890,00   | IT          | Rechnung  |
| 10.03.2026  | AN-2026-045 | Weber KG       | €2.500,00 | Beratung    | Angebot   |

Summary:
Total: €4.624,56
Rechnungen: 2
Angebote: 1
```

### DATEV Export (Optional)

Only available when configured with:

```bash
# Required for DATEV
DATEV_BERATER_NR=123456
DATEV_MANDANTEN_NR=78900
```

Generates DATEV-compliant CSV:

```csv
EXTF;510;DATEV Buchungsstapel;123456;78900;20260301;20260331;;;4;0
1234.56;S;1400;6000;12.03.2026;RE-2026-342;Müller GmbH;Büromaterial
890.00;S;1400;6200;11.03.2026;RE-2026-341;IT Services;Dienstleistung
```

---

## Flow 6: Email Sending

### Trigger
User wants to send a document via email

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. EMAIL REQUEST                                            │
│     "Sende die letzte Rechnung an buchhaltung@firma.de"     │
│     "/email buchhaltung@firma.de"                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. DOCUMENT SELECTION                                       │
│     a) Find referenced document(s)                          │
│     b) Load document data                                   │
│     c) Prepare attachment (PDF/image)                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. CONFIRMATION                                             │
│                                                              │
│     📧 Email senden?                                         │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│     An:      buchhaltung@firma.de                            │
│     Betreff: Rechnung RE-2026-0342                           │
│     Anhang:  rechnung_342.pdf                                │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     [Senden] [Bearbeiten] [Abbrechen]                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. SEND EMAIL                                               │
│     a) Connect to SMTP server                               │
│     b) Send email with attachment                           │
│     c) Handle errors (bounce, auth failure)                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  5. OUTPUT                                                   │
│                                                              │
│     ✅ Email versendet!                                      │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│     📧 An:     buchhaltung@firma.de                          │
│     📎 Anhang: rechnung_342.pdf (234 KB)                     │
│     🕐 Zeit:   13:30:45                                      │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Flow 7: Consent Management

### Trigger
User starts conversation or requests consent action

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. USER STARTS CONVERSATION (/start)                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. CONSENT CHECK                                            │
│     Check if user has consented:                             │
│     ├─ YES → Welcome message, ready to help                 │
│     └─ NO  → Show consent request                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. CONSENT REQUEST                                          │
│                                                              │
│     👋 Willkommen bei NexHelper!                             │
│                                                              │
│     Ich bin dein Dokumenten-Assistent für                    │
│     [COMPANY_NAME].                                          │
│                                                              │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     Vor der Nutzung benötige ich deine                       │
│     Einwilligung zur Datenverarbeitung:                      │
│                                                              │
│     • Deine Nachrichten werden verarbeitet                   │
│     • Dokumente werden auf EU-Servern gespeichert            │
│     • DSGVO-konforme Behandlung                              │
│     • Du kannst jederzeit widerrufen                         │
│                                                              │
│     Mehr Infos: nexhelper.de/datenschutz                     │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│     [✅ Einwilligen] [❌ Ablehnen]                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. USER ACCEPTS                                             │
│                                                              │
│     ✅ Vielen Dank für deine Einwilligung!                   │
│                                                              │
│     Jetzt kannst du:                                         │
│     📄 Dokumente senden (Rechnungen, Angebote)              │
│     🔍 Dokumente suchen                                      │
│     ⏰ Erinnerungen setzen                                   │
│     📤 Exportieren (DATEV, Email)                            │
│                                                              │
│     Sende einfach ein Foto oder PDF los!                     │
└─────────────────────────────────────────────────────────────┘
```

### Consent Withdrawal

```
User: /widerruf

Bot:  ⚠️ Einwilligung widerrufen?                             
      
      Dies wird:
      • Deine Einwilligung zurückziehen
      • Keine neuen Dokumente mehr verarbeiten
      • Bestehende Daten behalten (bis zur Löschung)
      
      [Widerrufen] [Abbrechen]

User: [Widerrufen]

Bot:  ✅ Einwilligung widerrufen.
      
      Du kannst jederzeit erneut einwilligen.
      
      Möchtest du alle deine Daten löschen?
      [Ja, alles löschen] [Nein, behalten]
```

---

## Commands Reference

| Command | Description | Example |
|---------|-------------|---------|
| `/start` | Start bot, show consent | `/start` |
| `/hilfe` | Show help | `/hilfe` |
| `/suche <query>` | Search documents | `/suche Müller Rechnung` |
| `/export` | Start export (select format) | `/export` |
| `/export excel [month]` | Excel export | `/export excel 03.2026` |
| `/export pdf [month]` | PDF export | `/export pdf` |
| `/export csv [month]` | CSV export | `/export csv` |
| `/export datev [month]` | DATEV export (if configured) | `/export datev 03.2026` |
| `/export email <address>` | Email export | `/export email buch@firma.de` |
| `/remind <text>` | Create reminder | `/remind Morgen Meeting` |
| `/remind list` | List reminders | `/remind list` |
| `/widerruf` | Withdraw consent | `/widerruf` |
| `/status` | Show statistics | `/status` |

---

## Quick Actions (Inline Buttons)

When document is received:

```
[Kategorie ändern]  [Exportieren]  [Löschen]
```

When search results shown:

```
[Details]  [Export]  [Neue Suche]
```

When reminder triggered:

```
[Erledigt]  [Verschieben]  [Löschen]
```

---

## Error Handling

### Document Processing Errors

```
❌ Dokument konnte nicht verarbeitet werden.

Grund: Das Bild ist zu unscharf.

Tipps:
• Bessere Beleuchtung
• Kamera ruhig halten
• Text horizontal ausrichten

[Erneut versuchen]
```

### Export Errors

```
❌ DATEV-Export fehlgeschlagen.

Grund: 3 Dokumente haben fehlende Pflichtfelder.

Betroffen:
• RE-123: Kein Betrag erkannt
• RE-145: Kein Lieferant erkannt
• BE-089: Kein Datum erkannt

[Dokumente korrigieren] [Trotzdem exportieren]
```

### Email Errors

```
❌ Email konnte nicht gesendet werden.

Grund: SMTP-Verbindung fehlgeschlagen.

Prüfe:
• SMTP-Einstellungen korrekt?
• Internetverbindung vorhanden?
• App-Passwort verwendet?

[Erneut versuchen] [Einstellungen]
```

---

## Daily Summary (Cron)

Every day at 18:00:

```
📊 Tageszusammenfassung - 12.03.2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 Dokumente empfangen: 5
💰 Gesamtbetrag: €2.345,00

📅 Morgen:
⏰ 14:00 - Meeting mit Müller

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Detaillierter Bericht] [Ignorieren]
```
