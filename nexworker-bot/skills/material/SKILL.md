# Skill: Material (nexworker-material)

Erfasst Materialverbrauch auf Baustellen.

## Nutzung

```bash
# Material hinzufügen
nexworker-material add --material "Kabel 10mm²" --menge 2 --einheit "Rollen" --preis 120 --baustelle "Schulze"

# Material einer Baustelle
nexworker-material list --baustelle "Schulze"

# Gesamtkosten einer Baustelle
nexworker-material costs --baustelle "Schulze"

# Material suchen
nexworker-material search --query "Kabel"
```

## Daten

Gespeichert in: `/app/storage/material/`

Format: JSON
```json
{
  "materialien": [
    {
      "id": "mat_001",
      "datum": "2026-03-21",
      "baustelle": "Schulze",
      "material": "Kabel 10mm²",
      "menge": 2,
      "einheit": "Rollen",
      "preis": 120,
      "user": "Thomas"
    }
  ]
}
```

## Integration

Agent erkennt bei Nachrichten wie:
- "2 Rollen Kabel 10mm², 240 Euro"
- "Material: 5m Rohr, 50€"
