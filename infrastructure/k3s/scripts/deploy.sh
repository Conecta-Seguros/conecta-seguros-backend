#!/bin/bash
# ============================================================================
#
# Uso:
#   ./scripts/deploy.sh deploy   develop
#   ./scripts/deploy.sh deploy   test
#   ./scripts/deploy.sh deploy   production
#   ./scripts/deploy.sh status   <env>
#   ./scripts/deploy.sh destroy  <env>
#
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# HELPERS
# ============================================================================
step() {
  echo ""
  echo -e "${CYAN}${BOLD}[$1] $2${NC}"
  echo -e "${CYAN}$(printf '%.0s─' {1..60})${NC}"
}

ok() {
  echo -e "  ${GREEN}[OK]${NC} $1"
}

warn() {
  echo -e "  ${YELLOW}[WARN]${NC} $1"
}

fail() {
  echo -e "  ${RED}[FAIL]${NC} $1"
}

wait_for_pod() {
  local label="$1"
  local namespace="$2"
  local timeout="${3:-120}"

  echo -e "  Waiting for pod ${BOLD}${label}${NC} (timeout: ${timeout}s)..."
  if kubectl wait --for=condition=ready pod -l "$label" \
    -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
    ok "Pod ready"
  else
    fail "Pod not ready after ${timeout}s"
    kubectl get pods -l "$label" -n "$namespace" 2>/dev/null
    return 1
  fi
}

wait_for_deployment() {
  local name="$1"
  local namespace="$2"
  local timeout="${3:-300}"

  echo -e "  Waiting for deployment ${BOLD}${name}${NC} (timeout: ${timeout}s)..."
  if kubectl rollout status deployment/"$name" \
    -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
    ok "Deployment ready"
  else
    fail "Deployment not ready after ${timeout}s"
    kubectl get pods -l "app.kubernetes.io/name=${name}" -n "$namespace" 2>/dev/null
    return 1
  fi
}

# ============================================================================
# VALIDATE ENV FILE
# ============================================================================
validate_env_file() {
  local env_file="$1"
  local env="$2"
  local errors=0

  # Variables explicitly allowed to be empty (optional / empty = default behavior)
  local -a OPTIONAL_VARS=(
    EUREKA_PEER_URLS          # empty = standalone mode (no HA clustering)
    EUREKA_PREFER_IP_ADDRESS  # empty = uses hostname (Spring default)
    EUREKA_ZONE               # empty = defaultZone (Spring default)
  )

  echo -e "  Validating secrets file..."

  # Check for empty values (KEY=)
  local empty_vars
  empty_vars=$(grep -E '^[A-Z_]+=\s*$' "$env_file" | cut -d= -f1 || true)
  if [ -n "$empty_vars" ]; then
    while IFS= read -r var; do
      [ -z "$var" ] && continue
      # Skip known optional variables
      local is_optional=false
      for opt in "${OPTIONAL_VARS[@]}"; do
        [ "$var" = "$opt" ] && is_optional=true && break
      done
      [ "$is_optional" = true ] && continue
      fail "Empty variable: ${var}" && ((errors++)) || true
    done <<< "$empty_vars"
  fi

  if [ $errors -gt 0 ]; then
    echo ""
    fail "Found ${errors} empty variable(s) in .env — fill them before deploying to ${env}"
    return 1
  fi

  ok "Secrets file validated (no empty variables)"
}

# ============================================================================
# SAFETY GATE (per environment)
# ============================================================================
safety_gate() {
  local env="$1"

  case "$env" in

    develop)
      # No gate for develop — live fast
      ;;

    test)
      echo ""
      echo -e "${YELLOW}${BOLD}⚠  Deploying to TEST environment (VPS 168.231.65.156)${NC}"
      echo -e "${YELLOW}   This will affect the shared test namespace.${NC}"
      echo ""

      # Validate .env completeness
      local env_file="${BASE_DIR}/overlays/${env}/secrets/.env"
      if [ -f "$env_file" ]; then
        validate_env_file "$env_file" "$env" || exit 1
      fi

      echo -e "  Continue? Press ${BOLD}Ctrl+C${NC} to cancel, or wait 5 seconds..."
      sleep 5
      ok "Proceeding with test deploy"
      ;;

    production)
      echo ""
      echo -e "${RED}${BOLD}🚨  PRODUCTION DEPLOY — READ CAREFULLY${NC}"
      echo -e "${RED}   Target: caicedoseguros.com (LIVE ENVIRONMENT)${NC}"
      echo -e "${RED}   This affects REAL users and REAL data.${NC}"
      echo ""

      # Validate .env completeness
      local env_file="${BASE_DIR}/overlays/${env}/secrets/.env"
      if [ -f "$env_file" ]; then
        validate_env_file "$env_file" "$env" || exit 1
      else
        fail "Production .env not found at ${env_file}"
        exit 1
      fi

      # Validate no 'latest' or 'local' image tags in production overlays
      echo -e "  Checking for unsafe image tags..."
      if grep -r "image:.*:latest\|image:.*:local\|newTag:.*latest\|newTag:.*local" \
         "${BASE_DIR}/components/"*/overlays/production/ 2>/dev/null | grep -v "^Binary"; then
        fail "Found 'latest' or 'local' image tags in production overlays — use versioned tags"
        exit 1
      fi
      ok "Image tags look safe"

      # Double confirmation
      echo ""
      echo -e "${RED}${BOLD}  Type exactly 'YES' (uppercase) to confirm production deploy:${NC}"
      read -r confirmation
      if [ "$confirmation" != "YES" ]; then
        echo -e "${YELLOW}  Deploy cancelled.${NC}"
        exit 0
      fi

      ok "Production deploy confirmed"
      ;;
  esac
}

# ============================================================================
# DEPLOY
# ============================================================================
cmd_deploy() {
  local env=$1
  local env_file="${BASE_DIR}/overlays/${env}/secrets/.env"

  echo -e "${BOLD}"
  echo "============================================"
  echo " DEPLOYING: ${env}"
  echo "============================================"
  echo -e "${NC}"

  # ── Safety gate ──
  safety_gate "$env"

  # ── 0. Preflight checks ──
  step "0/9" "Preflight checks"

  if ! kubectl cluster-info &>/dev/null; then
    fail "Cannot connect to cluster"
    exit 1
  fi
  ok "Cluster reachable"

  if [ ! -f "$env_file" ]; then
    local template_file="${BASE_DIR}/overlays/${env}/secrets/.env.template"
    if [ -f "$template_file" ]; then
      cp "$template_file" "$env_file"
      warn "Created .env from template — edit credentials before production"
    else
      fail "Secrets file not found: ${env_file}"
      exit 1
    fi
  fi
  ok "Secrets file exists"

  if grep -q 'CAMBIAR_AQUI' "$env_file" 2>/dev/null; then
    warn "Found CAMBIAR_AQUI placeholders — replace before production use"
  fi

  # Check local images are available in K3s (for local develop)
  if [ "$env" = "develop" ]; then
    local missing_images=0
    if ! sudo k3s ctr images ls 2>/dev/null | grep -q "caicedo-seguros/discovery-server:local"; then
      warn "Image 'caicedo-seguros/discovery-server:local' not found in K3s"
      warn "Run: ./scripts/build-images.sh build eureka-server"
      missing_images=1
    else
      ok "Eureka Server image available in K3s"
    fi

    if [ $missing_images -gt 0 ]; then
      echo ""
      echo -e "  ${YELLOW}Some images are missing. Build them first:${NC}"
      echo -e "    ${BOLD}./scripts/build-images.sh build${NC}"
      echo ""
      echo -e "  Continue deploy anyway? (services without images will fail)"
      echo -e "  Press Ctrl+C to cancel, or wait 5 seconds..."
      sleep 5
    fi
  fi

  # ── 1. Platform cluster-wide ──
  step "1/9" "Platform (cluster-wide: namespaces, storageclasses, clusterroles, ingress-nginx)"

  cd "$BASE_DIR"
  kubectl apply -k base/ 2>&1 | while read -r line; do
    echo "  $line"
  done
  ok "Platform cluster-wide applied"

  # ── ingress-nginx: security headers (idempotent) ──
  if kubectl get namespace ingress-nginx &>/dev/null; then
    kubectl apply -k base/ingress-nginx/ 2>&1 | while read -r line; do
      echo "  $line"
    done

    local current_headers
    current_headers=$(kubectl get configmap ingress-nginx-controller \
      -n ingress-nginx -o jsonpath='{.data.add-headers}' 2>/dev/null || true)

    if [ "$current_headers" != "ingress-nginx/security-headers" ]; then
      echo -e "  Configuring global security headers..."
      kubectl patch configmap ingress-nginx-controller -n ingress-nginx \
        --type=merge -p '{"data":{"add-headers":"ingress-nginx/security-headers"}}' \
        2>&1 | while read -r line; do echo "  $line"; done
      kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx \
        2>/dev/null || true
      kubectl rollout status deployment/ingress-nginx-controller \
        -n ingress-nginx --timeout=60s 2>&1 | while read -r line; do echo "  $line"; done
      ok "ingress-nginx security headers configured"
    else
      ok "ingress-nginx security headers already configured"
    fi
  else
    warn "ingress-nginx namespace not found — skipping security headers"
  fi

  # ── 2. Platform namespace-scoped ──
  step "2/9" "Platform namespace-scoped (quotas, policies, RBAC) → ${env}"

  if [ -d "overlays/${env}/platform" ]; then
    kubectl apply -k "overlays/${env}/platform/" 2>&1 | while read -r line; do
      echo "  $line"
    done
    ok "Platform namespace-scoped applied"
  else
    warn "No platform overlay for ${env}, skipping"
  fi

  # ── 3. Secrets ──
  step "3/9" "Secrets → ${env}"

  "${SCRIPT_DIR}/manage-secrets.sh" setup "$env"

  # ── 4. Observability Helm ──
  step "4/9" "Observability (Helm charts) → observability namespace"

  if [ -f "${SCRIPT_DIR}/install-observability.sh" ]; then
    echo -e "  Running install-observability.sh upgrade ${env}..."
    if "${SCRIPT_DIR}/install-observability.sh" upgrade "$env" 2>&1 | while read -r line; do
      echo "  $line"
    done; then
      ok "Observability Helm charts installed/upgraded"
    else
      warn "Observability install had issues (check logs above)"
      warn "You can retry: ./scripts/install-observability.sh upgrade ${env}"
    fi
  else
    warn "install-observability.sh not found, skipping"
  fi

  # ── 5. PostgreSQL ──
  step "5/9" "PostgreSQL → ${env}"

  if [ -d "components/postgresql/overlays/${env}" ]; then
    kubectl apply -k "components/postgresql/overlays/${env}/" 2>&1 | while read -r line; do
      echo "  $line"
    done
    wait_for_pod "app.kubernetes.io/name=postgresql" "$env" 180

    # Verificar databases
    echo -e "  Checking databases..."
    sleep 5
    if kubectl exec postgresql-0 -n "$env" -- \
      sh -c 'psql -U $POSTGRES_USER -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;"' 2>/dev/null | grep -q fusionauth; then
      ok "Databases initialized"
    else
      warn "Could not verify databases (may still be initializing)"
    fi
  else
    warn "No PostgreSQL overlay for ${env}, skipping"
  fi

  # ── 6. Eureka Server ──
  step "6/9" "Eureka Server → ${env}"

  if [ -d "components/eureka-server/overlays/${env}" ]; then
    kubectl apply -k "components/eureka-server/overlays/${env}/" 2>&1 | while read -r line; do
      echo "  $line"
    done
    wait_for_deployment "eureka-server" "$env" 180
  else
    warn "No Eureka Server overlay for ${env}, skipping"
  fi

  # ── 7. FusionAuth ──
  step "7/9" "FusionAuth → ${env}"

  if [ -d "components/fusionauth/overlays/${env}" ]; then
    kubectl apply -k "components/fusionauth/overlays/${env}/" 2>&1 | while read -r line; do
      echo "  $line"
    done
    wait_for_deployment "fusionauth" "$env" 300
  else
    warn "No FusionAuth overlay for ${env}, skipping"
  fi

  # ── 8. Jobs ──
  step "8/9" "Jobs (backup, maintenance) → ${env}"

  if [ -d "overlays/${env}/jobs" ]; then
    kubectl apply -k "overlays/${env}/jobs/" 2>&1 | while read -r line; do
      echo "  $line"
    done
    ok "Jobs applied"
  else
    warn "No jobs overlay for ${env}, skipping"
  fi

  # ── 9. Observability CRDs ──
  step "9/9" "Observability CRDs (custom ServiceMonitors, Rules)"

  if [ -d "overlays/${env}/observability" ] && \
     [ -f "overlays/${env}/observability/kustomization.yaml" ]; then
    if grep -q 'resources:' "overlays/${env}/observability/kustomization.yaml" 2>/dev/null; then
      kubectl apply -k "overlays/${env}/observability/" 2>&1 | while read -r line; do
        echo "  $line"
      done
      ok "Observability CRDs applied"
    else
      warn "Observability overlay exists but has no resources, skipping"
    fi
  else
    warn "No observability CRDs overlay for ${env}, skipping"
  fi

  # ── Done ──
  echo ""
  echo -e "${GREEN}${BOLD}"
  echo "============================================"
  echo " DEPLOY COMPLETE: ${env}"
  echo "============================================"
  echo -e "${NC}"

  cmd_status "$env"
}

# ============================================================================
# STATUS
# ============================================================================
cmd_status() {
  local env=$1

  echo -e "${BOLD}=== Environment: ${env} ===${NC}"
  echo ""

  echo -e "${CYAN}── Pods (${env}) ──${NC}"
  kubectl get pods -n "$env" -o wide 2>/dev/null || echo "  No pods"
  echo ""

  echo -e "${CYAN}── Pods (observability) ──${NC}"
  kubectl get pods -n observability --no-headers 2>/dev/null | head -12 || echo "  No pods"
  echo ""

  echo -e "${CYAN}── Services (${env}) ──${NC}"
  kubectl get svc -n "$env" 2>/dev/null || echo "  No services"
  echo ""

  echo -e "${CYAN}── CronJobs ──${NC}"
  kubectl get cronjobs -n "$env" 2>/dev/null || echo "  No cronjobs"
  echo ""

  echo -e "${CYAN}── PVCs ──${NC}"
  kubectl get pvc -n "$env" 2>/dev/null || echo "  No PVCs"
  echo ""

  echo -e "${CYAN}── Secrets ──${NC}"
  local count
  count=$(kubectl get secret caicedo-seguros-secrets -n "$env" -o json 2>/dev/null \
    | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',{})))" 2>/dev/null \
    || echo "NOT FOUND")
  if [ "$count" = "NOT FOUND" ]; then
    echo -e "  ${RED}✗${NC} caicedo-seguros-secrets"
  else
    echo -e "  ${GREEN}✓${NC} caicedo-seguros-secrets (${count} keys)"
  fi
  echo ""

  echo -e "${CYAN}── Ingress ──${NC}"
  kubectl get ingress -n "$env" 2>/dev/null || echo "  No ingress"
  echo ""

  echo -e "${CYAN}── Network Policies ──${NC}"
  kubectl get networkpolicies -n "$env" --no-headers 2>/dev/null || echo "  None"
  echo ""

  echo -e "${CYAN}── Helm Releases (observability) ──${NC}"
  helm list -n observability --no-headers 2>/dev/null || echo "  None"
  echo ""

  echo -e "${CYAN}── Access ──${NC}"
  if [ "$env" = "test" ] || [ "$env" = "production" ]; then
    case "$env" in
      test)
        echo "  FusionAuth:   https://auth-test.caicedoseguros.com"
        echo "  Grafana:      https://grafana.test.caicedoseguros.com"
        echo "  Kite:         https://kite.test.caicedoseguros.com"
        ;;
      production)
        echo "  FusionAuth:   https://auth.caicedoseguros.com"
        echo "  Grafana:      https://grafana.caicedoseguros.com"
        echo "  Kite:         https://kite.caicedoseguros.com"
        ;;
    esac
    echo ""
    echo "  Port-forwards (if needed):"
  fi
  echo "  Eureka:       kubectl port-forward svc/eureka-svc 8761:8761 -n ${env}"
  echo "  FusionAuth:   kubectl port-forward svc/fusionauth-svc 9011:9011 -n ${env}"
  echo "  PostgreSQL:   kubectl port-forward svc/postgresql-svc 5432:5432 -n ${env}"
  echo "  Grafana:      kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n observability"
  echo "  Prometheus:   kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n observability"
  echo "  Kite:         kubectl port-forward svc/kite 8090:8080 -n observability"
}

# ============================================================================
# DESTROY
# ============================================================================
cmd_destroy() {
  local env=$1
  local force=${2:-}

  echo -e "${RED}${BOLD}"
  echo "============================================"
  echo " DESTROYING: ${env}"
  echo "============================================"
  echo -e "${NC}"

  echo -e "${YELLOW}WARNING: This will delete all resources in namespace '${env}'${NC}"

  if [ "$force" = "--force" ]; then
    warn "Proceeding without confirmation (--force)"
  elif [ ! -t 0 ] || [ -n "${CI:-}" ]; then
    fail "Non-interactive context detected (no TTY or CI=true). Use --force to confirm destruction."
    exit 1
  else
    read -r -p "  Type 'yes' to confirm deletion of '${env}': " _confirm
    if [ "$_confirm" != "yes" ]; then
      echo -e "${YELLOW}  Cancelled.${NC}"
      exit 0
    fi
  fi

  cd "$BASE_DIR"

  echo -e "${CYAN}Deleting components (reverse order)...${NC}"

  [ -d "overlays/${env}/observability" ] && \
    kubectl delete -k "overlays/${env}/observability/" --ignore-not-found 2>/dev/null || true
  [ -d "overlays/${env}/jobs" ] && \
    kubectl delete -k "overlays/${env}/jobs/" --ignore-not-found 2>/dev/null || true
  [ -d "components/fusionauth/overlays/${env}" ] && \
    kubectl delete -k "components/fusionauth/overlays/${env}/" --ignore-not-found 2>/dev/null || true
  [ -d "components/eureka-server/overlays/${env}" ] && \
    kubectl delete -k "components/eureka-server/overlays/${env}/" --ignore-not-found 2>/dev/null || true
  [ -d "components/postgresql/overlays/${env}" ] && \
    kubectl delete -k "components/postgresql/overlays/${env}/" --ignore-not-found 2>/dev/null || true
  [ -d "overlays/${env}/platform" ] && \
    kubectl delete -k "overlays/${env}/platform/" --ignore-not-found 2>/dev/null || true

  "${SCRIPT_DIR}/manage-secrets.sh" delete "$env" 2>/dev/null || true

  echo ""
  echo -e "${YELLOW}Note: Observability Helm releases NOT deleted.${NC}"
  echo -e "  To remove: ./scripts/install-observability.sh uninstall"
  echo ""

  echo -e "${YELLOW}Delete PVCs in ${env}? This permanently destroys data.${NC}"

  if [ "$force" = "--force" ]; then
    warn "Deleting PVCs without confirmation (--force)"
    kubectl delete pvc --all -n "$env" 2>/dev/null || true
  elif [ ! -t 0 ] || [ -n "${CI:-}" ]; then
    warn "Non-interactive context — skipping PVC deletion. Run with --force to also delete PVCs."
  else
    read -r -p "  Type 'yes' to permanently delete all PVCs in '${env}': " _confirm_pvc
    if [ "$_confirm_pvc" = "yes" ]; then
      kubectl delete pvc --all -n "$env" 2>/dev/null || true
    else
      echo -e "${YELLOW}  PVCs kept.${NC}"
    fi
  fi

  echo ""
  echo -e "${GREEN}Environment ${env} destroyed${NC}"
}

# ============================================================================
# MAIN
# ============================================================================
usage() {
  echo "Usage: $0 {deploy|status|destroy} <environment>"
  echo ""
  echo "  deploy   Deploy full environment (ordered, 9 steps)"
  echo "  status   Show environment status"
  echo "  destroy  Delete all resources"
  echo ""
  echo "Environments: develop, test, production"
  echo ""
  echo "Prerequisites (develop):"
  echo "  ./scripts/build-images.sh build    # Build local images first"
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
  deploy)  cmd_deploy "$env" ;;
  status)  cmd_status "$env" ;;
  destroy) cmd_destroy "$env" "${3:-}" ;;
  *)       usage ;;
esac