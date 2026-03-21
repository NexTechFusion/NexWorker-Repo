# Skill: Voice (nexworker-voice)

Transkribiert Sprachnachrichten zu Text mit whisper.cpp

## Nutzung

```bash
# Transkribiere Audio-Datei
nexworker-voice transcribe /path/to/audio.ogg

# Mit Modell-Pfad
WHISPER_CPP_MODEL=/models/ggml-base.bin nexworker-voice transcribe audio.ogg
```

## Integration

Der Agent ruft diesen Skill auf wenn:
- User eine Voice Message sendet
- Audio-Anhang erkannt wird

Das Script gibt den transkribierten Text zurück den der Agent dann weiterverarbeitet.

## Environment

- `WHISPER_CPP_MODEL` - Pfad zum whisper Model (default: /models/ggml-base.bin)
