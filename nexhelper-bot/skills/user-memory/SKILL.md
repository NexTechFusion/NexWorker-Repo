# Skill: user-memory

Per-User Memory und Session-History für NexHelper.

## Description

Speichert User-spezifische Daten:
- Session Messages (letzte 50)
- Facts/Preferences (was User mag, weiß, etc.)

## Storage

```
storage/users/{user_id}/session.json
```

## Commands

```bash
# Message hinzufügen
nexhelper-user-memory add-message --user "579539601" --role "user" --content "Was ist Python?"

# Fact speichern
nexhelper-user-memory set-fact --user "579539601" --key "food" --value "Pizza"

# Facts holen
nexhelper-user-memory get-facts --user "579539601"

# Letzte Messages holen
nexhelper-user-memory get-recent --user "579539601" --count 10

# Suchen
nexhelper-user-memory search --user "579539601" --query "pizza"

# User-Daten löschen (GDPR)
nexhelper-user-memory delete --user "579539601"
```

## Output Contract

Alle Commands return JSON.

## Integration

Wird vom Classifier getriggert wenn User "Merke dir..." sagt.
Wird von Main-Bot genutzt um Context für LLM zu laden.
