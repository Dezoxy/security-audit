# Security Audit Orchestrator

Cross-platform toolkit for quick host security posture reviews. The repository contains three feature-parity implementations (Bash, Python, PowerShell) that orchestrate modular checks covering OS basics, patch posture, filesystem hygiene, networking, logging/audit, SSH, privileged users, Docker, and Kubernetes. Each check emits colorized `[INFO|WARN|CRIT]` lines and returns `0=OK`, `1=WARN`, `2=CRIT`; the orchestrators aggregate these into run-wide exit codes and timestamped logs you can hand to auditors or plug into CI.

## Implementations

| Path | Runtime | Notes |
|------|---------|-------|
| `security_orchestrator.sh` + `checks/` + `lib/` | Bash 4+, GNU userland | Original POSIX edition; great for minimal Linux hosts and SSH automation. |
| `python-version/` | Python 3.10+ | Pure-stdlib implementation with package-based checks (`security_audit.*`) and `security_orchestrator.py` CLI. |
| `powershell-version/` | PowerShell 7+ (`pwsh`) | Works on Windows, Linux, macOS; adds Windows-aware checks (Update Agent, Defender Firewall, Event Logs, Administrators group). |

Pick the version that best matches the target environment—logic and output structure are aligned across all three.

## What gets checked

- **Host & OS** – hostname, OS/kernel, reboot-required flag (Linux) or service status (Windows).  
- **Package/Windows Updates** – apt/dnf/yum upgrades, Windows Update Agent criticals, COM-based severity.  
- **Filesystem & Permissions** – `find` scans for world-writable without sticky bit and SUID/SGID binaries, or ACL reviews on `%TEMP%`, `C:\Users\Public`, etc.  
- **Network & Firewall** – `ss`/`netstat` listeners plus ufw/firewalld/iptables or Windows Defender Firewall profile summaries.  
- **Logging & Audit** – journald/rsyslog/auditd status or Windows Event Log/Collector/auditpol coverage.  
- **SSH** – `sshd_config` hardening (PermitRootLogin, PasswordAuthentication, Protocol, empty passwords) for both Linux and Windows OpenSSH paths.  
- **Users & Sudo/Admins** – UID 0 accounts, locked users, sudoers `NOPASSWD`, or Windows local Administrators group/Built-in Administrator status.  
- **Docker** – daemon reachability, socket perms, running containers, privileged/root usage.  
- **Kubernetes** – `kubectl` context, version info, privileged pods via API (requires `jq` in Bash, JSON parsing in other ports).

## Repository layout

- `checks/`, `lib/`, `security_orchestrator.sh` – Bash scripts & helpers.  
- `python-version/security_audit/` – Python package (orchestrator, logging helpers, per-topic modules).  
- `python-version/security_orchestrator.py` – Python CLI entry point.  
- `powershell-version/Invoke-SecurityOrchestrator.ps1` – PowerShell runner.  
- `powershell-version/checks/`, `powershell-version/lib/` – PowerShell check modules and shared logger.  
- `logs/`, `python-version/logs/`, `powershell-version/logs/` (ignored by Git) – timestamped reports plus `latest.log` symlinks/pointers.

## Running the orchestrators

### Bash

```bash
./security_orchestrator.sh
# or relocate logs
LOG_DIR=/tmp/security-audit ./security_orchestrator.sh
```

### Python

```bash
cd python-version
./security_orchestrator.py          # run all checks
./security_orchestrator.py --list-checks
LOG_DIR=/tmp/security-audit-py ./security_orchestrator.py
```

Requires Python 3.10+ (std lib only). Optionally create a virtualenv if you add third-party packages later.

### PowerShell

```pwsh
cd powershell-version
pwsh ./Invoke-SecurityOrchestrator.ps1
pwsh ./Invoke-SecurityOrchestrator.ps1 -ListChecks
LOG_DIR=C:\Temp\audit pwsh ./Invoke-SecurityOrchestrator.ps1
```

Supports Windows and PowerShell 7+ on Linux/macOS. On Windows, run an elevated shell to let logging/audit checks read Security event logs.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | All checks OK |
| 1 | At least one WARN, no CRIT |
| 2 | At least one CRIT |

Use these in CI/CD or remote execution to gate deployments.

## Extending the toolkit

1. Copy an existing check into the relevant runtime (e.g., `checks/check_<topic>.sh`, `python-version/security_audit/checks/check_<topic>.py`, `powershell-version/checks/check_<topic>.ps1`).  
2. Source/import the shared logging helpers so you get `section/info/warn/crit` (Bash), `CheckContext` (Python), or the PowerShell `Common.psm1` functions.  
3. Return/exit with `0/1/2` to signal OK/WARN/CRIT.  
4. Add the new check to the orchestrator’s list (Bash discovers via filename; Python/PowerShell register in `DEFAULT_CHECKS` / `$Checks`).  
5. Update this README if the new check adds notable coverage.

## Contributing

1. Fork or branch, edit, and run the relevant orchestrator locally (`LOG_DIR` helps keep logs sandboxed).  
2. `git add` / `git commit` with descriptive messages.  
3. Send a PR describing the environment(s) you tested (Linux distro, Windows build, etc.).  
4. Keep shells POSIX-friendly and avoid GNU-only flags unless documented; follow PowerShell best practices for Windows-specific behavior.
