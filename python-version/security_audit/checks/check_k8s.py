from __future__ import annotations

import json

from ..logging_utils import CheckContext
from ..utils import command_exists, run_command


def _privileged_containers(cluster_json: str) -> list[str]:
  try:
    data = json.loads(cluster_json)
  except json.JSONDecodeError:
    return []

  hits: list[str] = []
  for item in data.get("items", []):
    ns = item.get("metadata", {}).get("namespace", "default")
    pod_name = item.get("metadata", {}).get("name", "")
    containers = item.get("spec", {}).get("containers", [])
    for container in containers:
      security = container.get("securityContext") or {}
      if security.get("privileged") is True:
        hits.append(f"{ns} {pod_name} {container.get('name', '')}")
  return hits


def run(ctx: CheckContext) -> None:
  ctx.section("Kubernetes checks")

  if not command_exists("kubectl"):
    ctx.info("kubectl not found – skipping Kubernetes checks.")
    return

  try:
    cluster_result = run_command(["kubectl", "cluster-info"], check=False)
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"kubectl present but 'kubectl cluster-info' failed: {exc}")
    return

  if cluster_result.returncode != 0:
    ctx.warn("kubectl present but 'kubectl cluster-info' failed – no cluster context or auth issue.")
    return

  ctx.info("kubectl can reach a cluster.")
  try:
    version = run_command(["kubectl", "version", "--short"], check=False)
    for line in version.stdout.splitlines():
      ctx.info(line)
  except Exception:
    pass

  try:
    pods_json = run_command(["kubectl", "get", "pods", "-A", "-o", "json"], check=False)
  except Exception as exc:  # pylint: disable=broad-except
    ctx.warn(f"Failed to query pods for privileged containers: {exc}")
    return

  if pods_json.returncode != 0:
    ctx.warn("kubectl get pods returned non-zero; unable to assess privileged containers.")
    return

  privileged = _privileged_containers(pods_json.stdout)
  if privileged:
    ctx.crit("Privileged containers detected (namespace pod container):")
    for line in privileged:
      ctx.info(f"  {line}")
  else:
    ctx.info("No privileged containers detected via API scan.")
