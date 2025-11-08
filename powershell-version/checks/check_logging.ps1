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

if ($IsWindows) {
  try {
    $eventLogSvc = Get-Service -Name "eventlog" -ErrorAction Stop
    if ($eventLogSvc.Status -eq "Running") {
      Write-Info "Windows Event Log service is running."
    }
    else {
      Write-Warn -Context $Context -Message "Windows Event Log service status: $($eventLogSvc.Status)"
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Unable to query Windows Event Log service: $($_.Exception.Message)"
  }

  try {
    $collector = Get-Service -Name "Wecsvc" -ErrorAction Stop
    Write-Info "Windows Event Collector service status: $($collector.Status)"
  }
  catch {
    Write-Info "Windows Event Collector service not installed."
  }

  try {
    $coreLogs = Get-WinEvent -ListLog @("Application","Security","System") -ErrorAction Stop
    foreach ($log in $coreLogs) {
      $state = if ($log.IsEnabled) { "enabled" } else { "disabled" }
      Write-Info "Log $($log.LogName): $state, Retention=$($log.LogMode)"
      if (-not $log.IsEnabled) {
        Write-Warn -Context $Context -Message "Windows event log $($log.LogName) is disabled."
      }
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to query core Windows event logs: $($_.Exception.Message)"
  }

  if (Test-CommandAvailable -Name "auditpol") {
    try {
      $auditOutput = & auditpol /get /category:* 2>$null
      $noAuditLines = $auditOutput | Where-Object { $_ -match "No Auditing" }
      if ($noAuditLines) {
        Write-Warn -Context $Context -Message "Audit categories without coverage detected:"
        foreach ($line in $noAuditLines) {
          Write-Info "  $line"
        }
      }
      else {
        Write-Info "Auditpol reports categories configured."
      }
    }
    catch {
      Write-Warn -Context $Context -Message "Failed to run auditpol: $($_.Exception.Message)"
    }
  }
  else {
    Write-Warn -Context $Context -Message "auditpol not available; cannot inspect Windows audit policy."
  }
  return
}

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
