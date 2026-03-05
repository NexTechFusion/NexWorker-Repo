# NexWorker Visualization: The "Hybrid Sync" Strategy

Combine lightweight chat feedback (ASCII) with deep office management (Google Sheets).

## 🛠️ Part 1: ASCII Live-Status (The Worker's Feedback)
Whenever a worker sends a report, NexWorker replies with a structured ASCII snippet. This provides immediate confirmation and professional polish within the chat bubble.

**Example Reply:**
```text
✅ Bericht erfasst: [Kunde Müller]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👷 Wer:     Lars & Axel
📍 Ort:      Neubau Allee, Etage 2
🛠️ Arbeit:  Steckdosen montiert (22 Stk.)
📦 Mat:     3x NYM-J 3x1.5 (Trommel)
⏱️ Zeit:     08:00 - 16:30 (8.5h)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 Daten wurden ins Büro übertragen.
```

## 📊 Part 2: Google Sheets Synchronization (The Office Backend)
NexWorker acts as a real-time data entry clerk. Every chat event is appended to a Central Google Sheet or Excel Online via a webhook or API integration.

### Sheet Architecture (Tab: "Bautagebuch_2026")
| Zeitstempel | Projekt | Monteur | Tätigkeit | Material | Status | Link zum Foto |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 05.03. 16:30 | Müller | Axel | Montage ELT | NYM-J | ✅ Erledigt | [IMG_421.jpg] |
| 05.03. 14:15 | Allee | Lars | Trockenbau | - | ⚠️ Blockiert | [IMG_422.jpg] |

### Operational Benefits:
1.  **Zero Data Entry:** The office admin no longer has to type out handwritten notes.
2.  **Searchable History:** Filter by worker to calculate hours or by project to calculate costs.
3.  **Automatic Billing:** Connect the Sheet to Zapier or Make to generate an invoice as soon as a project is marked "✅ Erledigt".

---

## 🚀 Implementation for Pilot:
1.  **Script:** `tools/sync_to_sheets.py` — A simple Python script in the repo that takes the JSON output of NexWorker and appends it to a CSV/Sheet.
2.  **Prompt:** Update `System-Prompt.md` to format its final confirmation in the ASCII style shown above.
