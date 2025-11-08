#!/usr/bin/env bash
# checks/check_filesystem.sh
#
# Filesystem & permissions:
#  - world-writable dirs without sticky bit (/tmp, /var/tmp, /home)
#  - SUID/SGID binaries in standard paths; highlight custom ones

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_world_writable() {
  info "Scanning for world-writable dirs without sticky bit under /tmp /var/tmp /home..."

  if ! have_cmd find; then
    warn "find not available; skipping world-writable directory scan."
    return
  fi

  local ww
  ww="$(find /tmp /var/tmp /home -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | head -n 30)"

  if [ -n "$ww" ]; then
    warn "World-writable dirs without sticky bit (first 30):"
    printf "%s\n" "$ww"
  else
    info "No obvious world-writable dirs without sticky bit in target paths."
  fi
}

check_suid_sgid() {
  info "Scanning for SUID/SGID binaries in /bin /sbin /usr/bin /usr/sbin..."

  if ! have_cmd find; then
    warn "find not available; skipping SUID/SGID scan."
    return
  fi

  local suid
  suid="$(find /bin /sbin /usr/bin /usr/sbin -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null)"

  local count
  count="$(printf "%s\n" "$suid" | sed '/^$/d' | wc -l | tr -d ' ')"
  info "Found $count SUID/SGID binaries in standard paths."

  local custom
  custom="$(printf "%s\n" "$suid" | grep -E '^/usr/local|^/opt' || true)"
  if [ -n "$custom" ]; then
    warn "SUID/SGID binaries in /usr/local or /opt (review carefully):"
    printf "%s\n" "$custom"
  fi
}

check_filesystem() {
  section "Filesystem & permissions"
  check_world_writable
  check_suid_sgid
}

main() {
  reset_counts
  check_filesystem

  printf "\nSummary (filesystem): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"