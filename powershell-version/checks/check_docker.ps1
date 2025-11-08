param(
  [Parameter(Mandatory)]
  [pscustomobject]$Context
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot ".." "lib" "Common.psm1") -Force

function Invoke-DockerCommand {
  param(
    [Parameter(Mandatory)]
    [string[]]$Arguments
  )

  $output = & docker @Arguments 2>&1
  $code = $LASTEXITCODE
  return @{ Output = $output; ExitCode = $code }
}

Write-Section "Docker / container runtime"

if (-not (Test-CommandAvailable -Name "docker")) {
  Write-Info "Docker CLI not found – skipping Docker checks."
  return
}

try {
  $info = Invoke-DockerCommand -Arguments @("info")
}
catch {
  Write-Warn -Context $Context -Message "Docker CLI present but 'docker info' failed: $($_.Exception.Message)"
  return
}

if ($info.ExitCode -ne 0) {
  Write-Warn -Context $Context -Message "Docker CLI present but 'docker info' failed (daemon not running or insufficient permissions)."
  return
}

Write-Info "Docker daemon reachable."

$dockerSock = "/var/run/docker.sock"
if (Test-Path $dockerSock) {
  try {
    $item = Get-Item $dockerSock
    $acl = Get-Acl $dockerSock
    $mode = $item.Mode
    $owner = $acl.Owner
    $group = $acl.Group
    Write-Info "docker.sock perms: $mode ${owner}:${group}"
  }
  catch {
    Write-Warn -Context $Context -Message "Unable to read docker.sock permissions: $($_.Exception.Message)"
  }
}

try {
  $running = Invoke-DockerCommand -Arguments @("ps","--format","{{.ID}} {{.Image}} {{.Names}}")
}
catch {
  Write-Warn -Context $Context -Message "Failed to list running containers: $($_.Exception.Message)"
  return
}

$containers = $running.Output | Where-Object { $_ -and $_.Trim() }
if (-not $containers -or $containers.Count -eq 0) {
  Write-Info "No running containers."
  return
}

Write-Info "Running containers:"
foreach ($line in $containers) {
  Write-Info "  $line"
}

foreach ($line in $containers) {
  $parts = $line -split "\s+",3
  if ($parts.Count -lt 3) { continue }
  $id = $parts[0]
  $image = $parts[1]
  $name = $parts[2]

  try {
    $inspectRaw = & docker inspect $id 2>$null
    $inspect = $inspectRaw | ConvertFrom-Json -Depth 10
    if ($inspect -is [array]) {
      $inspect = $inspect[0]
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to inspect container ${name}: $($_.Exception.Message)"
    continue
  }

  $user = $inspect.Config.User
  if (-not $user) { $user = "(default/root)" }
  $privileged = $inspect.HostConfig.Privileged

  if ($user -eq "0" -or $user -eq "root" -or $user -eq "(default/root)" -or $user -eq "") {
    Write-Warn -Context $Context -Message "Container $name ($image) is running as root (User=$user). Consider using non-root user."
  }
  if ($privileged) {
    Write-Crit -Context $Context -Message "Container $name ($image) is running in privileged mode."
  }
}
