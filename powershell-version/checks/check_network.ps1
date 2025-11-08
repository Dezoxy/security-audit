param(
  [Parameter(Mandatory)]
  [pscustomobject]$Context
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot ".." "lib" "Common.psm1") -Force

function Invoke-CommandText {
  param(
    [Parameter(Mandatory)]
    [string]$Command,
    [string[]]$Arguments = @()
  )

  try {
    return (& $Command @Arguments 2>&1)
  }
  catch {
    throw $_
  }
}

Write-Section "Network & firewall"

Write-Info "Listening TCP/UDP ports (top 20 lines):"
$portCmd = $null
$portArgs = @()
if (Test-CommandAvailable -Name "ss") {
  $portCmd = "ss"
  $portArgs = @("-tulpen")
}
elseif (Test-CommandAvailable -Name "netstat") {
  $portCmd = "netstat"
  $portArgs = @("-tulpen")
}

if ($portCmd) {
  try {
    $ports = Invoke-CommandText -Command $portCmd -Arguments $portArgs
    foreach ($line in ($ports | Select-Object -First 20)) {
      Write-Info $line
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to list listening ports via $portCmd: $($_.Exception.Message)"
  }
}
else {
  Write-Warn -Context $Context -Message "Neither ss nor netstat available; cannot list listening ports."
}

Write-Info "Evaluating firewall status..."
if (Test-CommandAvailable -Name "ufw") {
  Write-Info "ufw detected."
  try {
    $status = Invoke-CommandText -Command "ufw" -Arguments @("status","verbose")
    foreach ($line in ($status | Select-Object -First 30)) {
      Write-Info $line
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to get ufw status: $($_.Exception.Message)"
  }
  return
}

if (Test-CommandAvailable -Name "firewall-cmd") {
  Write-Info "firewalld detected."
  try {
    $state = Invoke-CommandText -Command "firewall-cmd" -Arguments @("--state")
    if ($state -match "running") {
      Write-Info "firewalld is running."
      $detail = Invoke-CommandText -Command "firewall-cmd" -Arguments @("--list-all")
      foreach ($line in ($detail | Select-Object -First 30)) {
        Write-Info $line
      }
    }
    else {
      Write-Warn -Context $Context -Message "firewalld appears installed but not running."
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to query firewalld: $($_.Exception.Message)"
  }
  return
}

if (Test-CommandAvailable -Name "iptables") {
  Write-Warn -Context $Context -Message "No ufw/firewalld detected, but iptables exists. Showing top of rules:"
  try {
    $rules = Invoke-CommandText -Command "iptables" -Arguments @("-L","-n")
    foreach ($line in ($rules | Select-Object -First 30)) {
      Write-Info $line
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to dump iptables rules: $($_.Exception.Message)"
  }
  return
}

Write-Warn -Context $Context -Message "No firewall tooling detected (ufw/firewalld/iptables) – host may rely solely on upstream filtering."
