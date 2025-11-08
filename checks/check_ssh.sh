#!/usr/bin/env bash
# checks/check_ssh.sh
#
# SSH configuration checks:
#  - PermitRootLogin
#  - PasswordAuthentication
#  - PermitEmptyPasswords
#  - Protocol

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

check_ssh() {
  section "SSH configuration"

  local sshd_cfg="/etc/ssh/sshd_config"
  if [ ! -f "$sshd_cfg" ]; then
    info "No $sshd_cfg found (sshd may not be running on this host)."
    return 0
  fi

  info "Evaluating $sshd_cfg"

  conf_val() {
    local key="$1"
    awk -v k="$key" '
      $1 !~ /^#/ && tolower($1) == tolower(k) {print tolower($2)}
    ' "$sshd_cfg" | tail -n1
  }

  local permit_root password_auth empty_pw protocol

  permit_root="$(conf_val PermitRootLogin)"
  password_auth="$(conf_val PasswordAuthentication)"
  empty_pw="$(conf_val PermitEmptyPasswords)"
  protocol="$(conf_val Protocol)"

  if [ "$permit_root" = "yes" ]; then
    crit "PermitRootLogin is YES – root over SSH is high risk."
  elif [ -z "$permit_root" ]; then
    warn "PermitRootLogin not set – verify distribution default (often 'prohibit-password')."
  else
    info "PermitRootLogin=$permit_root"
  fi

  if [ "$password_auth" = "yes" ]; then
    warn "PasswordAuthentication=YES – consider key-only auth for servers."
  elif [ "$password_auth" = "no" ]; then
    info "PasswordAuthentication=NO (keys-only auth enforced)."
  else
    warn "PasswordAuthentication not explicitly set – check defaults."
  fi

  if [ "$empty_pw" = "yes" ]; then
    crit "PermitEmptyPasswords=YES – extremely dangerous."
  fi

  if [ -n "$protocol" ] && [ "$protocol" != "2" ]; then
    crit "SSH Protocol not restricted to 2."
  fi
}

main() {
  reset_counts
  check_ssh

  printf "\nSummary (SSH): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"