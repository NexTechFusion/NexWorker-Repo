#!/bin/bash
# nexworker-erinnerung - Erinnerungsverwaltung
# Usage: nexworker-erinnerung <command> [options]

set -e

STORAGE_DIR="/app/storage/erinnerungen"
INDEX_FILE="$STORAGE_DIR/erinnerungen.json"
NOW=$(date -Iseconds)

COMMAND="${1:-}"
shift || true

usage() {
    echo "nexworker-erinnerung - Erinnerungsverwaltung"
    echo ""
    echo "Commands:"
    echo "  add       Erinnerung setzen (--text, --zeit)"
    echo "  in        Erinnerung in X Minuten (--text, --minuten)"
    echo "  heute     Heutige Erinnerungen"
    echo "  list      Alle offenen Erinnerungen"
    echo "  delete    Erinnerung löschen (--id)"
    echo "  done      Als erledigt markieren (--id)"
    echo ""
    echo "Options:"
    echo "  --text TEXT      Erinnerungstext"
    echo "  --zeit DATUM    Zeitpunkt (ISO format)"
    echo "  --minuten N      Minuten ab jetzt"
}

init_index() {
    mkdir -p "$STORAGE_DIR"
    if [ ! -f "$INDEX_FILE" ]; then
        echo '{"erinnerungen":[]}' > "$INDEX_FILE"
    fi
}

generate_id() {
    echo "rem_$(date +%s)"
}

do_add() {
    local text=""
    local zeit=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --text) text="$2"; shift 2 ;;
            --zeit) zeit="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$text" ]; then
        echo "Error: --text ist erforderlich"
        exit 1
    fi
    
    if [ -z "$zeit" ]; then
        echo "Error: --zeit ist erforderlich (z.B. 2026-03-25T10:00:00)"
        exit 1
    fi
    
    init_index
    
    local id=$(generate_id)
    
    local entry=$(jq -n \
        --arg id "$id" \
        --arg text "$text" \
        --arg zeit "$zeit" \
        --arg status "pending" \
        --arg created "$NOW" \
        '{
            id: $id,
            text: $text,
            zeit: $zeit,
            status: $status,
            created: $created
        }')
    
    local new_data=$(jq --argjson entry "$entry" '.erinnerungen += [$entry]' "$INDEX_FILE")
    echo "$new_data" > "$INDEX_FILE"
    
    echo "✅ Erinnerung gesetzt:"
    echo "   $text"
    echo "   Zeit: $zeit"
    echo "   ID: $id"
}

do_in() {
    local text=""
    local minuten=60
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --text) text="$2"; shift 2 ;;
            --minuten) minuten="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$text" ]; then
        echo "Error: --text ist erforderlich"
        exit 1
    fi
    
    local zeit=$(date -Iseconds -d "+$minuten minutes")
    do_add --text "$text" --zeit "$zeit"
}

do_heute() {
    init_index
    
    local today=$(date +%Y-%m-%d)
    
    echo "=== Erinnerungen heute ==="
    echo ""
    
    jq --arg today "$today" \
        '[.erinnerungen[] | select(.zeit | startswith($today)) | select(.status == "pending")]' \
        "$INDEX_FILE" | jq -r '.[] | "\(.zeit | split("T")[1] | split("+")[0]) | \(.text)"'
}

do_list() {
    init_index
    
    echo "=== Alle offenen Erinnerungen ==="
    echo ""
    
    jq '[.erinnerungen[] | select(.status == "pending")] | sort_by(.zeit)' \
        "$INDEX_FILE" | jq -r '.[] | "\(.zeit) | \(.text) [\(._id)]"'
}

do_delete() {
    local id=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --id) id="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$id" ]; then
        echo "Error: --id ist erforderlich"
        exit 1
    fi
    
    init_index
    
    local new_data=$(jq --arg id "$id" \
        '.erinnerungen |= [.[] | select(.id != $id)]' \
        "$INDEX_FILE")
    echo "$new_data" > "$INDEX_FILE"
    
    echo "✅ Erinnerung gelöscht: $id"
}

do_done() {
    local id=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --id) id="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$id" ]; then
        echo "Error: --id ist erforderlich"
        exit 1
    fi
    
    init_index
    
    local new_data=$(jq --arg id "$id" \
        '.erinnerungen |= [.[] | if .id == $id then .status = "done" else . end]' \
        "$INDEX_FILE")
    echo "$new_data" > "$INDEX_FILE"
    
    echo "✅ Erledigt: $id"
}

case "$COMMAND" in
    add)
        do_add "$@"
        ;;
    in)
        do_in "$@"
        ;;
    heute|today)
        do_heute
        ;;
    list|ls)
        do_list
        ;;
    delete|rm)
        do_delete "$@"
        ;;
    done|complete)
        do_done "$@"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "nexworker-erinnerung: Unbekannter Befehl '$COMMAND'"
        usage
        exit 1
        ;;
esac
