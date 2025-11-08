#!/usr/bin/env bash
# security_orchestrator.sh
#
# Orchestrate multiple focused security check scripts.
#
# Exit codes:
#   0 = all checks passed with no WARN/CRIT
#   1 = at least one check had WARN but no CRIT
#   2 = at least one check had CRIT

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="$SCRIPT_DIR/checks"

# -------------------- logging setup --------------------

LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
RUN_TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/security_orchestrator_${RUN_TS}.log"

mkdir -p "$LOG_DIR"

LATEST_LINK="$LOG_DIR/latest.log"
ln -sfn "$(basename "$LOG_FILE")" "$LATEST_LINK"

# Header goes to real stdout before redirect
echo "=================================================="
echo " DevSecOps Security Orchestrator"
echo " Base dir: $SCRIPT_DIR"
echo " Log file: $LOG_FILE"
echo "=================================================="

# From now on: stdout+stderr -> tee -> console + log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting run at: $(date +"%Y-%m-%dT%H:%M:%S%z")"
echo

# -------------------- name mapper ---------------------

name_for_script() {
  case "$1" in
    check_os.sh)          echo "OS" ;;
    check_updates.sh)     echo "updates" ;;
    check_filesystem.sh)  echo "filesystem" ;;
    check_network.sh)     echo "network/firewall" ;;
    check_logging.sh)     echo "logging/audit" ;;
    check_ssh.sh)         echo "SSH" ;;
    check_sudo.sh)        echo "sudo/users" ;;
    check_docker.sh)      echo "Docker" ;;
    check_k8s.sh)         echo "Kubernetes" ;;
    *)                    echo "$1" ;;
  esac
}

TOTAL_WARN=0
TOTAL_CRIT=0

for script in "$CHECKS_DIR"/check_*.sh; do
  [ -x "$script" ] || continue

  base="$(basename "$script")"
  label="$(name_for_script "$base")"

  echo
  echo "▶ Running check: $label ($base)"
  echo "--------------------------------------------------"

  # Run checker, capture output and exit code
  output="$("$script" 2>&1)"
  rc=$?

  printf "%s\n" "$output"

  case "$rc" in
    0)
      echo "Result for $label: OK"
      ;;
    1)
      echo "Result for $label: WARN present"
      TOTAL_WARN=$((TOTAL_WARN+1))
      ;;
    2)
      echo "Result for $label: CRIT present"
      TOTAL_CRIT=$((TOTAL_CRIT+1))
      ;;
    *)
      echo "Result for $label: UNKNOWN exit code $rc"
      TOTAL_WARN=$((TOTAL_WARN+1))
      ;;
  esac
done

echo
echo "=================================================="
echo " Overall summary:"
echo "   Checks with WARN : $TOTAL_WARN"
echo "   Checks with CRIT : $TOTAL_CRIT"
echo " Finished at: $(date +"%Y-%m-%dT%H:%M:%S%z")"
echo " Log file: $LOG_FILE"
echo "=================================================="

if [ "$TOTAL_CRIT" -gt 0 ]; then
  exit 2
elif [ "$TOTAL_WARN" -gt 0 ]; then
  exit 1
else
  exit 0
fi