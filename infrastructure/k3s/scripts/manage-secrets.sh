#!/bin/bash
# ============================================================================
# manage-secrets.sh - Gestión completa de secrets desde .env
# ============================================================================
# Ruta: infrastructure/k3s/scripts/manage-secrets.sh
#
# Uso:
#   ./scripts/manage-secrets.sh setup   <entorno>    # init + edit + create (todo)
#   ./scripts/manage-secrets.sh init    [entorno|all] # .env.example → .env
#   ./scripts/manage-secrets.sh create  <entorno>     # kubectl create secret
#   ./scripts/manage-secrets.sh update  <entorno>     # kubectl apply secret
#   ./scripts/manage-secrets.sh delete  <entorno>     # kubectl delete secret
#   ./scripts/manage-secrets.sh verify  <entorno>     # verificar keys
#   ./scripts/manage-secrets.sh show    <entorno>     # mostrar comando sin ejecutar
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
OVERLAYS_DIR="${BASE_DIR}/overlays"
SECRET_NAME="caicedo-seguros-secrets"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  echo ""
  echo "Uso: $0 <command> [environment]"
  echo ""
  echo "  setup   <env>      Init + create en un solo paso"
  echo "  init    [env|all]  Copiar .env.example → .env"
  echo "  create  <env>      Crear secret (falla si ya existe)"
  echo "  update  <env>      Crear o actualizar secret"
  echo "  delete  <env>      Eliminar secret del cluster"
  echo "  verify  <env>      Verificar que el secret existe"
  echo "  show    <env>      Mostrar comando kubectl sin ejecutar"
  echo ""
  echo "Environments: develop, test, production"
  echo ""
  exit 1
}

get_env_file() { echo "${OVERLAYS_DIR}/$1/secrets/.env"; }
get_example()  { echo "${OVERLAYS_DIR}/$1/secrets/.env.example"; }

check_env_exists() {
  local env=$1
  local env_file=$(get_env_file "$env")
  if [ ! -f "$env_file" ]; then
    echo -e "${RED}[ERROR]${NC} No existe: ${env_file}"
    echo -e "       Ejecutar primero: $0 init ${env}"
    exit 1
  fi
}

check_namespace() {
  local env=$1
  if ! kubectl get namespace "${env}" > /dev/null 2>&1; then
    echo -e "${YELLOW}[WARN]${NC} Namespace '${env}' no existe. Creando..."
    kubectl create namespace "${env}"
    echo -e "${GREEN}[OK]${NC}   Namespace '${env}' creado"
  fi
}

# --- init: .env.example → .env ---
cmd_init() {
  local target="${1:-all}"

  if [ "$target" = "all" ]; then
    for env in develop test production; do cmd_init "$env"; done
    return
  fi

  local env_file=$(get_env_file "$target")
  local example=$(get_example "$target")

  if [ -f "$env_file" ]; then
    echo -e "${YELLOW}[SKIP]${NC} ${target}: .env ya existe en ${env_file}"
    return
  fi

  if [ ! -f "$example" ]; then
    echo -e "${RED}[ERROR]${NC} ${target}: .env.example no encontrado en ${example}"
    return 1
  fi

  cp "$example" "$env_file"
  echo -e "${GREEN}[OK]${NC}   ${target}: .env creado"
  echo -e "       ${CYAN}→ Editar: ${env_file}${NC}"
}

# --- create: kubectl create secret ---
cmd_create() {
  local env=$1
  local env_file=$(get_env_file "$env")
  check_env_exists "$env"
  check_namespace "$env"

  echo -e "[INFO] Creando secret '${SECRET_NAME}' en namespace '${env}'..."
  echo -e "${CYAN}       kubectl create secret generic ${SECRET_NAME} --from-env-file=${env_file} -n ${env}${NC}"
  echo ""

  kubectl create secret generic "${SECRET_NAME}" \
    --from-env-file="${env_file}" \
    -n "${env}"

  echo ""
  echo -e "${GREEN}[OK]${NC} Secret '${SECRET_NAME}' creado en namespace '${env}'"
  cmd_verify "$env"
}

# --- update: crear o reemplazar ---
cmd_update() {
  local env=$1
  local env_file=$(get_env_file "$env")
  check_env_exists "$env"
  check_namespace "$env"

  echo -e "[INFO] Actualizando secret '${SECRET_NAME}' en namespace '${env}'..."
  echo -e "${CYAN}       kubectl create secret generic ${SECRET_NAME} --from-env-file=${env_file} -n ${env} --dry-run=client -o yaml | kubectl apply -f -${NC}"
  echo ""

  kubectl create secret generic "${SECRET_NAME}" \
    --from-env-file="${env_file}" \
    -n "${env}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo ""
  echo -e "${GREEN}[OK]${NC} Secret '${SECRET_NAME}' actualizado en namespace '${env}'"
  cmd_verify "$env"
}

# --- delete: eliminar secret ---
cmd_delete() {
  local env=$1

  echo -e "${YELLOW}[WARN]${NC} Eliminando secret '${SECRET_NAME}' de namespace '${env}'..."
  read -p "         ¿Continuar? (y/N): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo -e "[CANCEL] Operación cancelada"
    return
  fi

  kubectl delete secret "${SECRET_NAME}" -n "${env}"
  echo -e "${GREEN}[OK]${NC} Secret eliminado"
}

# --- verify: verificar secret ---
cmd_verify() {
  local env=$1

  if ! kubectl get secret "${SECRET_NAME}" -n "${env}" > /dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Secret '${SECRET_NAME}' no existe en namespace '${env}'"
    exit 1
  fi

  local key_count=$(kubectl get secret "${SECRET_NAME}" -n "${env}" -o json | jq '.data | keys | length')
  echo -e "${GREEN}[OK]${NC} Secret '${SECRET_NAME}' en '${env}' (${key_count} keys):"
  kubectl get secret "${SECRET_NAME}" -n "${env}" -o json | \
    jq -r '.data | keys[]' | sed 's/^/       - /'
}

# --- show: mostrar comando sin ejecutar ---
cmd_show() {
  local env=$1
  local env_file=$(get_env_file "$env")

  echo ""
  echo -e "${CYAN}# Crear secret:${NC}"
  echo "kubectl create secret generic ${SECRET_NAME} \\"
  echo "  --from-env-file=${env_file} \\"
  echo "  -n ${env}"
  echo ""
  echo -e "${CYAN}# Actualizar secret:${NC}"
  echo "kubectl create secret generic ${SECRET_NAME} \\"
  echo "  --from-env-file=${env_file} \\"
  echo "  -n ${env} --dry-run=client -o yaml | kubectl apply -f -"
  echo ""
  echo -e "${CYAN}# Verificar:${NC}"
  echo "kubectl get secret ${SECRET_NAME} -n ${env} -o json | jq '.data | keys[]'"
  echo ""
}

# --- setup: init + pausa para editar + create ---
cmd_setup() {
  local env=$1
  local env_file=$(get_env_file "$env")

  echo "============================================"
  echo " Setup completo para: ${env}"
  echo "============================================"
  echo ""

  # Paso 1: init
  cmd_init "$env"

  # Paso 2: preguntar si quiere editar
  echo ""
  echo -e "${YELLOW}[PASO 2]${NC} Editar credenciales en: ${env_file}"
  read -p "         ¿Abrir editor ahora? (Y/n): " edit_confirm
  if [ "$edit_confirm" != "n" ] && [ "$edit_confirm" != "N" ]; then
    ${EDITOR:-vi} "$env_file"
  fi

  # Verificar que cambió los valores default
  if grep -q "CAMBIAR_AQUI" "$env_file"; then
    echo -e "${YELLOW}[WARN]${NC} El .env todavía tiene valores 'CAMBIAR_AQUI'"
    read -p "         ¿Continuar de todos modos? (y/N): " force_confirm
    if [ "$force_confirm" != "y" ] && [ "$force_confirm" != "Y" ]; then
      echo -e "       Editar manualmente: ${CYAN}${env_file}${NC}"
      echo -e "       Luego ejecutar:     ${CYAN}$0 create ${env}${NC}"
      exit 0
    fi
  fi

  # Paso 3: crear secret
  echo ""
  echo -e "${YELLOW}[PASO 3]${NC} Creando secret en el cluster..."
  cmd_create "$env"

  echo ""
  echo "============================================"
  echo -e " ${GREEN}Setup completado para: ${env}${NC}"
  echo ""
  echo " Aplicar jobs:"
  echo "   kubectl apply -k ${OVERLAYS_DIR}/${env}/jobs/"
  echo "============================================"
}

# --- Main ---
[ $# -lt 1 ] && usage

COMMAND=$1; shift

case "$COMMAND" in
  setup)  [ $# -lt 1 ] && usage; cmd_setup  "$1" ;;
  init)   cmd_init  "${1:-all}" ;;
  create) [ $# -lt 1 ] && usage; cmd_create "$1" ;;
  update) [ $# -lt 1 ] && usage; cmd_update "$1" ;;
  delete) [ $# -lt 1 ] && usage; cmd_delete "$1" ;;
  verify) [ $# -lt 1 ] && usage; cmd_verify "$1" ;;
  show)   [ $# -lt 1 ] && usage; cmd_show   "$1" ;;
  *)      usage ;;
esac