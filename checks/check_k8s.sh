#!/usr/bin/env bash
# checks/check_k8s.sh
#
# Kubernetes checks (best-effort):
#  - cluster reachability
#  - version info
#  - privileged containers (requires jq for full power)

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_kubernetes() {
  section "Kubernetes checks"

  if ! have_cmd kubectl; then
    info "kubectl not found – skipping Kubernetes checks."
    return 0
  fi

  if ! kubectl cluster-info >/dev/null 2>&1; then
    warn "kubectl present but 'kubectl cluster-info' failed – no cluster context or auth issue."
    return 0
  fi

  info "kubectl can reach a cluster."
  kubectl version --short || true

  if ! have_cmd jq; then
    warn "jq not installed – Kubernetes security checks are limited."
    return 0
  fi

  info "Scanning pods for privileged containers (all namespaces)..."

  local priv_pods
  priv_pods="$(
    kubectl get pods -A -o json 2>/dev/null \
      | jq -r '
          .items[]
          | {ns: .metadata.namespace, name: .metadata.name,
             cs: .spec.containers[]?}
          | select(.cs.securityContext.privileged == true)
          | "\(.ns) \(.name) \(.cs.name)"
        '
  )"

  if [ -n "$priv_pods" ]; then
    crit "Privileged containers detected (namespace pod container):"
    printf "%s\n" "$priv_pods"
  else
    info "No privileged containers detected via jq scan."
  fi
}

main() {
  reset_counts
  check_kubernetes

  printf "\nSummary (Kubernetes): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"