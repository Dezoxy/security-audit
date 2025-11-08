from __future__ import annotations

import platform
import socket
from pathlib import Path

from ..logging_utils import CheckContext


def _read_os_release() -> str | None:
  path = Path("/etc/os-release")
  if not path.exists():
    return None
  data: dict[str, str] = {}
  with path.open(encoding="utf-8", errors="ignore") as handle:
    for line in handle:
      if "=" not in line:
        continue
      key, value = line.rstrip().split("=", 1)
      data[key] = value.strip().strip('"')
  pretty = data.get("PRETTY_NAME") or data.get("NAME")
  return pretty


def run(ctx: CheckContext) -> None:
  ctx.section("Host & OS")
  hostname = socket.gethostname()
  kernel = platform.release()
  os_name = _read_os_release() or platform.system()

  ctx.info(f"Hostname: {hostname}")
  ctx.info(f"OS:       {os_name}")
  ctx.info(f"Kernel:   {kernel}")

  reboot_flag = Path("/var/run/reboot-required")
  if reboot_flag.exists():
    ctx.warn(f"System indicates a reboot is required ({reboot_flag}).")
