# NexWorker Live-Demo MVP (Roadmap)

Das Ziel: Ein klickbarer Prototyp, der einem Baustellen-Meister in 60 Sekunden zeigt, wie seine Sprachnachricht zu einem fertigen PDF-Bericht wird.

## 🛠️ Phase 1: Der "Magic-Forward" Bot (Woche 1)
Keine ERP-Integration, nur der "Wow-Effekt". 
1. **Forwarding-Interface:** User schickt eine Voice/Foto-Nachricht an eine Test-Nummer (Telegram/WhatsApp).
2. **OpenClaw-Logik:** Verarbeitung von Sprache-zu-Text (Whisper) und Bild-Analyse (Vision).
3. **Instant PDF:** Automatische Erstellung eines "Tagesberichts" im NexWorker-Design.
4. **Link-Return:** Bot schickt den PDF-Link in 30 Sekunden zurück.

## 📱 Phase 2: Live-Testing (Woche 2)
1. **Pilot-Betrieb:** Ein befreundeter Betrieb (2-3 Monteure) nutzt die Nummer für echte Baustellen.
2. **Feedback-Loop:** Was versteht die KI nicht? (Dialekt-Anpassungen, Fachbegriffe).
3. **Google Sheets Sync:** Die Daten landen in einem Live-Sheet für den Chef.

---

## 🏗️ Technischer Stack (NexWorker MVP)
* **Backend:** OpenClaw (Main Session)
* **AI-Models:** 
    * Whisper (Voice-Transcription)
    * Gemini-1.5-Pro / GPT-4o (Reasoning & OCR)
    * OpenRC (PDF Generation via LaTeX oder HTML-to-PDF)
* **Database:** SQLite (lokal in OpenClaw) + Google Sheets API (für den User Sichtbar).

---

## 📝 Nächste Schritte (Jetzt!)
1. [ ] **Die System-Prompt definieren:** Der "NexWorker Instruktionssatz" (Fokus auf Handwerker-Slang).
2. [ ] **PDF-Template entwerfen:** Ein Layout, das professionell aussieht (Logo, Projektname, Datum, Wetter, Ereignisse).
3. [ ] **Test-Szenario:** Eine Sequenz aus 3 Nachrichten erstellen, die wir live demonstrieren (Neuer Lead -> Material-Meldung -> Tagesabschluss).

---

*Wichtig: Wir verkaufen in der Demo NICHT die Technik, sondern die ZEITERSPARNIS.*
