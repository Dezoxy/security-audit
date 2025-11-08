param(
  [Parameter(Mandatory)]
  [pscustomobject]$Context
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot ".." "lib" "Common.psm1") -Force

function Invoke-Kubectl {
  param(
    [Parameter(Mandatory)]
    [string[]]$Arguments
  )

  $output = & kubectl @Arguments 2>&1
  $code = $LASTEXITCODE
  return @{ Output = $output; ExitCode = $code }
}

Write-Section "Kubernetes checks"

if (-not (Test-CommandAvailable -Name "kubectl")) {
  Write-Info "kubectl not found – skipping Kubernetes checks."
  return
}

try {
  $cluster = Invoke-Kubectl -Arguments @("cluster-info")
}
catch {
  Write-Warn -Context $Context -Message "kubectl present but 'kubectl cluster-info' failed: $($_.Exception.Message)"
  return
}

if ($cluster.ExitCode -ne 0) {
  Write-Warn -Context $Context -Message "kubectl present but 'kubectl cluster-info' failed – no cluster context or auth issue."
  return
}

Write-Info "kubectl can reach a cluster."

try {
  $version = Invoke-Kubectl -Arguments @("version","--short")
  foreach ($line in $version.Output) {
    Write-Info $line
  }
}
catch {
  # best-effort; ignore errors here
}

try {
  $pods = Invoke-Kubectl -Arguments @("get","pods","-A","-o","json")
}
catch {
  Write-Warn -Context $Context -Message "Failed to query pods for privileged containers: $($_.Exception.Message)"
  return
}

if ($pods.ExitCode -ne 0) {
  Write-Warn -Context $Context -Message "kubectl get pods returned non-zero; unable to assess privileged containers."
  return
}

try {
  $data = ($pods.Output -join "`n") | ConvertFrom-Json -Depth 15
}
catch {
  Write-Warn -Context $Context -Message "Unable to parse kubectl JSON output: $($_.Exception.Message)"
  return
}

$privileged = @()
foreach ($item in $data.items) {
  $ns = $item.metadata.namespace
  $podName = $item.metadata.name
  foreach ($container in $item.spec.containers) {
    if ($container.securityContext -and $container.securityContext.privileged) {
      $privileged += "$ns $podName $($container.name)"
    }
  }
}

if ($privileged.Count -gt 0) {
  Write-Crit -Context $Context -Message "Privileged containers detected (namespace pod container):"
  foreach ($entry in $privileged) {
    Write-Info "  $entry"
  }
}
else {
  Write-Info "No privileged containers detected via API scan."
}
