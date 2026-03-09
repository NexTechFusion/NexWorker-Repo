# Nex-Assistent MVP

## MVP Definition (Minimum Viable Product)

Das Minimum für einen erfolgreichen Launch:

---

## Core Features (Launch)

### 1. Foto/Upload → OCR → Kategorisierung

**Flow:**
```
User lädt Foto hoch
    ↓
OCR läuft (Google Vision / Textract)
    ↓
KI analysiert Inhalt (GPT-4 / Gemini)
    ↓
Dokument wird kategorisiert:
  - Rechnung
  - Angebot
  - Vertrag
  - Mahnung
  - Behörde
  - Sonstiges
    ↓
In Vector-DB gespeichert
```

**Tech:**
- OCR: Google Vision API oder AWS Textract
- Kategorisierung: GPT-4o-mini oder Gemini Flash
- Vector DB: Pinecone / Weaviate / Supabase pgvector

---

### 2. Smart Extraction

**Extrahierte Daten:**

| Feld | Erkennung |
|------|-----------|
| Absender | Firmenname, Adresse |
| Betrag | Euro-Betrag mit Währung |
| Datum | Dokumentendatum, Eingangsdatum |
| Zahlungsziel | Falls vorhanden |
| Frist | Falls vorhanden |
| IBAN | Falls vorhanden |
| Referenznummer | Falls vorhanden |

**Storage:**
```json
{
  "id": "doc_123",
  "type": "rechnung",
  "absender": "Stadtwerke München",
  "betrag": 127.50,
  "waehrung": "EUR",
  "datum": "2026-03-01",
  "zahlungsziel": "2026-03-15",
  "iban": "DE89...",
  "text_ocr": "...",
  "embedding": [0.1, 0.2, ...],
  "created_at": "2026-03-01T10:00:00Z"
}
```

---

### 3. Chat-Interface für Queries

**Natürliche Fragen:**

```
User: "Zeig mir alle Rechnungen von Stadtwerke"
Bot: [Liste mit 3 Rechnungen]

User: "Was ist fällig diese Woche?"
Bot: "2 Rechnungen:
      - Stadtwerke: 127,50€ (fällig 15.03.)
      - Telekom: 45,00€ (fällig 17.03.)"

User: "Habe ich Angebote von Elektro Müller?"
Bot: "Ja, 1 Angebot vom 12.01.2026 über 2.450€"
```

**Tech:**
- RAG (Retrieval Augmented Generation)
- Embeddings für semantische Suche
- GPT-4o-mini für Chat-Antworten

---

### 4. Fristen-Erkennung + Reminder

**Erkannte Fristen-Typen:**

1. **Zahlungsziele**
   - "Zahlbar bis 15.03.2026"
   - "Zahlungsziel 14 Tage"

2. **Kündigungsfristen**
   - "Kündigung 3 Monate zum Quartalsende"
   - "Jeweils zum 31.12. kündbar"

3. **Antwort-Fristen**
   - "Bitte antworten Sie bis..."
   - "Einspruch innerhalb von 2 Wochen"

**Reminder-System:**
```
Frist erkannt → Reminder erstellen:
  - 7 Tage vorher
  - 3 Tage vorher
  - 1 Tag vorher
  - Am Tag selbst

Notification via:
  - E-Mail
  - Push (App)
  - WhatsApp (optional)
```

---

## User Journey (MVP)

### Szenario: Rechnung erhalten

```
1. User bekommt Briefpost (Rechnung)
2. Macht Foto mit Handy
3. Lädt hoch in Nex-Assistent (App/Web)
4. KI erkennt automatisch:
   - Rechnung von Stadtwerke München
   - Betrag: 127,50€
   - Fällig: 15.03.2026
   - IBAN extrahiert
5. User bekommt Notification: "Rechnung erfasst"
6. Reminder am 10.03. und 14.03.
7. User kann per Chat fragen: "Zeig mir die IBAN"
```

---

## Tech-Architektur (MVP)

```
┌─────────────────┐
│   Frontend      │
│   (React/Next)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Backend API   │
│   (Node/Python) │
└────────┬────────┘
         │
    ┌────┴────┬─────────┬──────────┐
    ▼         ▼         ▼          ▼
┌───────┐ ┌───────┐ ┌────────┐ ┌────────┐
│  OCR  │ │  KI   │ │ Vector │ │   DB   │
│ Google│ │ GPT-4 │ │  DB    │ │Postgres│
└───────┘ └───────┘ └────────┘ └────────┘
```

---

## MVP Scope vs. Future

### ✅ Im MVP
- Foto-Upload
- OCR + Kategorisierung
- Smart Extraction (Basis-Felder)
- Chat-Interface
- Fristen-Erkennung
- E-Mail/Push Reminder
- Suche nach Dokumenten

### ❌ Nicht im MVP (Phase 2+)
- E-Mail-Integration (dokus@nex-assistent.de)
- ERP-Integration
- Dokumenten-Vernetzung
- Duplicate Detection
- Anomalie-Erkennung
- Compliance-Checker
- Voice-First
- Relationship Graph

---

## Launch-Kriterien

### Technisch
- [ ] OCR funktioniert zuverlässig (>95%)
- [ ] Kategorisierung korrekt (>90%)
- [ ] Fristen-Erkennung funktioniert (>80%)
- [ ] Chat-Antworten sinnvoll
- [ ] Reminder werden gesendet

### Business
- [ ] Landing Page online
- [ ] Pricing klar
- [ ] Onboarding-Flow definiert
- [ ] Beta-Tester bereit (min. 5)
- [ ] Support-Prozess definiert

---

## Timeline (Schätzung)

| Phase | Dauer | Ziel |
|-------|-------|------|
| Tech-Prototype | 2 Wochen | OCR + Kategorisierung funktioniert |
| Backend + DB | 2 Wochen | API + Vector DB + Storage |
| Frontend MVP | 2 Wochen | Upload + Chat + Dashboard |
| Testing | 1 Woche | Mit Beta-Testern |
| Launch Prep | 1 Woche | Landing Page, Pricing, Onboarding |

**Gesamt:** ~8 Wochen bis Launch

---

## Success Metrics (MVP)

1. **Aktive Nutzer:** 10+ in erstem Monat
2. **Dokumente/Monat:** 100+ hochgeladen
3. **Kategorisierungs-Accuracy:** >90%
4. **User-Satisfaction:** >4.0/5.0
5. **Conversion:** 5% Trial → Paid
