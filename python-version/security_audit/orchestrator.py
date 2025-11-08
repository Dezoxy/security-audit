from __future__ import annotations

import importlib
import os
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable, Iterable, List, Sequence, Tuple

from .logging_utils import CheckContext, TeeLogger


@dataclass
class CheckDefinition:
  """Describes a single security check."""

  label: str
  module: str
  func_name: str = "run"


DEFAULT_CHECKS: Sequence[CheckDefinition] = (
  CheckDefinition(label="OS", module="security_audit.checks.check_os"),
  CheckDefinition(label="updates", module="security_audit.checks.check_updates"),
  CheckDefinition(label="filesystem", module="security_audit.checks.check_filesystem"),
  CheckDefinition(label="network/firewall", module="security_audit.checks.check_network"),
  CheckDefinition(label="logging/audit", module="security_audit.checks.check_logging"),
  CheckDefinition(label="SSH", module="security_audit.checks.check_ssh"),
  CheckDefinition(label="sudo/users", module="security_audit.checks.check_sudo"),
  CheckDefinition(label="Docker", module="security_audit.checks.check_docker"),
  CheckDefinition(label="Kubernetes", module="security_audit.checks.check_k8s"),
)


def resolve_log_paths() -> Tuple[Path, Path]:
  script_dir = Path(__file__).resolve().parents[1]
  log_dir = Path(os.environ.get("LOG_DIR", script_dir / "logs"))
  log_dir.mkdir(parents=True, exist_ok=True)

  timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
  log_file = log_dir / f"security_orchestrator_{timestamp}.log"

  latest = log_dir / "latest.log"
  if latest.exists() or latest.is_symlink():
    latest.unlink()
  latest.symlink_to(log_file.name)

  return log_file, latest


def load_check_callable(defn: CheckDefinition) -> Callable[[CheckContext], None]:
  module = importlib.import_module(defn.module)
  func = getattr(module, defn.func_name, None)
  if func is None:
    raise AttributeError(f"{defn.module} missing '{defn.func_name}'")
  return func


def run_checks(checks: Sequence[CheckDefinition] | None = None) -> int:
  log_file, _ = resolve_log_paths()
  with TeeLogger(log_file) as logger:
    base_dir = Path(__file__).resolve().parents[1]
    logger.banner("DevSecOps Security Orchestrator", base_dir, log_file)

    selected = checks or DEFAULT_CHECKS
    total_warn = 0
    total_crit = 0

    for defn in selected:
      context = CheckContext(defn.label, logger)
      logger.sep(defn.label)

      try:
        check_fn = load_check_callable(defn)
        check_fn(context)
      except Exception as exc:  # pylint: disable=broad-except
        context.warn(f"Check '{defn.label}' failed: {exc}")
        if logger.debug_enabled:
          logger.debug("Exception detail", exc)

      logger.check_summary(defn.label, context.warn_count, context.crit_count)
      total_warn += context.warn_count
      total_crit += context.crit_count

    logger.overall_summary(total_warn, total_crit)

  if total_crit > 0:
    return 2
  if total_warn > 0:
    return 1
  return 0


__all__ = ["run_checks", "DEFAULT_CHECKS", "CheckDefinition"]
