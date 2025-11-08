#!/usr/bin/env python3
"""
Python entry point for the DevSecOps security orchestrator.
"""

from __future__ import annotations

import argparse
import sys

from security_audit.orchestrator import DEFAULT_CHECKS, run_checks


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(description="Run security posture checks.")
  parser.add_argument(
    "--list-checks",
    action="store_true",
    help="Show available checks and exit.",
  )
  return parser.parse_args()


def main() -> int:
  args = parse_args()
  if args.list_checks:
    for check in DEFAULT_CHECKS:
      print(f"{check.label}: {check.module}")
    return 0

  return run_checks()


if __name__ == "__main__":
  sys.exit(main())
