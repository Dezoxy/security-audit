from __future__ import annotations

from pathlib import Path

from ..logging_utils import CheckContext
from ..utils import command_exists, run_command


def _existing_paths(paths):
  return [path for path in paths if Path(path).exists()]


def _check_world_writable(ctx: CheckContext) -> None:
  ctx.info("Scanning for world-writable dirs without sticky bit under /tmp /var/tmp /home...")
  if not command_exists("find"):
    ctx.warn("find not available; skipping world-writable directory scan.")
    return

  targets = _existing_paths(["/tmp", "/var/tmp", "/home"])
  if not targets:
    ctx.info("Target directories missing; skipping scan.")
    return

  args = ["find", *targets, "-xdev", "-type", "d", "-perm", "-0002", "!", "-perm", "-1000"]
  try:
    result = run_command(args)
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"Failed to run find for world-writable dirs: {exc}")
    return

  lines = [line for line in result.stdout.splitlines() if line.strip()][:30]
  if lines:
    ctx.warn("World-writable dirs without sticky bit (first 30):")
    for line in lines:
      ctx.info(f"  {line}")
  else:
    ctx.info("No obvious world-writable dirs without sticky bit in target paths.")


def _check_suid_sgid(ctx: CheckContext) -> None:
  ctx.info("Scanning for SUID/SGID binaries in /bin /sbin /usr/bin /usr/sbin...")
  if not command_exists("find"):
    ctx.warn("find not available; skipping SUID/SGID scan.")
    return

  targets = _existing_paths(["/bin", "/sbin", "/usr/bin", "/usr/sbin"])
  if not targets:
    ctx.info("Standard binary directories missing; skipping scan.")
    return

  args = ["find", *targets, "-xdev", "(", "-perm", "-4000", "-o", "-perm", "-2000", ")", "-type", "f"]
  try:
    result = run_command(args)
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"Failed to run find for SUID/SGID binaries: {exc}")
    return

  binaries = [line for line in result.stdout.splitlines() if line.strip()]
  ctx.info(f"Found {len(binaries)} SUID/SGID binaries in standard paths.")

  custom = [line for line in binaries if line.startswith("/usr/local") or line.startswith("/opt")]
  if custom:
    ctx.warn("SUID/SGID binaries in /usr/local or /opt (review carefully):")
    for line in custom[:30]:
      ctx.info(f"  {line}")


def run(ctx: CheckContext) -> None:
  ctx.section("Filesystem & permissions")
  _check_world_writable(ctx)
  _check_suid_sgid(ctx)
