#!/usr/bin/env bash
# lib/common.sh
#
# Shared logging helpers and WARN/CRIT counters for security checks.

set -uo pipefail
IFS=$'\n\t'

# Colors if TTY
if [ -t 1 ]; then
  RED="$(printf '\033[31m')"
  YELLOW="$(printf '\033[33m')"
  GREEN="$(printf '\033[32m')"
  BLUE="$(printf '\033[34m')"
  BOLD="$(printf '\033[1m')"
  RESET="$(printf '\033[0m')"
else
  RED=""; YELLOW=""; GREEN=""; BLUE=""; BOLD=""; RESET=""
fi

WARN_COUNT=0
CRIT_COUNT=0

section() {
  printf "\n%s== %s ==%s\n" "$BOLD" "$1" "$RESET"
}

info() {
  printf "%s[INFO]%s %s\n" "$BLUE" "$RESET" "$*"
}

warn() {
  WARN_COUNT=$((WARN_COUNT+1))
  printf "%s[WARN]%s %s\n" "$YELLOW" "$RESET" "$*"
}

crit() {
  CRIT_COUNT=$((CRIT_COUNT+1))
  printf "%s[CRIT]%s %s\n" "$RED" "$RESET" "$*"
}

reset_counts() {
  WARN_COUNT=0
  CRIT_COUNT=0
}