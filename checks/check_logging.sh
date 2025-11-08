#!/usr/bin/env bash
# checks/check_logging.sh
#
# Logging & audit:
#  - journald / rsyslog
#  - auditd / audit subsystem presence

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_logging_audit() {
  section "Logging & audit"

  if have_cmd systemctl; then
    if systemctl is-active --quiet systemd-journald 2>/dev/null; then
      info "systemd-journald is active."
    else
      warn "systemd-journald is not reported as active."
    fi

    if systemctl is-active --quiet rsyslog 2>/dev/null; then
      info "rsyslog is active."
    else
      info "rsyslog not active (may be fine if journald is primary)."
    fi
  else
    warn "systemctl not available; cannot check journald/rsyslog status."
  fi

  if have_cmd auditctl || systemctl status auditd >/dev/null 2>&1; then
    info "auditd/audit subsystem appears present; review rules with 'auditctl -l'."
  else
    warn "No obvious audit subsystem detected (auditd/auditctl). Host-level auditing may be limited."
  fi
}

main() {
  reset_counts
  check_logging_audit

  printf "\nSummary (logging/audit): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"