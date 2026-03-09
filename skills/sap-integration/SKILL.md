# Skill: sap-integration

Integration with SAP ERP systems for document export.

## Description

This skill enables OpenClaw to export documents and data to SAP ERP systems via APIs or file-based integration.

## Features

- ✅ Export invoices to SAP
- ✅ Export purchase orders
- ✅ Create vendor master data
- ✅ Synchronize document status

## Prerequisites

- SAP S/4HANA or SAP ERP system
- API access (OData or IDoc)
- Or: SAP PI/PO integration

## Configuration

```bash
# SAP API Configuration
SAP_API_URL=https://sap.company.com/sap/opu/odata/sap/
SAP_API_USER=INTEGRATION_USER
SAP_API_PASS=your-password
SAP_CLIENT=100
SAP_LANGUAGE=DE
```

## Integration Methods

### 1. OData API (Recommended)

Modern SAP systems expose OData APIs:

```bash
# Create supplier invoice
curl -X POST \
  "${SAP_API_URL}API_SUPPLIERINVOICE_SRV/A_SupplierInvoice" \
  -u "${SAP_API_USER}:${SAP_API_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "CompanyCode": "1000",
    "DocumentDate": "2026-03-09",
    "PostingDate": "2026-03-09",
    "SupplierInvoiceIDByCompany": "RE-2026-123",
    "Supplier": "100001",
    "AmountInCompanyCodeCurrency": "450.00"
  }'
```

### 2. IDoc/File Interface

For legacy systems, use IDoc files:

```bash
# Generate IDoc file
./export_sap_idoc.sh invoice.json > INVOICE.idoc

# Upload to SAP directory
scp INVOICE.idoc sap-server:/usr/sap/IDOC/IN/
```

## Actions

### Export Invoice to SAP

```
User: "Buche diese Rechnung in SAP"
Bot:  "📤 Exportiere nach SAP..."
      "✅ Rechnung RE-123 in SAP gebucht (Belegnr: 500001234)"
```

### Check Vendor in SAP

```
User: "Prüfe Lieferant Müller in SAP"
Bot:  "🔍 Suche in SAP..."
      "✅ Lieferant gefunden:
      - Nr: 100001
      - Name: Müller GmbH
      - IBAN: DE89..."
```

## Supported Objects

| Object | OData API | IDoc |
|--------|-----------|------|
| Supplier Invoice | ✅ | ✅ |
| Purchase Order | ✅ | ✅ |
| Vendor Master | ✅ | ✅ |
| Customer Master | ✅ | ✅ |
| Material Master | ✅ | ✅ |
| Journal Entry | ✅ | ✅ |

## Scripts

- `export_sap_odata.sh` - OData API export
- `export_sap_idoc.sh` - IDoc file generation
- `sap_lookup_vendor.sh` - Vendor lookup
- `sap_test_connection.sh` - Connection test

## Error Handling

```bash
# Common SAP errors
HTTP 401 → Authentication failed
HTTP 404 → Object not found
HTTP 400 → Invalid data
HTTP 500 → SAP system error
```

## DSGVO Compliance

- ✅ Data encrypted in transit (HTTPS)
- ✅ Audit trail for all exports
- ✅ User confirmation required
- ✅ No personal data stored locally after sync

## Status

⚠️ **Beta** - Requires customer-specific SAP configuration
