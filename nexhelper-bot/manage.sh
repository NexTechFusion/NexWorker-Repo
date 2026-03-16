#!/bin/bash
# manage.sh — NexHelper Control Plane CLI
# Provides a unified interface to operate all customer instances.
#
# Usage:
#   ./manage.sh list                         List all provisioned customer instances
#   ./manage.sh status <instance-name>       Detailed health status for one instance
#   ./manage.sh logs <instance-name> [n]     Recent log lines (default 50)
#   ./manage.sh provision <id> <name> ...    Provision a new customer (delegates to provision-customer.sh)
#   ./manage.sh start <instance-name>        Start a stopped instance
#   ./manage.sh stop <instance-name>         Stop a running instance
#   ./manage.sh crons <instance-name>        List registered cron jobs for an instance
#   ./manage.sh monitor <instance-name>      Run nexhelper-monitor inside an instance
#   ./manage.sh summary                      Aggregate health across all instances (JSON)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-/opt/nexhelper/customers}"
OUTPUT_FORMAT="${FORMAT:-text}"

# ── helpers ────────────────────────────────────────────────────────────────────

_require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found on PATH" >&2
    exit 1
  fi
}

_all_instances() {
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E '^nexhelper-' || true
}

_container_status() {
  local name="$1"
  docker ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null \
    | awk -v n="$name" '$1 == n {print $2}' \
    | head -1
}

_instance_port() {
  local name="$1"
  docker inspect "$name" --format '{{range $p,$conf := .NetworkSettings.Ports}}{{if $conf}}{{(index $conf 0).HostPort}}{{end}}{{end}}' 2>/dev/null | head -1
}

_health_status() {
  local name="$1"
  local port
  port="$(_instance_port "$name")"
  if [ -n "$port" ]; then
    local http_code
    http_code="$(curl -o /dev/null -s -w '%{http_code}' --max-time 3 "http://localhost:$port/health" 2>/dev/null || echo "000")"
    if [ "$http_code" = "200" ]; then echo "healthy"; else echo "unreachable (HTTP $http_code)"; fi
  else
    echo "no-port"
  fi
}

_exec_in() {
  local name="$1"
  shift
  docker exec "$name" sh -lc "$*" 2>/dev/null
}

# ── commands ───────────────────────────────────────────────────────────────────

cmd_list() {
  local instances
  mapfile -t instances < <(_all_instances)

  if [ "${#instances[@]}" -eq 0 ]; then
    echo '{"instances":[],"count":0}'
    return
  fi

  local arr="[]"
  for name in "${instances[@]}"; do
    local run_status health
    run_status="$(docker inspect "$name" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")"
    if [ "$run_status" = "running" ]; then
      health="$(_health_status "$name")"
    else
      health="stopped"
    fi
    local port
    port="$(_instance_port "$name")"
    arr="$(echo "$arr" | jq -c \
      --arg n "$name" --arg s "$run_status" --arg h "$health" --arg p "$port" \
      '. + [{name:$n,runStatus:$s,health:$h,port:$p}]')"
  done

  jq -c -n --argjson instances "$arr" --argjson count "${#instances[@]}" \
    '{instances:$instances,count:$count}'
}

cmd_status() {
  local name="${1:-}"
  [ -z "$name" ] && { echo "Error: instance name required" >&2; exit 1; }

  local run_status health port
  run_status="$(docker inspect "$name" --format '{{.State.Status}}' 2>/dev/null || echo "not_found")"
  if [ "$run_status" = "not_found" ]; then
    jq -c -n --arg name "$name" '{name:$name,status:"not_found"}'
    return
  fi

  port="$(_instance_port "$name")"
  health="$(_health_status "$name")"

  local cron_count=0
  local monitor_status="unavailable"
  if [ "$run_status" = "running" ]; then
    cron_count="$(_exec_in "$name" "openclaw cron list --json 2>/dev/null | jq '.jobs | length' 2>/dev/null || echo 0")"
    local monitor_raw
    monitor_raw="$(_exec_in "$name" "nexhelper-monitor report 2>/dev/null || echo '{}'")"
    monitor_status="$(echo "$monitor_raw" | jq -r '.status // "unavailable"' 2>/dev/null || echo "unavailable")"
  fi

  local image_info
  image_info="$(docker inspect "$name" --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")"

  jq -c -n \
    --arg name "$name" \
    --arg runStatus "$run_status" \
    --arg health "$health" \
    --arg port "$port" \
    --arg image "$image_info" \
    --arg monitorStatus "$monitor_status" \
    --argjson cronCount "${cron_count:-0}" \
    '{name:$name,runStatus:$runStatus,health:$health,port:$port,image:$image,monitorStatus:$monitorStatus,cronJobCount:$cronCount}'
}

cmd_logs() {
  local name="${1:-}"
  local lines="${2:-50}"
  [ -z "$name" ] && { echo "Error: instance name required" >&2; exit 1; }
  docker logs "$name" --tail "$lines" 2>&1
}

cmd_provision() {
  local provision_script="$SCRIPT_DIR/provision-customer.sh"
  if [ ! -x "$provision_script" ]; then
    echo "Error: provision-customer.sh not found at $SCRIPT_DIR" >&2
    exit 1
  fi
  "$provision_script" "$@"
}

cmd_start() {
  local name="${1:-}"
  [ -z "$name" ] && { echo "Error: instance name required" >&2; exit 1; }
  local customer_dir
  customer_dir="$(find "$BASE_DIR" -maxdepth 2 -name "docker-compose.yaml" \
    | xargs grep -l "container_name: $name" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)"
  if [ -n "$customer_dir" ] && [ -f "$customer_dir/start.sh" ]; then
    bash "$customer_dir/start.sh"
  else
    docker start "$name" 2>/dev/null \
      && jq -c -n --arg name "$name" '{status:"started",name:$name}' \
      || jq -c -n --arg name "$name" '{status:"error",name:$name,reason:"could not start"}'
  fi
}

cmd_stop() {
  local name="${1:-}"
  [ -z "$name" ] && { echo "Error: instance name required" >&2; exit 1; }
  docker stop "$name" 2>/dev/null \
    && jq -c -n --arg name "$name" '{status:"stopped",name:$name}' \
    || jq -c -n --arg name "$name" '{status:"error",name:$name,reason:"could not stop"}'
}

cmd_crons() {
  local name="${1:-}"
  [ -z "$name" ] && { echo "Error: instance name required" >&2; exit 1; }
  _exec_in "$name" "openclaw cron list --json 2>/dev/null || echo '{}'"
}

cmd_monitor() {
  local name="${1:-}"
  [ -z "$name" ] && { echo "Error: instance name required" >&2; exit 1; }
  _exec_in "$name" "nexhelper-monitor report 2>/dev/null || echo '{\"status\":\"unavailable\"}'"
}

cmd_summary() {
  local list_json
  list_json="$(cmd_list)"
  local instances
  mapfile -t instances < <(echo "$list_json" | jq -r '.instances[].name')

  local healthy=0 degraded=0 stopped=0 total="${#instances[@]}"
  local details="[]"

  for name in "${instances[@]}"; do
    local run_status health
    run_status="$(echo "$list_json" | jq -r --arg n "$name" '.instances[] | select(.name==$n) | .runStatus')"
    health="$(echo "$list_json" | jq -r --arg n "$name" '.instances[] | select(.name==$n) | .health')"
    if [ "$run_status" != "running" ]; then
      stopped=$((stopped + 1))
    elif [ "$health" = "healthy" ]; then
      healthy=$((healthy + 1))
    else
      degraded=$((degraded + 1))
    fi
    details="$(echo "$details" | jq -c \
      --arg n "$name" --arg s "$run_status" --arg h "$health" \
      '. + [{name:$n,runStatus:$s,health:$h}]')"
  done

  local overall_status="ok"
  [ "$degraded" -gt 0 ] && overall_status="degraded"
  [ "$stopped" -gt 0 ] && overall_status="${overall_status:-warning}"

  jq -c -n \
    --arg status "$overall_status" \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --argjson total "$total" \
    --argjson healthy "$healthy" \
    --argjson degraded "$degraded" \
    --argjson stopped "$stopped" \
    --argjson details "$details" \
    '{status:$status,timestamp:$ts,total:$total,healthy:$healthy,degraded:$degraded,stopped:$stopped,instances:$details}'
}

# ── dispatch ───────────────────────────────────────────────────────────────────

_require_cmd docker
_require_cmd jq

CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  list)       cmd_list "$@" ;;
  status)     cmd_status "$@" ;;
  logs)       cmd_logs "$@" ;;
  provision)  cmd_provision "$@" ;;
  start)      cmd_start "$@" ;;
  stop)       cmd_stop "$@" ;;
  crons)      cmd_crons "$@" ;;
  monitor)    cmd_monitor "$@" ;;
  summary)    cmd_summary "$@" ;;
  help|--help|-h)
    cat <<'EOF'
NexHelper Control Plane — manage.sh

Commands:
  list                         List all provisioned instances with health
  status <instance>            Detailed status for one instance
  logs <instance> [lines]      Tail container logs (default 50 lines)
  provision <id> <name> ...    Provision a new customer instance
  start <instance>             Start a stopped instance
  stop <instance>              Stop a running instance
  crons <instance>             Show scheduled cron jobs for an instance
  monitor <instance>           Run full observability report for an instance
  summary                      Aggregate health across all instances

Environment:
  BASE_DIR=/opt/nexhelper/customers   Base directory for customer instances

Examples:
  ./manage.sh list
  ./manage.sh status nexhelper-acme-001
  ./manage.sh logs nexhelper-acme-001 100
  ./manage.sh summary
  ./manage.sh provision 001 "Acme GmbH" --telegram "123:ABC" --delivery-to telegram:579539601
EOF
    ;;
  *)
    echo "Unknown command: $CMD. Run './manage.sh help' for usage." >&2
    exit 1
    ;;
esac
