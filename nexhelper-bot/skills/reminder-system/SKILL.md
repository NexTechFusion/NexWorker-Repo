# Skill: reminder-system

Manage reminders and deadlines for NexHelper customers.

## Description

This skill enables OpenClaw to create, manage, and trigger reminders for important deadlines, appointments, and follow-ups.

## Features

- ✅ Create reminders via natural language
- ✅ List upcoming reminders
- ✅ Delete/cancel reminders
- ✅ Automatic notifications when triggered
- ✅ Integration with OpenClaw cron system

## Actions

### 1. Create Reminder

```
User: "Erinnere mich morgen um 14 Uhr an das Meeting mit Müller"
Bot:  "✅ Erinnerung erstellt:
      📅 Morgen, 14:00 Uhr
      📝 Meeting mit Müller"
```

### 2. List Reminders

```
User: "Zeig mir meine Erinnerungen"
Bot:  "📅 Deine Erinnerungen:
      
      1. [Morgen 14:00] Meeting mit Müller
      2. [15.03. 09:00] Steuererklärung abgeben
      3. [20.03. 10:00] Kundenanruf"
```

### 3. Delete Reminder

```
User: "Lösche Erinnerung 1"
Bot:  "🗑️ Erinnerung gelöscht: Meeting mit Müller"
```

## Storage

Reminders are stored in canonical storage:

```
storage/canonical/reminders/<id>.json
```

## Cron Integration

Uses OpenClaw's native cron system:

```yaml
cron:
  - name: "reminder-check"
    schedule: "every 1 minute"
    action: "check_reminders"
```

## Implementation

### Memory Structure

```json
{
  "reminders": [
    {
      "id": "rem_abc123",
      "userId": "12345678",
      "text": "Meeting mit Müller",
      "datetime": "2026-03-10T14:00:00",
      "timezone": "Europe/Berlin",
      "created": "2026-03-09T10:30:00",
      "delivered": false,
      "cancelled": false
    }
  ]
}
```

### Cron Job

Checks every minute for due reminders, marks delivery state, and avoids duplicate sends via idempotency keys.

## Commands

| Command | Description |
|---------|-------------|
| `/remind <text>` | Create reminder (natural language) |
| `/remind list` | List all reminders |
| `/remind delete <id>` | Delete reminder |
| `/remind clear` | Delete all reminders |

## Natural Language Patterns

OpenClaw should recognize:

```
"Erinnere mich [zeit] an [text]"
"Weck mich [zeit] für [text]"
"Vergiss nicht: [text] am [zeit]"
"Termin [zeit]: [text]"
```

### Time Patterns

```
"morgen" → next day
"übermorgen" → day after tomorrow
"nächste Woche" → next week
"in X Stunden" → in X hours
"am X.Y." → specific date
"um X Uhr" → specific time
```

## DSGVO Compliance

- ✅ Reminders stored per customer (isolated)
- ✅ Can be deleted by user
- ✅ Audit trail for reminder actions
