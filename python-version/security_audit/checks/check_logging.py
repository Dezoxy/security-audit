from __future__ import annotations

from ..logging_utils import CheckContext
from ..utils import command_exists, run_command


def _systemctl_active(service: str) -> bool:
  try:
    result = run_command(["systemctl", "is-active", "--quiet", service], capture=False)
    return result.returncode == 0
  except FileNotFoundError:
    return False
  except Exception:
    return False


def _systemctl_status(service: str) -> bool:
  try:
    result = run_command(["systemctl", "status", service])
    return result.returncode == 0
  except FileNotFoundError:
    return False
  except Exception:
    return False


def run(ctx: CheckContext) -> None:
  ctx.section("Logging & audit")

  if command_exists("systemctl"):
    if _systemctl_active("systemd-journald"):
      ctx.info("systemd-journald is active.")
    else:
      ctx.warn("systemd-journald is not reported as active.")

    if _systemctl_active("rsyslog"):
      ctx.info("rsyslog is active.")
    else:
      ctx.info("rsyslog not active (may be fine if journald is primary).")
  else:
    ctx.warn("systemctl not available; cannot check journald/rsyslog status.")

  if command_exists("auditctl") or _systemctl_status("auditd"):
    ctx.info("auditd/audit subsystem appears present; review rules with 'auditctl -l'.")
  else:
    ctx.warn("No obvious audit subsystem detected (auditd/auditctl). Host-level auditing may be limited.")
