# NexHelper v1 Spec - Entity Support & Proactivity

**Version:** 1.0  
**Scope:** Entity tagging + Budget alerts  
**Date:** 2026-03-13

---

## 1. Goals

Solve for multi-entity customers within single bot instance:

1. **Tag documents by entity** (Marketing, Engineering, etc.)
2. **Track budgets per entity** with alerts
3. **Filter queries/export by entity**
4. **Backwards compatible** with existing documents

---

## 2. Data Model

### Document Schema (v2)

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
  "tags": ["marketing", "q1", "reisekosten"],
  "entity": "marketing",
  "fileRef": "2026-03/photo_123.jpg",
  "extractedAt": "2026-03-13T08:00:00Z",
  "source": "telegram"
}
```

**Notes:**
- `entity` = primary entity (string) - for filtering
- `tags` = flexible labels (array) - for categorization
- If no entity: store as `null` or `"default"`
- Existing docs without entity → treated as `"default"`

---

## 3. Entity Config

### config/entities.yaml

```yaml
# Entity definitions for this customer
# Entities = special tags with budgets attached

entities:
  - id: default
    name: "Uncategorized"
    budget: null  # No budget tracking
    aliases: []
    active: true

  - id: marketing
    name: "Marketing Dept"
    budget: 5000
    budgetPeriod: monthly
    aliases: ["@marketing", "!mkt", "marketing"]
    active: true
    notifyOnOverBudget: true
    notifyChannel: telegram

  - id: engineering
    name: "Engineering"
    budget: 15000
    budgetPeriod: monthly
    aliases: ["@engineering", "!eng", "engineering"]
    active: true
    notifyOnOverBudget: true
    notifyChannel: telegram

  - id: travel
    name: "Reisekosten"
    budget: 2000
    budgetPeriod: quarterly
    aliases: ["@travel", "!reise"]
    active: false  # Disabled entities still exist for historical data
```

**Design Decisions:**
- `aliases` = recognized entity mentions in messages
- `active` = whether new documents can be tagged to this entity
- `budgetPeriod` = monthly | quarterly | yearly | null

---

## 4. Entity Detection

### Flow: How to assign entity to document

```
Document received
        │
        ▼
┌──────────────────────┐
│ 1. Check message     │
│    for entity alias  │
└────────┬─────────────┘
         │
    ┌────┴────┐
    │ Found?  │
    └────┬────┘
      Yes │ No
    ┌─────┴─────┐    ┌──────────────────┐
    ▼           │    │ 2. Check config │
┌───────────┐   │    │    for default  │
│ Use alias │   │    │    entity       │
│ as entity │   │    └────────┬─────────┘
└───────────┘   │             │
                │        ┌────┴────┐
                │        │ Has     │
                │        │ default?│
                │        └────┬────┘
                │         Yes │
                │    ┌────────┴────────┐
                │    ▼                 ▼
                │ ┌──────────┐  ┌────────────┐
                │ │Use default│  │Ask user:   │
                │ └──────────┘  │"Which entity?"│
                │                └────────────┘
```

### Detection Priority:

1. **Explicit mention** in message: "Rechnung für Marketing" → entity=marketing
2. **Alias match** in message text: "@marketing" → entity=marketing  
3. **Supplier match**: Supplier known to belong to entity (future: supplier mapping)
4. **Default entity** from config
5. **Ask user**: "Welche Abteilung?" with quick-reply buttons

---

## 5. Storage Structure

### storage/entities/

```
storage/
├── entities/
│   ├── _registry.json         # Entity configs (loaded from entities.yaml + runtime state)
│   │
│   ├── marketing/
│   │   ├── stats.json         # Budget tracking
│   │   │   {
│   │   │     "period": "2026-03",
│   │   │     "spent": 2300.00,
│   │   │     "budget": 5000.00,
│   │   │     "transactions": ["doc_abc", "doc_def"]
│   │   │   }
│   │   │
│   │   └── suppliers.json     # Known suppliers for this entity
│   │     ["Müller KG", "Büro Plus", "Amazon Business"]
│   │
│   └── engineering/
│       ├── stats.json
│       └── suppliers.json
│
└── memory/
    └── YYYY-MM-DD.md          # Document records (unchanged)
```

### Why files over SQLite (v1):

- Simpler to implement
- Human-readable for debugging
- Easy backup/migration
- Can migrate to SQLite later if queries become painful

---

## 6. Commands (Entity-Aware)

| Command | Behavior |
|---------|----------|
| `/export` | Export all documents |
| `/export @marketing` | Export only marketing documents |
| `/export @engineering --since 2026-01` | Filtered export |
| `/stats` | Show all entity stats |
| `/stats @marketing` | Show specific entity |
| `/entity` | List available entities |
| `/entity set marketing` | Set default entity for future docs |
| `/budget` | Show all budgets + alerts |
| `/budget @marketing` | Show specific budget |

---

## 7. Budget Alerts

### Cron Job: budget-check

**Schedule:** Every hour (configurable)

**Logic:**

```python
for entity in active_entities:
    if entity.budget and entity.notifyOnOverBudget:
        current = calculate_spending(entity, entity.budgetPeriod)
        percentage = current / entity.budget
        
        if percentage >= 100:
            alert = "🚨 BUDGET EXCEEDED"
        elif percentage >= 90:
            alert = "⚠️ 90% reached"
        elif percentage >= 75:
            alert = "⚡ 75% reached"
        
        if alert and not already_notified_this_period(alert):
            send_notification(entity.notifyChannel, alert)
```

**Alert Thresholds:** 75%, 90%, 100%

**Cooldown:** One alert per threshold per period (don't spam)

---

## 8. Query Filtering

### How entity context applies:

**User says:** "Zeig mir alle Rechnungen"

**Agent does:**
1. Read config/entities.yaml
2. Check if user set default entity (stored in USER.md or session)
3. If entity context exists → filter memory_search by entity tag
4. Return filtered results

**User says:** "Zeig mir alle Rechnungen für Marketing"

**Agent does:**
1. Detect "Marketing" → entity=marketing
2. Filter by entity=marketing
3. Return results

---

## 9. Migration (Existing Customers)

### For customers upgrading to v1:

1. **Create config/entities.yaml** with single default entity:
   ```yaml
   entities:
     - id: default
       name: "Default"
       budget: null
       aliases: []
       active: true
   ```

2. **Existing documents** → entity field = null (treated as "default" for queries)

3. **Optionally:** Run entity detection on historical docs to retroactively tag

---

## 10. What's NOT in v1

| Feature | Reason | v2? |
|---------|--------|-----|
| Supplier mapping to entities | Needs historical data | Yes |
| Entity-level permissions | Complexity | Maybe |
| Multi-currency | EUR only for German KMU | Maybe |
| SQLite migration | Files sufficient for now | If needed |
| Auto-reminders from dates | Separate feature | Yes |
| Weekly digest | Separate feature | Yes |

---

## 11. Implementation Order

1. ✅ Document schema v2 (add entity field)
2. ⬜ Config loader for entities.yaml
3. ⬜ Entity detection (alias matching)
4. ⬜ Document storage with entity tag
5. ⬜ Entity filtering in queries
6. ⬜ Budget stats calculation
7. ⬜ Budget alert cron job
8. ⬜ Entity-aware commands
9. ⬜ Migration script for existing customers

---

## 12. Open Questions

- [ ] Should entity be required or optional per document?
- [ ] How to handle documents that span multiple entities (split amounts)?
- [ ] Budget reset on new period - archive old stats or overwrite?
- [ ] Language per entity (German vs English responses)?
