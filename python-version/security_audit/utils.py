from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
from pathlib import Path
from typing import Iterable, Sequence


def command_exists(cmd: str) -> bool:
  return shutil.which(cmd) is not None


def run_command(
  args: Sequence[str],
  *,
  check: bool = False,
  capture: bool = True,
  timeout: int | None = None,
  env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess:
  return subprocess.run(  # noqa: S603
    args,
    check=check,
    capture_output=capture,
    text=True,
    timeout=timeout,
    env=env,
  )


def tail_text(text: str, max_lines: int) -> str:
  lines = text.strip().splitlines()
  return "\n".join(lines[:max_lines])


def head_file(path: Path, max_lines: int = 20) -> str:
  if not path.exists():
    return ""
  lines: list[str] = []
  with path.open(encoding="utf-8", errors="ignore") as handle:
    for _, line in zip(range(max_lines), handle):
      lines.append(line.rstrip())
  return "\n".join(lines)


def read_json(text: str):
  return json.loads(text) if text.strip() else None


def format_command(args: Sequence[str]) -> str:
  return " ".join(shlex.quote(part) for part in args)
