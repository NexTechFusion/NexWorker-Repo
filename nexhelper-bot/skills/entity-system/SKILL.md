# Skill: entity-system

Entity management for multi-department document tracking.

## Description

Manages entities (departments, cost centers) with budgets and aliases. Enables:
- AI-based entity detection from message text
- Document tagging by entity
- Budget tracking and alerts
- Entity-aware queries and exports

## Config

```yaml
# config/entities.yaml
entities:
  - id: default
    name: "Default"
    budget: null
    aliases: []
    active: true

  - id: marketing
    name: "Marketing Dept"
    budget: 5000
    budgetPeriod: monthly
    aliases: ["@marketing", "!mkt", "marketing"]
    active: true
    notifyOnOverBudget: true
```

## Storage

```
storage/
├── entities/
│   ├── _registry.json       # Cached entity config
│   ├── marketing/
│   │   ├── stats.json       # {"period": "2026-03", "spent": 2300, "budget": 5000}
│   │   └── suppliers.json   # ["Supplier A", "Supplier B"]
```

## Actions

### 1. Detect Entity

Input: message text
Output: JSON with entity, confidence, action

```bash
# Detect entity from text
nexhelper-entity detect "Rechnung für Marketing"
# Returns: {"entity":"marketing","confidence":0.94,"action":"execute"}
```

### 2. Tag Document

Input: document, entity_id
Output: updated document

```bash
# Tag document with entity
nexhelper-entity tag doc_123 marketing
```

### 3. Get Budget Status

Input: entity_id
Output: budget stats

```bash
# Get budget for entity
nexhelper-entity budget marketing
# Returns: {"period": "2026-03", "spent": 2300, "budget": 5000, "remaining": 2700, "percent": 46}
```

### 4. Update Budget

Input: entity_id, amount, operation (add/subtract)
Output: updated stats

```bash
# Add expense to budget
nexhelper-entity spend marketing 150.00
# Subtract credit
nexhelper-entity spend marketing -50.00
```

### 5. Check Budget Alerts

Input: none (cron job)
Output: alert messages

```bash
# Check all entities for over-budget
nexhelper-entity check-budgets
# Returns: [] if all ok, or [{"entity": "marketing", "alert": "90%", ...}]
```

### 6. List Entities

Input: none
Output: entity list

```bash
nexhelper-entity list
# Returns: [{"id": "default", "name": "Default", ...}, ...]
```

## Classification Context

Aliases are context signals for the classifier, not hard routing rules:

```
"Rechnung für [entity]" → entity = entity
"[entity] Rechnung" → entity = entity
"@marketing" → entity = marketing
"!mkt" → entity = marketing
"[entity] Angebot" → entity = entity
```

## Cron Jobs

```yaml
- name: "entity-budget-check"
  schedule: "cron: 0 * * * *"
  # Checks budgets hourly, sends alerts
```

## Integration

The agent (OpenClaw) uses this skill via:

1. **On document receipt**: Call `detect` → if entity found, auto-tag
2. **On query**: Check for entity in query → filter by entity
3. **On cron**: Call `check-budgets` → send notifications
