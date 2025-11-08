from __future__ import annotations

from ..logging_utils import CheckContext
from ..utils import command_exists, run_command


def _check_ports(ctx: CheckContext) -> None:
  ctx.info("Listening TCP/UDP ports (top 20 lines):")
  cmd = None
  if command_exists("ss"):
    cmd = ["ss", "-tulpen"]
  elif command_exists("netstat"):
    cmd = ["netstat", "-tulpen"]

  if cmd is None:
    ctx.warn("Neither ss nor netstat available; cannot list listening ports.")
    return

  try:
    result = run_command(cmd)
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"Failed to inspect listening ports ({' '.join(cmd)}): {exc}")
    return

  for line in result.stdout.splitlines()[:20]:
    ctx.info(line)


def _check_firewall(ctx: CheckContext) -> None:
  ctx.info("Evaluating firewall status...")

  if command_exists("ufw"):
    ctx.info("ufw detected.")
    try:
      result = run_command(["ufw", "status", "verbose"], capture=True, check=False)
      text = result.stdout or result.stderr
      for line in text.splitlines()[:30]:
        ctx.info(line)
    except Exception as exc:  # pylint: disable=broad-except
      ctx.warn(f"Failed to get ufw status: {exc}")
    return

  if command_exists("firewall-cmd"):
    ctx.info("firewalld detected.")
    try:
      state = run_command(["firewall-cmd", "--state"])
      if "running" in state.stdout:
        ctx.info("firewalld is running.")
        detail = run_command(["firewall-cmd", "--list-all"])
        for line in detail.stdout.splitlines()[:30]:
          ctx.info(line)
      else:
        ctx.warn("firewalld appears installed but not running.")
    except Exception as exc:  # pylint: disable=broad-except
      ctx.warn(f"Failed to query firewalld: {exc}")
    return

  if command_exists("iptables"):
    ctx.warn("No ufw/firewalld detected, but iptables exists. Showing top of rules:")
    try:
      result = run_command(["iptables", "-L", "-n"])
      for line in result.stdout.splitlines()[:30]:
        ctx.info(line)
    except Exception as exc:  # pylint: disable=broad-except
      ctx.warn(f"Failed to dump iptables rules: {exc}")
    return

  ctx.warn("No firewall tooling detected (ufw/firewalld/iptables) – host may rely solely on upstream filtering.")


def run(ctx: CheckContext) -> None:
  ctx.section("Network & firewall")
  _check_ports(ctx)
  _check_firewall(ctx)
