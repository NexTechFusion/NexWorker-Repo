# NexHelper Simulation Results

## 10 Simulated User Interactions - Flaw Detection

---

## Simulation 1: User sends corrupted PDF

```
User: [sends corrupted PDF file that can't be opened]
```

**Expected Behavior:**
1. Bot attempts to analyze with `pdf` tool
2. Tool returns error
3. Bot informs user

**FLAW FOUND:**
❌ No handling for corrupted files
❌ User stuck with error message, no recovery

**FIX:**
```markdown
### PDF beschädigt:
"❌ PDF-Datei ist beschädigt oder kann nicht geöffnet werden.

Optionen:
• Neue Datei senden
• Foto der Rechnung machen statt PDF

[Neue Datei senden]"
```

---

## Simulation 2: User wants to update document metadata

```
User: "Ändere die Kategorie von RE-2026-0342 zu 'IT'"
```

**Expected Behavior:**
1. Bot finds document in memory
2. Updates the category
3. Confirms change

**FLAW FOUND:**
❌ No `/edit` command documented
❌ No flow for updating existing documents
❌ Memory entries are immutable in current design

**FIX:**
Add to SOUL.md:
```markdown
### Dokument bearbeiten:
Wenn Nutzer Metadaten ändern will:
1. memory_search nach Dokument
2. memory_get um Eintrag zu lesen
3. edit um Eintrag zu aktualisieren
4. Bestätigung senden

Command: /edit [DOC-NR] [FELD] [WERT]
```

---

## Simulation 3: User asks for statistics over time

```
User: "Wie viele Rechnungen hatten wir letzten Monat?"
User: "Was war unser höchster Einzelbetrag?"
```

**Expected Behavior:**
1. Bot searches across multiple memory files
2. Aggregates data
3. Shows statistics

**FLAW FOUND:**
❌ `/status` only shows current stats
❌ No aggregation across days/months
❌ No analytics capability

**FIX:**
Add analytics section:
```markdown
### Statistiken:
/suche mit Zeitraum gibt automatisch Zusammenfassung:

"📊 Statistik: März 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Dokumente: 45
💰 Gesamt: €23.456,00
📈 Höchster: €5.200,00 (RE-2026-0315)
📉 Durchschnitt: €521,24
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

---

## Simulation 4: User sends duplicate document

```
User: [sends same invoice photo twice by accident]
```

**Expected Behavior:**
1. Bot detects duplicate (same invoice number)
2. Asks if user wants to replace or skip

**FLAW FOUND:**
❌ No duplicate detection
❌ Would create two memory entries
❌ Double-counts in exports

**FIX:**
```markdown
### Duplikat erkannt:
"⚠️ Rechnung RE-2026-0342 bereits vorhanden!

Vorhanden: 12.03.2026, 14:30
Neu: 12.03.2026, 15:45

[Ersetzen] [Beide behalten] [Abbrechen]"
```

---

## Simulation 5: User wants to delete a document

```
User: "Lösche RE-2026-0342"
```

**Expected Behavior:**
1. Bot finds and removes document
2. Removes from memory AND original file
3. Logs deletion for audit

**FLAW FOUND:**
❌ No `/delete` command
❌ DSGVO requires deletion capability
❌ No audit trail for deletions

**FIX:**
```markdown
### Dokument löschen:
1. memory_search nach Dokument
2. Bestätigung anfragen (DSGVO!)
3. Originaldatei löschen (documents/)
4. Memory-Eintrag entfernen
5. Audit-Log Eintrag

"⚠️ Dokument wirklich löschen?

RE-2026-0342 | Müller GmbH | €1.234,56

Diese Aktion kann nicht rückgängig gemacht werden.

[Löschen] [Abbrechen]"
```

---

## Simulation 6: User sends document with multiple pages

```
User: [sends 5-page PDF invoice]
```

**Expected Behavior:**
1. Bot processes all pages
2. Extracts data from each
3. Stores multi-page doc

**FLAW FOUND:**
⚠️ Partial handling - `pdf` tool can do this
✅ Already works via `pdf` tool
❌ No explicit guidance in SOUL.md

**FIX:**
Add note in SOUL.md:
```markdown
### Mehrseitige PDFs:
- `pdf` Tool extrahiert alle Seiten
- Eine Memory-Entry pro Dokument (nicht pro Seite)
- Datei speichern als完整的 PDF
```

---

## Simulation 7: User switches between German and English

```
User: "Send me all invoices from March"
User: "Zeig mir die Rechnungen"
```

**Expected Behavior:**
1. Bot responds in same language
2. Understands both languages

**FLAW FOUND:**
❌ SOUL.md specifies German only
❌ No bilingual support
❌ English users confused

**FIX:**
```markdown
## SPRACHE

- **Primär:** Deutsch
- **Fallback:** Englisch wenn Nutzer Englisch spricht
- Erkenne Sprache der ersten Nachricht
- Antworte in gleicher Sprache
```

---

## Simulation 8: User forwards document from another chat

```
User: [forwards message with document from another Telegram chat]
```

**Expected Behavior:**
1. Bot receives forwarded document
2. Processes normally
3. Notes it was forwarded (optional)

**FLAW FOUND:**
✅ Should work - Telegram forwards preserve media
⚠️ No test for this case
❓ Unknown behavior - needs testing

**ACTION:** Test with real Telegram forward

---

## Simulation 9: User asks for document by vendor pattern

```
User: "Zeig mir alle Müller Rechnungen"
User: "Was haben wir bei IT* gekauft?"
```

**Expected Behavior:**
1. Bot does fuzzy search on vendor name
2. Shows all matching

**FLAW FOUND:**
✅ Should work via memory_search
⚠️ No explicit wildcard handling documented
❓ Behavior unknown for partial matches

**FIX:**
```markdown
### Suche mit Mustern:
- "Müller" → findet "Müller GmbH", "Müller KG"
- "IT*" → findet alle mit "IT" am Anfang
- memory_search unterstützt fuzzy matching
```

---

## Simulation 10: User sends very large file (>20MB)

```
User: [sends 50MB PDF scan]
```

**Expected Behavior:**
1. Bot receives file
2. Telegram has 50MB limit for bots - should work
3. Processing might be slow

**FLAW FOUND:**
❌ No file size limits documented
❌ No timeout handling for large files
❌ No progress indicator for long processing

**FIX:**
```markdown
### Große Dateien:
Wenn Verarbeitung länger dauert:
"⏳ Verarbeite große Datei...
Dies kann einen Moment dauern."

Timeout nach 60s:
"⚠️ Verarbeitung timeout.
Datei zu groß? Versuche:
• Kleinere Scans
• Foto statt PDF
• Datei aufteilen"
```

---

## Summary of Fixes Needed

| # | Issue | Priority | Fix Location |
|---|-------|----------|--------------|
| 1 | Corrupted PDF handling | High | SOUL.md |
| 2 | Edit document metadata | High | SOUL.md + Commands |
| 3 | Statistics/analytics | Medium | SOUL.md |
| 4 | Duplicate detection | High | SOUL.md |
| 5 | Delete document | Critical (DSGVO) | SOUL.md + Commands |
| 6 | Multi-page PDFs | Low | SOUL.md (docs only) |
| 7 | Bilingual support | Medium | SOUL.md |
| 8 | Forwarded messages | Low | Testing needed |
| 9 | Fuzzy search patterns | Low | SOUL.md |
| 10 | Large file handling | Medium | SOUL.md |

---

## Critical Fixes (Must Have)

1. **Delete Document** - DSGVO requirement
2. **Duplicate Detection** - Data integrity
3. **Edit Metadata** - User correction capability
4. **Corrupted File Handling** - User experience

## Next Steps

1. Convert all simulations to executable regression cases in `tests/regression/run.sh`
2. Enforce canonical storage checks before each scenario assertion
3. Validate idempotency for reminder/export cron-style replay
4. Track pass/fail in structured JSON output
