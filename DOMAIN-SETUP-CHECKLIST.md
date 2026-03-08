# NexWorker Domain Setup Checklist
## Schritt für Schritt zur fertigen Website auf nexworker.de

**Domain:** nexworker.de (bei hostinger.de gekauft)  
**Ziel:** Website live schalten mit vollständiger SEO-Infrastruktur

---

## Phase 1: DNS & Hosting (Bei Hostinger)

### Schritt 1.1: Hosting-Plan prüfen
- [ ] Logge dich bei hostinger.de ein
- [ ] Prüfe: Hast du einen Hosting-Plan oder nur die Domain?
- [ ] Falls nur Domain: Hosting hinzubuchen (Single Shared Hosting ~2€/Monat)
- [ ] Falls Hosting vorhanden: Weiter zu Schritt 1.2

### Schritt 1.2: Domain mit Hosting verbinden
- [ ] Im Hostinger-Dashboard: "Hosting" → "Domains"
- [ ] "Add Website" oder Domain zuweisen
- [ ] nexworker.de als Hauptdomain festlegen
- [ ] Warte auf DNS-Propagation (bis 24h, meist 1-2h)

### Schritt 1.3: SSL-Zertifikat aktivieren
- [ ] Im Hosting-Dashboard: "SSL" oder "Security"
- [ ] "Free SSL" oder "Let's Encrypt" aktivieren
- [ ] HTTPS erzwingen (Auto-Redirect HTTP → HTTPS)
- [ ] Warte auf SSL-Aktivierung (meist automatisch)

### Schritt 1.4: Subdomains (Optional)
- [ ] www.nexworker.de auf Hauptdomain umleiten
- [ ] Falls Blog geplant: blog.nexworker.de (später)

---

## Phase 2: Website hochladen

### Schritt 2.1: FTP/SFTP-Zugang einrichten
- [ ] Im Hostinger-Dashboard: "Files" → "FTP Accounts"
- [ ] FTP-Credentials notieren:
  - Host: ftp.hostinger.de (oder server IP)
  - Username: [wird angezeigt]
  - Password: [selbst gesetzt]
  - Port: 21 (FTP) oder 22 (SFTP)

### Schritt 2.2: Dateien hochladen

**Option A: Via File Manager (Hostinger-Dashboard)**
- [ ] "Files" → "File Manager"
- [ ] Ordner `public_html` öffnen
- [ ] Alle Dateien aus `/root/.openclaw/workspace/NexWorker-Repo/` hochladen

**Option B: Via FTP-Client (FileZilla, Cyberduck)**
- [ ] FTP-Client öffnen
- [ ] Verbinden mit Hostinger-Credentials
- [ ] In Ordner `public_html` navigieren
- [ ] Alle Dateien hochladen

**Dateien zum Hochladen:**
```
/public_html/
├── index.html              (Homepage)
├── wissenssicherung-handwerk.html (Pillar Page 1)
├── llms.txt                (AI Crawler Info)
├── robots.txt              (Suchmaschinen-Steuerung)
├── sitemap.xml             (XML-Sitemap)
└── (weitere Pillar Pages folgen)
```

### Schritt 2.3: Dateiberechtigungen prüfen
- [ ] Alle HTML-Dateien: 644
- [ ] Alle Ordner: 755
- [ ] Im File Manager: Rechtsklick → "Permissions" / "Change Permissions"

---

## Phase 3: DNS-Records prüfen

### Schritt 3.1: A-Record setzen
- [ ] Im Hostinger-Dashboard: "DNS Zone Editor" oder "Domains" → "DNS"
- [ ] A-Record prüfen:
  ```
  Type: A
  Name: @
  Value: [Hostinger Server IP]
  TTL: 3600
  ```

### Schritt 3.2: www-Record setzen
- [ ] CNAME für www:
  ```
  Type: CNAME
  Name: www
  Value: nexworker.de
  TTL: 3600
  ```

### Schritt 3.3: DNS propagieren lassen
- [ ] Warte 1-24 Stunden
- [ ] Prüfen mit: https://dnschecker.org/#A/nexworker.de
- [ ] Website aufrufen: https://nexworker.de

---

## Phase 4: Google Search Console (GSC)

### Schritt 4.1: Google Account
- [ ] Google Account mit nexworker.de-Email erstellen (optional)
- [ ] Oder bestehenden Google Account nutzen

### Schritt 4.2: Search Console öffnen
- [ ] https://search.google.com/search-console
- [ ] "Jetzt starten" klicken

### Schritt 4.3: Property hinzufügen
- [ ] "URL-Präfix" wählen
- [ ] URL eingeben: `https://nexworker.de`
- [ ] "Weiter" klicken

### Schritt 4.4: Ownership verifizieren

**Option A: HTML-Datei (Empfohlen)**
- [ ] Google erstellt Verifizierungsdatei (z.B. `google1234567890.html`)
- [ ] Datei herunterladen
- [ ] In `public_html` hochladen
- [ ] "Bestätigen" klicken

**Option B: DNS-Record**
- [ ] Im Hostinger DNS-Editor
- [ ] TXT-Record hinzufügen:
  ```
  Type: TXT
  Name: @
  Value: google-site-verification=[CODE]
  ```
- [ ] 1 Stunde warten
- [ ] In GSC "Bestätigen" klicken

### Schritt 4.5: Sitemap einreichen
- [ ] In GSC: "Sitemaps" im linken Menü
- [ ] Sitemap-URL eingeben: `sitemap.xml`
- [ ] "Absenden" klicken

---

## Phase 5: Google Analytics 4 (GA4)

### Schritt 5.1: Analytics-Konto erstellen
- [ ] https://analytics.google.com
- [ ] "Konto erstellen" (falls neu)
- [ ] Property für nexworker.de erstellen

### Schritt 5.2: Data Stream einrichten
- [ ] "Web" wählen
- [ ] URL eingeben: `https://nexworker.de`
- [ ] Stream-Name: "NexWorker Website"
- [ ] "Erstellen"

### Schritt 5.3: Measurement ID kopieren
- [ ] ID kopieren (Format: G-XXXXXXXXXX)
- [ ] Merken für später

### Schritt 5.4: GA4 in Website einbinden

**In index.html vor `</head>` einfügen:**
```html
<!-- Google Analytics 4 -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

- [ ] G-XXXXXXXXXX mit eigener ID ersetzen
- [ ] Auch in Pillar Pages einfügen
- [ ] Dateien neu hochladen

### Schritt 5.5: Conversions einrichten
- [ ] In GA4: "Events" → "Create event"
- [ ] Demo-Request als Conversion definieren
- [ ] Form-Submit tracken

---

## Phase 6: Bing Webmaster Tools

### Schritt 6.1: Konto erstellen
- [ ] https://www.bing.com/webmasters
- [ ] Mit Google Account oder Microsoft Account anmelden

### Schritt 6.2: Website hinzufügen
- [ ] "Add a site"
- [ ] URL: `https://nexworker.de`
- [ ] Sitemap: `https://nexworker.de/sitemap.xml`

### Schritt 6.3: Verifizierung
- [ ] Gleiche Methode wie bei Google (DNS oder HTML-Datei)
- [ ] "Verify" klicken

---

## Phase 7: SEO-Checks vor Launch

### Schritt 7.1: Technische Prüfung
- [ ] Alle Seiten aufrufbar: https://nexworker.de, https://nexworker.de/wissenssicherung-handwerk.html
- [ ] HTTPS funktioniert (keine Mixed Content Warnings)
- [ ] Mobile-Responsive (auf Smartphone testen)
- [ ] Keine 404-Fehler

### Schritt 7.2: Meta-Tags prüfen
- [ ] Title auf jeder Seite vorhanden (max 60 Zeichen)
- [ ] Meta-Description auf jeder Seite (max 160 Zeichen)
- [ ] Canonical-Tag auf jeder Seite
- [ ] Open Graph Tags für Social Media

### Schritt 7.3: Schema Markup validieren
- [ ] https://search.google.com/test/rich-results
- [ ] Homepage testen
- [ ] Pillar Page testen
- [ ] Keine Errors

### Schritt 7.4: Performance prüfen
- [ ] https://pagespeed.web.dev/
- [ ] Homepage testen
- [ ] Core Web Vitals: Alle grün
- [ ] Falls rot: Optimieren (Bilder, CSS, JS)

---

## Phase 8: Nach dem Launch

### Schritt 8.1: Google Search Console
- [ ] Coverage Report prüfen (nach 1-2 Tagen)
- [ ] URLs indexieren lassen ("URL Inspection" → "Request indexing")
- [ ] Sitemap-Status prüfen

### Schritt 8.2: Erste Rankings abwarten
- [ ] Nach 1-2 Wochen: Brand-Keywords (nexworker, nexworker.de)
- [ ] Nach 4-8 Wochen: Erste Long-Tail-Keywords
- [ ] Nach 3-6 Monaten: Ziel-Keywords

### Schritt 8.3: Content fortsetzen
- [ ] Beweissicherung Baustelle Pillar Page erstellen
- [ ] WhatsApp Baudokumentation Pillar Page erstellen
- [ ] 2-3 Supporting Content pro Woche

### Schritt 8.4: Link Building starten
- [ ] Guest Post Pitches senden
- [ ] HARO/ResponseSource registrieren
- [ ] Google Alerts einrichten

---

## Quick-Reference: Wichtigste URLs

| URL | Zweck |
|-----|-------|
| https://nexworker.de | Homepage |
| https://nexworker.de/sitemap.xml | Sitemap für Google |
| https://nexworker.de/robots.txt | Crawler-Steuerung |
| https://nexworker.de/llms.txt | AI-Crawler Info |
| https://search.google.com/search-console | Google Search Console |
| https://analytics.google.com | Google Analytics |
| https://www.bing.com/webmasters | Bing Webmaster |
| https://pagespeed.web.dev/ | PageSpeed Insights |
| https://search.google.com/test/rich-results | Rich Results Test |

---

## Support-Dateien (Bereits erstellt)

| Datei | Pfad | Status |
|-------|------|--------|
| index.html | /root/.openclaw/workspace/NexWorker-Repo/ | ✅ Bereit |
| wissenssicherung-handwerk.html | /root/.openclaw/workspace/NexWorker-Repo/ | ✅ Bereit |
| llms.txt | /root/.openclaw/workspace/NexWorker-Repo/ | ✅ Bereit |
| robots.txt | /root/.openclaw/workspace/NexWorker-Repo/ | ✅ Bereit |
| sitemap.xml | /root/.openclaw/workspace/NexWorker-Repo/ | ✅ Bereit |

---

## Hosting-Alternative: VPS/Cloud

**Falls du mehr Kontrolle möchtest:**

| Anbieter | Kosten | Vorteil |
|----------|--------|---------|
| Hostinger Cloud | 8€/Monat | Mehr Kontrolle |
| Hetzner Cloud | 4€/Monat | Deutschland, günstig |
| DigitalOcean | 6€/Monat | Einfach, gut dokumentiert |

---

## Status-Check

**Aktuell zu tun:**
1. [ ] Hosting-Plan bei Hostinger prüfen
2. [ ] Domain mit Hosting verbinden
3. [ ] SSL aktivieren
4. [ ] Dateien via FTP/File Manager hochladen
5. [ ] Google Search Console einrichten
6. [ ] Google Analytics einbinden
7. [ ] Bing Webmaster Tools

**Sobald Website live ist:**
8. [ ] Sitemap einreichen
9. [ ] Rich Results testen
10. [ ] PageSpeed testen

---

**Let me know when you've completed steps 1-3, then I'll help with the next phase!**