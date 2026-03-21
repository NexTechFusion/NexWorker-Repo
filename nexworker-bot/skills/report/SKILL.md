# Skill: Report (nexworker-report)

Generiert Tagesberichte aus den erfassten Daten.

## Nutzung

```bash
# Tagesbericht für heute
nexworker-report heute

# Bericht für bestimmte Baustelle
nexworker-report baustelle --name "Schulze"

# Bericht für Datum
nexworker-report datum --date "2026-03-20"

# Kurzer Status
nexworker-report status
```

## Daten-Grundlage

Der Report fasst zusammen:
- Check-in/out Zeiten (aus `/app/storage/zeiterfassung/`)
- Material-Verbrauch (aus `/app/storage/material/`)
- Fotos (aus `/app/storage/fotos/`)

## Output

Markdown-Format:
```markdown
# Tagesbericht - 21.03.2026

## Baustelle: Schulze

### Arbeitszeit
- Thomas: 07:00 - 16:30 (8.5h)
- Pause: 30min

### Material
- 2x Kabel 10mm² = 240€
- Gesamt: 240€

### Fotos
- 14:30 Schaden an Kabeldose
- 15:00 Neuer Verteilerkasten

---
Erstellt: 21.03.2026 17:00
```

## Integration

Agent ruft auf bei:
- User fragt nach Tagesbericht
- User sagt "was hab ich heute gemacht?"
