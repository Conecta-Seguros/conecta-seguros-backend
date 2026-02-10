#!/bin/bash
# ============================================================================
#
# Uso:
#   ./scripts/port-forward.sh start     # Inicia todos los port-forwards
#   ./scripts/port-forward.sh stop      # Detiene todos
#   ./scripts/port-forward.sh status    # Muestra estado
#   ./scripts/port-forward.sh logs      # Muestra logs
#
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="${SCRIPT_DIR}/.pf-pids"
LOG_DIR="${SCRIPT_DIR}/.pf-logs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# SERVICIOS: nombre|namespace|servicio|puerto_local:puerto_remoto
# ============================================================================
SERVICES=(
  "FusionAuth|develop|svc/fusionauth-svc|9011:9011"
  "PostgreSQL|develop|svc/postgresql-svc|5432:5432"
  "Grafana|observability|svc/kube-prometheus-stack-grafana|3000:80"
  "Prometheus|observability|svc/kube-prometheus-stack-prometheus|9090:9090"
  "Alertmanager|observability|svc/kube-prometheus-stack-alertmanager|9093:9093"
)

# ============================================================================
# HELPERS
# ============================================================================
ensure_dirs() {
  mkdir -p "$PID_DIR" "$LOG_DIR"
}

get_name()      { echo "$1" | cut -d'|' -f1; }
get_namespace() { echo "$1" | cut -d'|' -f2; }
get_service()   { echo "$1" | cut -d'|' -f3; }
get_ports()     { echo "$1" | cut -d'|' -f4; }
get_local_port(){ echo "$1" | cut -d'|' -f4 | cut -d':' -f1; }

pid_file() {
  local name
  name=$(get_name "$1" | tr '[:upper:]' '[:lower:]')
  echo "${PID_DIR}/${name}.pid"
}

log_file() {
  local name
  name=$(get_name "$1" | tr '[:upper:]' '[:lower:]')
  echo "${LOG_DIR}/${name}.log"
}

is_running() {
  local pf="$1"
  local pfile
  pfile=$(pid_file "$pf")
  if [ -f "$pfile" ]; then
    local pid
    pid=$(cat "$pfile")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    rm -f "$pfile"
  fi
  return 1
}

# ============================================================================
# START
# ============================================================================
cmd_start() {
  ensure_dirs

  echo -e "${BOLD}"
  echo "============================================"
  echo " Starting port-forwards (local development)"
  echo "============================================"
  echo -e "${NC}"

  # Preflight
  if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Cannot connect to cluster"
    exit 1
  fi

  local started=0
  local skipped=0
  local failed=0

  for svc in "${SERVICES[@]}"; do
    local name ns service ports local_port
    name=$(get_name "$svc")
    ns=$(get_namespace "$svc")
    service=$(get_service "$svc")
    ports=$(get_ports "$svc")
    local_port=$(get_local_port "$svc")

    # Skip if already running
    if is_running "$svc"; then
      local pid
      pid=$(cat "$(pid_file "$svc")")
      echo -e "  ${YELLOW}[SKIP]${NC} ${name} — already running (PID ${pid}, port ${local_port})"
      skipped=$((skipped + 1))
      continue
    fi

    # Check if port is already in use
    if lsof -i ":${local_port}" &>/dev/null 2>&1 || ss -tlnp 2>/dev/null | grep -q ":${local_port} "; then
      echo -e "  ${RED}[FAIL]${NC} ${name} — port ${local_port} already in use"
      failed=$((failed + 1))
      continue
    fi

    # Check if service exists
    if ! kubectl get "$service" -n "$ns" &>/dev/null; then
      echo -e "  ${RED}[FAIL]${NC} ${name} — ${service} not found in ${ns}"
      failed=$((failed + 1))
      continue
    fi

    # Start port-forward in background
    local lfile
    lfile=$(log_file "$svc")
    kubectl port-forward "$service" "$ports" -n "$ns" \
      > "$lfile" 2>&1 &
    local pid=$!

    # Wait briefly and verify it started
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid" > "$(pid_file "$svc")"
      echo -e "  ${GREEN}[OK]${NC} ${name} → http://localhost:${local_port} (PID ${pid})"
      started=$((started + 1))
    else
      echo -e "  ${RED}[FAIL]${NC} ${name} — port-forward exited immediately"
      cat "$lfile" 2>/dev/null | head -3 | while read -r line; do
        echo -e "         ${line}"
      done
      failed=$((failed + 1))
    fi
  done

  echo ""
  echo -e "${CYAN}────────────────────────────────────────${NC}"
  echo -e "  Started: ${GREEN}${started}${NC} | Skipped: ${YELLOW}${skipped}${NC} | Failed: ${RED}${failed}${NC}"
  echo -e "${CYAN}────────────────────────────────────────${NC}"

  if [ $started -gt 0 ] || [ $skipped -gt 0 ]; then
    echo ""
    echo -e "${BOLD}Servicios disponibles:${NC}"
    for svc in "${SERVICES[@]}"; do
      if is_running "$svc"; then
        local name local_port
        name=$(get_name "$svc")
        local_port=$(get_local_port "$svc")
        case "$name" in
          Grafana)
            local pass
            pass=$(kubectl get secret kube-prometheus-stack-grafana -n observability \
              -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "?")
            echo -e "  ${GREEN}●${NC} ${name}:       http://localhost:${local_port}  (admin / ${pass})"
            ;;
          FusionAuth)
            echo -e "  ${GREEN}●${NC} ${name}:    http://localhost:${local_port}"
            ;;
          *)
            echo -e "  ${GREEN}●${NC} ${name}:  http://localhost:${local_port}"
            ;;
        esac
      fi
    done
    echo ""
    echo -e "  Detener: ${CYAN}./scripts/port-forward.sh stop${NC}"
  fi
}

# ============================================================================
# STOP
# ============================================================================
cmd_stop() {
  ensure_dirs

  echo -e "${BOLD}Stopping port-forwards...${NC}"

  local stopped=0
  for svc in "${SERVICES[@]}"; do
    local name
    name=$(get_name "$svc")
    if is_running "$svc"; then
      local pid
      pid=$(cat "$(pid_file "$svc")")
      kill "$pid" 2>/dev/null || true
      rm -f "$(pid_file "$svc")"
      echo -e "  ${GREEN}[OK]${NC} ${name} (PID ${pid}) stopped"
      stopped=$((stopped + 1))
    fi
  done

  if [ $stopped -eq 0 ]; then
    echo -e "  ${YELLOW}No active port-forwards${NC}"
  else
    echo -e "  ${GREEN}${stopped} port-forward(s) stopped${NC}"
  fi

  # Cleanup any orphaned kubectl port-forward processes
  pkill -f "kubectl port-forward" 2>/dev/null || true
}

# ============================================================================
# STATUS
# ============================================================================
cmd_status() {
  ensure_dirs

  echo -e "${BOLD}=== Port-Forward Status ===${NC}"
  echo ""

  local running=0
  local total=${#SERVICES[@]}

  for svc in "${SERVICES[@]}"; do
    local name local_port
    name=$(get_name "$svc")
    local_port=$(get_local_port "$svc")

    if is_running "$svc"; then
      local pid
      pid=$(cat "$(pid_file "$svc")")
      echo -e "  ${GREEN}●${NC} ${name}: http://localhost:${local_port} (PID ${pid})"
      running=$((running + 1))
    else
      echo -e "  ${RED}○${NC} ${name}: not running (port ${local_port})"
    fi
  done

  echo ""
  echo -e "  ${running}/${total} active"
}

# ============================================================================
# LOGS
# ============================================================================
cmd_logs() {
  ensure_dirs

  echo -e "${BOLD}=== Port-Forward Logs ===${NC}"
  for svc in "${SERVICES[@]}"; do
    local name lfile
    name=$(get_name "$svc")
    lfile=$(log_file "$svc")

    if [ -f "$lfile" ]; then
      echo ""
      echo -e "${CYAN}── ${name} ──${NC}"
      tail -5 "$lfile" 2>/dev/null || echo "  (empty)"
    fi
  done
}

# ============================================================================
# MAIN
# ============================================================================
usage() {
  echo "Usage: $0 {start|stop|status|logs}"
  echo ""
  echo "  start   Launch all port-forwards in background"
  echo "  stop    Kill all port-forwards"
  echo "  status  Show which are running"
  echo "  logs    Show recent logs"
  echo ""
  echo "Services:"
  for svc in "${SERVICES[@]}"; do
    local name local_port
    name=$(get_name "$svc")
    local_port=$(get_local_port "$svc")
    echo "  ${name} → localhost:${local_port}"
  done
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

case "$1" in
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  logs)   cmd_logs ;;
  *)      usage ;;
esac