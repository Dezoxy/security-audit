param(
  [Parameter(Mandatory)]
  [pscustomobject]$Context
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot ".." "lib" "Common.psm1") -Force

function Test-SystemctlActive {
  param(
    [Parameter(Mandatory)]
    [string]$Service
  )

  if (-not (Test-CommandAvailable -Name "systemctl")) {
    return $null
  }

  & systemctl is-active --quiet $Service 2>$null
  return ($LASTEXITCODE -eq 0)
}

function Test-SystemctlStatus {
  param(
    [Parameter(Mandatory)]
    [string]$Service
  )

  if (-not (Test-CommandAvailable -Name "systemctl")) {
    return $false
  }

  & systemctl status $Service 2>$null
  return ($LASTEXITCODE -eq 0)
}

Write-Section "Logging & audit"

if (Test-CommandAvailable -Name "systemctl") {
  $journald = Test-SystemctlActive -Service "systemd-journald"
  if ($journald) {
    Write-Info "systemd-journald is active."
  }
  else {
    Write-Warn -Context $Context -Message "systemd-journald is not reported as active."
  }

  $rsyslog = Test-SystemctlActive -Service "rsyslog"
  if ($rsyslog) {
    Write-Info "rsyslog is active."
  }
  else {
    Write-Info "rsyslog not active (may be fine if journald is primary)."
  }
}
else {
  Write-Warn -Context $Context -Message "systemctl not available; cannot check journald/rsyslog status."
}

if ((Test-CommandAvailable -Name "auditctl") -or (Test-SystemctlStatus -Service "auditd")) {
  Write-Info "auditd/audit subsystem appears present; review rules with 'auditctl -l'."
}
else {
  Write-Warn -Context $Context -Message "No obvious audit subsystem detected (auditd/auditctl). Host-level auditing may be limited."
}
