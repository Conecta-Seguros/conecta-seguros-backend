#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
OVERLAYS_DIR="${BASE_DIR}/overlays"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

init_env() {
  local env=$1
  local secrets_dir="${OVERLAYS_DIR}/${env}/jobs/secrets"

  if [ ! -d "$secrets_dir" ]; then
    echo -e "${YELLOW}[SKIP]${NC} ${env}: carpeta secrets/ no existe"
    return
  fi

  if [ -f "${secrets_dir}/.env" ]; then
    echo -e "${YELLOW}[SKIP]${NC} ${env}: .env ya existe (no se sobrescribe)"
    return
  fi

  if [ ! -f "${secrets_dir}/.env.example" ]; then
    echo -e "${RED}[ERROR]${NC} ${env}: .env.example no encontrado"
    return 1
  fi

  cp "${secrets_dir}/.env.example" "${secrets_dir}/.env"
  echo -e "${GREEN}[OK]${NC}   ${env}: .env creado desde .env.example"
  echo -e "       ${YELLOW}→ Editar: ${secrets_dir}/.env${NC}"
}

TARGET="${1:-all}"

echo "============================================"
echo " Inicializando secrets para: ${TARGET}"
echo "============================================"
echo ""

if [ "$TARGET" = "all" ]; then
  for env in develop test production; do
    init_env "$env"
  done
else
  init_env "$TARGET"
fi

echo ""
echo "============================================"
echo " Siguiente paso:"
echo "   1. Editar los .env con credenciales reales"
echo "   2. Aplicar: kubectl apply -k overlays/<entorno>/jobs/"
echo "============================================"