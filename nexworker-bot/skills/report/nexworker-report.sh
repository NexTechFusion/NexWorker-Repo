#!/bin/bash
# nexworker-report - Tagesbericht generieren
# Usage: nexworker-report <command> [options]

set -e

ZEIT_DIR="/app/storage/zeiterfassung"
MATERIAL_FILE="/app/storage/material/material.json"
FOTOS_FILE="/app/storage/fotos/index.json"
TODAY=$(date +%Y-%m-%d)

COMMAND="${1:-}"
shift || true

usage() {
    echo "nexworker-report - Tagesbericht generieren"
    echo ""
    echo "Commands:"
    echo "  heute      Bericht für heute"
    echo "  baustelle  Bericht für Baustelle"
    echo "  datum      Bericht für Datum"
    echo "  status     Kurzer Status"
}

get_date_file() {
    local date="$1"
    echo "$ZEIT_DIR/${date}.json"
}

calc_hours() {
    local start="$1"
    local ende="$2"
    local pausen="${3:-0}"
    
    if [ -z "$ende" ] || [ "$ende" = "null" ]; then
        echo "inoffen"
        return
    fi
    
    # Parse HH:MM
    local start_h=$(echo $start | cut -d: -f1)
    local start_m=$(echo $start | cut -d: -f2)
    local end_h=$(echo $ende | cut -d: -f1)
    local end_m=$(echo $ende | cut -d: -f2)
    
    local start_min=$((start_h * 60 + start_m))
    local end_min=$((end_h * 60 + end_m))
    local diff=$((end_min - start_min - pausen))
    
    local hours=$((diff / 60))
    local mins=$((diff % 60))
    
    echo "${hours}.${mins}"
}

format_time() {
    local h=$1
    local m=$2
    printf "%02d:%02d" $h $m
}

do_heute() {
    local date="$TODAY"
    local zeit_file=$(get_date_file "$date")
    
    echo "# Tagesbericht - $(date +%d.%m.%Y)"
    echo ""
    
    # Zeiterfassung
    if [ -f "$zeit_file" ]; then
        echo "## Arbeitszeiten"
        echo ""
        
        jq -r '.eintraege[] | "\(.user) | \(.baustelle) | \(.start // "?") - \(.ende // "offen") | \(.pausen // 0)min"' "$zeit_file" | while IFS='|' read -r user baustelle start ende pausen; do
            local st=$(echo $start | xargs)
            local en=$(echo $ende | xargs)
            local p=$(echo $pausen | xargs)
            
            local hours=$(calc_hours "$st" "$en" "$p")
            echo "- **$user** auf *$baustelle*: $st - $en ($hours h, $p Pause)"
        done
        echo ""
    else
        echo "## Keine Zeiterfassung für heute"
        echo ""
    fi
    
    # Material
    if [ -f "$MATERIAL_FILE" ]; then
        echo "## Material"
        echo ""
        
        local total=$(jq --arg d "$date" \
            '[.materialien[] | select(.datum == $d)] | map(.gesamtpreis) | add // 0' \
            "$MATERIAL_FILE")
        
        if [ "$total" != "0" ]; then
            jq --arg d "$date" \
                '[.materialien[] | select(.datum == $d)]' \
                "$MATERIAL_FILE" | jq -r '.[] | "- \(.menge)x \(.material): \(.gesamtpreis)€"' 
            echo ""
            echo "**Gesamtmaterial:** ${total}€"
            echo ""
        else
            echo "Kein Material heute"
            echo ""
        fi
    fi
    
    # Fotos
    if [ -f "$FOTOS_FILE" ]; then
        echo "## Fotos"
        echo ""
        
        local count=$(jq --arg d "$date" \
            '[.fotos[] | select(.datum == $d)] | length' \
            "$FOTOS_FILE")
        
        if [ "$count" != "0" ]; then
            jq --arg d "$date" \
                '[.fotos[] | select(.datum == $d)]' \
                "$FOTOS_FILE" | jq -r '.[] | "- \(.uhrzeit) \(.beschreibung // "ohne Beschreibung")"'
            echo ""
        else
            echo "Keine Fotos heute"
            echo ""
        fi
    fi
    
    echo "---"
    echo "*Erstellt: $(date +%d.%m.%Y %H:%M)*"
}

do_baustelle() {
    local name=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --name) name="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$name" ]; then
        echo "Error: --name ist erforderlich"
        exit 1
    fi
    
    echo "# Bericht - Baustelle $name"
    echo ""
    echo "(Aggregiert alle Daten für diese Baustelle)"
    echo ""
    
    # Zeiterfassung
    if [ -f "$ZEIT_DIR/$TODAY.json" ]; then
        echo "## Heutige Arbeitszeit"
        jq --arg b "$name" \
            '[.eintraege[] | select(.baustelle == $b)]' \
            "$ZEIT_DIR/$TODAY.json" | jq -r '.[] | "- \(.user): \(.start // "?") - \(.ende // "offen")"'
        echo ""
    fi
    
    # Material
    if [ -f "$MATERIAL_FILE" ]; then
        local total=$(jq --arg b "$name" \
            '[.materialien[] | select(.baustelle == $b)] | map(.gesamtpreis) | add // 0' \
            "$MATERIAL_FILE")
        
        echo "## Material: ${total}€"
        jq --arg b "$name" \
            '[.materialien[] | select(.baustelle == $b)]' \
            "$MATERIAL_FILE" | jq -r '.[] | "- \(.datum): \(.menge)x \(.material) = \(.gesamtpreis)€"'
        echo ""
    fi
}

do_status() {
    local zeit_file=$(get_date_file "$TODAY")
    
    echo "=== Status $(date +%d.%m.%Y) ==="
    echo ""
    
    if [ -f "$zeit_file" ]; then
        local users=$(jq -r '.eintraege[] | .user' "$zeit_file" | sort -u)
        echo "Eingecheckt:"
        for u in $users; do
            local status=$(jq --arg user "$u" \
                '[.eintraege[] | select(.user == $user)] | last' \
                "$zeit_file" | jq -r '.ende // "🔴 noch da"')
            
            if [ "$status" = "null" ] || [ -z "$status" ]; then
                status="🔴 noch da"
            else
                status="✅ $status"
            fi
            
            echo "  - $u: $status"
        done
    else
        echo "Keine Check-ins heute"
    fi
}

case "$COMMAND" in
    heute|today)
        do_heute
        ;;
    baustelle)
        do_baustelle "$@"
        ;;
    datum)
        do_datum "$@"
        ;;
    status)
        do_status
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "nexworker-report: Unbekannter Befehl '$COMMAND'"
        usage
        exit 1
        ;;
esac
