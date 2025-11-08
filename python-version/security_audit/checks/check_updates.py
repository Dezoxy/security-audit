from __future__ import annotations

from ..logging_utils import CheckContext
from ..utils import command_exists, run_command


def _apt_updates(ctx: CheckContext) -> None:
  ctx.info("Detected apt-based system.")

  if command_exists("unattended-upgrades"):
    ctx.info("unattended-upgrades installed (automatic security updates available).")

  if not command_exists("apt"):
    return

  ctx.info("Checking for upgradable packages (apt list --upgradable)...")
  try:
    result = run_command(["apt", "list", "--upgradable"])
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"Failed to list apt upgrades: {exc}")
    return

  lines = [line for line in result.stdout.splitlines()[1:21] if line.strip()]
  if lines:
    ctx.warn("Packages available for upgrade (showing first 20):")
    for line in lines:
      ctx.info(f"  {line}")
  else:
    ctx.info("No upgradable packages found (or unable to list).")


def _dnf_updates(ctx: CheckContext) -> None:
  ctx.info("Detected dnf-based system.")
  ctx.info("Checking for security updates (dnf updateinfo list security)...")
  try:
    result = run_command(["dnf", "updateinfo", "list", "security"])
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"Failed to query dnf updateinfo: {exc}")
    return

  lines = [line for line in result.stdout.splitlines() if line.strip()]
  if any("Important/" in line or "Critical/" in line for line in lines):
    ctx.crit("Important/Critical security updates are pending:")
    for line in lines[:20]:
      ctx.info(f"  {line}")
  elif lines:
    ctx.warn("Security updates are available (none flagged as Important/Critical in first lines).")
    for line in lines[:20]:
      ctx.info(f"  {line}")
  else:
    ctx.info("No security updates reported by dnf updateinfo.")


def run(ctx: CheckContext) -> None:
  ctx.section("Package updates")

  if command_exists("apt-get"):
    _apt_updates(ctx)
  elif command_exists("dnf"):
    _dnf_updates(ctx)
  elif command_exists("yum"):
    ctx.info("Detected yum-based system.")
    ctx.warn("Please review 'yum check-update' output manually for pending updates.")
  else:
    ctx.warn("Unknown/no package manager detected; cannot assess updates.")
