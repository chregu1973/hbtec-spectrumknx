#!/bin/bash

BASE_DIR="/opt/hbtec/spectrumknx"

VERSION_FILE="$HOME/hbtec-dev/VERSION"

if [ -f "$VERSION_FILE" ]
then
    VERSION=$(cat "$VERSION_FILE")
else
    VERSION="unbekannt"
fi

SERVER_IP=$(hostname -I | awk '{print $1}')

list_projects() {

    echo
    echo "Installierte Projekte"
    echo "====================="
    echo

    for dir in "$BASE_DIR"/*
    do
        [ -d "$dir" ] || continue

        if [ -f "$dir/project.conf" ]
        then
            source "$dir/project.conf"

            echo "Projekt : $PROJECT_NAME"
            echo "Gateway : $KNX_IP"
            echo "Port    : $WEB_PORT"
            echo
        fi
    done
}

select_project() {

    echo
    echo "Projekt auswählen"
    echo

    mapfile -t PROJECTS < <(
        find "$BASE_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        | sort
    )

    if [ ${#PROJECTS[@]} -eq 0 ]
    then
        echo "Keine Projekte gefunden."
        return 1
    fi

    select PROJECT_DIR in "${PROJECTS[@]}"
    do
        if [ -n "$PROJECT_DIR" ]
        then
            source "$PROJECT_DIR/project.conf"
            return 0
        fi
    done
}

show_status() {

    select_project || return

    echo
    echo "========================================"
    echo " Projektstatus"
    echo "========================================"
    echo

    echo "Projekt : $PROJECT_NAME"
    echo "Gateway : $KNX_IP"
    echo "Port    : $WEB_PORT"
    echo "Secure  : $SECURE"

         NUC_IP=$(hostname -I | awk '{print $1}')
    echo
    echo "WebUI"
    echo "-------"
    echo "http://${NUC_IP}:${WEB_PORT}"
    echo

    docker ps \
      --filter label=com.docker.compose.project="$PROJECT_ID"

    echo
}


install_project() {

    ~/hbtec-dev/scripts/spectrumknx-install.sh

}
remove_project() {

    select_project || return

    echo
    echo "========================================"
    echo " Projekt löschen"
    echo "========================================"
    echo

    echo "Projekt : $PROJECT_NAME"
    echo

    read -rp "Wirklich löschen? (j/n): " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[JjYy]$ ]]
    then
        echo "Abgebrochen."
        return
    fi

    docker compose \
      -p "$PROJECT_ID" \
      -f "$PROJECT_DIR/docker-compose.yml" \
      -f "$PROJECT_DIR/docker-compose.prod.yml" \
      down -v

    rm -rf "$PROJECT_DIR"

    echo
    echo "Projekt gelöscht."
    echo
}

restart_project() {

    select_project || return

    echo
    echo "========================================"
    echo " Projekt neustarten"
    echo "========================================"
    echo

    echo "Projekt : $PROJECT_NAME"
    echo

    docker compose \
      -p "$PROJECT_ID" \
      -f "$PROJECT_DIR/docker-compose.yml" \
      -f "$PROJECT_DIR/docker-compose.prod.yml" \
      restart

    echo
    echo "Projekt erfolgreich neugestartet."
    echo
}

show_logs() {

    select_project || return

    echo
    echo "========================================"
    echo " Logs"
    echo "========================================"
    echo
    echo "1) Backend"
    echo "2) Datenbank"
    echo "3) Live Backend"
    echo "4) Live Datenbank"
    echo

    read -rp "Auswahl: " LOG_CHOICE

    case "$LOG_CHOICE" in

        1)
            docker compose \
                -p "$PROJECT_ID" \
                -f "$PROJECT_DIR/docker-compose.yml" \
                -f "$PROJECT_DIR/docker-compose.prod.yml" \
                logs --tail=100 backend
            ;;

        2)
            docker compose \
                -p "$PROJECT_ID" \
                -f "$PROJECT_DIR/docker-compose.yml" \
                -f "$PROJECT_DIR/docker-compose.prod.yml" \
                logs --tail=100 db
            ;;

        3)
            docker compose \
                -p "$PROJECT_ID" \
                -f "$PROJECT_DIR/docker-compose.yml" \
                -f "$PROJECT_DIR/docker-compose.prod.yml" \
                logs -f backend
            ;;

        4)
            docker compose \
                -p "$PROJECT_ID" \
                -f "$PROJECT_DIR/docker-compose.yml" \
                -f "$PROJECT_DIR/docker-compose.prod.yml" \
                logs -f db
            ;;

    esac

    echo
}

test_knx_gateway() {

    select_project || return

    echo
    echo "========================================"
    echo " KNX Gateway Test"
    echo "========================================"
    echo

    echo "Projekt : $PROJECT_NAME"
    echo "Gateway : $KNX_IP"
    echo

    echo "Ping-Test..."
    echo

    if ping -c 2 -W 2 "$KNX_IP" >/dev/null 2>&1
    then
        echo "✅ Gateway erreichbar"
    else
        echo "❌ Gateway nicht erreichbar"
    fi

    echo
    echo "Port 3671 Test..."
    echo

    if timeout 3 bash -c "</dev/tcp/$KNX_IP/3671" 2>/dev/null
    then
        echo "✅ Port 3671 erreichbar"
    else
        echo "❌ Port 3671 nicht erreichbar"
    fi

    echo
    echo "Containerstatus"
    echo "---------------"

    docker ps \
        --filter label=com.docker.compose.project="$PROJECT_ID"

    echo
    echo "WebUI:"
    echo "http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
    echo
}

create_backup() {

    select_project || return

    echo
    echo "========================================"
    echo " Backup erstellen"
    echo "========================================"
    echo

    BACKUP_DIR="$PROJECT_DIR/backups"

    mkdir -p "$BACKUP_DIR"

    BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql"

    DB_CONTAINER=$(docker ps \
        --filter label=com.docker.compose.project="$PROJECT_ID" \
        --filter label=com.docker.compose.service=db \
        --format "{{.Names}}" | head -n1)

    if [ -z "$DB_CONTAINER" ]
    then
        echo "Fehler: Datenbankcontainer nicht gefunden."
        return
    fi

    echo "Sichere nach:"
    echo "$BACKUP_FILE"
    echo

    docker exec "$DB_CONTAINER" \
        pg_dump \
        -U knxuser \
        knx_analyzer > "$BACKUP_FILE"

    echo
    echo "Backup erfolgreich erstellt."
    echo
}

update_project() {

    select_project || return

    echo
    echo "========================================"
    echo " Projekt Update"
    echo "========================================"
    echo

    echo "Projekt : $PROJECT_NAME"
    echo

    read -rp "Vor dem Update Backup erstellen? (j/n): " BACKUP

    if [[ "$BACKUP" =~ ^[JjYy]$ ]]
    then
        BACKUP_DIR="$PROJECT_DIR/backups"

        mkdir -p "$BACKUP_DIR"

        BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql"

        DB_CONTAINER=$(docker ps \
            --filter label=com.docker.compose.project="$PROJECT_ID" \
            --filter label=com.docker.compose.service=db \
            --format "{{.Names}}" | head -n1)

        if [ -n "$DB_CONTAINER" ]
        then
            echo
            echo "Erstelle Backup ..."
            docker exec "$DB_CONTAINER" \
                pg_dump \
                -U knxuser \
                knx_analyzer > "$BACKUP_FILE"

            echo "Backup gespeichert:"
            echo "$BACKUP_FILE"
            echo
        fi
    fi

    echo "Aktualisiere Repository ..."
    echo

    cd "$PROJECT_DIR"

    git pull

    echo
    echo "Aktualisiere Docker Image ..."
    echo

    docker compose \
        -p "$PROJECT_ID" \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        pull

    echo
    echo "Starte neue Version ..."
    echo

    docker compose \
        -p "$PROJECT_ID" \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        up -d

    echo
    echo "Update abgeschlossen."
    echo
}

while true
do
    clear

    echo "========================================"
    echo " hbTec SpectrumKNX Manager" @cko
    echo "========================================"
    echo
    echo " Version: $VERSION | IP Adresse: $SERVER_IP"
    echo
    echo
    echo "1) Projekte anzeigen"
    echo "2) Status anzeigen"
    echo "3) Neuinstallation"
    echo "4) Deinstallation"
    echo "5) Neustart"
    echo "6) Logs"
    echo "7) KNX Gateway testen"
    echo "8) Update"
    echo "0) Beenden"
    echo

    read -rp "Auswahl: " CHOICE

    case "$CHOICE" in

        1)
            list_projects
            read -rp "ENTER drücken..." _
            ;;
        2)
           show_status
           read -rp "Enter drücken..." _
           ;;
        3)
           install_project
           ;;
        4)
           remove_project
           read -rp "ENTER drücken..." _
           ;;
        5)
           restart_project
           read -rp "ENTER drücken..." _
           ;;
        6)
           show_logs
           read -rp "ENTER drücken..." _
           ;;
       7)
          test_knx_gateway
          read -rp "Enter drücken..."_
          ;;
       8)
          update_project
          read -rp "ENTER drücken..." _
          ;;

       0)
            exit 0
            ;;
    esac

done
