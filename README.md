# Security Audit Orchestrator

Lightweight Bash toolkit that strings together a handful of host security posture checks. The top-level `security_orchestrator.sh` script discovers each `checks/check_*.sh`, runs them in sequence, captures WARN/CRIT counters, and writes consolidated logs you can hand to an auditor or keep for drift reviews.  
Looking for other runtimes? See `python-version/` (pure Python) and `powershell-version/` (PowerShell 7+) for feature-parity ports with their own READMEs.

## What it checks

- **Host & OS (`check_os.sh`)** – hostname, OS/kernel info, pending reboot flag.  
- **Package updates (`check_updates.sh`)** – apt/dnf/yum awareness, highlights pending (security) updates.  
- **Filesystem (`check_filesystem.sh`)** – world-writable directories without sticky bit, SUID/SGID binaries in standard and custom paths.  
- **Network & firewall (`check_network.sh`)** – listening services plus ufw/firewalld/iptables status.  
- **Logging & audit (`check_logging.sh`)** – journald/rsyslog health and auditd presence.  
- **SSH (`check_ssh.sh`)** – risky `sshd_config` toggles (root login, passwords, protocol, empty passwords).  
- **Users & sudo (`check_sudo.sh`)** – UID 0 accounts, locked users, lax `NOPASSWD` sudo rules.  
- **Docker (`check_docker.sh`)** – daemon reachability, socket perms, root/privileged containers.  
- **Kubernetes (`check_k8s.sh`)** – verifies `kubectl` context, prints versions, flags privileged pods when `jq` is available.

Each check script exits with `0=OK`, `1=WARN`, `2=CRIT` and shares the colorized logging helpers in `lib/common.sh`.

## Repository layout

- `security_orchestrator.sh` – main entry point that runs every check, aggregates exit codes, and saves logs.  
- `checks/` – individual, focused check scripts (can be run standalone).  
- `lib/common.sh` – logging helpers, WARN/CRIT counters, color output.  
- `logs/` – runtime output (ignored by Git) with timestamped reports and a `latest.log` symlink.

## Requirements

- Bash 4+, standard GNU userland tools (`awk`, `sed`, `find`, `grep`, `stat`, etc.).  
- Privileged read access when inspecting `/etc/shadow`, `/etc/sudoers`, `docker.sock`, etc.  
- Optional tooling per check: `apt/apt-get`, `dnf`, `yum`, `ss netstat`, `systemctl`, `docker`, `kubectl`, `jq`, `firewall-cmd`, `ufw`, `iptables`.

## Usage

Run everything (writes to `logs/security_orchestrator_<timestamp>.log` and keeps a `logs/latest.log` symlink):

```bash
./security_orchestrator.sh
```

Interpret the orchestrator exit status to make CI/CD decisions:

| Exit code | Meaning                         |
|-----------|---------------------------------|
| 0         | No WARN or CRIT findings        |
| 1         | At least one WARN, no CRITs     |
| 2         | At least one CRIT finding       |

Run a single check while developing or troubleshooting:

```bash
checks/check_network.sh
```

Point logs elsewhere (for ephemeral CI runners) by setting `LOG_DIR`:

```bash
LOG_DIR=/tmp/security-audit ./security_orchestrator.sh
```

## Extending the toolkit

1. Drop a new executable `checks/check_<topic>.sh`.  
2. Source `lib/common.sh`, call `reset_counts`, and use `section/info/warn/crit`.  
3. Return `0/1/2` like the existing checks. The orchestrator will pick it up automatically.
