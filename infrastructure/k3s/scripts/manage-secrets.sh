#!/bin/bash
# ============================================================================
# Uso:
#   ./scripts/manage-secrets.sh setup   <env>    # Create or update secret
#   ./scripts/manage-secrets.sh status  <env>    # Show secret status
#   ./scripts/manage-secrets.sh delete  <env>    # Delete secret
#
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SECRET_NAME="caicedo-seguros-secrets"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# SETUP (CREATE OR UPDATE)
# ============================================================================
cmd_setup() {
  local env=$1
  local env_file="${BASE_DIR}/overlays/${env}/secrets/.env"
  local template_file="${BASE_DIR}/overlays/${env}/secrets/.env.template"

  echo -e "${CYAN}============================================${NC}"
  echo -e "${CYAN} Secrets setup: ${env}${NC}"
  echo -e "${CYAN}============================================${NC}"

  # Si no existe .env pero sí .env.template, copiar automáticamente
  if [ ! -f "$env_file" ]; then
    if [ -f "$template_file" ]; then
      cp "$template_file" "$env_file"
      echo -e "${YELLOW}[WARN]${NC} Created .env from template. Edit credentials before production:"
      echo -e "       ${env_file}"
    else
      echo -e "${RED}[ERROR]${NC} File not found: ${env_file}"
      echo -e "  Create it:"
      echo -e "  cp overlays/${env}/secrets/.env.template overlays/${env}/secrets/.env"
      exit 1
    fi
  fi

  # Warn about placeholders (fixed: grep -q avoids capture issues)
  if grep -q 'CAMBIAR_AQUI' "$env_file" 2>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Found 'CAMBIAR_AQUI' placeholders in .env — replace before production"
  fi

  # Create/update secret (IDEMPOTENT: --dry-run=client | kubectl apply)
  echo -e "${CYAN}Creating/updating secret '${SECRET_NAME}' in namespace '${env}'...${NC}"

  kubectl create secret generic "${SECRET_NAME}" \
    --from-env-file="${env_file}" \
    -n "${env}" \
    --dry-run=client -o yaml | kubectl apply -f -

  # Count keys
  local key_count
  key_count=$(kubectl get secret "${SECRET_NAME}" -n "${env}" -o json 2>/dev/null \
    | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',{})))" 2>/dev/null \
    || echo "?")

  echo -e "${GREEN}[OK]${NC} Secret '${SECRET_NAME}' in '${env}' (${key_count} keys)"

  # List keys
  kubectl get secret "${SECRET_NAME}" -n "${env}" -o json 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin).get('data', {})
for k in sorted(data.keys()):
    print(f'       - {k}')
" 2>/dev/null || true

  echo ""
}

# ============================================================================
# STATUS
# ============================================================================
cmd_status() {
  local env=$1

  echo -e "${CYAN}=== Secret status: ${env} ===${NC}"

  if kubectl get secret "${SECRET_NAME}" -n "${env}" &>/dev/null; then
    local key_count
    key_count=$(kubectl get secret "${SECRET_NAME}" -n "${env}" -o json 2>/dev/null \
      | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',{})))" 2>/dev/null \
      || echo "?")
    echo -e "  ${GREEN}✓${NC} ${SECRET_NAME} (${key_count} keys)"
  else
    echo -e "  ${RED}✗${NC} ${SECRET_NAME} — not found"
  fi

  echo ""
  echo -e "${CYAN}All secrets in namespace ${env}:${NC}"
  kubectl get secrets -n "${env}" --no-headers 2>/dev/null | while read -r line; do
    echo "  $line"
  done
}

# ============================================================================
# DELETE
# ============================================================================
cmd_delete() {
  local env=$1

  echo -e "${YELLOW}Deleting secret '${SECRET_NAME}' in namespace '${env}'...${NC}"
  if kubectl delete secret "${SECRET_NAME}" -n "${env}" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC} Deleted"
  else
    echo -e "  ${YELLOW}[SKIP]${NC} Not found"
  fi
}

# ============================================================================
# MAIN
# ============================================================================
usage() {
  echo "Usage: $0 {setup|status|delete} <environment>"
  echo ""
  echo "  setup   Create or update secret from .env file (idempotent)"
  echo "  status  Show current secret and key counts"
  echo "  delete  Remove application secret"
  echo ""
  echo "Environments: develop, test, production"
  exit 1
}

if [ $# -lt 2 ]; then
  usage
fi

command=$1
env=$2

case "$env" in
  develop|test|production) ;;
  *) echo -e "${RED}Invalid environment: ${env}${NC}"; usage ;;
esac

case "$command" in
  setup)  cmd_setup "$env" ;;
  status) cmd_status "$env" ;;
  delete) cmd_delete "$env" ;;
  *)      usage ;;
esac