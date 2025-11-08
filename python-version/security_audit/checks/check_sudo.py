from __future__ import annotations

import os
import pwd
import re
from pathlib import Path

from ..logging_utils import CheckContext


NOPASSWD_RE = re.compile(r"^[^#].*NOPASSWD", re.IGNORECASE)


def _scan_sudo_file(path: Path, ctx: CheckContext) -> None:
  if not path.exists():
    return
  try:
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
  except PermissionError:
    ctx.warn(f"{path} not readable; cannot assess sudo rules.")
    return

  hits = [line.strip() for line in lines if NOPASSWD_RE.search(line)]
  if not hits:
    return

  ctx.warn(f"NOPASSWD entries in {path}:")
  for line in hits:
    ctx.info(f"  {line}")
    if "NOPASSWD: ALL" in line and "ALL" in line:
      ctx.crit(f"Very broad NOPASSWD rule detected in {path} (ALL=(ALL) NOPASSWD: ALL).")


def run(ctx: CheckContext) -> None:
  ctx.section("Users & sudo")

  uid0_accounts = [entry.pw_name for entry in pwd.getpwall() if entry.pw_uid == 0]
  ctx.info(f"UID 0 accounts: {' '.join(uid0_accounts) if uid0_accounts else '(none)'}")
  if any(user != "root" for user in uid0_accounts):
    ctx.crit("Non-root account(s) with UID 0 detected – high risk.")

  shadow = Path("/etc/shadow")
  if shadow.exists():
    try:
      locked = []
      with shadow.open(encoding="utf-8", errors="ignore") as handle:
        for line in handle:
          parts = line.split(":")
          if len(parts) > 1 and parts[1].startswith(("!", "*")):
            locked.append(parts[0])
      ctx.info(f"Locked/disabled accounts (shadow): {' '.join(locked) if locked else '(none)'}")
    except PermissionError:
      ctx.warn("/etc/shadow not readable; password state checks incomplete.")
  else:
    ctx.warn("/etc/shadow not found; password state checks incomplete.")

  _scan_sudo_file(Path("/etc/sudoers"), ctx)
  sudoers_d = Path("/etc/sudoers.d")
  if sudoers_d.is_dir():
    for file_path in sorted(sudoers_d.iterdir()):
      if file_path.is_file():
        _scan_sudo_file(file_path, ctx)
