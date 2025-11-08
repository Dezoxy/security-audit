#!/usr/bin/env bash
# checks/check_os.sh
#
# Host & OS baseline:
#  - hostname, OS, kernel
#  - simple reboot-required indicator

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

check_os_basics() {
  section "Host & OS"

  local hostname kernel os pretty
  hostname="$(hostname)"
  kernel="$(uname -r)"

  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    pretty="${PRETTY_NAME:-$NAME}"
    os="$pretty"
  else
    os="$(uname -s)"
  fi

  info "Hostname: $hostname"
  info "OS:       $os"
  info "Kernel:   $kernel"

  if [ -f /var/run/reboot-required ]; then
    warn "System indicates a reboot is required (/var/run/reboot-required)."
  fi
}

main() {
  reset_counts
  check_os_basics

  printf "\nSummary (OS): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"