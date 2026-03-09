# Nex-Assistent Features

## 1. Intelligente Fristen-Matrix ⏰

**Problem:** Fristen sind versteckt in Texten

**Lösung:**
```
📄 Brief von Versicherung XY:
"Kündigung bis 31.12. möglich, 
3 Monate Frist zum Quartalsende"

→ KI extrahiert:
✅ Kündigung möglich: Ja
✅ Kündigungsfrist: 3 Monate zum Quartalsende
✅ Nächster Kündigungstermin: 30.09.2026
✅ Reminder: 01.08.2026 (rechtzeitig vorbereiten)
```

**Feature:**
- Fristen-Timeline (Kalender-View)
- Automatische Erinnerungen (30/14/7 Tage vorher)
- "Kann ich noch kündigen?" - Chat-Query

---

## 2. Dokumenten-Vernetzung 🔗

**Auto-Verknüpfung:**

```
📤 Angebot #1234 von Elektro Müller
    ↓ (3 Monate später)
📥 Rechnung #1234 von Elektro Müller
    ↓ (automatisch verknüpft!)
✅ "Diese Rechnung gehört zu Angebot #1234"
✅ "Betrag stimmt: 2.450€"
✅ "Zahlungsziel: 14 Tage"
```

**Das erkennt die KI:**
- Gleicher Absender
- Ähnlicher Betreff
- Zeitliche Nähe
- Referenznummern

**Output:**
```
"📊 Projektübersicht Elektro Müller:
- Angebot: 12.01.2026
- Rechnung: 15.04.2026
- Status: Offen (fällig 29.04.)
- Differenz: 0€ (stimmt überein)"
```

---

## 3. Smart Extraction 🎯

**Nicht nur OCR, sondern VERSTEHEN:**

| Dokumenttyp | Extrahierte Daten |
|-------------|-------------------|
| **Rechnung** | Betrag, Datum, Zahlungsziel, IBAN, Steuernummer |
| **Vertrag** | Vertragspartner, Laufzeit, Kündigungsfrist, Kosten |
| **Behördenbrief** | Aktenzeichen, Frist, Ansprechpartner, Amt |
| **Angebot** | Gültigkeit, Preis, Artikel, Lieferzeit |

**Auto-Felder:**
```
📸 Foto hochgeladen
→ KI erkennt: "Rechnung"
→ Extrahiert:
   - Absender: "Stadtwerke München"
   - Betrag: "127,50€"
   - Fällig: "15.03.2026"
   - IBAN: "DE89..."
→ Auto-Action:
   ✅ In "Rechnungen" gespeichert
   ✅ Reminder für 10.03. erstellt
   ✅ In ERP vorbereitet (Export)
```

---

## 4. Context-Aware Chat 💬

**Natürliche Fragen:**

```
User: "Was habe ich von der Stadt noch offen?"

Bot: "📋 3 Dokumente von Stadt München:
     
     1. Steuerbescheid 2025 (erledigt)
     2. Baugenehmigung Antrag (läuft, 
        Frist: 20.03.2026)
     3. Gewerbeanmeldung Änderung 
        (offen, unterschreiben bis 01.04.)

     ⚠️ Aktion nötig: Baugenehmigung 
        in 11 Tagen!"
```

**Smart Queries:**
- "Zeig mir alle offenen Rechnungen über 1.000€"
- "Welche Verträge laufen dieses Jahr aus?"
- "Habe ich Mahnungen von Firma XY?"
- "Was muss ich diese Woche erledigen?"

---

## 5. Duplicate Detection 🔍

**Problem:** Gleiche Dokumente mehrfach

**Lösung:**
```
📄 Dokument hochgeladen
→ KI prüft: "Habe ich das schon?"
→ Ergebnis: "⚠️ Duplikat erkannt!
   Identisch mit Brief vom 12.01.2026"
→ Option: Überschreiben / Behalten / Verknüpfen
```

---

## 6. Smart Workflows ⚡

**Automatische Aktionen:**

```
IF Dokumenttyp = "Rechnung" 
   AND Betrag < 500€
   THEN → Status: "Kleinbetrag"
   → ERP: "Zur Zahlung freigegeben"

IF Dokumenttyp = "Mahnung"
   THEN → Priorität: "Hoch"
   → Reminder: "Sofort"
   → Chat: "⚠️ Mahnung erkannt!"

IF Absender = "Finanzamt"
   THEN → Kategorie: "Behörde"
   → Frist-Erkennung: "Priorität 1"
```

---

## 7. Anomalie-Erkennung 🚨

**Die KI merkt sich das "Normale":**

```
📊 Rechnung von Lieferant XY:
- Üblicher Betrag: ~500€
- Dieser Betrag: 2.300€
→ ⚠️ "Ungewöhnlich hoher Betrag!"
   Prüfen Sie: Neue Preisliste? Fehler?"
```

**Weitere Anomalien:**
- "Ungewöhnlicher Absender für diese Kategorie"
- "Fehlende Daten (keine IBAN bei Rechnung)"
- "Verdacht auf Phishing-Mail"
- "Frist ungewöhnlich kurz"

---

## 8. Voice-First 🎤

**Für unterwegs (Handwerker-Chef):**

```
🎤 "Nex, welche Rechnungen sind diese Woche fällig?"

🎤 "Nex, speichere das als Vertrag mit Müller GmbH"

🎤 "Nex, erinner mich morgen an den Brief vom Finanzamt"

🎤 "Nex, hat die Stadt München schon geantwortet?"
```

**Hands-Free Dokumentation:**
- Foto + Sprachkommentar
- "Das ist die Rechnung für Projekt XY"

---

## 9. Smart Export 📤

**Ein-Klick zu ERP:**

```
📄 Rechnung erkannt
→ Export-Button: "Zu DATEV"
→ Auto-Mapping:
   - Buchungskonto: vorgeschlagen
   - Kostenstelle: erkannt
   - Belegnummer: auto-generiert
→ Bestätigen → In DATEV gebucht
```

**Unterstützt:**
- DATEV
- Lexware
- SAP
- Excel-Export
- CSV für Custom

---

## 10. Compliance-Checker ✅

**Automatisch geprüft:**

```
📄 Vertrag hochgeladen

✅ Vollständigkeit:
   - Vertragspartner: Ja
   - Laufzeit: Ja
   - Kündigungsfrist: Ja
   - Unterschrift: Ja

⚠️ Warnungen:
   - AGB fehlen
   - Datenschutzklausel unklar
   - Laufzeit ungewöhnlich lang (5 Jahre)
```

---

## 11. Relationship Graph 🕸️

**Wer ist verbunden mit wem?**

```
📊 Firma Müller GmbH:
├── Vertrag: Wartung (aktiv)
├── Rechnungen: 12 (2024), 8 (2025)
├── Kontakt: Herr Schmidt
├── Projekte: 3
└── Status: "Guter Kunde, pünktlich"

"Zeige mir alle Beziehungen zu Firma XY"
```

---

## 12. Smart Templates 📝

**Antworten generieren:**

```
📄 Mahnung erhalten

Bot: "Möchten Sie antworten?"
→ Template: "Zahlungsbestätigung"
→ Template: "Widerspruch"
→ Template: "Ratenzahlung anfragen"

Auto-Ausfüllen:
- Empfänger: erkannt
- Aktenzeichen: erkannt
- Ihre Daten: hinterlegt
```
