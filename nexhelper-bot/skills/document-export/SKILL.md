# Skill: document-export

Export documents to various formats and external systems (DATEV, SAP, Lexware, Email).

## Description

This skill enables OpenClaw to export processed documents to external accounting and ERP systems commonly used by German KMU.

## Supported Export Targets

| Target | Format | Use Case |
|--------|--------|----------|
| DATEV | CSV/DTVF | Accounting export |
| SAP | XML/IDoc | ERP integration |
| Lexware | CSV | Accounting software |
| Email | PDF attachment | Manual forwarding |
| Cloud | S3/GCS | Backup/archive |

## Actions

### 1. Export to DATEV

Creates DATEV-compatible CSV files for import into DATEV Unternehmen online.

```bash
# Trigger via command
/export datev [date-range]
```

**Generated Files:**
- `EXTF_Buchungsstapel.csv` - Booking records
- `EXTF_Kontenbeschriftungen.csv` - Account labels

### 2. Export to SAP

Creates SAP-compatible XML files for ERP import.

```bash
# Trigger via command
/export sap [document-id]
```

### 3. Export to Lexware

Creates Lexware-compatible CSV for import.

```bash
# Trigger via command
/export lexware [date-range]
```

### 4. Export via Email

Sends documents as PDF attachments.

```bash
# Trigger via command
/export email to@example.com [document-ids]
```

### 5. Export to Cloud Storage

Uploads to S3-compatible storage.

```bash
# Trigger via command
/export s3 bucket-name [document-ids]
```

## Tools Used

- `read` - Read document data from storage
- `write` - Generate export files
- `exec` - Execute API calls and scripts

## Configuration

Add to customer's `config.yaml`:

```yaml
export:
  datev:
    enabled: true
    beraterNr: "123456"
    mandantenNr: "78900"
    sachkontenlaenge: 4
    
  sap:
    enabled: false
    apiUrl: "${SAP_API_URL}"
    apiKey: "${SAP_API_KEY}"
    
  lexware:
    enabled: false
    
  email:
    enabled: true
    smtp:
      host: "${SMTP_HOST}"
      port: 587
      user: "${SMTP_USER}"
      pass: "${SMTP_PASS}"
      
  s3:
    enabled: false
    endpoint: "${S3_ENDPOINT}"
    bucket: "${S3_BUCKET}"
    accessKey: "${S3_ACCESS_KEY}"
    secretKey: "${S3_SECRET_KEY}"
```

## Environment Variables

```bash
# Email (optional)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=nexhelper@example.com
SMTP_PASS=your-password

# SAP (optional)
SAP_API_URL=https://sap.example.com/api
SAP_API_KEY=your-api-key

# S3 (optional)
S3_ENDPOINT=https://s3.example.com
S3_BUCKET=nexhelper-docs
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
```

## Example Usage

### In conversation:

```
User: "Exportiere alle Rechnungen von März nach DATEV"
Bot:  "Ich exportiere 23 Rechnungen nach DATEV..."
      [Generiert DATEV-CSV]
      "✅ Exportiert: EXTF_Buchungsstapel.csv (23 Buchungen)"
```

### Via command:

```
User: /export datev 2026-03
Bot:  "📊 DATEV-Export für März 2026:
       - 23 Rechnungen
       - Gesamtbetrag: €12.450,00
       ✅ Datei: EXTF_Buchungsstapel.csv"
```

## Scripts

- `export_datev.sh` - DATEV CSV generator
- `export_sap.sh` - SAP XML generator
- `export_lexware.sh` - Lexware CSV generator
- `send_email.sh` - Email sender
- `upload_s3.sh` - S3 uploader

## Data Flow

```
Canonical Document Store
      ↓
Read documents
      ↓
Transform to target format
      ↓
Generate file / Call API
      ↓
Confirm to user
      ↓
Audit log entry with operation id
```

## DSGVO Compliance

- ✅ Documents stay on EU servers
- ✅ Export logged in audit trail
- ✅ User consent checked before export
- ✅ Sensitive data encrypted in transit
