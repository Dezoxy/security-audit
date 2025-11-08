#!/usr/bin/env bash
# checks/check_updates.sh
#
# Package manager security posture:
#  - available updates
#  - security updates (dnf-based)
#  - general warnings when unknown

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_updates() {
  section "Package updates"

  if have_cmd apt-get; then
    info "Detected apt-based system."

    if have_cmd unattended-upgrades; then
      info "unattended-upgrades installed (automatic security updates available)."
    fi

    if have_cmd apt; then
      info "Checking for upgradable packages (apt list --upgradable)..."
      local up_all
      up_all="$(apt list --upgradable 2>/dev/null | sed -n '2,20p')"

      if [ -n "$up_all" ]; then
        warn "Packages available for upgrade (showing first 20):"
        printf "%s\n" "$up_all"
      else
        info "No upgradable packages found (or unable to list)."
      fi
    fi

  elif have_cmd dnf; then
    info "Detected dnf-based system (RHEL/Rocky/Fedora)."

    info "Checking for security updates (dnf updateinfo list security)..."
    local sec
    sec="$(dnf updateinfo list security 2>/dev/null | sed -n '1,20p' || true)"
    if echo "$sec" | grep -Eq 'Important/|Critical/'; then
      crit "Important/Critical security updates are pending:"
      printf "%s\n" "$sec"
    elif [ -n "$sec" ]; then
      warn "Security updates are available (none flagged as Important/Critical in first lines)."
      printf "%s\n" "$sec"
    else
      info "No security updates reported by dnf updateinfo."
    fi

  elif have_cmd yum; then
    info "Detected yum-based system."
    warn "Please review 'yum check-update' output manually for pending updates."

  else
    warn "Unknown/no package manager detected; cannot assess updates."
  fi
}

main() {
  reset_counts
  check_updates

  printf "\nSummary (updates): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"