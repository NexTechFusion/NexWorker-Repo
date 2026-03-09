# Skill: email-sender

Send emails via SMTP from OpenClaw.

## Description

This skill enables OpenClaw to send emails with optional attachments, useful for document forwarding, notifications, and alerts.

## Features

- ✅ Send plain text emails
- ✅ Send HTML emails
- ✅ Attach files (PDFs, images, etc.)
- ✅ Multiple recipients
- ✅ CC/BCC support
- ✅ Template support

## Actions

### 1. Send Document

```
User: "Sende diese Rechnung an buchhaltung@firma.de"
Bot:  "📧 Sende Rechnung an buchhaltung@firma.de..."
      "✅ Email versendet!"
```

### 2. Send Notification

```
User: "Informiere das Team über den neuen Kunden"
Bot:  "📧 Sende Email an team@firma.de..."
      "✅ Benachrichtigung versendet!"
```

### 3. Send Report

```
User: "Sende den Monatsbericht an chef@firma.de"
Bot:  "📊 Erstelle Bericht..."
      "📧 Sende an chef@firma.de..."
      "✅ Bericht versendet!"
```

## Configuration

Add to customer's `.env`:

```bash
# SMTP Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=nexhelper@yourcompany.com
SMTP_PASS=your-app-password
SMTP_FROM=NexHelper <nexhelper@yourcompany.com>

# Optional: Default recipients
EMAIL_DEFAULT_TO=buchhaltung@company.com
EMAIL_CC=backup@company.com
```

## Commands

| Command | Description |
|---------|-------------|
| `/email <to> <text>` | Send email |
| `/email doc <doc-id> <to>` | Send document |
| `/email template <name>` | Use template |

## Templates

Templates are stored in:

```
config/email-templates/
├── welcome.md
├── invoice.md
├── report.md
└── notification.md
```

### Example Template

```markdown
# Template: invoice

Subject: Rechnung {{invoice_number}} - {{company_name}}

Guten Tag {{recipient_name}},

anbei erhalten Sie die Rechnung {{invoice_number}}.

Rechnungsbetrag: {{amount}}
Fälligkeitsdatum: {{due_date}}

Mit freundlichen Grüßen
{{sender_name}}
```

## DSGVO Compliance

- ✅ Emails are logged in audit trail
- ✅ Recipient must be approved
- ✅ User consent required
- ✅ No automatic mailing without confirmation

## Security

- ✅ TLS encryption for SMTP
- ✅ App passwords recommended (not main password)
- ✅ Rate limiting to prevent spam
- ✅ Attachment size limit (default: 10MB)

## Rate Limits

Default limits to prevent spam:

- **Per minute**: 5 emails
- **Per hour**: 20 emails
- **Per day**: 100 emails

## Error Handling

```bash
# Common SMTP errors
535 5.7.8  → Authentication failed (check user/pass)
550 5.1.1  → Recipient not found
552 5.3.4  → Message too large
554 5.7.1  → Blocked by spam filter
```

## Example Usage

### Via Script

```bash
./send_email.sh \
    buchhaltung@firma.de \
    "Neue Rechnung" \
    "Im Anhang finden Sie die neue Rechnung." \
    /path/to/rechnung.pdf
```

### Via OpenClaw

```
User: "Sende die letzte Rechnung an buchhaltung@firma.de"
Bot:  "📧 Letzte Rechnung gefunden: RE-2026-03-123
      Empfänger: buchhaltung@firma.de
      
      Bestätigen? [Ja/Nein]"
User: "Ja"
Bot:  "✅ Email versendet!"
```
