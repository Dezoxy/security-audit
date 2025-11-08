#!/usr/bin/env bash
# checks/check_network.sh
#
# Network & firewall:
#  - listening ports
#  - firewall presence (ufw/firewalld/iptables)

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_ports() {
  info "Listening TCP/UDP ports (top 20 lines):"

  if have_cmd ss; then
    ss -tulpen 2>/dev/null | sed -n '1,20p'
  elif have_cmd netstat; then
    netstat -tulpen 2>/dev/null | sed -n '1,20p'
  else
    warn "Neither ss nor netstat available; cannot list listening ports."
  fi
}

check_firewall() {
  info "Evaluating firewall status..."

  if have_cmd ufw; then
    info "ufw detected."
    ufw status verbose || warn "Failed to get ufw status."
    return
  fi

  if have_cmd firewall-cmd; then
    info "firewalld detected."
    if firewall-cmd --state 2>/dev/null | grep -q running; then
      info "firewalld is running."
      firewall-cmd --list-all 2>/dev/null || true
    else
      warn "firewalld appears installed but not running."
    fi
    return
  fi

  if have_cmd iptables; then
    warn "No ufw/firewalld detected, but iptables exists. Showing top of rules:"
    iptables -L -n | sed -n '1,30p'
    return
  fi

  warn "No firewall tooling detected (ufw/firewalld/iptables) – host may rely solely on upstream filtering."
}

check_network() {
  section "Network & firewall"
  check_ports
  check_firewall
}

main() {
  reset_counts
  check_network

  printf "\nSummary (network/firewall): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"