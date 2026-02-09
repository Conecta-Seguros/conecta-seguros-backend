#!/bin/bash
# ============================================================================
# install-observability.sh - Instalación completa del stack de observabilidad
# ============================================================================
# Ruta: infrastructure/k3s/scripts/install-observability.sh
#
# Uso:
#   ./scripts/install-observability.sh install  <entorno>
#   ./scripts/install-observability.sh upgrade  <entorno>
#   ./scripts/install-observability.sh status   <entorno>
#   ./scripts/install-observability.sh uninstall <entorno>
#
# Instala:
#   1. kube-prometheus-stack (Prometheus + Alertmanager + Grafana + Node Exporter)
#   2. Loki (almacenamiento de logs)
#   3. Promtail (recolección de logs)
#   4. Blackbox Exporter (probes HTTP/TCP)
#   5. Postgres Exporter (métricas PostgreSQL)
#   6. Custom CRDs (ServiceMonitors, PrometheusRules, PodMonitors, Probes)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
BASE_VALUES="${BASE_DIR}/base/observability/helm-values"
NAMESPACE="observability"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  echo ""
  echo "Uso: $0 <command> <environment>"
  echo ""
  echo "  install   <env>   Instalación completa (repos + charts + CRDs)"
  echo "  upgrade   <env>   Actualizar charts existentes"
  echo "  status    <env>   Verificar estado de todos los componentes"
  echo "  uninstall <env>   Desinstalar todo el stack"
  echo ""
  echo "Environments: develop, test, production"
  echo ""
  exit 1
}

get_overlay_values() {
  echo "${BASE_DIR}/overlays/$1/observability/helm-values/$1-overrides.yaml"
}

# ============================================================================
# HELM REPOS
# ============================================================================
setup_repos() {
  echo -e "${CYAN}[1/6] Configurando repositorios Helm...${NC}"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
  helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
  helm repo update
  echo -e "${GREEN}[OK]${NC} Repositorios actualizados"
}

# ============================================================================
# NAMESPACE
# ============================================================================
setup_namespace() {
  local env=$1
  echo -e "${CYAN}[2/6] Verificando namespace...${NC}"

  if ! kubectl get namespace "${NAMESPACE}" > /dev/null 2>&1; then
    kubectl create namespace "${NAMESPACE}"
    echo -e "${GREEN}[OK]${NC} Namespace '${NAMESPACE}' creado"
  else
    echo -e "${YELLOW}[SKIP]${NC} Namespace '${NAMESPACE}' ya existe"
  fi

  # Labels para el namespace
  kubectl label namespace "${NAMESPACE}" \
    conecta.seguros/environment="${env}" \
    conecta.seguros/tier=infrastructure \
    --overwrite
}

# ============================================================================
# POSTGRES EXPORTER SECRET
# ============================================================================
setup_postgres_exporter_secret() {
  local env=$1
  local env_file="${BASE_DIR}/overlays/${env}/secrets/.env"

  echo -e "${CYAN}[3/6] Configurando secret de Postgres Exporter...${NC}"

  if [ ! -f "$env_file" ]; then
    echo -e "${YELLOW}[WARN]${NC} No se encontró ${env_file}. Postgres Exporter necesita credenciales."
    echo -e "       Ejecutar: ./scripts/manage-secrets.sh init ${env}"
    return
  fi

  # Extraer variables del .env
  local PG_HOST=$(grep '^POSTGRES_FUSIONAUTH_BACKUP_URL' "$env_file" | sed 's|.*jdbc:postgresql://||' | cut -d: -f1)
  local PG_PORT=$(grep '^POSTGRES_FUSIONAUTH_BACKUP_PORT' "$env_file" | cut -d= -f2)
  local PG_USER=$(grep '^POSTGRES_FUSIONAUTH_BACKUP_ROOT_USER' "$env_file" | cut -d= -f2)
  local PG_PASS=$(grep '^POSTGRES_FUSIONAUTH_BACKUP_ROOT_PASSWORD' "$env_file" | cut -d= -f2)
  local PG_DB=$(grep '^POSTGRES_FUSIONAUTH_BACKUP_DB' "$env_file" | cut -d= -f2)

  local DSN="postgresql://${PG_USER}:${PG_PASS}@${PG_HOST}:${PG_PORT}/${PG_DB}?sslmode=disable"

  kubectl create secret generic postgres-exporter-credentials \
    --from-literal=DATA_SOURCE_NAME="${DSN}" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo -e "${GREEN}[OK]${NC} Secret 'postgres-exporter-credentials' configurado"
}

# ============================================================================
# HELM INSTALLS
# ============================================================================
install_charts() {
  local env=$1
  local action=$2  # install o upgrade
  local overlay_values=$(get_overlay_values "$env")

  echo -e "${CYAN}[4/6] ${action^} charts Helm...${NC}"

  # --- kube-prometheus-stack ---
  echo -e "  → kube-prometheus-stack..."
  helm ${action} kube-prometheus-stack \
    prometheus-community/kube-prometheus-stack \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/kube-prometheus-stack.yaml" \
    --set commonLabels."conecta\.seguros/environment"="${env}" \
    --wait --timeout 10m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} kube-prometheus-stack"

  # --- Loki ---
  echo -e "  → loki..."
  helm ${action} loki \
    grafana/loki \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/loki.yaml" \
    --wait --timeout 5m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} loki"

  # --- Promtail ---
  echo -e "  → promtail..."
  helm ${action} promtail \
    grafana/promtail \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/promtail.yaml" \
    --wait --timeout 5m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} promtail"

  # --- Blackbox Exporter ---
  echo -e "  → blackbox-exporter..."
  helm ${action} blackbox-exporter \
    prometheus-community/prometheus-blackbox-exporter \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/blackbox-exporter.yaml" \
    --wait --timeout 3m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} blackbox-exporter"

  # --- Postgres Exporter ---
  echo -e "  → postgres-exporter..."
  helm ${action} postgres-exporter \
    prometheus-community/prometheus-postgres-exporter \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/postgres-exporter.yaml" \
    --wait --timeout 3m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} postgres-exporter"
}

# ============================================================================
# CUSTOM CRDS (ServiceMonitors, PrometheusRules, PodMonitors, Probes)
# ============================================================================
apply_custom_resources() {
  local env=$1
  local overlay_path="${BASE_DIR}/overlays/${env}/observability"

  echo -e "${CYAN}[5/6] Aplicando recursos custom (CRDs)...${NC}"

  if [ -f "${overlay_path}/kustomization.yaml" ]; then
    kubectl apply -k "${overlay_path}/" 2>&1 | sed 's/^/  /'
    echo -e "  ${GREEN}[OK]${NC} Custom resources aplicados"
  else
    echo -e "  ${YELLOW}[SKIP]${NC} No se encontró ${overlay_path}/kustomization.yaml"
  fi
}

# ============================================================================
# STATUS
# ============================================================================
show_status() {
  local env=$1
  echo -e "${CYAN}[6/6] Estado del stack de observabilidad...${NC}"
  echo ""

  echo -e "${CYAN}=== Helm Releases ===${NC}"
  helm list -n "${NAMESPACE}" 2>/dev/null || echo "  No releases found"
  echo ""

  echo -e "${CYAN}=== Pods ===${NC}"
  kubectl get pods -n "${NAMESPACE}" -o wide 2>/dev/null || echo "  No pods found"
  echo ""

  echo -e "${CYAN}=== Services ===${NC}"
  kubectl get svc -n "${NAMESPACE}" 2>/dev/null || echo "  No services found"
  echo ""

  echo -e "${CYAN}=== PVCs ===${NC}"
  kubectl get pvc -n "${NAMESPACE}" 2>/dev/null || echo "  No PVCs found"
  echo ""

  echo -e "${CYAN}=== CRDs ===${NC}"
  echo "  ServiceMonitors:  $(kubectl get servicemonitors -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)"
  echo "  PodMonitors:      $(kubectl get podmonitors -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)"
  echo "  PrometheusRules:  $(kubectl get prometheusrules -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)"
  echo "  Probes:           $(kubectl get probes -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)"
  echo ""

  echo -e "${CYAN}=== Acceso ===${NC}"
  echo "  Grafana:      kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n ${NAMESPACE}"
  echo "  Prometheus:   kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n ${NAMESPACE}"
  echo "  Alertmanager: kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n ${NAMESPACE}"
  echo ""
}

# ============================================================================
# UNINSTALL
# ============================================================================
cmd_uninstall() {
  local env=$1

  echo -e "${RED}[WARN] Desinstalar TODO el stack de observabilidad de '${NAMESPACE}'${NC}"
  read -p "         ¿Continuar? (y/N): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "[CANCEL] Operación cancelada"
    exit 0
  fi

  echo -e "${CYAN}Desinstalando charts...${NC}"
  helm uninstall postgres-exporter    -n "${NAMESPACE}" 2>/dev/null || true
  helm uninstall blackbox-exporter    -n "${NAMESPACE}" 2>/dev/null || true
  helm uninstall promtail             -n "${NAMESPACE}" 2>/dev/null || true
  helm uninstall loki                 -n "${NAMESPACE}" 2>/dev/null || true
  helm uninstall kube-prometheus-stack -n "${NAMESPACE}" 2>/dev/null || true

  echo -e "${CYAN}Eliminando custom resources...${NC}"
  kubectl delete servicemonitors,podmonitors,prometheusrules,probes --all -n "${NAMESPACE}" 2>/dev/null || true

  echo -e "${CYAN}Eliminando secrets...${NC}"
  kubectl delete secret postgres-exporter-credentials -n "${NAMESPACE}" 2>/dev/null || true

  echo -e "${GREEN}[OK]${NC} Stack desinstalado. PVCs preservados para datos."
  echo -e "     Para eliminar datos: kubectl delete pvc --all -n ${NAMESPACE}"
}

# ============================================================================
# MAIN COMMANDS
# ============================================================================
cmd_install() {
  local env=$1

  echo "============================================"
  echo " Instalación: Stack Observabilidad - ${env}"
  echo "============================================"
  echo ""

  setup_repos
  setup_namespace "$env"
  setup_postgres_exporter_secret "$env"
  install_charts "$env" "install"
  apply_custom_resources "$env"
  show_status "$env"

  echo "============================================"
  echo -e " ${GREEN}Instalación completada: ${env}${NC}"
  echo "============================================"
}

cmd_upgrade() {
  local env=$1

  echo "============================================"
  echo " Upgrade: Stack Observabilidad - ${env}"
  echo "============================================"
  echo ""

  setup_repos
  setup_postgres_exporter_secret "$env"
  install_charts "$env" "upgrade"
  apply_custom_resources "$env"
  show_status "$env"

  echo "============================================"
  echo -e " ${GREEN}Upgrade completado: ${env}${NC}"
  echo "============================================"
}

cmd_status() {
  local env=$1
  show_status "$env"
}

# ============================================================================
# ENTRY POINT
# ============================================================================
[ $# -lt 2 ] && usage

COMMAND=$1
ENV=$2

# Validar entorno
case "$ENV" in
  develop|test|production) ;;
  *) echo -e "${RED}[ERROR]${NC} Entorno inválido: ${ENV}"; usage ;;
esac

# Verificar dependencias
for cmd in helm kubectl; do
  if ! command -v $cmd &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} ${cmd} no encontrado. Instalar primero."
    exit 1
  fi
done

case "$COMMAND" in
  install)   cmd_install "$ENV" ;;
  upgrade)   cmd_upgrade "$ENV" ;;
  status)    cmd_status "$ENV" ;;
  uninstall) cmd_uninstall "$ENV" ;;
  *)         usage ;;
esac