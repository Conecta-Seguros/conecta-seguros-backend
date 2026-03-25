#!/bin/bash
# ============================================================================
#
# Uso:
#   ./scripts/install-cert-manager.sh install   <env>
#   ./scripts/install-cert-manager.sh upgrade    <env>
#   ./scripts/install-cert-manager.sh uninstall
#   ./scripts/install-cert-manager.sh status
#
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CERT_MANAGER_VERSION="v1.17.1"
HELM_RELEASE="cert-manager"
NAMESPACE="cert-manager"
CLOUDFLARE_SECRET_NAME="cloudflare-api-token-secret"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# HELPERS
# ============================================================================
get_env_value() {
  local file="$1"
  local key="$2"
  grep "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- || true
}

resolve_cloudflare_token() {
  local env=$1
  local env_file="${BASE_DIR}/overlays/${env}/secrets/.env"

  # 1. Variable de entorno ya seteada
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    echo "${CLOUDFLARE_API_TOKEN}"
    return
  fi

  # 2. Archivo .env del overlay
  if [ -f "$env_file" ]; then
    local token
    token=$(get_env_value "$env_file" "CLOUDFLARE_API_TOKEN")
    if [ -n "$token" ]; then
      echo "$token"
      return
    fi
  fi

  # 3. Pedir interactivamente solo si hay TTY disponible
  if [ ! -e /dev/tty ] || ! { true </dev/tty; } 2>/dev/null; then
    echo -e "${RED}[ERROR]${NC} CLOUDFLARE_API_TOKEN no encontrado y no hay TTY disponible." >&2
    echo -e "        Exportá la variable antes de ejecutar:" >&2
    echo -e "        export CLOUDFLARE_API_TOKEN=<tu-token>" >&2
    echo -e "        O agregala al archivo overlays/${env}/secrets/.env" >&2
    exit 1
  fi

  echo -e "${YELLOW}[INPUT]${NC} Token de API de Cloudflare no encontrado." >&2
  echo -e "        (Zone:DNS:Edit + Zone:Zone:Read sobre caicedoseguros.com)" >&2
  read -rsp "        Ingresa el token: " token_input </dev/tty
  echo "" >&2
  echo "$token_input"
}

# ============================================================================
# HELM REPO
# ============================================================================
setup_repo() {
  echo -e "${CYAN}[1/5] Configurando repositorio Helm (jetstack)...${NC}"
  helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
  helm repo update jetstack
  echo -e "${GREEN}[OK]${NC} Repositorio jetstack actualizado"
}

# ============================================================================
# INSTALL / UPGRADE
# ============================================================================
install_chart() {
  echo -e "${CYAN}[2/5] Instalando cert-manager ${CERT_MANAGER_VERSION}...${NC}"

  helm upgrade --install "${HELM_RELEASE}" jetstack/cert-manager \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --version "${CERT_MANAGER_VERSION}" \
    --set crds.enabled=true \
    --set global.leaderElection.namespace="${NAMESPACE}" \
    --atomic --cleanup-on-fail \
    --wait --timeout 10m \
    2>&1 | tail -5

  echo -e "${GREEN}[OK]${NC} cert-manager ${CERT_MANAGER_VERSION} instalado"
}

# ============================================================================
# CLOUDFLARE SECRET
# ============================================================================
setup_cloudflare_secret() {
  local env=$1

  echo -e "${CYAN}[3/5] Configurando secret de Cloudflare...${NC}"

  local token
  token=$(resolve_cloudflare_token "$env")

  if [ -z "$token" ]; then
    echo -e "${RED}[ERROR]${NC} Token de Cloudflare vacío. Abortando."
    exit 1
  fi

  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLOUDFLARE_SECRET_NAME}
  namespace: ${NAMESPACE}
stringData:
  api-token: "${token}"
EOF

  echo -e "${GREEN}[OK]${NC} Secret '${CLOUDFLARE_SECRET_NAME}' configurado en namespace '${NAMESPACE}'"
}

# ============================================================================
# APPLY CLUSTERISSUERS + CERTIFICATE
# ============================================================================
apply_issuers() {
  local env=$1

  echo -e "${CYAN}[4/5] Aplicando ClusterIssuers e Ingress certificate...${NC}"

  kubectl apply -f "${BASE_DIR}/base/ingress/certificate-issuer.yaml"
  echo -e "  ${GREEN}[OK]${NC} ClusterIssuers aplicados"

  # Certificate del overlay (sólo si existe el overlay de ingress para el env)
  local ingress_overlay="${BASE_DIR}/overlays/${env}/ingress"
  if [ -f "${ingress_overlay}/kustomization.yaml" ]; then
    kubectl apply -k "${ingress_overlay}/"
    echo -e "  ${GREEN}[OK]${NC} Certificate y recursos de ingress (${env}) aplicados"
  else
    echo -e "  ${YELLOW}[SKIP]${NC} No hay overlay de ingress para '${env}'"
  fi
}

# ============================================================================
# STATUS
# ============================================================================
show_status() {
  echo -e "${CYAN}[5/5] Estado de cert-manager...${NC}"
  echo ""

  echo -e "${CYAN}── Helm Release ──${NC}"
  helm list -n "${NAMESPACE}" 2>/dev/null || echo "  No encontrado"
  echo ""

  echo -e "${CYAN}── Pods ──${NC}"
  kubectl get pods -n "${NAMESPACE}" 2>/dev/null || echo "  No hay pods"
  echo ""

  echo -e "${CYAN}── ClusterIssuers ──${NC}"
  kubectl get clusterissuer 2>/dev/null || echo "  No hay ClusterIssuers"
  echo ""

  echo -e "${CYAN}── Certificates ──${NC}"
  kubectl get certificate -A 2>/dev/null || echo "  No hay Certificates"
  echo ""

  echo -e "${CYAN}── CertificateRequests ──${NC}"
  kubectl get certificaterequest -A 2>/dev/null || echo "  No hay CertificateRequests"
}

# ============================================================================
# UNINSTALL
# ============================================================================
cmd_uninstall() {
  echo -e "${RED}${BOLD}Desinstalando cert-manager...${NC}"
  echo -e "${YELLOW}Presiona Ctrl+C para cancelar, o espera 5 segundos...${NC}"
  sleep 5

  helm uninstall "${HELM_RELEASE}" -n "${NAMESPACE}" 2>/dev/null || true

  echo -e "${YELLOW}Nota: Los CRDs de cert-manager pueden permanecer. Para limpiarlos:${NC}"
  echo "  kubectl get crd | grep cert-manager.io | awk '{print \$1}' | xargs kubectl delete crd"
  echo ""
  echo -e "${GREEN}cert-manager desinstalado${NC}"
}

# ============================================================================
# MAIN
# ============================================================================
usage() {
  echo "Uso: $0 {install|upgrade|uninstall|status} [environment]"
  echo ""
  echo "  install   <env>  Instalación inicial"
  echo "  upgrade   <env>  Actualizar (idempotente)"
  echo "  uninstall        Eliminar release de Helm"
  echo "  status           Mostrar estado actual"
  echo ""
  echo "Environments: develop, test, production"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

command=$1

case "$command" in
  install|upgrade)
    if [ $# -lt 2 ]; then
      echo -e "${RED}Se requiere un entorno${NC}"
      usage
    fi
    env=$2
    case "$env" in
      develop|test|production) ;;
      *) echo -e "${RED}Entorno inválido: ${env}${NC}"; usage ;;
    esac

    echo -e "${BOLD}"
    echo "============================================"
    echo " cert-manager: ${command} → ${env}"
    echo "============================================"
    echo -e "${NC}"

    setup_repo
    install_chart

    # El secret de Cloudflare y los ClusterIssuers sólo tienen sentido en
    # production, donde Let's Encrypt necesita DNS-01 para dominios wildcard.
    if [ "$env" = "production" ]; then
      setup_cloudflare_secret "$env"
      apply_issuers "$env"
    else
      echo -e "${YELLOW}[SKIP]${NC} Cloudflare secret e Issuers omitidos en entorno '${env}' (solo production)"
    fi

    show_status
    ;;
  uninstall)
    cmd_uninstall
    ;;
  status)
    show_status
    ;;
  *)
    usage
    ;;
esac
