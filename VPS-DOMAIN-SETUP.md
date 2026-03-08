# NexWorker Domain auf VPS zeigen

**Domain:** nexworker.de (bei Hostinger)  
**VPS:** v2202502215330313077.supersrv.de  
**Ziel:** Domain auf VPS zeigen lassen, Website dort hosten

---

## Schritt 1: DNS bei Hostinger konfigurieren

### 1.1 Bei Hostinger einloggen
- [ ] https://hpanel.hostinger.de
- [ ] Domain nexworker.de auswählen
- [ ] "DNS Zone Editor" oder "DNS Verwaltung" öffnen

### 1.2 A-Record setzen
- [ ] Alle bestehenden A-Records löschen (falls vorhanden)
- [ ] Neuen A-Record erstellen:
  ```
  Type: A
  Name: @ (oder leer)
  Value: [DEINE VPS IP]
  TTL: 3600 (oder "Automatic")
  ```

### 1.3 www-Record setzen
- [ ] CNAME für www:
  ```
  Type: CNAME
  Name: www
  Value: nexworker.de
  TTL: 3600
  ```

### 1.4 DNS propagieren lassen
- [ ] Warten 1-24 Stunden (meist 1-2 Stunden)
- [ ] Prüfen: https://dnschecker.org/#A/nexworker.de
- [ ] Sollte deine VPS-IP zeigen

---

## Schritt 2: VPS-IP herausfinden

Falls du die IP nicht kennst:

```bash
# Auf dem VPS ausführen:
curl -4 ifconfig.me
# oder
curl -4 icanhazip.com
```

---

## Schritt 3: Webserver auf VPS einrichten

### Option A: Nginx (Empfohlen)

```bash
# Nginx installieren
sudo apt update
sudo apt install nginx -y

# Status prüfen
sudo systemctl status nginx

# Firewall öffnen
sudo ufw allow 'Nginx Full'
```

### Option B: Apache

```bash
# Apache installieren
sudo apt update
sudo apt install apache2 -y

# Firewall öffnen
sudo ufw allow 'Apache Full'
```

---

## Schritt 4: Website-Dateien auf VPS kopieren

### 4.1 Dateien lokal vorbereiten

**Dateien die du brauchst:**
- index.html
- wissenssicherung-handwerk.html
- llms.txt
- robots.txt
- sitemap.xml

### 4.2 Per SCP auf VPS kopieren

```bash
# Lokal ausführen (nicht auf VPS):
scp -r /root/.openclaw/workspace/NexWorker-Repo/* root@DEINE-VPS-IP:/var/www/nexworker.de/

# Oder falls der Ordner noch nicht existiert:
ssh root@DEINE-VPS-IP "mkdir -p /var/www/nexworker.de"
scp /root/.openclaw/workspace/NexWorker-Repo/*.html root@DEINE-VPS-IP:/var/www/nexworker.de/
scp /root/.openclaw/workspace/NexWorker-Repo/*.txt root@DEINE-VPS-IP:/var/www/nexworker.de/
scp /root/.openclaw/workspace/NexWorker-Repo/*.xml root@DEINE-VPS-IP:/var/www/nexworker.de/
```

### 4.3 Nginx-Konfiguration erstellen

```bash
# Auf dem VPS:
sudo nano /etc/nginx/sites-available/nexworker.de
```

**Inhalt einfügen:**
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name nexworker.de www.nexworker.de;
    
    root /var/www/nexworker.de;
    index index.html;
    
    # Alle Dateien serven
    location / {
        try_files $uri $uri/ =404;
    }
    
    # llms.txt für AI-Crawler
    location = /llms.txt {
        add_header Content-Type text/plain;
    }
    
    # robots.txt
    location = /robots.txt {
        add_header Content-Type text/plain;
    }
    
    # sitemap.xml
    location = /sitemap.xml {
        add_header Content-Type application/xml;
    }
}
```

```bash
# Site aktivieren
sudo ln -s /etc/nginx/sites-available/nexworker.de /etc/nginx/sites-enabled/

# Konfiguration testen
sudo nginx -t

# Nginx neu laden
sudo systemctl reload nginx
```

---

## Schritt 5: SSL-Zertifikat (Let's Encrypt)

```bash
# Certbot installieren
sudo apt install certbot python3-certbot-nginx -y

# SSL-Zertifikat erstellen
sudo certbot --nginx -d nexworker.de -d www.nexworker.de

# Automatische Verlängerung testen
sudo certbot renew --dry-run
```

Certbot fragt nach:
- Email-Adresse (für Benachrichtigungen)
- AGB akzeptieren
- HTTP auf HTTPS umleiten? → JA

---

## Schritt 6: Testen

### 6.1 DNS-Propagation prüfen
```bash
# Lokal ausführen:
nslookup nexworker.de
# Sollte VPS-IP zeigen

dig nexworker.de
```

### 6.2 Website aufrufen
- [ ] http://nexworker.de → sollte auf HTTPS weiterleiten
- [ ] https://nexworker.de → sollte Website zeigen
- [ ] https://nexworker.de/llms.txt → sollte Text zeigen
- [ ] https://nexworker.de/sitemap.xml → sollte XML zeigen
- [ ] https://nexworker.de/wissenssicherung-handwerk.html → sollte Pillar Page zeigen

---

## Schritt 7: Firewall & Sicherheit

```bash
# Firewall konfigurieren
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable

# Status prüfen
sudo ufw status
```

---

## Quick-Commands (Copy & Paste)

**Auf dem VPS ausführen:**

```bash
# 1. Nginx installieren
sudo apt update && sudo apt install nginx -y

# 2. Verzeichnis erstellen
sudo mkdir -p /var/www/nexworker.de

# 3. Nginx-Konfig erstellen
sudo tee /etc/nginx/sites-available/nexworker.de << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name nexworker.de www.nexworker.de;
    root /var/www/nexworker.de;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location = /llms.txt {
        add_header Content-Type text/plain;
    }
    
    location = /robots.txt {
        add_header Content-Type text/plain;
    }
    
    location = /sitemap.xml {
        add_header Content-Type application/xml;
    }
}
EOF

# 4. Site aktivieren
sudo ln -sf /etc/nginx/sites-available/nexworker.de /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 5. Testen und neu laden
sudo nginx -t && sudo systemctl reload nginx

# 6. Firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 7. Certbot installieren
sudo apt install certbot python3-certbot-nginx -y
```

**Nach DNS-Propagation (wenn nexworker.de auf VPS zeigt):**

```bash
# SSL-Zertifikat holen
sudo certbot --nginx -d nexworker.de -d www.nexworker.de
```

---

## Dateien auf VPS kopieren

**Wenn duSSH-Zugang zum VPS hast:**

```bash
# Lokal (wo die Dateien sind):
scp *.html *.txt *.xml root@NEXWORKER.DE:/var/www/nexworker.de/

# Oder mit IP:
scp /root/.openclaw/workspace/NexWorker-Repo/*.html root@DEINE-VPS-IP:/var/www/nexworker.de/
scp /root/.openclaw/workspace/NexWorker-Repo/*.txt root@DEINE-VPS-IP:/var/www/nexworker.de/
scp /root/.openclaw/workspace/NexWorker-Repo/*.xml root@DEINE-VPS-IP:/var/www/nexworker.de/
```

---

## Status-Check

**Nach dem Setup:**
- [ ] DNS zeigt auf VPS-IP
- [ ] Nginx läuft
- [ ] Website unter http://nexworker.de erreichbar
- [ ] HTTPS funktioniert (Let's Encrypt)
- [ ] Alle Seiten laden (index, pillar, llms, robots, sitemap)

**Dann:**
- [ ] Google Search Console einrichten
- [ ] Sitemap einreichen

---

**Was ich von dir brauche:**
1. VPS-IP-Adresse (oder Domain des VPS)
2. SSH-Zugang zum VPS?
3. Oder soll ich die Dateien direkt hier auf dem Server vorbereiten und du kopierst sie manuell?