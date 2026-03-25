#!/bin/bash
# ============================================================================
#
# Uso:
#   ./scripts/build-images.sh build                  # Build ALL services
#   ./scripts/build-images.sh build eureka-server     # Build one service
#   ./scripts/build-images.sh build eureka-server api-gateway  # Build several
#   ./scripts/build-images.sh list                    # Show registered services
#   ./scripts/build-images.sh status                  # Show images in K3s
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
# SERVICE REGISTRY
# ============================================================================
# Formato: "name|image_name|dockerfile_path|context_path"
#
#   name             → Nombre corto para el CLI (ej: eureka-server)
#   image_name       → Nombre completo de la imagen (ej: caicedo-seguros/discovery-server)
#   dockerfile_path  → Ruta al Dockerfile relativa al REPO ROOT
#   context_path     → Ruta al build context relativa al REPO ROOT
#
# REPO ROOT se infiere desde BASE_DIR (k3s/) subiendo 2 niveles:
#   k3s/ → infrastructure/ → conecta-seguros-backend/
# ============================================================================
REPO_ROOT="$(cd "${BASE_DIR}/../.." && pwd)"

LOCAL_TAG="local"

# ┌──────────────────────────────────────────────────────────────────────────┐
# │ AGREGAR NUEVOS SERVICIOS AQUÍ                                           │
# │                                                                         │
# │ Formato: "nombre|imagen|ruta-dockerfile|ruta-context"                   │
# │ Las rutas son relativas a la raíz del monorepo                         │
# └──────────────────────────────────────────────────────────────────────────┘
SERVICES=(
  "eureka-server|caicedo-seguros/discovery-server|discovery-server/Dockerfile|discovery-server"
  # "api-gateway|caicedo-seguros/api-gateway|api-gateway/Dockerfile|api-gateway"
  # "clients-service|caicedo-seguros/clients-service|clients-service/Dockerfile|clients-service"
  # "products-service|caicedo-seguros/products-service|products-service/Dockerfile|products-service"
  # "payments-service|caicedo-seguros/payments-service|payments-service/Dockerfile|payments-service"
  # "news-service|caicedo-seguros/news-service|news-service/Dockerfile|news-service"
)

# ============================================================================
# HELPERS
# ============================================================================
get_name()       { echo "$1" | cut -d'|' -f1; }
get_image()      { echo "$1" | cut -d'|' -f2; }
get_dockerfile() { echo "$1" | cut -d'|' -f3; }
get_context()    { echo "$1" | cut -d'|' -f4; }

find_service() {
  local target="$1"
  for svc in "${SERVICES[@]}"; do
    if [ "$(get_name "$svc")" = "$target" ]; then
      echo "$svc"
      return 0
    fi
  done
  return 1
}

# ============================================================================
# BUILD
# ============================================================================
build_service() {
  local svc="$1"
  local name image dockerfile context full_image
  name=$(get_name "$svc")
  image=$(get_image "$svc")
  dockerfile=$(get_dockerfile "$svc")
  context=$(get_context "$svc")
  full_image="${image}:${LOCAL_TAG}"

  local dockerfile_abs="${REPO_ROOT}/${dockerfile}"
  local context_abs="${REPO_ROOT}/${context}"

  echo ""
  echo -e "${CYAN}━━━ Building: ${BOLD}${name}${NC}${CYAN} ━━━${NC}"
  echo -e "  Image:      ${full_image}"
  echo -e "  Dockerfile: ${dockerfile}"
  echo -e "  Context:    ${context}"

  # Validate
  if [ ! -f "$dockerfile_abs" ]; then
    echo -e "  ${RED}[FAIL]${NC} Dockerfile not found: ${dockerfile_abs}"
    return 1
  fi

  if [ ! -d "$context_abs" ]; then
    echo -e "  ${RED}[FAIL]${NC} Context dir not found: ${context_abs}"
    return 1
  fi

  # Step 1: Docker build
  echo -e "  ${CYAN}[1/3]${NC} Building Docker image..."
  if docker build \
    -t "${full_image}" \
    -f "${dockerfile_abs}" \
    "${context_abs}" 2>&1 | tail -5; then
    echo -e "  ${GREEN}[OK]${NC} Docker build complete"
  else
    echo -e "  ${RED}[FAIL]${NC} Docker build failed"
    return 1
  fi

  # Step 2: Export to tar
  local tar_file="/tmp/${name}-image.tar"
  echo -e "  ${CYAN}[2/3]${NC} Exporting image..."
  if ! docker save "${full_image}" -o "${tar_file}"; then
    echo -e "  ${RED}[FAIL]${NC} docker save failed for ${full_image}"
    rm -f "${tar_file}"
    return 1
  fi
  local size
  size=$(du -sh "${tar_file}" | cut -f1)
  echo -e "  ${GREEN}[OK]${NC} Exported (${size})"

  # Step 3: Import into K3s containerd
  echo -e "  ${CYAN}[3/3]${NC} Importing into K3s containerd..."
  if sudo k3s ctr images import "${tar_file}" 2>&1; then
    echo -e "  ${GREEN}[OK]${NC} Imported → ${full_image}"
  else
    echo -e "  ${RED}[FAIL]${NC} K3s import failed"
    echo -e "  ${YELLOW}Hint:${NC} Is K3s running? Try: sudo systemctl status k3s"
    rm -f "${tar_file}"
    return 1
  fi

  # Cleanup tar
  rm -f "${tar_file}"

  echo -e "  ${GREEN}✅ ${name} ready in K3s${NC}"
  return 0
}

cmd_build() {
  local targets=("$@")
  local built=0
  local failed=0
  local total=0

  echo -e "${BOLD}"
  echo "============================================"
  echo " Building images for K3s (local)"
  echo "============================================"
  echo -e "${NC}"
  echo -e "  Repo root: ${REPO_ROOT}"

  # Preflight
  if ! command -v docker &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker not installed"
    exit 1
  fi

  if ! sudo k3s ctr images ls &>/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Cannot connect to K3s containerd"
    echo -e "  Is K3s running? Try: sudo systemctl status k3s"
    exit 1
  fi

  # If no targets specified, build all
  if [ ${#targets[@]} -eq 0 ]; then
    echo -e "  Building ${BOLD}all${NC} services (${#SERVICES[@]})..."
    for svc in "${SERVICES[@]}"; do
      total=$((total + 1))
      if build_service "$svc"; then
        built=$((built + 1))
      else
        failed=$((failed + 1))
      fi
    done
  else
    # Build specific targets
    for target in "${targets[@]}"; do
      total=$((total + 1))
      local svc
      if svc=$(find_service "$target"); then
        if build_service "$svc"; then
          built=$((built + 1))
        else
          failed=$((failed + 1))
        fi
      else
        echo -e "  ${RED}[FAIL]${NC} Unknown service: ${target}"
        echo -e "  ${YELLOW}Available:${NC} $(printf '%s ' "${SERVICES[@]}" | sed 's/|[^|]*|[^|]*|[^ ]* / /g; s/|.*//')"
        failed=$((failed + 1))
      fi
    done
  fi

  # Summary
  echo ""
  echo -e "${CYAN}────────────────────────────────────────${NC}"
  echo -e "  Built: ${GREEN}${built}${NC} | Failed: ${RED}${failed}${NC} | Total: ${total}"
  echo -e "${CYAN}────────────────────────────────────────${NC}"

  [ $failed -gt 0 ] && return 1
  return 0
}

# ============================================================================
# LIST
# ============================================================================
cmd_list() {
  echo -e "${BOLD}=== Registered Services ===${NC}"
  echo ""
  printf "  ${CYAN}%-20s %-45s %-30s${NC}\n" "NAME" "IMAGE" "DOCKERFILE"
  printf "  %-20s %-45s %-30s\n" "────────────────────" "─────────────────────────────────────────────" "──────────────────────────────"
  for svc in "${SERVICES[@]}"; do
    local name image dockerfile
    name=$(get_name "$svc")
    image=$(get_image "$svc")
    dockerfile=$(get_dockerfile "$svc")
    printf "  %-20s %-45s %-30s\n" "$name" "${image}:${LOCAL_TAG}" "$dockerfile"
  done
  echo ""
  echo -e "  ${#SERVICES[@]} service(s) registered"
}

# ============================================================================
# STATUS
# ============================================================================
cmd_status() {
  echo -e "${BOLD}=== Images in K3s containerd ===${NC}"
  echo ""

  local images_list
  if ! images_list=$(sudo k3s ctr images ls 2>&1); then
    echo -e "  ${RED}[FAIL]${NC} Could not query K3s containerd: ${images_list}"
    return 1
  fi

  for svc in "${SERVICES[@]}"; do
    local name image matched size
    name=$(get_name "$svc")
    image=$(get_image "$svc")

    matched=$(echo "${images_list}" | grep "${image}:${LOCAL_TAG}" | head -1)
    if [ -n "$matched" ]; then
      size=$(echo "$matched" | awk '{print $NF}')
      echo -e "  ${GREEN}●${NC} ${name}: ${image}:${LOCAL_TAG} (${size})"
    else
      echo -e "  ${RED}○${NC} ${name}: not imported"
    fi
  done
  echo ""
}

# ============================================================================
# MAIN
# ============================================================================
usage() {
  echo "Usage: $0 {build|list|status} [service...]"
  echo ""
  echo "Commands:"
  echo "  build [name...]  Build and import images into K3s"
  echo "                   No args = build all, or specify service names"
  echo "  list             Show registered services"
  echo "  status           Show which images are in K3s"
  echo ""
  echo "Examples:"
  echo "  $0 build                          # Build all"
  echo "  $0 build eureka-server            # Build one"
  echo "  $0 build eureka-server api-gateway  # Build several"
  echo "  $0 list                           # Show services"
  echo "  $0 status                         # Check K3s images"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

command=$1
shift

case "$command" in
  build)  cmd_build "$@" ;;
  list)   cmd_list ;;
  status) cmd_status ;;
  *)      usage ;;
esac