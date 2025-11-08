from __future__ import annotations

import json
import pwd
import grp
from pathlib import Path

from ..logging_utils import CheckContext
from ..utils import command_exists, run_command


def _docker_sock_info(ctx: CheckContext) -> None:
  sock = Path("/var/run/docker.sock")
  if not sock.exists():
    return
  try:
    stat_result = sock.stat()
    perms = oct(stat_result.st_mode & 0o777)
    owner = pwd.getpwuid(stat_result.st_uid).pw_name
    group = grp.getgrgid(stat_result.st_gid).gr_name
    ctx.info(f"docker.sock perms: {perms} {owner}:{group}")
  except Exception:  # pylint: disable=broad-except
    ctx.warn("Unable to read docker.sock permissions.")


def _inspect_container(container_id: str) -> dict:
  result = run_command(["docker", "inspect", container_id])
  data = json.loads(result.stdout)
  if isinstance(data, list):
    return data[0]
  return data


def run(ctx: CheckContext) -> None:
  ctx.section("Docker / container runtime")

  if not command_exists("docker"):
    ctx.info("Docker CLI not found – skipping Docker checks.")
    return

  try:
    info_result = run_command(["docker", "info"], check=False)
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"Docker CLI present but 'docker info' failed: {exc}")
    return

  if info_result.returncode != 0:
    ctx.warn("Docker CLI present but 'docker info' failed (daemon not running or insufficient permissions).")
    return

  ctx.info("Docker daemon reachable.")
  _docker_sock_info(ctx)

  try:
    running = run_command(["docker", "ps", "--format", "{{.ID}} {{.Image}} {{.Names}}"])
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"Failed to list running containers: {exc}")
    return

  lines = [line.strip() for line in running.stdout.splitlines() if line.strip()]
  if not lines:
    ctx.info("No running containers.")
    return

  ctx.info("Running containers:")
  for line in lines:
    ctx.info(f"  {line}")

  for line in lines:
    parts = line.split(maxsplit=2)
    if len(parts) < 3:
      continue
    container_id, image, name = parts
    try:
      inspect = _inspect_container(container_id)
    except Exception as exc:  # pylint: disable=broad-except
      ctx.warn(f"Failed to inspect container {name}: {exc}")
      continue

    user = (inspect.get("Config", {}) or {}).get("User") or "(default/root)"
    privileged = (inspect.get("HostConfig", {}) or {}).get("Privileged", False)

    if user in {"0", "root", "", "(default/root)"}:
      ctx.warn(f"Container {name} ({image}) is running as root (User={user}). Consider using non-root user.")
    if privileged:
      ctx.crit(f"Container {name} ({image}) is running in privileged mode.")
