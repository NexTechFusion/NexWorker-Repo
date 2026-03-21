# NexWorker RAG Skill

**Zweck:** Durchsuche die Firmen-Wissensbasis bevor du antwortest.

## Wissensbasis

Alle Dokumente liegen in:
```
/root/.openclaw/nexworker-demogmbh-bot/storage/wissensbasis/
```

Dokumente:
- `faq.md` - Häufige Fragen (Urlaub, Kontakte, Standards)
- `baupvo.md` - BauPVO Kurzübersicht
- Alle weiteren PDFs und MD-Dateien

## Verfügbare Tools

### Suchen (Tool: `nexworker-rag-search`)
```bash
python3 /root/.openclaw/nexworker-demogmbh-bot/nexworker_rag.py search --query "DEINE_FRAGE" --top-k 3
```

### Neu indexieren (Tool: `nexworker-rag-index`)
```bash
python3 /root/.openclaw/nexworker-demogmbh-bot/nexworker_rag.py index
```

## Workflow

1. **User fragt etwas** → Erst suchen in Wissensbasis
2. **Wenn relevant gefunden** → Zitieren + Zusammenfassung
3. **Wenn nix gefunden** → Aus General-Wissen antworten

## Beispiel

User: "Was ist die Pflicht für FI-Schutz?"
→ Suchen: `python3 .../nexworker_rag.py search --query "FI Schutzschalter Pflicht"`
→ Ergebnis: "Laut BauPVO sind FI-Schutzschalter vorgeschrieben..."
