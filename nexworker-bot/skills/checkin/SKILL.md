# Skill: Check-in (nexworker-checkin)

Erfasst Arbeitszeiten: wann startet wer auf welcher Baustelle.

## Nutzung

```bash
# Check-in (Arbeitsbeginn)
nexworker-checkin in --zeit "07:00" --baustelle "Baustelle Müller"

# Check-out (Feierabend)
nexworker-checkin out --zeit "16:30"

# Status anzeigen
nexworker-checkin status

# Heutige Zeiten anzeigen
nexworker-checkin heute

# Für User (wird aus Nachricht extrahiert)
nexworker-checkin in --user "Thomas" --zeit "07:00" --baustelle "Schulze"
```

## Daten

Gespeichert in: `/app/storage/zeiterfassung/`

Format: JSON pro Tag
```json
{
  "datum": "2026-03-21",
  "eintraege": [
    {
      "user": "Thomas",
      "baustelle": "Schulze",
      "start": "07:00",
      "ende": null,
      "pausen": 0
    }
  ]
}
```

## Integration

Agent ruft auf bei Nachrichten wie:
- "Bin auf Baustelle X, Start 7 Uhr"
- "Feierabend"
- "Check-in"
- "Wo bin ich gerade?"
