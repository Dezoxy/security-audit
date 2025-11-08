from __future__ import annotations

from pathlib import Path
from typing import Optional

from ..logging_utils import CheckContext


def _conf_val(path: Path, key: str) -> Optional[str]:
  key = key.lower()
  value: Optional[str] = None
  try:
    with path.open(encoding="utf-8", errors="ignore") as handle:
      for line in handle:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
          continue
        parts = stripped.split()
        if parts[0].lower() == key and len(parts) > 1:
          value = parts[1].lower()
  except FileNotFoundError:
    return None
  return value


def run(ctx: CheckContext) -> None:
  ctx.section("SSH configuration")
  sshd_cfg = Path("/etc/ssh/sshd_config")
  if not sshd_cfg.exists():
    ctx.info("No /etc/ssh/sshd_config found (sshd may not be running on this host).")
    return

  ctx.info(f"Evaluating {sshd_cfg}")

  permit_root = _conf_val(sshd_cfg, "PermitRootLogin")
  password_auth = _conf_val(sshd_cfg, "PasswordAuthentication")
  empty_pw = _conf_val(sshd_cfg, "PermitEmptyPasswords")
  protocol = _conf_val(sshd_cfg, "Protocol")

  if permit_root == "yes":
    ctx.crit("PermitRootLogin is YES – root over SSH is high risk.")
  elif permit_root:
    ctx.info(f"PermitRootLogin={permit_root}")
  else:
    ctx.warn("PermitRootLogin not set – verify distribution default (often 'prohibit-password').")

  if password_auth == "yes":
    ctx.warn("PasswordAuthentication=YES – consider key-only auth for servers.")
  elif password_auth == "no":
    ctx.info("PasswordAuthentication=NO (keys-only auth enforced).")
  else:
    ctx.warn("PasswordAuthentication not explicitly set – check defaults.")

  if empty_pw == "yes":
    ctx.crit("PermitEmptyPasswords=YES – extremely dangerous.")

  if protocol and protocol != "2":
    ctx.crit("SSH Protocol not restricted to 2.")
