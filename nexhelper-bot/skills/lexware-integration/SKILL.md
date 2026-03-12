# Skill: lexware-integration

Integration with Lexware accounting software.

## Description

This skill enables OpenClaw to export documents to Lexware for accounting and bookkeeping.

## Features

- ✅ Export invoices to Lexware buchhaltung
- ✅ Export receipts to Lexware 
- ✅ CSV import files for Lexware
- ✅ DATEV-compatible format (Lexware can import DATEV)

## Supported Products

| Product | Method | Status |
|---------|--------|--------|
| Lexware buchhaltung | CSV import | ✅ |
| Lexware financial | CSV import | ✅ |
| Lexoffice | API | ⚠️ Planned |

## Configuration

```bash
# Lexware settings (for CSV export)
LEXWARE_SACHKONTENLAENGE=4
LEXWARE_KOSTENSTELLEN=false
```

## CSV Format

Lexware can import DATEV-compatible CSV files:

```csv
EXTF;510;DATEV Buchungsstapel;100000;100;20260301;20260331;;;4;0
450.00;S;1400;6000;09.03.2026;RE-123;Müller GmbH;Rechnung
```

## Actions

### Export Invoice to Lexware

```
User: "Exportiere diese Rechnung nach Lexware"
Bot:  "📤 Generiere Lexware-Export..."
      "✅ CSV erstellt: Buchungsstapel.csv
      
      Import in Lexware:
      1. Buchhaltung öffnen
      2. Import → DATEV-Datei
      3. Datei auswählen"
```

### Export Monthly Bookings

```
User: "Exportiere alle Buchungen von März nach Lexware"
Bot:  "📊 23 Buchungen gefunden
      💰 Gesamtbetrag: €12.450,00
      
      Exportieren? [Ja/Nein]"
User: "Ja"
Bot:  "✅ Exportiert: Buchungsstapel_Maerz.csv"
```

## Import in Lexware

1. **Lexware buchhaltung** öffnen
2. **Buchungen** → **Import/Export** → **DATEV-Import**
3. Datei auswählen
4. Zuordnung prüfen
5. Importieren

## Scripts

- `export_lexware_csv.sh` - Generate Lexware-compatible CSV
- `export_lexware_receipts.sh` - Export receipts with images

## Account Mapping

Default account mapping for common document types:

| Document Type | Account (Soll) | Account (Haben) |
|---------------|----------------|-----------------|
| Invoice (Expense) | 1400 | 6000 |
| Invoice (Revenue) | 1200 | 8400 |
| Receipt | 1400 | 6000 |
| Credit Note | 1200 | 8400 |

## Example Output

```csv
EXTF;510;DATEV Buchungsstapel;100000;100;20260309;20260309;;;4;0
450.00;S;1400;6000;09.03.2026;RE-2026-123;Müller GmbH;Büromaterial
1250.00;S;1400;6200;09.03.2026;RE-2026-124;IT-Services GmbH;Dienstleistung
89.00;S;1400;4930;09.03.2026;BE-2026-001;Tankstelle;Kraftstoff
```

## DSGVO Compliance

- ✅ Local CSV generation (no external API)
- ✅ User controls data export
- ✅ Audit trail maintained
- ✅ Data deleted with instance removal

## Status

✅ **Stable** - Uses DATEV-compatible format supported by Lexware
