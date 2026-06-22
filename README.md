# hbTec SpectrumKNX Manager

Verwaltung von mehreren SpectrumKNX-Installationen auf einem Linux-System.

## Version

Aktuelle Version siehe Datei:

```text
VERSION
```

---

# Funktionen

Der Manager unterstützt:

- Projekte anzeigen
- Status anzeigen
- Neuinstallation
- Deinstallation
- Neustart
- Logs anzeigen
- KNX Gateway testen
- Backup erstellen
- Update durchführen

---

# Voraussetzungen

Installierte Pakete:

```bash
docker
docker compose
git
```

Prüfen:

```bash
docker --version
docker compose version
git --version
```

---

# Installation

Skripte ausführbar machen:

```bash
chmod +x scripts/spectrumknx-install.sh
chmod +x scripts/spectrumknx-manager.sh
```

---

# Neue SpectrumKNX Installation

Start:

```bash
./scripts/spectrumknx-install.sh
```

Folgende Informationen werden abgefragt:

```text
Projektname
KNX Gateway IP
KNX Secure Ja/Nein
Web-Port
```

Nach erfolgreicher Installation wird die URL angezeigt.

Beispiel:

```text
http://192.168.186.155:8011
```

---

# Manager starten

```bash
./scripts/spectrumknx-manager.sh
```

---

# Projektstruktur

```text
/opt/hbtec/spectrumknx/

├── projekt1
│   ├── project.conf
│   ├── backups
│   ├── docker-compose.yml
│   └── .env
│
├── projekt2
│   ├── project.conf
│   └── backups
│
└── projekt3
```

---

# Backup

Backup erstellen:

```text
Menü
→ Backup erstellen
```

Backups werden gespeichert unter:

```text
/opt/hbtec/spectrumknx/<projekt>/backups
```

Dateiformat:

```text
backup_YYYYMMDD_HHMMSS.sql
```

---

# Update

Menü:

```text
Update
```

Ablauf:

1. Optional Backup erstellen
2. Git Repository aktualisieren
3. Docker Image aktualisieren
4. Container neu starten

---

# Deinstallation

Menü:

```text
Deinstallation
```

Entfernt:

- Container
- Netzwerke
- Docker Volumes
- Projektverzeichnis

---

# KNX Secure

Bei aktivem Secure Tunneling:

```text
Settings
→ KNX Security Keys
```

Anschließend die Datei

```text
.knxkeys
```

hochladen.

---

# Autor

hbTec AG

Interne Verwaltungsumgebung für SpectrumKNX.
