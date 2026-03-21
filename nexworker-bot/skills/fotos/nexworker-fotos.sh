#!/bin/bash
# nexworker-fotos - Foto-Dokumentation
# Usage: nexworker-fotos <command> [options]

set -e

STORAGE_DIR="/app/storage/fotos"
INDEX_FILE="$STORAGE_DIR/index.json"
TODAY=$(date +%Y-%m-%d)
CURRENT_USER="${USER:-Unknown}"

COMMAND="${1:-}"
shift || true

usage() {
    echo "nexworker-fotos - Foto-Dokumentation"
    echo ""
    echo "Commands:"
    echo "  add          Foto hinzufügen"
    echo "  search       Fotos durchsuchen"
    echo "  list         Fotos auflisten"
    echo "  heute        Fotos von heute"
    echo ""
    echo "Options:"
    echo "  --file PATH         Foto-Datei"
    echo "  --baustelle NAME    Baustelle"
    echo "  --beschreibung TXT  Beschreibung"
    echo "  --user NAME         Fotograf (default: $CURRENT_USER)"
    echo "  --query TXT         Suchbegriff"
}

init_index() {
    mkdir -p "$STORAGE_DIR/$TODAY"
    if [ ! -f "$INDEX_FILE" ]; then
        echo '{"fotos":[]}' > "$INDEX_FILE"
    fi
}

generate_id() {
    echo "foto_$(date +%s)"
}

do_add() {
    local file=""
    local baustelle=""
    local beschreibung=""
    local user="$CURRENT_USER"
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --file) file="$2"; shift 2 ;;
            --baustelle) baustelle="$2"; shift 2 ;;
            --beschreibung) beschreibung="$2"; shift 2 ;;
            --user) user="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$file" ]; then
        echo "Error: --file ist erforderlich"
        exit 1
    fi
    
    if [ ! -f "$file" ]; then
        echo "Error: Datei nicht gefunden: $file"
        exit 1
    fi
    
    init_index
    
    # Ziel-Datei
    local ext="${file##*.}"
    local dest_name="foto_$(date +%H%M%S).$ext"
    local dest_dir="$STORAGE_DIR/$TODAY"
    local dest_path="$dest_dir/$dest_name"
    
    # Kopiere Datei
    mkdir -p "$dest_dir"
    cp "$file" "$dest_path"
    
    # ID und Uhrzeit
    local id=$(generate_id)
    local uhrzeit=$(date +%H:%M)
    
    # Index-Eintrag
    local entry=$(jq -n \
        --arg id "$id" \
        --arg datum "$TODAY" \
        --arg uhrzeit "$uhrzeit" \
        --arg baustelle "$baustelle" \
        --arg beschreibung "$beschreibung" \
        --arg file "$dest_path" \
        --arg user "$user" \
        '{
            id: $id,
            datum: $datum,
            uhrzeit: $uhrzeit,
            baustelle: $baustelle,
            beschreibung: $beschreibung,
            file: $file,
            user: $user
        }')
    
    # An Index anhängen
    local new_data=$(jq --argjson entry "$entry" '.fotos += [$entry]' "$INDEX_FILE")
    echo "$new_data" > "$INDEX_FILE"
    
    echo "✅ Foto gespeichert: $dest_path"
    echo "   ID: $id"
}

do_search() {
    local query=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --query) query="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$query" ]; then
        echo "Error: --query ist erforderlich"
        exit 1
    fi
    
    if [ ! -f "$INDEX_FILE" ]; then
        echo "Keine Fotos vorhanden"
        exit 0
    fi
    
    # Suche in Beschreibung oder Baustelle
    jq --arg query "$query" \
        '[.fotos[] | select(.beschreibung | contains($query)) or .baustelle | contains($query))]' \
        "$INDEX_FILE" | jq -r '.[] | "\(.datum) \(.uhrzeit) | \(.baustelle) | \(.beschreibung)"'
}

do_list() {
    local baustelle=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --baustelle) baustelle="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ ! -f "$INDEX_FILE" ]; then
        echo "Keine Fotos vorhanden"
        exit 0
    fi
    
    if [ -n "$baustelle" ]; then
        jq --arg b "$baustelle" \
            '[.fotos[] | select(.baustelle == $b)]' \
            "$INDEX_FILE" | jq -r '.[] | "\(.datum) \(.uhrzeit) | \(.beschreibung)"'
    else
        jq -r '.fotos[] | "\(.datum) \(.uhrzeit) | \(.baustelle) | \(.beschreibung)"' "$INDEX_FILE"
    fi
}

do_heute() {
    if [ ! -f "$INDEX_FILE" ]; then
        echo "Keine Fotos heute"
        exit 0
    fi
    
    jq --argdatum "$TODAY" \
        '[.fotos[] | select(.datum == $datum)]' \
        "$INDEX_FILE" | jq -r '.[] | "\(.uhrzeit) | \(.baustelle) | \(.beschreibung)"'
}

case "$COMMAND" in
    add)
        do_add "$@"
        ;;
    search)
        do_search "$@"
        ;;
    list)
        do_list "$@"
        ;;
    heute|today)
        do_heute
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "nexworker-fotos: Unbekannter Befehl '$COMMAND'"
        usage
        exit 1
        ;;
esac
