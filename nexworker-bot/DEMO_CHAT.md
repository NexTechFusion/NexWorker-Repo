# NexWorker Demo Bot - Chat Simulation

## Setup

**Directory:** `/root/.openclaw/nexworker-demo-bot/`
**Port:** 3001
**Model:** Google Gemini 2.0 Flash

---

## Demo Chat Scenarios

### Szenario 1: Normaler Arbeitstag

```
👤 Monteur Thomas (07:15):
"Guten Morgen! Bin auf Baustelle Schulze, München. Team ist Peter und ich."

🤖 NexWorker:
"✅ Check-in 07:15
📍 Baustelle Schulze, München
👥 Thomas + Peter

Was liegt heute an?"

---

👤 Monteur Thomas (11:30):
"Material angekommen. 3 Rollen Kabel NYM-J 5x2.5, ca 320 Euro. Und 2 Verteilerdosen, 45 Euro."

🤖 NexWorker:
"📦 Material erfasst:
• 3x Kabel NYM-J 5x2.5 – 320€
• 2x Verteilerdosen – 45€
─────────────
💰 Gesamt: 365€

Noch mehr Material?"

---

👤 Monteur Thomas (12:45):
"Mittagspause. Haben 30 Minuten."

🤖 NexWorker:
"🍴 Pause dokumentiert – 30 Min

Weiter geht's!"

---

👤 Monteur Thomas (16:30):
"Feierabend! 8 Stunden netto gearbeitet."

🤖 NexWorker:
"📋 TAGESBERICHT
═══════════════════
📍 Baustelle: Schulze, München
👥 Team: Thomas + Peter

⏱ Zeit:
• Thomas: 8,0h
• Peter: 8,0h
• Gesamt: 16,0h

📦 Material: 365€
• 3x Kabel NYM-J 5x2.5
• 2x Verteilerdosen

─────────────
✅ Export bereit
📄 PDF | 📊 Excel | 📤 An Büro senden"
```

---

### Szenario 2: Mehrere Baustellen

```
👤 Monteur (06:45):
"Start. Baustelle Neue Straße 12. Allein heute."

🤖 NexWorker:
"✅ Check-in 06:45
📍 Neue Straße 12
👤 Solo-Team

Guter Start!"

---

👤 Monteur (10:00):
"Muss zur zweiten Baustelle. Bismarckstraße. Materialübergabe."

🤖 NexWorker:
"🔄 Baustellenwechsel
─────────────
❌ Check-out: Neue Straße 12
⏱ Bisher: 3h 15min

✅ Check-in: Bismarckstraße
📍 10:00

Was wird übergeben?"

---

👤 Monteur (10:15):
"2 Kabeltrommeln, 1 Verteilerschrank. Übergabe an Firma Krämer."

🤖 NexWorker:
"📦 Materialübergabe dokumentiert:
• 2x Kabeltrommeln
• 1x Verteilerschrank
👤 Empfänger: Firma Krämer

Foto für Beweissicherung?"
```

---

### Szenario 3: Problem / Meldung

```
👤 Monteur (14:00):
"Problem! Pumpe defekt vorgefunden. Kann nicht weiterarbeiten."

🤖 NexWorker:
"⚠️ BLOCKER gemeldet
─────────────
📍 Aktuelle Baustelle
🔧 Problem: Pumpe defekt
⏱ 14:00

❓ Foto gemacht für Dokumentation?
❓ Ersatzteil bestellt?
❓ Chef benachrichtigen?"

---

👤 Monteur (14:05):
"Foto ist drauf. Chef weiß Bescheid. Warten auf Ersatzteil."

🤖 NexWorker:
"✅ Dokumentiert:
📸 Foto vorhanden
👤 Chef informiert
⏳ Warten auf Ersatzteil

Wartezeit wird erfasst. Sag Bescheid wenn's weitergeht!"
```

---

### Szenario 4: Wochenbericht

```
👤 Monteur (Freitag 16:00):
"Wochenbericht bitte."

🤖 NexWorker:
"📊 WOCHENBERICHT KW 12
═══════════════════════
Zeitraum: Mo 17.03 – Fr 21.03

⏱ Arbeitszeit:
• Thomas: 42,5h
• Peter: 40,0h
• Gesamt: 82,5h

📦 Material gesamt: 1.847€

📍 Baustellen:
• Schulze, München – 3 Tage
• Neue Straße 12 – 1 Tag
• Bismarckstraße – 1 Tag

⚠️ Vorfälle: 1 (Pumpe defekt)

─────────────
✅ Alle Tage dokumentiert
📄 PDF exportieren?"
```

---

### Szenario 5: Sprachnachricht

```
👤 Monteur (Sprachnachricht, 07:00):
🔊 "Guten Morgen, bin auf der Baustelle Weber in Stuttgart, Karlstraße 15. Heute mit dem ganzen Team, also Peter, Hans und ich. Wir machen die Elektrik im ersten Stock fertig."

🤖 NexWorker:
"✅ Check-in 07:00
📍 Baustelle Weber, Stuttgart
📍 Karlstraße 15
👥 Thomas, Peter, Hans

Aufgabe: Elektrik 1. Stock

Meldet euch bei Material oder Fragen!"
```

---

## Bot-Befehle

| Befehl | Funktion |
|--------|----------|
| `/start` | Begrüßung & Kurzanleitung |
| `/bericht` | Tagesbericht generieren |
| `/woche` | Wochenbericht |
| `/material` | Material-Liste heute |
| `/zeit` | Heutige Arbeitszeit |
| `/hilfe` | Alle Befehle |
| `/status` | Aktuelle Baustelle & Zeit |

---

## Automatische Erinnerungen

### 12:00 Uhr (Mittag):
```
🤖 NexWorker:
"🍴 Erinnerung: Mittagspause dokumentieren?
Bisher: 5h gearbeitet."
```

### 17:00 Uhr (Feierabend):
```
🤖 NexWorker:
"🕕 Feierabend-Erinnerung!
Bisher: 9,5h auf der Baustelle.

Noch Material vergessen? Check-out senden?"
```

### Wochenende:
```
🤖 NexWorker (Sonntag 18:00):
"📋 Wochenbericht für KW 12 steht bereit!

Schicken an:
• Büro per E-Mail
• Export als PDF

👉 /woche zum Ansehen"
```

---

## BauPVO 2026 Compliance

```
👤 Monteur:
"Welches Material war das nochmal auf Baustelle Schulze?"

🤖 NexWorker:
"📦 Baustelle Schulze (17.03.2026):

• 3x Kabel NYM-J 5x2.5 – 320€
  Lieferant: Elektro Großhandel Süd
  Lieferschein: ES-2026-0317-042
  
• 2x Verteilerdosen – 45€
  Lieferant: same
  Lieferschein: ES-2026-0317-042

─────────────
✅ BauPVO-konform dokumentiert
📎 Alle Belege archiviert"
```

---

## Start Bot

```bash
cd /root/.openclaw/nexworker-demo-bot

# 1. Neuen Telegram Bot erstellen (einmalig)
# Chat mit @BotFather auf Telegram
# /newbot → Name: "NexWorker Demo" → Username: "nexworker_demo_bot"
# Token in .env eintragen

# 2. Bot starten
openclaw gateway start --config ./config/openclaw.json
```

---

## Todo

- [ ] Neuen Bot-Token von @BotFather holen
- [ ] Token in .env eintragen
- [ ] Bot starten und testen
- [ ] Demo-Chats aufzeichnen
- [ ] Screenshots für Landing Page
