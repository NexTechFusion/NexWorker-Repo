# Skill: reminder-system

Manage reminders and deadlines for NexHelper customers.

## Description

This skill enables OpenClaw to create, manage, and trigger reminders for important deadlines, appointments, and follow-ups.

## Features

- ✅ Create reminders via natural language (German/English)
- ✅ List upcoming reminders
- ✅ Delete/cancel reminders
- ✅ Automatic notifications when triggered
- ✅ Multilingual time parsing

## Important: OpenClaw Cron Bug Workaround

**Problem:** OpenClaw v2026.x has a known bug where the CLI cannot connect to the gateway via WebSocket for `cron` operations (timeout after 10-30 seconds).

**Related Issues:**
- [GitHub #7667](https://github.com/openclaw/openclaw/issues/7667) - Cron tool operations timeout after 10s
- [GitHub #6902](https://github.com/openclaw/openclaw/issues/6902) - Cron tool timeout after gateway restart  
- [GitHub #19874](https://github.com/openclaw/openclaw/issues/19874) - Cron CLI times out on gateway WebSocket

**Workaround:** `nexhelper-set-reminder` writes directly to `~/.openclaw/cron/jobs.json` instead of using `openclaw cron add`. The gateway automatically picks up changes to this file.

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

Reminders are stored in two places:

1. **Cron Jobs:** `~/.openclaw/cron/jobs.json` (for triggering)
2. **Canonical Storage:** `storage/canonical/reminders/<id>.json` (for listing/management)

## Commands

| Command | Description |
|---------|-------------|
| `nexhelper-set-reminder --text "..." --time "..." --user ID [--channel CH]` | Create reminder |
| `nexhelper-reminder list --user ID` | List all reminders |
| `nexhelper-reminder delete --id ID` | Delete reminder |

### Channel Auto-Detection

When `--channel` is not specified, the system auto-detects from `--user` ID format:
- User ID starts with `+` (e.g., `+491606301723`) → **WhatsApp**
- User ID is all digits (e.g., `579539601`) → **Telegram**

For explicit channel selection:
```bash
nexhelper-set-reminder --text "Meeting" --time "14:00" --user "+491606301723" --channel whatsapp
```

## Natural Language Time Parsing

`nexhelper-set-reminder` supports multilingual time parsing via `nx_parse_relative_time`:

### Simple Formats
```
"5m"  → in 5 minutes
"1h"  → in 1 hour
"30s" → in 30 seconds
"1d"  → in 1 day
```

### German
```
"in 5 Minuten"      → in 5 minutes
"in einer Stunde"   → in 1 hour
"in 2 Stunden"      → in 2 hours
"morgen"            → tomorrow
"übermorgen"        → day after tomorrow
"in einer Woche"    → in 1 week
"halbe Stunde"      → in 30 minutes
```

### English
```
"in 5 minutes"     → in 5 minutes
"in an hour"        → in 1 hour
"tomorrow"          → tomorrow
"day after tomorrow" → in 2 days
"in one week"       → in 7 days
"half an hour"       → in 30 minutes
```

### ISO Timestamp
```
"2026-03-17T15:00:00"  → specific time
"2026-03-17T15:00:00Z" → UTC time
```

## Implementation

### Job JSON Structure (jobs.json)

```json
{
  "version": 1,
  "jobs": [
    {
      "id": "uuid-here",
      "name": "reminder-uuid",
      "createdAtMs": 1773779889000,
      "updatedAtMs": 1773779889000,
      "schedule": {
        "kind": "at",
        "at": "2026-03-17T14:00:00Z"
      },
      "sessionTarget": "isolated",
      "wakeMode": "now",
      "payload": {
        "kind": "agentTurn",
        "message": "⏰ ERINNERUNG: Meeting mit Müller"
      },
      "delivery": {
        "mode": "announce",
        "channel": "telegram",
        "to": "579539601"
      }
    }
  ]
}
```

### Canonical Reminder Structure

```json
{
  "reminder": {
    "id": "rem_abc123",
    "userId": "579539601",
    "text": "Meeting mit Müller",
    "datetime": "2026-03-10T14:00:00",
    "timezone": "Europe/Berlin",
    "created": "2026-03-09T10:30:00",
    "delivered": false,
    "cancelled": false
  }
}
```

## DSGVO Compliance

- ✅ Reminders stored per customer (isolated)
- ✅ Can be deleted by user
- ✅ Audit trail for reminder actions
- ✅ Automatic retention (via cron retention-job)
