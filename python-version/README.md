# Python Security Orchestrator

Mirrors the Bash-based toolkit in a pure Python implementation. It loads the same logical checks (OS, updates, filesystem, network, logging, SSH, sudo, Docker, Kubernetes), aggregates WARN/CRIT counts, and writes timestamped logs.

## Requirements

- Python 3.10 or newer.
- Access to the host utilities each check relies on (`find`, `ss`, `systemctl`, `docker`, `kubectl`, etc.). Missing tooling only affects the respective check.

## Layout

- `security_orchestrator.py` – CLI entry point with `--list-checks` support.
- `security_audit/` – Python package containing:
  - `orchestrator.py` – shared runner, log handling, exit codes.
  - `logging_utils.py` – tee logger with WARN/CRIT counting helpers.
  - `checks/` – one module per security check, mirroring the Bash scripts.

Logs default to `python-version/logs/`, but you can override with `LOG_DIR`.

## Usage

```bash
cd python-version
./security_orchestrator.py
```

Inspect available checks without running them:

```bash
./security_orchestrator.py --list-checks
```

Change the log destination (useful for CI runners or sandboxed environments):

```bash
LOG_DIR=/tmp/security-audit-python ./security_orchestrator.py
```

Exit codes follow the same convention as the Bash version:

| Code | Meaning                         |
|------|---------------------------------|
| 0    | All checks OK                   |
| 1    | At least one WARN, no CRIT      |
| 2    | At least one CRIT finding       |

Extend by dropping a new module under `security_audit/checks/` that exposes `run(context)`; add it to `DEFAULT_CHECKS` in `security_audit/orchestrator.py` if ordering matters.
