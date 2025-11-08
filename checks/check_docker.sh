#!/usr/bin/env bash
# checks/check_docker.sh
#
# Docker checks:
#  - docker.sock perms
#  - running containers
#  - root / privileged containers

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_docker() {
  section "Docker / container runtime"

  if ! have_cmd docker; then
    info "Docker CLI not found – skipping Docker checks."
    return 0
  fi

  if ! docker info >/dev/null 2>&1; then
    warn "Docker CLI present but 'docker info' failed (daemon not running or insufficient permissions)."
    return 0
  fi

  info "Docker daemon reachable."

  if [ -S /var/run/docker.sock ]; then
    local perm
    # Linux stat (fallback for BSD/macOS)
    perm="$(stat -c '%a %U:%G' /var/run/docker.sock 2>/dev/null || stat -f '%Lp %Su:%Sg' /var/run/docker.sock 2>/dev/null || echo '?')"
    info "docker.sock perms: $perm"
  fi

  local running
  running="$(docker ps --format '{{.ID}} {{.Image}} {{.Names}}' 2>/dev/null)"
  if [ -z "$running" ]; then
    info "No running containers."
    return 0
  fi

  info "Running containers:"
  printf "%s\n" "$running"

  while read -r id img name; do
    local inspect user privileged
    inspect="$(docker inspect "$id" 2>/dev/null || true)"

    user="$(printf "%s\n" "$inspect" | grep -m1 '"User":' | sed 's/.*"User": "\(.*\)".*/\1/' | tr -d ' ')"
    privileged="$(printf "%s\n" "$inspect" | grep -m1 '"Privileged":' | sed 's/.*"Privileged": \(true\|false\).*/\1/' | tr -d ' ,')"

    [ -z "$user" ] && user="(default/root)"

    if [ "$user" = "0" ] || [ "$user" = "(default/root)" ]; then
      warn "Container $name ($img) is running as root (User=$user). Consider using non-root user."
    fi

    if [ "$privileged" = "true" ]; then
      crit "Container $name ($img) is running in privileged mode."
    fi
  done <<< "$running"
}

main() {
  reset_counts
  check_docker

  printf "\nSummary (Docker): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"