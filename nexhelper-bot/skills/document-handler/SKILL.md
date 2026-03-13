# Skill: document-handler

Handles document receipt, entity detection, and budget updates.

## Description

Processes incoming documents:
1. Extract entity from message text
2. Analyze document (image/PDF)
3. Extract key data (amount, date, supplier)
4. Tag with entity
5. Update entity budget
6. Store in memory

## Usage

```bash
# Process a document
nexhelper-doc handle --file /path/to/doc.pdf --message "Rechnung für Marketing"

# Query with entity filter
nexhelper-doc search "Rechnung" --entity marketing

# List recent documents
nexhelper-doc list --entity marketing --limit 10
```

## Integration

Called by agent when user sends a document:

```
User sends: [Invoice PDF] + "Rechnung für Marketing"

Agent calls:
1. image/pdf tool → extract data
2. nexhelper-entity detect "Rechnung für Marketing" → "marketing"  
3. nexhelper-doc store --type rechnung --amount 1234.56 --entity marketing
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
