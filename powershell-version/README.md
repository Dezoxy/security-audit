# PowerShell Security Orchestrator

PowerShell port of the DevSecOps security audit toolkit. The entry script `Invoke-SecurityOrchestrator.ps1` mirrors the Bash/Python behavior: it discovers check scripts under `checks/`, runs them sequentially, logs WARN/CRIT counts, and emits exit codes `0/1/2` (OK/WARN/CRIT).

## Requirements

- PowerShell 7+ (`pwsh`) on Linux/macOS/Windows.
- Standard host utilities that each check inspects (`find`, `ss`, `systemctl`, `docker`, `kubectl`, etc.). Missing tooling only affects the corresponding check.
- Optional: `LOG_DIR` environment variable to relocate logs (default `powershell-version/logs/`).

## Layout

- `Invoke-SecurityOrchestrator.ps1` – CLI entry point (`pwsh ./Invoke-SecurityOrchestrator.ps1`).
- `lib/Common.psm1` – shared logger, section helpers, WARN/CRIT counters, command detection.
- `checks/*.ps1` – individual checks with the same focus areas as the Bash scripts (OS, updates, filesystem, network, logging, SSH, sudo, Docker, Kubernetes).

## Usage

List available checks without executing them:

```pwsh
cd powershell-version
pwsh ./Invoke-SecurityOrchestrator.ps1 -ListChecks
```

Run the full suite (writes `logs/security_orchestrator_<timestamp>.log` and maintains a `logs/latest.log` pointer):

```pwsh
cd powershell-version
pwsh ./Invoke-SecurityOrchestrator.ps1
```

Direct logs to a custom directory (useful on ephemeral hosts):

```pwsh
LOG_DIR=/tmp/security-audit-pwsh pwsh ./Invoke-SecurityOrchestrator.ps1
```

Exit codes match the other implementations:

| Code | Meaning                        |
|------|--------------------------------|
| 0    | No WARN/CRIT findings          |
| 1    | WARN(s) present, no CRIT       |
| 2    | At least one CRIT finding      |

## Extending

1. Add a new `checks/check_<topic>.ps1` script accepting `-Context` (see existing files).  
2. Use `Write-Section/Write-Info/Write-Warn/Write-Crit` from `Common.psm1` to log findings.  
3. Append the new script to `$Checks` in `Invoke-SecurityOrchestrator.ps1`. It will automatically participate in the run and aggregate WARN/CRIT totals.
