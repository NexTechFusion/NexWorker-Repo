# NexTech Fusion - Der Digitale Bauhelfer (MVP)

Dieses Repository enthält das Fundament für das erste NexTech-Produkt: Die Automatisierung der Baustellen-Dokumentation für das Handwerk und Baugewerbe mittels OpenClaw.

## 🏆 Das Produkt: "NexWorker"

### 🎯 Zielgruppe
Alle Gewerke im Bauwesen (Elektro, Sanitär/Heizung, Trockenbau, Landschaftsbau), die unter manuellem Dokumentationsdruck leiden und keine komplexen Apps nutzen wollen.

---

### 🚀 Phasenplan (Brutal Schlank)

#### Phase 1: Der WhatsApp-Putzmann (Hook) 🧹
* **Was:** WhatsApp-Nachrichten (Voice, Text, Foto) direkt in eine saubere Excel-Liste verwandeln.
* **Wie:** Der Monteur chattet wie gewohnt. Unsere OpenClaw-Instanz verarbeitet die Intents und sortiert sie nach Projekten.
* **Der Kill-Shot:** Keinerlei Schulung nötig. Keine neue App auf dem Handy.

#### Phase 2: Die NexTech Sicherheits-Box (Moat) 🛡️
* **Was:** Lokale Datenverarbeitung beim Kunden vor Ort (Edge Computing).
* **Wie:** OpenClaw läuft auf einem dedizierten Gerät im Büro des Meisters. 
* **Der Kill-Shot:** 100% DSGVO-konform. Betriebsgeheimnisse bleiben auf dem eigenen Server – ein unschlagbares Argument im deutschen Mittelstand.

#### Phase 3: Der ERP-Geist (Integration) 🔗
* **Was:** Automatischer Import der Baustellen-Daten in bestehende Software (Lexware, pds, Streit).
* **Wie:** Direkte API-Anbindung oder Datenbank-Injects über OpenClaw Scripte.
* **Der Kill-Shot:** "Ein-Klick-Rechnung". Die Buchhaltung spart 80% der Zeit bei der Fakturierung.

---

### 📝 Der "Handwerker-Flüsterer" (Sales-Flyer Entwurf)

**Headline:** Haben Sie auch keine Lust mehr auf Freitagabend-Zettelwirtschaft?

**Problem:** 
* Monteure vergessen Material aufzuschreiben.
* Fotos liegen unsortiert auf 5 Handys verteilt.
* Das Büro muss Stunden investieren, um Berichte für die Rechnung zu tippen.

**Die NexTech Lösung:**
1. **Chatten:** Ihre Jungs schicken einfach Sprachnachrichten oder Fotos per WhatsApp an Ihre private Firmen-KI.
2. **Sortieren:** Unsere KI erkennt Projekte, Materialien und Stunden automatisch.
3. **Rechnen:** Jeden Freitag liegt ein fertiger Bericht auf Ihrem Schreibtisch – fertig zur Abrechnung.

**"Sicherer als alles andere:"** Ihre Daten bleiben in Deutschland, auf Ihrem eigenen System. Keine Cloud, kein Risiko.

---

### 📦 Produkt-Module (Das "NexWorker" Ökosystem)

NexWorker bündelt drei kritische Geschäftsfunktionen in einer einzigen WhatsApp-Schnittstelle:

### 1. Schatten-CRM (Kunden & Leads)
* **Funktion:** Verwandelt lockeres Chatten mit Kunden in strukturierte CRM-Daten. 
* **Value:** Leads werden sofort erfasst, Kontaktdaten automatisch aus dem Chat extrahiert und Follow-ups terminiert.
* **OpenClaw-Rolle:** Extraktion von Entitäten (Name, Adresse, Tel) aus Chatverläufen.

### 2. ERP-Middleware (Prozess & Material)
* **Funktion:** Die Brücke zwischen Baustelle und Buchhaltung.
* **Value:** Materialverbrauch und Arbeitszeiten werden per Chat gemeldet und direkt in Excel oder das ERP-System (Lexware, pds) übertragen.
* **OpenClaw-Rolle:** Strukturierung von unstrukturiertem Text/Sprache in Datenbankformate.

### 3. Automatisches Bautagebuch (Recht & Doku)
* **Funktion:** Rechtssichere Dokumentation ohne Aufwand.
* **Value:** Fotos und Kurznotizen der Monteure werden täglich zu einem PDF-Bericht (inkl. Wetterdaten) zusammengefasst.
* **OpenClaw-Rolle:** Vision-Analyse von Baustellen-Fotos und Zusammenführung aller Ereignisse des Tages.

---

## 🛠️ Technische Meilensteine (Roadmap)
* **Kanal:** Telegram/WhatsApp Bridge (Provider-Setup).
* **Agent:** OpenClaw Core mit `image`, `memory` und `exec` für PDF-Generation.
* **Storage:** Lokale `MEMORY.md` Struktur pro Projekt für maximale Durchsuchbarkeit.

---

*Erstellt von NexTech Fusion Assistant - März 2026*
