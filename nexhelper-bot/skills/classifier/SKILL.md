# Skill: classifier

AI-first intent and entity classification for NexHelper workflows.

## Description

Provides strict JSON outputs for:
- Intent classification
- Entity detection
- Candidate reranking for search relevance

## Commands

```bash
nexhelper-classify intent --text "Erinnere mich morgen an Angebot"
nexhelper-classify entity --text "Rechnung für Marketing" --entities-json '["default","marketing"]'
nexhelper-classify rerank --query "Müller Rechnung März" --candidates-json '[{"id":"doc_1","text":"..."}]'
```

## Output Contract

All commands return machine-readable JSON and no additional prose.

## Fallback Behavior

If API calls fail, command returns low-confidence fallback JSON with `action: "clarify"`.
