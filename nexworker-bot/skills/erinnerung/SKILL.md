# Skill: Erinnerung (nexworker-erinnerung)

Setzt und verwaltet Erinnerungen für Baustellen-Termine.

## Nutzung

```bash
# Erinnerung setzen
nexworker-erinnerung add --text "Abnahme Baustelle Müller" --zeit "2026-03-25 10:00"

# Erinnerung in X Minuten
nexworker-erinnerung in --text "Baustelle anrufen" --minuten 30

# Heutige Erinnerungen
nexworker-erinnerung heute

# Erinnerung löschen
nexworker-erinnerung delete --id 123

# Hilfe
nexworker-erinnerung help
```

## Daten

Gespeichert in: `/app/storage/erinnerungen/`

Format: JSON
```json
{
  "erinnerungen": [
    {
      "id": "rem_123",
      "text": "Abnahme Baustelle Müller",
      "zeit": "2026-03-25T10:00:00",
      "status": "pending",
      "created": "2026-03-21T14:00:00"
    }
  ]
}
```

## Integration

Nutzt OpenClaw cron tool für zeitbasierte Erinnerungen.
Der Bot sendet eine Nachricht wenn die Erinnerung fällig wird.

## Beispiele für Erkennung

- "Erinnere mich in 30 Minuten an X"
- "Morgen um 10 Uhr ist Abnahme"
- "Nicht vergessen: Material bestellen"
