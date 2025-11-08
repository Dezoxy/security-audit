"""
Python implementation of the DevSecOps security audit toolkit.

Modules under security_audit.checks mirror the Bash checks and expose a
`run(context)` function that receives a CheckContext with helpers for
structured logging plus WARN/CRIT tracking.
"""

from .orchestrator import run_checks  # re-export for convenience

__all__ = ["run_checks"]
