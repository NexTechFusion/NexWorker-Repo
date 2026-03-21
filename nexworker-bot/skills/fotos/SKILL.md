# Skill: Fotos (nexworker-fotos)

Dokumentiert Fotos von der Baustelle mit Metadaten.

## Nutzung

```bash
# Foto speichern mit Tags
nexworker-fotos add --file /path/to/photo.jpg --baustelle "Schulze" --beschreibung "Schaden an Kabel"

# Foto-Index durchsuchen
nexworker-fotos search --query "Schaden"

# Alle Fotos einer Baustelle
nexworker-fotos list --baustelle "Schulze"

# Fotos von heute
nexworker-fotos heute
```

## Daten

Gespeichert in: `/app/storage/fotos/{datum}/`

Metadata: `/app/storage/fotos/index.json`
```json
{
  "fotos": [
    {
      "id": "foto_001",
      "datum": "2026-03-21",
      "uhrzeit": "14:30",
      "baustelle": "Schulze",
      "beschreibung": "Schaden an Kabel",
      "file": "2026-03/foto_schulze_001.jpg",
      "user": "Thomas"
    }
  ]
}
```

## Integration

Agent ruft auf bei:
- User schickt Foto mit Beschreibung
- User fragt nach Fotos von Baustelle X
