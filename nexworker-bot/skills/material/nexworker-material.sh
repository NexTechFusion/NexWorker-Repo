#!/bin/bash
# nexworker-material - Material-Erfassung
# Usage: nexworker-material <command> [options]

set -e

STORAGE_DIR="/app/storage/material"
INDEX_FILE="$STORAGE_DIR/material.json"
TODAY=$(date +%Y-%m-%d)
CURRENT_USER="${USER:-Unknown}"

COMMAND="${1:-}"
shift || true

usage() {
    echo "nexworker-material - Material-Erfassung"
    echo ""
    echo "Commands:"
    echo "  add          Material hinzufügen"
    echo "  list         Material auflisten"
    echo "  costs        Kosten zusammenfassen"
    echo "  search       Material suchen"
    echo ""
    echo "Options:"
    echo "  --material NAME   Material-Bezeichnung"
    echo "  --menge N         Menge"
    echo "  --einheit E       Einheit (Rollen, Meter, Stück...)"
    echo "  --preis N         Preis in Euro"
    echo "  --baustelle NAME  Baustelle"
    echo "  --user NAME       Erfasst von"
}

init_index() {
    mkdir -p "$STORAGE_DIR"
    if [ ! -f "$INDEX_FILE" ]; then
        echo '{"materialien":[]}' > "$INDEX_FILE"
    fi
}

generate_id() {
    echo "mat_$(date +%s)"
}

do_add() {
    local material=""
    local menge=1
    local einheit="Stück"
    local preis=0
    local baustelle=""
    local user="$CURRENT_USER"
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --material) material="$2"; shift 2 ;;
            --menge) menge="$2"; shift 2 ;;
            --einheit) einheit="$2"; shift 2 ;;
            --preis) preis="$2"; shift 2 ;;
            --baustelle) baustelle="$2"; shift 2 ;;
            --user) user="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$material" ]; then
        echo "Error: --material ist erforderlich"
        exit 1
    fi
    
    if [ -z "$baustelle" ]; then
        echo "Error: --baustelle ist erforderlich"
        exit 1
    fi
    
    init_index
    
    local id=$(generate_id)
    local gesamtpreis=$(echo "$menge * $preis" | bc)
    
    local entry=$(jq -n \
        --arg id "$id" \
        --arg datum "$TODAY" \
        --arg baustelle "$baustelle" \
        --arg material "$material" \
        --argjson menge "$menge" \
        --arg einheit "$einheit" \
        --argjson preis "$preis" \
        --argjson gesamt "$gesamtpreis" \
        --arg user "$user" \
        '{
            id: $id,
            datum: $datum,
            baustelle: $baustelle,
            material: $material,
            menge: $menge,
            einheit: $einheit,
            preis: $preis,
            gesamtpreis: $gesamt,
            user: $user
        }')
    
    local new_data=$(jq --argjson entry "$entry" '.materialien += [$entry]' "$INDEX_FILE")
    echo "$new_data" > "$INDEX_FILE"
    
    echo "✅ Material erfasst:"
    echo "   $menge $einheit $material = ${gesamtpreis}€ (Baustelle: $baustelle)"
}

do_list() {
    local baustelle=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --baustelle) baustelle="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    init_index
    
    if [ -n "$baustelle" ]; then
        jq --arg b "$baustelle" \
            '[.materialien[] | select(.baustelle == $b)]' \
            "$INDEX_FILE" | jq -r '.[] | "\(.datum) | \(.menge) \(.einheit) \(.material) | \(.gesamtpreis)€"'
    else
        jq -r '.materialien[] | "\(.datum) | \(.baustelle) | \(.menge) \(.einheit) \(.material) | \(.gesamtpreis)€"' "$INDEX_FILE"
    fi
}

do_costs() {
    local baustelle=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --baustelle) baustelle="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    init_index
    
    if [ -n "$baustelle" ]; then
        local total=$(jq --arg b "$baustelle" \
            '[.materialien[] | select(.baustelle == $b)] | map(.gesamtpreis) | add' \
            "$INDEX_FILE")
        echo "Kosten für $baustelle: ${total}€"
    else
        local total=$(jq '[.materialien[].gesamtpreis] | add' "$INDEX_FILE")
        echo "Gesamtkosten: ${total}€"
    fi
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
    
    init_index
    
    jq --arg q "$query" \
        '[.materialien[] | select(.material | contains($q))]' \
        "$INDEX_FILE" | jq -r '.[] | "\(.datum) | \(.baustelle) | \(.menge) \(.einheit) \(.material) | \(.gesamtpreis)€"'
}

case "$COMMAND" in
    add)
        do_add "$@"
        ;;
    list)
        do_list "$@"
        ;;
    costs)
        do_costs "$@"
        ;;
    search)
        do_search "$@"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "nexworker-material: Unbekannter Befehl '$COMMAND'"
        usage
        exit 1
        ;;
esac
