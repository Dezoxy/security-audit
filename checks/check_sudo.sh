#!/usr/bin/env bash
# checks/check_sudo.sh
#
# Sudo & user checks:
#  - non-root UID 0 accounts
#  - locked accounts overview
#  - NOPASSWD sudo rules

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

check_users_sudo() {
  section "Users & sudo"

  # UID 0 accounts
  local uid0
  uid0="$(awk -F: '$3 == 0 {print $1}' /etc/passwd)"
  info "UID 0 accounts: $(echo "$uid0" | tr '\n' ' ')"
  if echo "$uid0" | grep -qv '^root$'; then
    crit "Non-root account(s) with UID 0 detected – high risk."
  fi

  # locked accounts
  if [ -r /etc/shadow ]; then
    local locked
    locked="$(awk -F: '$2 ~ /^(!|\*)/ {print $1}' /etc/shadow)"
    info "Locked/disabled accounts (shadow): $(echo "$locked" | tr '\n' ' ')"
  else
    warn "/etc/shadow not readable; password state checks incomplete."
  fi

  # sudoers
  local sudoers_main="/etc/sudoers"
  local sudoers_d="/etc/sudoers.d"

  scan_sudo_file() {
    local file="$1"
    [ -r "$file" ] || return 0
    local hits
    hits="$(grep -E '^[^#].*NOPASSWD' "$file" || true)"
    if [ -n "$hits" ]; then
      warn "NOPASSWD entries in $file:"
      printf "%s\n" "$hits"
      if echo "$hits" | grep -q 'ALL[[:space:]]*=[^=]*ALL.*NOPASSWD: ALL'; then
        crit "Very broad NOPASSWD rule detected in $file (ALL=(ALL) NOPASSWD: ALL)."
      fi
    fi
  }

  if [ -f "$sudoers_main" ]; then
    scan_sudo_file "$sudoers_main"
  fi
  if [ -d "$sudoers_d" ]; then
    while IFS= read -r -d '' f; do
      scan_sudo_file "$f"
    done < <(find "$sudoers_d" -type f -print0 2>/dev/null)
  fi
}

main() {
  reset_counts
  check_users_sudo

  printf "\nSummary (sudo/users): WARN=%d, CRIT=%d\n" "$WARN_COUNT" "$CRIT_COUNT"

  if [ "$CRIT_COUNT" -gt 0 ]; then
    exit 2
  elif [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"