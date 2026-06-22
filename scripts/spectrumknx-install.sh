#!/bin/bash

set -e

BASE_DIR="/opt/hbtec/spectrumknx"

echo
echo "========================================"
echo "   hbTec SpectrumKNX Installer"
echo "========================================"
echo

#############################################
# Systemprüfung
#############################################

ARCH=$(uname -m)

echo "Systemprüfung"
echo "-------------"
echo

echo "Architektur : $ARCH"

if [[ "$ARCH" != "x86_64" ]]
then
    echo
    echo "WARNUNG:"
    echo "Dieses System ist nicht x86_64."
    echo
    echo "SpectrumKNX wurde von hbTec aktuell"
    echo "nur auf Intel/AMD Systemen getestet."
    echo
    echo "Bekannter Fehler auf ARM64:"
    echo "  exec /usr/local/bin/uvicorn: exec format error"
    echo

    read -rp "Trotzdem fortfahren? (j/n): " CONTINUE

    if [[ ! "$CONTINUE" =~ ^[JjYy]$ ]]
    then
        exit 0
    fi
else
    echo "Status       : OK"
fi

echo


#############################################
# Voraussetzungen prüfen
#############################################

if ! command -v docker >/dev/null 2>&1; then
    echo "FEHLER: Docker ist nicht installiert."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "FEHLER: Docker Compose ist nicht verfügbar."
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "FEHLER: Git ist nicht installiert."
    exit 1
fi

#############################################
# Eingaben
#############################################

read -rp "Projektname: " PROJECT_NAME

PROJECT_ID=$(echo "$PROJECT_NAME" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/_/g')

read -rp "KNX Gateway IP: " KNX_IP

echo
echo "KNX Secure?"
echo "1) Nein"
echo "2) Ja"
read -rp "Auswahl: " SECURE

#############################################
# Freien Port suchen
#############################################

WEB_PORT=""

for p in $(seq 8010 8099)
do
    if ! ss -tulpn | grep -q ":$p "
    then
        WEB_PORT="$p"
        break
    fi
done

echo
read -rp "Web-Port [$WEB_PORT]: " USER_PORT

if [ -n "$USER_PORT" ]
then
    WEB_PORT="$USER_PORT"
fi

#############################################
# KNX Verbindungstyp
#############################################

if [ "$SECURE" = "2" ]
then
    CONNECTION_TYPE="TUNNELING_TCP_SECURE"
    SECURE_TEXT="true"
else
    CONNECTION_TYPE="TUNNELING"
    SECURE_TEXT="false"
fi

#############################################
# Projektverzeichnis
#############################################

INSTALL_DIR="${BASE_DIR}/${PROJECT_ID}"

echo
echo "Installationsverzeichnis:"
echo "$INSTALL_DIR"
echo

sudo mkdir -p "$BASE_DIR"
sudo chown -R "$USER:$USER" "$BASE_DIR"

#############################################
# Bestehendes Projekt prüfen
#############################################

if [ -d "$INSTALL_DIR" ]
then
    echo "FEHLER:"
    echo "Projekt existiert bereits:"
    echo "$INSTALL_DIR"
    exit 1
fi

#############################################
# Repository klonen
#############################################

git clone https://github.com/martinhoefling/SpectrumKNX.git "$INSTALL_DIR"

cd "$INSTALL_DIR"

#############################################
# Feste Containernamen entfernen
#############################################

#############################################
# Compose-Datei für Multi-Projekt-Betrieb
#############################################

# feste Containernamen entfernen
sed -i '/container_name:/d' docker-compose.yml

# DB-Port entfernen
python3 <<'PY'
from pathlib import Path

p = Path("docker-compose.yml")
txt = p.read_text()

txt = txt.replace(
'''    ports:
      - "${POSTGRES_PORT:-5432}:5432"
''',
'')

p.write_text(txt)
PY

# Backend-Port ersetzen
python3 <<PY
from pathlib import Path

p = Path("docker-compose.yml")
txt = p.read_text()

txt = txt.replace(
'''    ports:
      - "8000:8000"
''',
'''    ports:
      - "${WEB_PORT}:8000"
''')

p.write_text(txt)
PY
#############################################
# ENV erstellen
#############################################

cat > .env <<EOF
KNX_GATEWAY_IP=$KNX_IP
KNX_GATEWAY_PORT=3671
KNX_CONNECTION_TYPE=$CONNECTION_TYPE

POSTGRES_USER=knxuser
POSTGRES_PASSWORD=knxpassword
POSTGRES_DB=knx_analyzer
POSTGRES_HOST=db
POSTGRES_PORT=5432

LOG_LEVEL=INFO

APP_IMAGE=ghcr.io/martinhoefling/spectrumknx:latest
EOF

#############################################
# Projektkonfiguration
#############################################

cat > project.conf <<EOF
PROJECT_NAME="$PROJECT_NAME"
PROJECT_ID=$PROJECT_ID
KNX_IP=$KNX_IP
SECURE=$SECURE_TEXT
WEB_PORT=$WEB_PORT
INSTALL_DIR=$INSTALL_DIR
EOF

#############################################
# Compose Override
#############################################

#############################################
# Container starten
#############################################

echo
echo "Container werden gestartet..."
echo

docker compose \
  -p "$PROJECT_ID" \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  up -d --force-recreate

#############################################
# IP erkennen
#############################################

NUC_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}')

if [ -z "$NUC_IP" ]
then
    NUC_IP=$(hostname -I | awk '{print $1}')
fi

#############################################
# Fertigmeldung
#############################################

echo
echo "========================================"
echo " Installation erfolgreich"
echo "========================================"
echo

echo "Projekt:"
echo "  $PROJECT_NAME"
echo

echo "Gateway:"
echo "  $KNX_IP"
echo

echo "Secure:"
echo "  $SECURE_TEXT"
echo

echo "WebUI:"
echo "  http://${NUC_IP}:${WEB_PORT}"
echo

echo "Nächste Schritte:"
echo "  1. WebUI öffnen"
echo "  2. .knxproj hochladen"

if [ "$SECURE" = "2" ]
then
    echo "  3. .knxkeys hochladen"
fi

echo
