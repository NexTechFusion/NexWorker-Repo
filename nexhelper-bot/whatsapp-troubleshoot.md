# WhatsApp Troubleshooting Guide

## Issue: 401 Unauthorized Errors After QR Scan

### Symptoms
- QR code scans successfully
- Phone shows "logging in..."
- Connection immediately fails with 401 Unauthorized
- Error locations: `rva`, `frc`, `cco`, `odn`
- Dashboard shows: `Linked: Yes, Running: No, Connected: No`

### Root Cause
- **Stale sessions** on WhatsApp's side from previous failed attempts
- Multiple QR scans that left "ghost" linked devices
- WhatsApp rejecting new connections because old sessions were still registered
- Corrupted auth state in `~/.openclaw/credentials/whatsapp/`

---

## The Fix (3 Steps)

### Step 1: Remove All Linked Devices on Phone

This is the **critical step**.

1. Open **WhatsApp** on your phone
2. Go to **Settings → Linked Devices**
3. **Remove ALL linked devices** (especially any "OpenClaw" or "Browser" entries)

### Step 2: Wipe Credentials on Server

Run these commands on the gateway host:

```bash
# Logout from WhatsApp
openclaw channels logout --channel whatsapp

# Delete all credential files
rm -rf ~/.openclaw/credentials/whatsapp/*
```

### Step 3: Fresh QR Scan

```bash
# Generate new QR
openclaw channels login --channel whatsapp

# Scan immediately (within 60 seconds!)
```

---

## Verification

Check status:

```bash
openclaw channels status --probe
```

Expected output:
```
- WhatsApp default: enabled, configured, linked, running, connected
```

---

## Summary Table

| Step | Action | Why It Mattered |
|------|--------|-----------------|
| 1 | Remove all linked devices on phone | Killed competing sessions |
| 2 | Wipe credentials on server | Cleared corrupted auth state |
| 3 | Fresh QR + immediate scan | Clean pairing without conflicts |

---

## Quick Reference: Error Codes

| Code | Location | Meaning |
|------|----------|---------|
| 401 | `rva` | Session conflict |
| 401 | `frc` | Failed reconnection |
| 401 | `cco` | Connection conflict |
| 401 | `odn` | On-device network issue |
| 408 | - | QR scan timeout |
| 515 | - | Stream connection error |

---

## Prevention Tips

1. **Don't retry multiple times** — Each failed scan may extend rate limits
2. **Wait 24-48 hours** if you hit rate limits
3. **Always clear linked devices first** before re-scanning
4. **Scan within 60 seconds** of QR appearing

---

## Related Docs

- https://coclaw.com/troubleshooting/solutions/whatsapp-401-no-cookie-auth-credentials/
- https://coclaw.com/troubleshooting/solutions/whatsapp-login-timeout-408-websocket-error/
- https://coclaw.com/guides/whatsapp-setup/

---

## Date
March 16, 2026 — Resolved for NexHelper AL TG Bot (+447575435104)
