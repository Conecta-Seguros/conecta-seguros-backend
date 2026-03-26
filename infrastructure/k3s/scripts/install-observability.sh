#!/bin/bash
# ============================================================================
#
# Uso:
#   ./scripts/install-observability.sh install  <env>
#   ./scripts/install-observability.sh upgrade  <env>
#   ./scripts/install-observability.sh uninstall
#   ./scripts/install-observability.sh status
#
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NAMESPACE="observability"
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
BASE_VALUES="${BASE_DIR}/base/observability/helm-values"

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

urlencode() {
  local string="$1"
  local encoded=""
  local i c
  for (( i=0; i<${#string}; i++ )); do
    c="${string:$i:1}"
    case "$c" in
      [a-zA-Z0-9._~-]) encoded+="$c" ;;
      *) encoded+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  echo "$encoded"
}

# ============================================================================
# HELM REPOS
# ============================================================================
setup_repos() {
  echo -e "${CYAN}[1/6] Configurando repositorios Helm...${NC}"

  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
  helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
  helm repo add kite https://kite-org.github.io/kite/ 2>/dev/null || true
  helm repo update

  echo -e "${GREEN}[OK]${NC} Repositorios actualizados"
}

# ============================================================================
# NAMESPACE
# ============================================================================
setup_namespace() {
  local env=$1

  echo -e "${CYAN}[2/6] Verificando namespace...${NC}"

  if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
    kubectl create namespace "${NAMESPACE}"
    echo -e "${GREEN}[OK]${NC} Namespace '${NAMESPACE}' creado"
  else
    echo -e "${YELLOW}[SKIP]${NC} Namespace '${NAMESPACE}' ya existe"
  fi

  kubectl label namespace "${NAMESPACE}" \
    caicedo.seguros/environment="${env}" \
    caicedo.seguros/tier=infrastructure \
    --overwrite 2>/dev/null || true
}

# ============================================================================
# POSTGRES EXPORTER SECRET
# ============================================================================
setup_postgres_exporter_secret() {
  local env=$1
  local env_file="${BASE_DIR}/overlays/${env}/secrets/.env"

  echo -e "${CYAN}[3/6] Configurando secret de Postgres Exporter...${NC}"

  if [ ! -f "$env_file" ]; then
    echo -e "${YELLOW}[WARN]${NC} No se encontró ${env_file}."
    echo -e "       Ejecutar: cp overlays/${env}/secrets/.env.template overlays/${env}/secrets/.env"
    return
  fi

  # Read credentials from the unified .env
  local PG_USER
  local PG_PASS
  PG_USER=$(get_env_value "$env_file" "POSTGRES_ROOT_USER")
  PG_PASS=$(get_env_value "$env_file" "POSTGRES_ROOT_PASSWORD")

  if [ -z "$PG_USER" ] || [ -z "$PG_PASS" ]; then
    echo -e "${YELLOW}[WARN]${NC} POSTGRES_ROOT_USER or POSTGRES_ROOT_PASSWORD empty in .env"
    return
  fi

  # DSN: percent-encode credentials to handle special chars (@/:?;) in passwords
  local PG_USER_ENC PG_PASS_ENC
  PG_USER_ENC=$(urlencode "$PG_USER")
  PG_PASS_ENC=$(urlencode "$PG_PASS")
  local DSN="postgresql://${PG_USER_ENC}:${PG_PASS_ENC}@postgresql-svc.${env}.svc.cluster.local:5432/postgres?sslmode=disable"

  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-exporter-credentials
  namespace: ${NAMESPACE}
stringData:
  DATA_SOURCE_NAME: "${DSN}"
EOF

  echo -e "${GREEN}[OK]${NC} Secret 'postgres-exporter-credentials' configurado"
}

# ============================================================================
# KITE SECRET
# ============================================================================
setup_kite_secret() {
  local env=$1

  echo -e "${CYAN}[3b/6] Configurando credenciales de Kite...${NC}"

  # Priority 1: caicedo-seguros-secrets in app namespace (populated by manage-secrets.sh)
  # Run: ./scripts/manage-secrets.sh setup <env>  before this script
  local APP_SECRET="caicedo-seguros-secrets"
  KITE_ADMIN_PASSWORD=""
  KITE_JWT_SECRET=""
  KITE_ENCRYPT_KEY=""

  if kubectl get secret "${APP_SECRET}" -n "${env}" &>/dev/null; then
    KITE_ADMIN_PASSWORD=$(kubectl get secret "${APP_SECRET}" -n "${env}" \
      -o jsonpath='{.data.KITE_ADMIN_PASSWORD}' 2>/dev/null | base64 -d 2>/dev/null || true)
    KITE_JWT_SECRET=$(kubectl get secret "${APP_SECRET}" -n "${env}" \
      -o jsonpath='{.data.KITE_JWT_SECRET}' 2>/dev/null | base64 -d 2>/dev/null || true)
    KITE_ENCRYPT_KEY=$(kubectl get secret "${APP_SECRET}" -n "${env}" \
      -o jsonpath='{.data.KITE_ENCRYPT_KEY}' 2>/dev/null | base64 -d 2>/dev/null || true)
  else
    echo -e "${YELLOW}[WARN]${NC} '${APP_SECRET}' no encontrado en namespace '${env}'."
    echo -e "       Ejecutá primero: ./scripts/manage-secrets.sh setup ${env}"
  fi

  # Priority 2: kite-credentials in observability namespace (auto-gen persistence from prior runs)
  if kubectl get secret kite-credentials -n "${NAMESPACE}" &>/dev/null; then
    [ -z "$KITE_ADMIN_PASSWORD" ] && KITE_ADMIN_PASSWORD=$(kubectl get secret kite-credentials -n "${NAMESPACE}" \
      -o jsonpath='{.data.KITE_ADMIN_PASSWORD}' 2>/dev/null | base64 -d 2>/dev/null || true)
    [ -z "$KITE_JWT_SECRET" ] && KITE_JWT_SECRET=$(kubectl get secret kite-credentials -n "${NAMESPACE}" \
      -o jsonpath='{.data.KITE_JWT_SECRET}' 2>/dev/null | base64 -d 2>/dev/null || true)
    [ -z "$KITE_ENCRYPT_KEY" ] && KITE_ENCRYPT_KEY=$(kubectl get secret kite-credentials -n "${NAMESPACE}" \
      -o jsonpath='{.data.KITE_ENCRYPT_KEY}' 2>/dev/null | base64 -d 2>/dev/null || true)
  fi

  # Priority 3: auto-generate (last resort)
  local generated=false

  if [ -z "$KITE_ADMIN_PASSWORD" ]; then
    KITE_ADMIN_PASSWORD=$(openssl rand -base64 32)
    generated=true
    echo -e "${YELLOW}[WARN]${NC} KITE_ADMIN_PASSWORD auto-generado (guardado en K8s secret)"
  fi

  if [ -z "$KITE_JWT_SECRET" ]; then
    KITE_JWT_SECRET=$(openssl rand -base64 32)
    generated=true
    echo -e "${YELLOW}[WARN]${NC} KITE_JWT_SECRET auto-generado (guardado en K8s secret)"
  fi

  if [ -z "$KITE_ENCRYPT_KEY" ]; then
    KITE_ENCRYPT_KEY=$(openssl rand -base64 32)
    generated=true
    echo -e "${YELLOW}[WARN]${NC} KITE_ENCRYPT_KEY auto-generado (guardado en K8s secret)"
  fi

  if [ "$generated" = true ]; then
    echo -e "${YELLOW}[WARN]${NC} Credenciales Kite auto-generadas y persistidas en K8s secret 'kite-credentials'."
    echo -e "       Para persistirlas en .env, copialas desde K8s:"
    echo -e "       kubectl get secret kite-credentials -n ${NAMESPACE} -o jsonpath='{.data.KITE_ADMIN_PASSWORD}' | base64 -d"
    echo -e "       kubectl get secret kite-credentials -n ${NAMESPACE} -o jsonpath='{.data.KITE_JWT_SECRET}' | base64 -d"
    echo -e "       kubectl get secret kite-credentials -n ${NAMESPACE} -o jsonpath='{.data.KITE_ENCRYPT_KEY}' | base64 -d"
    echo -e "       Luego ejecutá: ./scripts/manage-secrets.sh setup ${env}"
  fi

  # Persist generated secrets to K8s so they survive between script runs
  if ! kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: kite-credentials
  namespace: ${NAMESPACE}
stringData:
  KITE_ADMIN_PASSWORD: "${KITE_ADMIN_PASSWORD}"
  KITE_JWT_SECRET: "${KITE_JWT_SECRET}"
  KITE_ENCRYPT_KEY: "${KITE_ENCRYPT_KEY}"
EOF
  then
    echo -e "${RED}[ERROR]${NC} Failed to persist 'kite-credentials' to namespace '${NAMESPACE}'." >&2
    echo -e "       KITE_ADMIN_PASSWORD, KITE_JWT_SECRET and KITE_ENCRYPT_KEY were NOT saved." >&2
    echo -e "       Check that the namespace exists and you have RBAC permissions." >&2
    exit 1
  fi

  export KITE_ADMIN_PASSWORD
  export KITE_JWT_SECRET
  export KITE_ENCRYPT_KEY

  echo -e "${GREEN}[OK]${NC} Credenciales de Kite configuradas"
}

# ============================================================================
# HELM INSTALLS
# ============================================================================
install_charts() {
  local env=$1

  echo -e "${CYAN}[4/6] Installing/upgrading Helm charts...${NC}"

  if [ ! -d "$BASE_VALUES" ]; then
    echo -e "${RED}[ERROR]${NC} Helm values not found: ${BASE_VALUES}"
    echo -e "       Expected: kube-prometheus-stack.yaml, loki.yaml, promtail.yaml, etc."
    return 1
  fi

  # --- kube-prometheus-stack ---
  echo -e "  → kube-prometheus-stack..."
  helm upgrade --install kube-prometheus-stack \
    prometheus-community/kube-prometheus-stack \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/kube-prometheus-stack.yaml" \
    --set commonLabels."caicedo\.seguros/environment"="${env}" \
    --wait --timeout 10m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} kube-prometheus-stack"

  # --- Loki ---
  echo -e "  → loki..."
  helm upgrade --install loki \
    grafana/loki \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/loki.yaml" \
    --wait --timeout 5m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} loki"

  # --- Promtail ---
  echo -e "  → promtail..."
  helm upgrade --install promtail \
    grafana/promtail \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/promtail.yaml" \
    --wait --timeout 5m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} promtail"

  # --- Blackbox Exporter ---
  echo -e "  → blackbox-exporter..."
  helm upgrade --install blackbox-exporter \
    prometheus-community/prometheus-blackbox-exporter \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/blackbox-exporter.yaml" \
    --wait --timeout 3m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} blackbox-exporter"

  # --- Postgres Exporter ---
  echo -e "  → postgres-exporter..."
  helm upgrade --install postgres-exporter \
    prometheus-community/prometheus-postgres-exporter \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/postgres-exporter.yaml" \
    --timeout 3m \
    2>&1 | tail -3
  echo -e "  ${GREEN}[OK]${NC} postgres-exporter (may CrashLoop until PostgreSQL is ready)"

  # --- Kite Dashboard ---
  setup_kite_secret "$env"
  echo -e "  → kite dashboard..."
  KITE_EXTRA_VALUES=""
  local kite_overlay="${BASE_DIR}/overlays/${env}/observability/helm-values/kite-${env}-overrides.yaml"
  if [ -f "$kite_overlay" ]; then
    KITE_EXTRA_VALUES="--values ${kite_overlay}"
  fi
  local kite_secrets_file
  kite_secrets_file=$(mktemp /tmp/kite-secrets-XXXXXX.yaml)
  chmod 600 "$kite_secrets_file"
  cat > "$kite_secrets_file" <<EOF
superUser:
  password: "${KITE_ADMIN_PASSWORD}"
jwtSecret: "${KITE_JWT_SECRET}"
encryptKey: "${KITE_ENCRYPT_KEY}"
EOF
  helm upgrade --install kite kite/kite \
    --namespace "${NAMESPACE}" \
    --values "${BASE_VALUES}/kite.yaml" \
    ${KITE_EXTRA_VALUES} \
    --values "${kite_secrets_file}" \
    --wait --timeout 3m \
    2>&1 | tail -3
  rm -f "$kite_secrets_file"
  echo -e "  ${GREEN}[OK]${NC} kite dashboard"
}

# ============================================================================
# CUSTOM CRDs (ServiceMonitors, PrometheusRules)
# ============================================================================
apply_custom_crds() {
  local env=$1

  echo -e "${CYAN}[5/6] Aplicando CRDs custom...${NC}"

  if [ -d "${BASE_DIR}/overlays/${env}/observability" ] && \
     [ -f "${BASE_DIR}/overlays/${env}/observability/kustomization.yaml" ]; then
    if grep -q 'resources:' "${BASE_DIR}/overlays/${env}/observability/kustomization.yaml" 2>/dev/null; then
      kubectl apply -k "${BASE_DIR}/overlays/${env}/observability/" 2>&1 | while read -r line; do
        echo "  $line"
      done
      echo -e "${GREEN}[OK]${NC} CRDs custom aplicados"
    else
      echo -e "${YELLOW}[SKIP]${NC} No custom CRDs to apply"
    fi
  else
    echo -e "${YELLOW}[SKIP]${NC} No observability overlay for ${env}"
  fi
}

# ============================================================================
# STATUS
# ============================================================================
show_status() {
  echo -e "${CYAN}[6/6] Estado del stack...${NC}"
  echo ""

  echo -e "${CYAN}── Helm Releases ──${NC}"
  helm list -n "${NAMESPACE}" 2>/dev/null || echo "  None"
  echo ""

  echo -e "${CYAN}── Pods ──${NC}"
  kubectl get pods -n "${NAMESPACE}" -o wide 2>/dev/null || echo "  No pods"
  echo ""

  echo -e "${CYAN}── Services ──${NC}"
  kubectl get svc -n "${NAMESPACE}" 2>/dev/null || echo "  No services"
  echo ""

  echo -e "${CYAN}── Access ──${NC}"
  echo "  Grafana:      kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n ${NAMESPACE}"
  echo "                User: admin | Pass: kubectl get secret kube-prometheus-stack-grafana -n ${NAMESPACE} -o jsonpath='{.data.admin-password}' | base64 -d"
  echo "  Prometheus:   kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n ${NAMESPACE}"
  echo "  Alertmanager: kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n ${NAMESPACE}"
  echo "  Kite:         kubectl port-forward svc/kite 8090:8090 -n ${NAMESPACE}"
  echo "                User: admin | Pass: (see .env KITE_ADMIN_PASSWORD)"
}

# ============================================================================
# UNINSTALL
# ============================================================================
cmd_uninstall() {
  echo -e "${RED}${BOLD}Uninstalling observability stack...${NC}"
  echo -e "${YELLOW}Press Ctrl+C to cancel, or wait 5 seconds...${NC}"
  sleep 5

  for release in kite postgres-exporter blackbox-exporter promtail loki kube-prometheus-stack; do
    echo -e "  Uninstalling ${release}..."
    helm uninstall "$release" -n "${NAMESPACE}" 2>/dev/null || true
  done

  echo -e "${YELLOW}Note: Prometheus CRDs may remain. To fully clean:${NC}"
  echo "  kubectl delete crd prometheusrules.monitoring.coreos.com"
  echo "  kubectl delete crd servicemonitors.monitoring.coreos.com"
  echo "  kubectl delete crd podmonitors.monitoring.coreos.com"
  echo "  kubectl delete crd alertmanagerconfigs.monitoring.coreos.com"

  echo -e "${GREEN}Observability stack uninstalled${NC}"
}

# ============================================================================
# MAIN
# ============================================================================
usage() {
  echo "Usage: $0 {install|upgrade|uninstall|status} [environment]"
  echo ""
  echo "  install   <env>  Fresh install"
  echo "  upgrade   <env>  Install or upgrade (idempotent)"
  echo "  uninstall        Remove all Helm releases"
  echo "  status           Show current state"
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
      echo -e "${RED}Environment required${NC}"
      usage
    fi
    env=$2
    case "$env" in
      develop|test|production) ;;
      *) echo -e "${RED}Invalid environment: ${env}${NC}"; usage ;;
    esac

    echo -e "${BOLD}"
    echo "============================================"
    echo " Observability Stack: ${command} → ${env}"
    echo "============================================"
    echo -e "${NC}"

    setup_repos
    setup_namespace "$env"
    setup_postgres_exporter_secret "$env"
    install_charts "$env"
    apply_custom_crds "$env"
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