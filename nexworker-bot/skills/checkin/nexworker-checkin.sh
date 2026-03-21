#!/bin/bash
# nexworker-checkin - Arbeitszeit-Erfassung
# Usage: nexworker-checkin <command> [options]

set -e

STORAGE_DIR="/tmp/nexworker-test/zeiterfassung"
TODAY=$(date +%Y-%m-%d)
CURRENT_USER="${USER:-Unknown}"

COMMAND="${1:-}"
shift || true

usage() {
    echo "nexworker-checkin - Arbeitszeit erfassen"
    echo ""
    echo "Commands:"
    echo "  in      Check-in (Arbeitsbeginn)"
    echo "  out     Check-out (Feierabend)"
    echo "  status  Aktuellen Status anzeigen"
    echo "  heute   Heutige Zeiten anzeigen"
    echo ""
    echo "Options:"
    echo "  --user NAME      Mitarbeiter (default: $CURRENT_USER)"
    echo "  --zeit HH:MM     Uhrzeit (default: jetzt)"
    echo "  --baustelle NAME  Baustelle"
    echo "  --pausen MIN     Pausen in Minuten"
}

# JSON helpers
jq_installed() {
    command -v jq &> /dev/null
}

init_file() {
    mkdir -p "$STORAGE_DIR"
    local file="$STORAGE_DIR/$TODAY.json"
    if [ ! -f "$file" ]; then
        echo "{\"datum\": \"$TODAY\", \"eintraege\": []}" > "$file"
    fi
    echo "$file"
}

do_checkin() {
    local user="$CURRENT_USER"
    local zeit="$(date +%H:%M)"
    local baustelle=""
    local pausen=0
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --user) user="$2"; shift 2 ;;
            --zeit) zeit="$2"; shift 2 ;;
            --baustelle) baustelle="$2"; shift 2 ;;
            --pausen) pausen="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$baustelle" ]; then
        echo "Error: --baustelle ist erforderlich"
        exit 1
    fi
    
    local file=$(init_file)
    
    # Neuer Eintrag
    local entry=$(jq -n \
        --arg user "$user" \
        --arg zeit "$zeit" \
        --arg baustelle "$baustelle" \
        --argjson pausen "$pausen" \
        '{
            user: $user,
            start: $zeit,
            baustelle: $baustelle,
            ende: null,
            pausen: $pausen,
            timestamp: now | todate
        }')
    
    # An Array anhängen
    local new_data=$(jq --argjson entry "$entry" '.eintraege += [$entry]' "$file")
    echo "$new_data" > "$file"
    
    echo "✅ Check-in: $user um $zeit auf $baustelle"
}

do_checkout() {
    local user="$CURRENT_USER"
    local zeit="$(date +%H:%M)"
    local pausen=0
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --user) user="$2"; shift 2 ;;
            --zeit) zeit="$2"; shift 2 ;;
            --pausen) pausen="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    local file=$(init_file)
    
    # Letzten offenen Eintrag für User finden und schließen
    local entry_index=$(jq --arg user "$user" \
        '[.eintraege | to_entries[] | select(.value.user == $user and .value.ende == null)] | first | .key' \
        "$file" 2>/dev/null || echo "-1")
    
    if [ "$entry_index" = "-1" ] || [ "$entry_index" = "null" ]; then
        echo "Kein offener Check-in für $user"
        exit 1
    fi
    
    # Ende setzen
    local new_data=$(jq \
        --arg user "$user" \
        --arg zeit "$zeit" \
        --argjson pausen "$pausen" \
        '.eintraege |= . | to_entries | map(if .value.user == $user and .value.ende == null then .value.ende = $zeit | .value.pausen = $pausen else . end) | map(.value)' \
        "$file")
    echo "$new_data" > "$file"
    
    echo "✅ Check-out: $user um $zeit"
}

do_status() {
    local user="${1:-$CURRENT_USER}"
    local file="$STORAGE_DIR/$TODAY.json"
    
    if [ ! -f "$file" ]; then
        echo "Keine Einträge für heute"
        exit 0
    fi
    
    local offen=$(jq --arg user "$user" \
        '[.eintraege[] | select(.user == $user and .ende == null)]' \
        "$file")
    
    if [ "$offen" = "[]" ]; then
        echo "Status: Nicht eingecheckt"
    else
        local baustelle=$(echo "$offen" | jq -r '.[0].baustelle')
        local start=$(echo "$offen" | jq -r '.[0].start')
        echo "Status: Eingecheckt auf $baustelle seit $start"
    fi
}

do_heute() {
    local file="$STORAGE_DIR/$TODAY.json"
    
    if [ ! -f "$file" ]; then
        echo "Keine Einträge für heute"
        exit 0
    fi
    
    jq -r '.eintraege[] | "\(.user) | \(.baustelle) | \(.start // "?") - \(.ende // "offen")"' "$file"
}

case "$COMMAND" in
    in|checkin)
        do_checkin "$@"
        ;;
    out|checkout)
        do_checkout "$@"
        ;;
    status)
        do_status "$@"
        ;;
    heute|today)
        do_heute
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "nexworker-checkin: Unbekannter Befehl '$COMMAND'"
        usage
        exit 1
        ;;
esac
