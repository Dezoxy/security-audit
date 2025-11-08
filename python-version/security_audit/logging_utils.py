from __future__ import annotations

import os
import sys
import traceback
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO


def _color(code: str, enabled: bool) -> str:
  return code if enabled else ""


class TeeLogger:
  """Writes messages to stdout and a log file simultaneously."""

  def __init__(self, log_path: Path):
    self.log_path = log_path
    self.handle: TextIO | None = None
    self.use_color = sys.stdout.isatty()
    self.debug_enabled = os.environ.get("DEBUG") == "1"
    self.colors = {
      "reset": "\033[0m" if self.use_color else "",
      "bold": "\033[1m" if self.use_color else "",
      "blue": "\033[34m" if self.use_color else "",
      "green": "\033[32m" if self.use_color else "",
      "yellow": "\033[33m" if self.use_color else "",
      "red": "\033[31m" if self.use_color else "",
    }

  def __enter__(self) -> "TeeLogger":
    self.handle = self.log_path.open("a", encoding="utf-8")
    return self

  def __exit__(self, exc_type, exc, tb):
    if self.handle:
      self.handle.close()
    return False

  def _write(self, message: str) -> None:
    print(message)
    if self.handle:
      self.handle.write(f"{self._strip_ansi(message)}\n")
      self.handle.flush()

  def _strip_ansi(self, text: str) -> str:
    if not self.use_color:
      return text
    # Rough removal of ANSI sequences.
    import re

    return re.sub(r"\x1B\[[0-?]*[ -/]*[@-~]", "", text)

  def banner(self, title: str, base_dir: Path, log_file: Path) -> None:
    lines = [
      "=" * 50,
      f"{title}",
      f"Base dir: {base_dir}",
      f"Log file: {log_file}",
      "=" * 50,
      "",
      f"Starting run at: {self._timestamp()}",
      "",
    ]
    for line in lines:
      self._write(line)

  def sep(self, label: str) -> None:
    self._write("")
    line = f"▶ Running check: {label}"
    self._write(line)
    self._write("-" * 50)

  def section(self, title: str) -> None:
    self._write(f"{self.colors['bold']}== {title} =={self.colors['reset']}")

  def info(self, message: str) -> None:
    prefix = f"{self.colors['blue']}[INFO]{self.colors['reset']}" if self.use_color else "[INFO]"
    self._write(f"{prefix} {message}")

  def warn(self, message: str) -> None:
    prefix = f"{self.colors['yellow']}[WARN]{self.colors['reset']}" if self.use_color else "[WARN]"
    self._write(f"{prefix} {message}")

  def crit(self, message: str) -> None:
    prefix = f"{self.colors['red']}[CRIT]{self.colors['reset']}" if self.use_color else "[CRIT]"
    self._write(f"{prefix} {message}")

  def check_summary(self, label: str, warn_count: int, crit_count: int) -> None:
    self._write(f"Summary ({label}): WARN={warn_count}, CRIT={crit_count}")

  def overall_summary(self, warn_total: int, crit_total: int) -> None:
    self._write("")
    self._write("=" * 50)
    self._write("Overall summary:")
    self._write(f"  Checks with WARN : {warn_total}")
    self._write(f"  Checks with CRIT : {crit_total}")
    self._write(f"  Finished at: {self._timestamp()}")
    self._write("=" * 50)

  def debug(self, title: str, exc: Exception) -> None:
    if not self.debug_enabled:
      return
    self._write(f"[DEBUG] {title}: {exc}")
    self._write("".join(traceback.format_exception(exc)))

  def _timestamp(self) -> str:
    from datetime import datetime

    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S%z")


@dataclass
class CheckContext:
  label: str
  logger: TeeLogger
  warn_count: int = 0
  crit_count: int = 0

  def section(self, title: str) -> None:
    self.logger.section(title)

  def info(self, message: str) -> None:
    self.logger.info(message)

  def warn(self, message: str) -> None:
    self.warn_count += 1
    self.logger.warn(message)

  def crit(self, message: str) -> None:
    self.crit_count += 1
    self.logger.crit(message)
