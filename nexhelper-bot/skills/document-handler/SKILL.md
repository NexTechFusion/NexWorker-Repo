# Skill: document-handler

Handles document receipt, entity detection, and budget updates.

## Description

Processes incoming documents:
1. Normalize and validate extracted metadata
2. Resolve entity through AI classifier
3. Deduplicate via canonical fingerprint and file hash
4. Persist canonical JSON as source of truth
5. Update entity budget
6. Mirror summary to memory if needed

## Usage

```bash
# Process a document
nexhelper-doc store --type rechnung --amount 1234.56 --supplier "Müller GmbH" --number RE-2026-0342 --date 2026-03-12 --file /path/to/doc.pdf --source-text "Rechnung für Marketing" --idempotency-key evt_123

# Query with entity filter
nexhelper-doc search --query "Rechnung" --entity marketing --semantic true

# List recent documents
nexhelper-doc list --limit 10
```

## Integration

Called by agent when user sends a document:

```
User sends: [Invoice PDF] + "Rechnung für Marketing"

Agent calls:
1. image/pdf tool → extract data
2. nexhelper-entity detect "Rechnung für Marketing" → {"entity":"marketing","confidence":...}
3. nexhelper-doc store --type rechnung --amount 1234.56 --entity marketing --idempotency-key <event-id>
4. nexhelper-entity spend marketing 1234.56
```

## Document Schema (v2)

```json
{
  "id": "doc_abc123",
  "type": "rechnung|angebot|lieferschein|gutschrift|quittung|sonstiges",
  "number": "RE-2026-0342",
  "supplier": "Müller GmbH",
  "amount": 1234.56,
  "currency": "EUR",
  "date": "2026-03-12",
  "dueDate": "2026-03-26",
  "category": "Büromaterial",
  "entity": "marketing",
  "tags": ["marketing", "q1"],
  "fileRef": "2026-03/photo_123.jpg",
  "extractedAt": "2026-03-13T08:00:00Z",
  "source": "telegram"
}
```
