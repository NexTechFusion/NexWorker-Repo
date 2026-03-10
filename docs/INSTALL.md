# NexWorker Installation & Setup Guide (v1.0)

Dieser Guide beschreibt Schritt für Schritt, wie eine dedizierte OpenClaw-Instanz als **NexWorker-Knoten** für einen Pilotkunden aufgesetzt wird.

## 📋 Anforderungen
* Ein dedizierter Server (z.B. Hetzner Cloud ARM CAX11 für ~€4/Monat oder ein Raspberry Pi vor Ort).
* Ein Telegram-Bot (via BotFather) oder eine WhatsApp-Nummer (via Provider).
* Installiertes OpenClaw (`npm install -g openclaw`).

---

## 🛠️ Schritt 1: OpenClaw Initialisierung
Erstelle ein neues Verzeichnis für den Kunden-Knoten und initialisiere OpenClaw.

```bash
mkdir nexworker-knoten-kunde-a
cd nexworker-knoten-kunde-a
openclaw init
```

## 🛠️ Schritt 2: Konfiguration (config.yaml)
Passe die `config.yaml` an, um den "NexWorker"-Modus zu aktivieren.

```yaml
# NexWorker Gateway Config
gateway:
  port: 18790
  auth:
    token: "dein-kunden-token-hier"

# Den NexWorker System-Prompt laden
agent:
  systemPrompt: |
    $(cat path/to/NexWorker/System-Prompt.md)

# Kanäle konfigurieren (Beispiel Telegram)
channels:
  telegram:
    token: "DEIN_BOT_TOKEN"
    enabled: true
```

## 🛠️ Schritt 3: Die "Welcome Message" (Onboarding)
Der erste Eindruck zählt. Hinterlege diese Nachricht als Start-Event oder in einem Begrüßungs-Script.

### 📝 Der NexWorker Willkommens-Text (Copy-Paste)
> "Moin! 🏗️ Ich bin **NexWorker**, dein neuer digitaler Bauhelfer.
> 
> Ab sofort kannst du mir einfach hier im Chat alles zur Baustelle schicken:
> ✅ **Sprachnachrichten:** (z.B. 'Bin fertig beim Müller, 5m NYM verlegt.')
> ✅ **Fotos:** Einfach vom Arbeitsfortschritt oder Materialzettel machen.
> ✅ **Stunden:** 'Bin jetzt weg, 8 Stunden gearbeitet.'
> 
> Ich sortiere alles automatisch in eure Projektberichte ein. Keine Zettel, kein Stress. 
> 
> **Leg gleich los: Schick mir kurz deinen Namen und an welchem Projekt du heute arbeitest!**"

---

## 🛠️ Schritt 4: Deployment & Start
Starte das Gateway im Hintergrund.

```bash
openclaw gateway start
```

## 🧪 Schritt 5: Der "First Run" Test
1. Füge den Bot in eine WhatsApp/Telegram-Gruppe mit den Monteuren hinzu.
2. Der Bot postet automatisch die **Welcome Message**.
3. Ein Monteur schickt die erste Test-Nachricht.
4. Prüfe in `/root/.openclaw/workspace/memory/`, ob der NexWorker die Projektdatei korrekt angelegt hat.

---
*Erstellt für NexTech Fusion Deployment - März 2026*
